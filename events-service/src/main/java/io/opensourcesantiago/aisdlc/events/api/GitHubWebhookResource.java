package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.command.EventCommandService;
import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.quarkus.hibernate.reactive.panache.common.WithTransaction;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Uni;
import io.vertx.core.json.JsonObject;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * GitHub Webhook endpoint to capture REAL events from GitHub repository
 * This enables production-ready E2E testing with actual GitHub data
 */
@Path("/api/webhook/github")
@Tag(name = "GitHub Webhook", description = "Capture real GitHub events")
public class GitHubWebhookResource {

    @Inject
    EventCommandService commandService;

    /**
     * Process GitHub issue event
     * Called when an issue is opened, edited, closed, etc.
     */
    @POST
    @Path("/issues")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @WithTransaction
    @Operation(summary = "GitHub Issue Webhook",
               description = "Receives GitHub issue webhooks and creates detection events")
    public Uni<Response> handleIssueEvent(JsonObject payload) {
        Log.infof("Received GitHub issue webhook: %s", payload.getString("action"));

        String action = payload.getString("action");
        JsonObject issue = payload.getJsonObject("issue");

        if (issue == null) {
            return Uni.createFrom().item(Response.status(400).entity("Missing issue data").build());
        }

        Integer issueNumber = issue.getInteger("number");
        String trackingId = "gh-issue-" + issueNumber;

        // Create detection event from real GitHub data
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source", "github_webhook");
        metadata.put("action", action);
        metadata.put("title", issue.getString("title"));
        metadata.put("author", issue.getJsonObject("user").getString("login"));
        metadata.put("created_at", issue.getString("created_at"));
        metadata.put("url", issue.getString("html_url"));

        // Extract labels if present
        if (issue.containsKey("labels")) {
            metadata.put("labels", issue.getJsonArray("labels").getList());
        }

        return commandService.publishEvent(
            trackingId,
            "webhook-" + UUID.randomUUID().toString().substring(0, 8),
            "detection.github_issue_" + action,
            issueNumber,
            null,
            EventStatus.COMPLETED,
            EventStage.DETECTION,
            metadata
        ).map(event -> Response.ok(new JsonObject()
            .put("status", "Event recorded")
            .put("event_id", event.getEventId().toString())
            .put("tracking_id", trackingId)
            .put("issue_number", issueNumber)
        ).build());
    }

    /**
     * Process GitHub PR event
     * Called when a PR is opened, closed, merged, etc.
     */
    @POST
    @Path("/pull_request")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @WithTransaction
    @Operation(summary = "GitHub PR Webhook",
               description = "Receives GitHub PR webhooks and creates PR events")
    public Uni<Response> handlePullRequestEvent(JsonObject payload) {
        Log.infof("Received GitHub PR webhook: %s", payload.getString("action"));

        String action = payload.getString("action");
        JsonObject pr = payload.getJsonObject("pull_request");

        if (pr == null) {
            return Uni.createFrom().item(Response.status(400).entity("Missing PR data").build());
        }

        Integer prNumber = pr.getInteger("number");
        Integer issueNumber = extractIssueNumber(pr.getString("title"), pr.getString("body"));
        String trackingId = issueNumber != null ? "gh-issue-" + issueNumber : "gh-pr-" + prNumber;

        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source", "github_webhook");
        metadata.put("action", action);
        metadata.put("pr_title", pr.getString("title"));
        metadata.put("pr_url", pr.getString("html_url"));
        metadata.put("author", pr.getJsonObject("user").getString("login"));
        metadata.put("created_at", pr.getString("created_at"));
        metadata.put("merged", pr.getBoolean("merged", false));

        if (pr.containsKey("merged_at") && pr.getString("merged_at") != null) {
            metadata.put("merged_at", pr.getString("merged_at"));
        }

        EventStage stage = "closed".equals(action) && pr.getBoolean("merged", false)
            ? EventStage.PR_MANAGEMENT
            : EventStage.PR_MANAGEMENT;

        EventStatus status = "closed".equals(action) ? EventStatus.COMPLETED : EventStatus.IN_PROGRESS;

        String eventType = "merged".equals(action) || (pr.getBoolean("merged", false) && "closed".equals(action))
            ? "pr.merged"
            : "pr." + action;

        return commandService.publishEvent(
            trackingId,
            "webhook-" + UUID.randomUUID().toString().substring(0, 8),
            eventType,
            issueNumber != null ? issueNumber : prNumber,
            prNumber,
            status,
            stage,
            metadata
        ).map(event -> Response.ok(new JsonObject()
            .put("status", "Event recorded")
            .put("event_id", event.getEventId().toString())
            .put("tracking_id", trackingId)
            .put("pr_number", prNumber)
        ).build());
    }

    /**
     * Manual event ingestion for E2E testing
     * Allows posting custom events directly
     */
    @POST
    @Path("/manual")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @WithTransaction
    @Operation(summary = "Manual Event Ingestion",
               description = "Create custom events for testing (production-ready data)")
    public Uni<Response> manualEvent(JsonObject request) {
        String trackingId = request.getString("tracking_id");
        String eventType = request.getString("event_type");
        Integer issueNumber = request.getInteger("issue_number");
        Integer prNumber = request.getInteger("pr_number");
        String stageStr = request.getString("stage");
        String statusStr = request.getString("status");

        EventStage stage = EventStage.valueOf(stageStr);
        EventStatus status = EventStatus.valueOf(statusStr);

        Map<String, Object> metadata = request.getJsonObject("metadata") != null
            ? request.getJsonObject("metadata").getMap()
            : new HashMap<>();

        return commandService.publishEvent(
            trackingId,
            "manual-" + UUID.randomUUID().toString().substring(0, 8),
            eventType,
            issueNumber,
            prNumber,
            status,
            stage,
            metadata
        ).map(event -> Response.ok(new JsonObject()
            .put("status", "Event created")
            .put("event_id", event.getEventId().toString())
        ).build());
    }

    /**
     * Extract issue number from PR title or body (e.g., "#1008", "fixes #1008")
     */
    private Integer extractIssueNumber(String title, String body) {
        String text = (title != null ? title : "") + " " + (body != null ? body : "");
        java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("#(\\d+)");
        java.util.regex.Matcher matcher = pattern.matcher(text);
        if (matcher.find()) {
            return Integer.parseInt(matcher.group(1));
        }
        return null;
    }
}
