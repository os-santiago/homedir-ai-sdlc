package io.opensourcesantiago.aisdlc.events.health;

import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Readiness;

/**
 * Projection health check - verifies projections are in sync with events
 */
@Readiness
@ApplicationScoped
public class ProjectionHealthCheck implements HealthCheck {

    @Inject
    EventRepository eventRepo;

    @Inject
    EventQueryService queryService;

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named("Projection sync");

        try {
            Long eventCount = eventRepo.countAll().await().atMost(java.time.Duration.ofSeconds(5));
            Long projectionCount = queryService.countProjections().await().atMost(java.time.Duration.ofSeconds(5));

            long lag = eventCount - projectionCount;
            boolean healthy = lag <= 100; // Allow up to 100 events lag

            if (healthy) {
                builder.up();
            } else {
                builder.down();
            }

            builder.withData("event_count", eventCount)
                .withData("projection_count", projectionCount)
                .withData("lag", lag)
                .withData("threshold", 100);

        } catch (Exception e) {
            builder.down()
                .withData("error", e.getMessage());
        }

        return builder.build();
    }
}
