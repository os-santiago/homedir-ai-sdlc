package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import io.opensourcesantiago.aisdlc.events.repository.TrackingStateRepository;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.time.Instant;
import java.util.Map;

/**
 * Health and status endpoints
 */
@Path("/api/health")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Health", description = "Service health and status")
public class HealthResource {

    @Inject
    EventRepository eventRepo;

    @Inject
    TrackingStateRepository trackingRepo;

    @Inject
    EventQueryService queryService;

    /**
     * Service status
     */
    @GET
    @Path("/status")
    @Operation(summary = "Get service status", description = "Returns service health and database statistics")
    public Uni<Map<String, Object>> getStatus() {
        return Uni.combine().all()
            .unis(
                eventRepo.countAll(),
                trackingRepo.count(),
                queryService.countProjections()
            )
            .asTuple()
            .map(tuple -> Map.of(
                "status", "UP",
                "timestamp", Instant.now().toString(),
                "version", "0.4.0",
                "database", Map.of(
                    "events", tuple.getItem1(),
                    "tracking_states", tuple.getItem2(),
                    "projections", tuple.getItem3()
                )
            ));
    }

    /**
     * Readiness probe
     */
    @GET
    @Path("/ready")
    @Operation(summary = "Readiness probe", description = "Returns OK if service is ready to accept requests")
    public Uni<Map<String, String>> ready() {
        // Check database connectivity
        return eventRepo.countAll()
            .map(count -> Map.of("status", "READY"));
    }

    /**
     * Liveness probe
     */
    @GET
    @Path("/live")
    @Operation(summary = "Liveness probe", description = "Returns OK if service is alive")
    public Map<String, String> live() {
        return Map.of("status", "ALIVE");
    }
}
