package io.opensourcesantiago.aisdlc.events.lifecycle;

import io.quarkus.logging.Log;
import io.quarkus.runtime.ShutdownEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;

/**
 * Graceful shutdown handling
 */
@ApplicationScoped
public class ShutdownService {

    void onShutdown(@Observes ShutdownEvent event) {
        Log.info("===========================================");
        Log.info("AI-SDLC Events Service Shutting Down");
        Log.info("===========================================");

        Log.info("Graceful shutdown initiated");

        // Allow time for in-flight requests to complete
        try {
            Thread.sleep(2000); // 2 second grace period
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        Log.info("Shutdown complete");
    }
}
