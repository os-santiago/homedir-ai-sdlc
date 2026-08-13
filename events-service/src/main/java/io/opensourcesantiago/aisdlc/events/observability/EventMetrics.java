package io.opensourcesantiago.aisdlc.events.observability;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * Custom metrics for event processing
 */
@ApplicationScoped
public class EventMetrics {

    @Inject
    MeterRegistry registry;

    private final ConcurrentHashMap<String, Counter> eventCounters = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Timer> eventTimers = new ConcurrentHashMap<>();

    /**
     * Record event published
     */
    public void recordEventPublished(String eventType, EventStage stage, EventStatus status) {
        getCounter("events.published.total", "type", eventType).increment();
        getCounter("events.published.by_stage", "stage", stage.name()).increment();
        getCounter("events.published.by_status", "status", status.name()).increment();

        if (status == EventStatus.FAILED) {
            getCounter("events.failed.total", "type", eventType).increment();
        } else if (status == EventStatus.COMPLETED) {
            getCounter("events.completed.total", "type", eventType).increment();
        }
    }

    /**
     * Record projection created
     */
    public void recordProjectionCreated() {
        getCounter("projections.created.total").increment();
    }

    /**
     * Record projection update duration
     */
    public void recordProjectionDuration(long durationMs) {
        getTimer("projections.update.duration").record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * Record SSE connection
     */
    public void recordSSEConnection(String endpoint) {
        getCounter("sse.connections.total", "endpoint", endpoint).increment();
    }

    /**
     * Record SSE disconnection
     */
    public void recordSSEDisconnection(String endpoint) {
        getCounter("sse.disconnections.total", "endpoint", endpoint).increment();
    }

    /**
     * Record API request
     */
    public void recordAPIRequest(String endpoint, int statusCode) {
        getCounter("api.requests.total", "endpoint", endpoint, "status", String.valueOf(statusCode)).increment();
    }

    /**
     * Record query execution time
     */
    public void recordQueryDuration(String queryName, long durationMs) {
        getTimer("queries.duration", "query", queryName).record(durationMs, TimeUnit.MILLISECONDS);
    }

    // Helper methods

    private Counter getCounter(String name, String... tags) {
        String key = name + String.join("_", tags);
        return eventCounters.computeIfAbsent(key, k ->
            Counter.builder(name)
                .tags(tags)
                .description("Custom event metric")
                .register(registry)
        );
    }

    private Timer getTimer(String name, String... tags) {
        String key = name + String.join("_", tags);
        return eventTimers.computeIfAbsent(key, k ->
            Timer.builder(name)
                .tags(tags)
                .description("Custom event timer")
                .register(registry)
        );
    }
}
