package io.opensourcesantiago.aisdlc.events;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * REST API for querying AI-SDLC events
 * Provides endpoints to track issue lifecycle through event streams
 */
@Path("/api/sdlc/events")
@Produces(MediaType.APPLICATION_JSON)
public class EventApiResource {

    @ConfigProperty(name = "sdlc.state-dir", defaultValue = "/var/lib/homedir-sdlc")
    String stateDir;

    @Inject
    EventQueryService eventQueryService;

    /**
     * Get all events for a specific tracking ID
     *
     * GET /api/sdlc/events/track/{trackingId}
     */
    @GET
    @Path("/track/{trackingId}")
    public Response getEventsByTrackingId(@PathParam("trackingId") String trackingId) {
        try {
            List<Map<String, Object>> events = eventQueryService.getEventsByTrackingId(trackingId);
            return Response.ok(events).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get all events for a specific issue number
     *
     * GET /api/sdlc/events/issue/{issueNumber}
     */
    @GET
    @Path("/issue/{issueNumber}")
    public Response getEventsByIssue(@PathParam("issueNumber") int issueNumber) {
        try {
            String trackingId = eventQueryService.getTrackingIdForIssue(issueNumber);
            if (trackingId == null) {
                return Response.status(404)
                    .entity(Map.of("error", "No tracking ID found for issue " + issueNumber))
                    .build();
            }

            List<Map<String, Object>> events = eventQueryService.getEventsByTrackingId(trackingId);
            return Response.ok(Map.of(
                "issue_number", issueNumber,
                "tracking_id", trackingId,
                "events", events
            )).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get latest N events across all issues
     *
     * GET /api/sdlc/events/latest?limit=100
     */
    @GET
    @Path("/latest")
    public Response getLatestEvents(@QueryParam("limit") @DefaultValue("100") int limit) {
        try {
            List<Map<String, Object>> events = eventQueryService.getLatestEvents(limit);
            return Response.ok(events).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get events by stage
     *
     * GET /api/sdlc/events/stage/{stage}?limit=100
     */
    @GET
    @Path("/stage/{stage}")
    public Response getEventsByStage(
            @PathParam("stage") String stage,
            @QueryParam("limit") @DefaultValue("100") int limit) {
        try {
            List<Map<String, Object>> events = eventQueryService.getEventsByStage(stage, limit);
            return Response.ok(Map.of(
                "stage", stage,
                "events", events
            )).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get event timeline for an issue (formatted for visualization)
     *
     * GET /api/sdlc/events/timeline/{issueNumber}
     */
    @GET
    @Path("/timeline/{issueNumber}")
    public Response getEventTimeline(@PathParam("issueNumber") int issueNumber) {
        try {
            Map<String, Object> timeline = eventQueryService.getEventTimeline(issueNumber);
            return Response.ok(timeline).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get event statistics
     *
     * GET /api/sdlc/events/stats
     */
    @GET
    @Path("/stats")
    public Response getEventStats() {
        try {
            Map<String, Object> stats = eventQueryService.getEventStatistics();
            return Response.ok(stats).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Get all active tracking IDs (issues currently in pipeline)
     *
     * GET /api/sdlc/events/active
     */
    @GET
    @Path("/active")
    public Response getActiveTrackings() {
        try {
            List<Map<String, Object>> active = eventQueryService.getActiveTrackings();
            return Response.ok(active).build();
        } catch (Exception e) {
            return Response.serverError()
                .entity(Map.of("error", e.getMessage()))
                .build();
        }
    }

    /**
     * Stream events (SSE - Server-Sent Events)
     *
     * GET /api/sdlc/events/stream
     */
    @GET
    @Path("/stream")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    public Response streamEvents() {
        // TODO: Implement SSE for real-time event streaming
        return Response.status(501)
            .entity(Map.of("error", "SSE streaming not yet implemented"))
            .build();
    }
}
