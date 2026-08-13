package io.opensourcesantiago.aisdlc.events.lifecycle;

import io.opensourcesantiago.aisdlc.events.projection.ProjectionUpdater;
import io.quarkus.logging.Log;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;

/**
 * Application startup initialization
 */
@ApplicationScoped
public class StartupService {

    @Inject
    ProjectionUpdater projectionUpdater;

    void onStart(@Observes StartupEvent event) {
        Log.info("===========================================");
        Log.info("AI-SDLC Events Service Starting");
        Log.info("Version: 1.0.0");
        Log.info("===========================================");

        // Refresh materialized views on startup
        Log.info("Refreshing materialized views on startup...");
        projectionUpdater.refreshMaterializedViews()
            .subscribe()
            .with(
                unused -> Log.info("Materialized views refreshed successfully"),
                failure -> Log.error("Failed to refresh materialized views on startup", failure)
            );

        Log.info("Application startup complete");
    }
}
