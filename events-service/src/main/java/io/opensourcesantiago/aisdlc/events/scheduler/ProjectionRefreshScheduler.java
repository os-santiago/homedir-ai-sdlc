package io.opensourcesantiago.aisdlc.events.scheduler;

import io.opensourcesantiago.aisdlc.events.projection.ProjectionUpdater;
import io.quarkus.logging.Log;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Scheduled tasks for projection maintenance
 */
@ApplicationScoped
public class ProjectionRefreshScheduler {

    @Inject
    ProjectionUpdater projectionUpdater;

    /**
     * Refresh materialized views every 5 minutes
     */
    @Scheduled(cron = "0 */5 * * * ?")
    public void refreshMaterializedViews() {
        Log.info("Scheduled refresh of materialized views started");

        projectionUpdater.refreshMaterializedViews()
            .subscribe()
            .with(
                unused -> Log.info("Materialized views refreshed successfully"),
                failure -> Log.errorf(failure, "Failed to refresh materialized views")
            );
    }
}
