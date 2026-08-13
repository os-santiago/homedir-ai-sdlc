package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.projection.EventProjection;
import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;
import java.util.Map;

/**
 * Public REST API for event queries
 * Read-only access to event projections and analytics
 */
@Path("/api/events")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Events API", description = "Query events, timelines, and analytics")
public class EventsResource {

    @Inject
    EventQueryService queryService;

    /**
     * Get recent events across all issues
     */
    @GET
    @Path("/recent")
    @Operation(summary = "Get recent events", description = "Returns the most recent events across all issues")
    @APIResponse(responseCode = "200", description = "Recent events",
        content = @Content(schema = @Schema(implementation = EventProjection.class)))
    public Uni<List<EventProjection>> getRecentEvents(
        @Parameter(description = "Maximum number of events to return")
        @QueryParam("limit") @DefaultValue("50") int limit
    ) {
        if (limit > 500) {
            limit = 500; // Cap at 500
        }
        return queryService.getRecentEvents(limit);
    }

    /**
     * Get timeline for a specific issue
     */
    @GET
    @Path("/timeline/{issueNumber}")
    @Operation(summary = "Get issue timeline", description = "Returns chronological event flow for an issue")
    @APIResponse(responseCode = "200", description = "Issue timeline")
    @APIResponse(responseCode = "404", description = "Issue not found")
    public Uni<List<EventProjection>> getIssueTimeline(
        @Parameter(description = "GitHub issue number", required = true)
        @PathParam("issueNumber") Integer issueNumber
    ) {
        return queryService.getIssueTimeline(issueNumber);
    }

    /**
     * Get events by stage
     */
    @GET
    @Path("/stage/{stage}")
    @Operation(summary = "Get events by stage", description = "Returns events in a specific pipeline stage")
    @APIResponse(responseCode = "200", description = "Events in stage")
    public Uni<List<EventProjection>> getEventsByStage(
        @Parameter(description = "Pipeline stage (DETECTION, ADMISSION, IMPLEMENTATION, PR_MANAGEMENT, CI_CHECKS, ERROR)",
            required = true)
        @PathParam("stage") EventStage stage,

        @Parameter(description = "Maximum number of events to return")
        @QueryParam("limit") @DefaultValue("100") int limit
    ) {
        if (limit > 500) {
            limit = 500;
        }
        return queryService.getEventsByStage(stage, limit);
    }

    /**
     * Get failed events
     */
    @GET
    @Path("/failed")
    @Operation(summary = "Get failed events", description = "Returns events with FAILED status for investigation")
    @APIResponse(responseCode = "200", description = "Failed events")
    public Uni<List<EventProjection>> getFailedEvents(
        @Parameter(description = "Maximum number of events to return")
        @QueryParam("limit") @DefaultValue("100") int limit
    ) {
        if (limit > 500) {
            limit = 500;
        }
        return queryService.getFailedEvents(limit);
    }

    /**
     * Get events by tracking ID
     */
    @GET
    @Path("/tracking/{trackingId}")
    @Operation(summary = "Get events by tracking ID", description = "Returns all events for a tracking session")
    @APIResponse(responseCode = "200", description = "Events for tracking ID")
    public Uni<List<EventProjection>> getEventsByTracking(
        @Parameter(description = "Tracking ID (format: track_ISSUE_TIMESTAMP)", required = true)
        @PathParam("trackingId") String trackingId
    ) {
        return queryService.getEventsByTracking(trackingId);
    }

    /**
     * Get active issues
     */
    @GET
    @Path("/active")
    @Operation(summary = "Get active issues", description = "Returns currently in-progress issues")
    @APIResponse(responseCode = "200", description = "Active issues")
    public Uni<List<Map<String, Object>>> getActiveIssues() {
        return queryService.getActiveIssues();
    }

    /**
     * Get stage statistics
     */
    @GET
    @Path("/statistics/stages")
    @Operation(summary = "Get stage statistics", description = "Returns aggregated metrics per pipeline stage")
    @APIResponse(responseCode = "200", description = "Stage statistics")
    public Uni<List<Map<String, Object>>> getStageStatistics() {
        return queryService.getStageStatistics();
    }

    /**
     * Get admission decisions summary
     */
    @GET
    @Path("/statistics/admission-decisions")
    @Operation(summary = "Get admission decisions summary", description = "Returns breakdown of ACCEPT/REJECT/DEFER decisions")
    @APIResponse(responseCode = "200", description = "Admission decisions")
    public Uni<Map<String, Long>> getAdmissionDecisions() {
        return queryService.getAdmissionDecisionsSummary();
    }

    /**
     * Get error rate by stage
     */
    @GET
    @Path("/statistics/error-rate")
    @Operation(summary = "Get error rate by stage", description = "Returns error percentage per pipeline stage")
    @APIResponse(responseCode = "200", description = "Error rates")
    public Uni<List<Map<String, Object>>> getErrorRate() {
        return queryService.getErrorRateByStage();
    }

    /**
     * Get issue throughput
     */
    @GET
    @Path("/statistics/throughput")
    @Operation(summary = "Get issue throughput", description = "Returns issues completed per day")
    @APIResponse(responseCode = "200", description = "Throughput metrics")
    public Uni<List<Map<String, Object>>> getThroughput(
        @Parameter(description = "Number of days to analyze")
        @QueryParam("days") @DefaultValue("30") int days
    ) {
        if (days > 365) {
            days = 365; // Cap at 1 year
        }
        return queryService.getIssueThroughput(days);
    }

    /**
     * Get projection count (health check)
     */
    @GET
    @Path("/count")
    @Operation(summary = "Get projection count", description = "Returns total number of event projections (health check)")
    @APIResponse(responseCode = "200", description = "Projection count")
    public Uni<Map<String, Long>> getCount() {
        return queryService.countProjections()
            .map(count -> Map.of("count", count));
    }
}
