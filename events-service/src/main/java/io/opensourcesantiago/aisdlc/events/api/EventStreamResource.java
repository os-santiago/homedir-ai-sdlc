package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.projection.EventProjection;
import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Multi;
import io.vertx.core.json.JsonObject;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jboss.resteasy.reactive.RestStreamElementType;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * Server-Sent Events (SSE) endpoints for real-time dashboard updates
 */
@Path("/api/stream")
@Tag(name = "Event Stream", description = "Real-time event streaming via SSE")
public class EventStreamResource {

    @Inject
    EventQueryService queryService;

    /**
     * Stream recent events (updates every 5 seconds)
     */
    @GET
    @Path("/events")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.APPLICATION_JSON)
    @Operation(summary = "Stream recent events",
               description = "Server-Sent Events stream of recent events, updates every 5 seconds")
    public Multi<List<EventProjection>> streamRecentEvents() {
        Log.info("SSE client connected to /api/stream/events");

        return Multi.createFrom().ticks().every(Duration.ofSeconds(5))
            .onItem().transformToUniAndConcatenate(tick ->
                queryService.getRecentEvents(20))
            .onCancellation().invoke(() ->
                Log.info("SSE client disconnected from /api/stream/events"));
    }

    /**
     * Stream active issues (updates every 10 seconds)
     */
    @GET
    @Path("/active")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.APPLICATION_JSON)
    @Operation(summary = "Stream active issues",
               description = "Server-Sent Events stream of active issues, updates every 10 seconds")
    public Multi<List<Map<String, Object>>> streamActiveIssues() {
        Log.info("SSE client connected to /api/stream/active");

        return Multi.createFrom().ticks().every(Duration.ofSeconds(10))
            .onItem().transformToUniAndConcatenate(tick ->
                queryService.getActiveIssues())
            .onCancellation().invoke(() ->
                Log.info("SSE client disconnected from /api/stream/active"));
    }

    /**
     * Stream stage statistics (updates every 30 seconds)
     */
    @GET
    @Path("/statistics")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.APPLICATION_JSON)
    @Operation(summary = "Stream stage statistics",
               description = "Server-Sent Events stream of stage statistics, updates every 30 seconds")
    public Multi<List<Map<String, Object>>> streamStatistics() {
        Log.info("SSE client connected to /api/stream/statistics");

        return Multi.createFrom().ticks().every(Duration.ofSeconds(30))
            .onItem().transformToUniAndConcatenate(tick ->
                queryService.getStageStatistics())
            .onCancellation().invoke(() ->
                Log.info("SSE client disconnected from /api/stream/statistics"));
    }

    /**
     * Stream dashboard snapshot (combined data, updates every 15 seconds)
     */
    @GET
    @Path("/dashboard")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.APPLICATION_JSON)
    @Operation(summary = "Stream dashboard snapshot",
               description = "Server-Sent Events stream with combined dashboard data")
    public Multi<JsonObject> streamDashboard() {
        Log.info("SSE client connected to /api/stream/dashboard");

        return Multi.createFrom().ticks().every(Duration.ofSeconds(15))
            .onItem().transformToUniAndConcatenate(tick ->
                queryService.getRecentEvents(10)
                    .chain(events -> queryService.getActiveIssues()
                        .chain(active -> queryService.getStageStatistics()
                            .map(stats -> new JsonObject()
                                .put("timestamp", System.currentTimeMillis())
                                .put("recentEvents", events)
                                .put("activeIssues", active)
                                .put("stageStatistics", stats)))))
            .onCancellation().invoke(() ->
                Log.info("SSE client disconnected from /api/stream/dashboard"));
    }
}
