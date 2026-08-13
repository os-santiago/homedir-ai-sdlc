package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.quarkus.hibernate.reactive.panache.common.WithSession;
import io.smallrye.mutiny.Uni;
import io.vertx.core.json.JsonObject;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * Dashboard snapshot endpoint for polling
 */
@Path("/api/dashboard")
@Tag(name = "Dashboard", description = "Dashboard data snapshot")
public class DashboardResource {

    @Inject
    EventQueryService queryService;

    @GET
    @Path("/snapshot")
    @Produces(MediaType.APPLICATION_JSON)
    @WithSession
    @Operation(summary = "Get dashboard snapshot",
               description = "Returns combined dashboard data for polling")
    public Uni<JsonObject> getDashboardSnapshot() {
        return queryService.getRecentEvents(20)
            .map(events -> new JsonObject()
                .put("timestamp", System.currentTimeMillis())
                .put("recentEvents", events)
                .put("activeIssues", new io.vertx.core.json.JsonArray())
                .put("stageStatistics", new io.vertx.core.json.JsonArray()));
    }
}
