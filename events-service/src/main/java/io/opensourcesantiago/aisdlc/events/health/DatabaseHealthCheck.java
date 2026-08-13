package io.opensourcesantiago.aisdlc.events.health;

import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Readiness;

/**
 * Database connectivity health check
 */
@Readiness
@ApplicationScoped
public class DatabaseHealthCheck implements HealthCheck {

    @Inject
    EventRepository eventRepo;

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named("Database connectivity");

        try {
            // Simple query to verify database is accessible
            Long count = eventRepo.countAll().await().atMost(java.time.Duration.ofSeconds(5));

            builder.up()
                .withData("event_count", count)
                .withData("query_time_ms", "<5000");
        } catch (Exception e) {
            builder.down()
                .withData("error", e.getMessage())
                .withData("error_class", e.getClass().getSimpleName());
        }

        return builder.build();
    }
}
