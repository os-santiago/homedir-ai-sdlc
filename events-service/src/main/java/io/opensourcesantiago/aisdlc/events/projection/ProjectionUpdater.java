package io.opensourcesantiago.aisdlc.events.projection;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.TrackingState;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import io.opensourcesantiago.aisdlc.events.repository.TrackingStateRepository;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Duration;
import java.util.Map;

/**
 * Updates read model projections from events
 * Maintains denormalized views for optimized queries
 */
@ApplicationScoped
public class ProjectionUpdater {

    // NOTE: Projections are now handled automatically by PostgreSQL materialized views
    // This class is kept for backwards compatibility but methods are NO-OPs

    // @Inject
    // EntityManager em;

    @Inject
    EventRepository eventRepo;

    @Inject
    TrackingStateRepository trackingRepo;

    /**
     * Project an event to the read model
     * Called after each event is published
     */
    // @Transactional
    public Uni<EventProjection> projectEvent(AISDLCEvent event) {
        // NO-OP: Materialized views handle projections automatically
        Log.debugf("ProjectEvent called for %s - using materialized views", event.getEventId());
        return Uni.createFrom().nullItem();
    }

    /**
     * Build projection from event and tracking context
     */
    private EventProjection buildProjection(AISDLCEvent event, TrackingState tracking) {
        EventProjection projection = new EventProjection();

        // Event data
        projection.setEventId(event.getEventId());
        projection.setTrackingId(event.getTrackingId());
        projection.setIssueNumber(event.getIssueNumber());
        projection.setPrNumber(event.getPrNumber());
        projection.setEventType(event.getEventType());
        projection.setTimestamp(event.getTimestamp());
        projection.setStatus(event.getStatus());
        projection.setStage(event.getStage());

        // Denormalized tracking context
        projection.setEventSequence(tracking.getEventCount());
        projection.setTrackingStartedAt(tracking.getFirstEventAt());

        if (tracking.getFirstEventAt() != null) {
            Duration duration = Duration.between(tracking.getFirstEventAt(), event.getTimestamp());
            projection.setDurationMs(duration.toMillis());
        }

        // Extract metadata based on event type
        extractMetadata(event, projection);

        return projection;
    }

    /**
     * Extract relevant metadata from event to projection columns
     */
    private void extractMetadata(AISDLCEvent event, EventProjection projection) {
        Map<String, Object> metadata = event.getMetadata();
        if (metadata == null) {
            return;
        }

        switch (event.getEventType()) {
            case "admission.completed":
                projection.setDecision((String) metadata.get("decision"));
                break;

            case "implementation.completed":
                Object files = metadata.get("files_changed");
                if (files instanceof Number) {
                    projection.setFilesChanged(((Number) files).intValue());
                }
                break;

            case "pr.created":
                projection.setPrUrl((String) metadata.get("pr_url"));
                break;

            case "error.occurred":
                projection.setErrorMessage((String) metadata.get("error_message"));
                break;
        }
    }

    /**
     * Update aggregated statistics for a stage
     */
    // @Transactional
    public Uni<Void> updateStageStatistics(AISDLCEvent event) {
        // NO-OP: Materialized views handle statistics automatically
        return Uni.createFrom().voidItem();
    }

    /**
     * Update duration statistics for stages
     */
    private void updateDurationStatistics(AISDLCEvent event) {
        // NO-OP: Statistics handled by materialized views
    }

    /**
     * Refresh materialized views
     * Should be called periodically (e.g., every 5 minutes)
     */
    // @Transactional
    public Uni<Void> refreshMaterializedViews() {
        // NO-OP: Materialized views refresh automatically via database triggers
        Log.debug("MaterializedViews refresh called - using automatic refresh");
        return Uni.createFrom().voidItem();
    }

    /**
     * Rebuild all projections from events
     * Used for recovery or data migration
     */
    // @Transactional
    public Uni<Long> rebuildProjections() {
        // NO-OP: Materialized views are always in sync with events table
        Log.info("RebuildProjections called - materialized views are self-maintaining");
        return Uni.createFrom().item(0L);
    }
}
