package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.api.dto.PublishEventRequest;
import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.service.EventPublisher;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.Map;

/**
 * Internal API for publishing events
 * Used by worker scripts to publish events to the event store
 */
@Path("/internal/events")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Internal Events", description = "Internal API for event publishing (worker integration)")
public class InternalEventsResource {

    @Inject
    EventPublisher eventPublisher;

    /**
     * Publish issue.detected event
     */
    @POST
    @Path("/issue-detected")
    @Operation(summary = "Publish issue detected event")
    public Uni<Response> issueDetected(@Valid PublishEventRequest request) {
        return eventPublisher.publishIssueDetected(request.getIssueNumber(), request.getMetadata())
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish issue.claimed event
     */
    @POST
    @Path("/issue-claimed")
    @Operation(summary = "Publish issue claimed event")
    public Uni<Response> issueClaimed(@Valid PublishEventRequest request) {
        return eventPublisher.publishIssueClaimed(request.getIssueNumber(), request.getMetadata())
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish admission.started event
     */
    @POST
    @Path("/admission-started")
    @Operation(summary = "Publish admission started event")
    public Uni<Response> admissionStarted(@Valid PublishEventRequest request) {
        return eventPublisher.publishAdmissionStarted(request.getIssueNumber())
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish admission.completed event
     */
    @POST
    @Path("/admission-completed")
    @Operation(summary = "Publish admission completed event")
    public Uni<Response> admissionCompleted(@Valid PublishEventRequest request) {
        String decision = (String) request.getMetadata().get("decision");
        String reason = (String) request.getMetadata().get("reason");

        return eventPublisher.publishAdmissionCompleted(request.getIssueNumber(), decision, reason)
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish implementation.started event
     */
    @POST
    @Path("/implementation-started")
    @Operation(summary = "Publish implementation started event")
    public Uni<Response> implementationStarted(@Valid PublishEventRequest request) {
        return eventPublisher.publishImplementationStarted(request.getIssueNumber())
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish implementation.completed event
     */
    @POST
    @Path("/implementation-completed")
    @Operation(summary = "Publish implementation completed event")
    public Uni<Response> implementationCompleted(@Valid PublishEventRequest request) {
        Long durationMs = getLongFromMetadata(request.getMetadata(), "duration_ms", 0L);
        Integer filesChanged = getIntFromMetadata(request.getMetadata(), "files_changed", 0);

        return eventPublisher.publishImplementationCompleted(
                request.getIssueNumber(), durationMs, filesChanged)
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish pr.created event
     */
    @POST
    @Path("/pr-created")
    @Operation(summary = "Publish PR created event")
    public Uni<Response> prCreated(@Valid PublishEventRequest request) {
        String prUrl = (String) request.getMetadata().get("pr_url");

        return eventPublisher.publishPRCreated(
                request.getIssueNumber(), request.getPrNumber(), prUrl)
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Publish error.occurred event
     */
    @POST
    @Path("/error")
    @Operation(summary = "Publish error event")
    public Uni<Response> error(@Valid PublishEventRequest request) {
        String errorMessage = (String) request.getMetadata().get("error_message");

        return eventPublisher.publishError(request.getIssueNumber(), errorMessage)
            .map(event -> Response.ok(toResponse(event)).build());
    }

    /**
     * Generic publish endpoint
     */
    @POST
    @Path("/publish")
    @Operation(summary = "Generic event publish endpoint")
    public Uni<Response> publish(@Valid PublishEventRequest request) {
        // Route to specific method based on event type
        return switch (request.getEventType()) {
            case "issue.detected" -> issueDetected(request);
            case "issue.claimed" -> issueClaimed(request);
            case "admission.started" -> admissionStarted(request);
            case "admission.completed" -> admissionCompleted(request);
            case "implementation.started" -> implementationStarted(request);
            case "implementation.completed" -> implementationCompleted(request);
            case "pr.created" -> prCreated(request);
            case "error.occurred" -> error(request);
            default -> Uni.createFrom().item(
                Response.status(Response.Status.BAD_REQUEST)
                    .entity(Map.of("error", "Unknown event type: " + request.getEventType()))
                    .build()
            );
        };
    }

    // Helper methods

    private Map<String, Object> toResponse(AISDLCEvent event) {
        return Map.of(
            "event_id", event.getEventId().toString(),
            "tracking_id", event.getTrackingId(),
            "event_type", event.getEventType(),
            "issue_number", event.getIssueNumber(),
            "status", event.getStatus().toString()
        );
    }

    private Long getLongFromMetadata(Map<String, Object> metadata, String key, Long defaultValue) {
        Object value = metadata.get(key);
        if (value instanceof Number) {
            return ((Number) value).longValue();
        }
        return defaultValue;
    }

    private Integer getIntFromMetadata(Map<String, Object> metadata, String key, Integer defaultValue) {
        Object value = metadata.get(key);
        if (value instanceof Number) {
            return ((Number) value).intValue();
        }
        return defaultValue;
    }
}
