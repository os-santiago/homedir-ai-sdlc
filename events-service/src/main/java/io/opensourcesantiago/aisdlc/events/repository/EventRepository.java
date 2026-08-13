package io.opensourcesantiago.aisdlc.events.repository;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;
import java.util.UUID;

/**
 * Repository for AI-SDLC events
 * Uses Hibernate Reactive Panache for async database operations
 */
@ApplicationScoped
public class EventRepository implements PanacheRepositoryBase<AISDLCEvent, UUID> {

    /**
     * Persist event (async)
     */
    public Uni<AISDLCEvent> persistEvent(AISDLCEvent event) {
        return persistAndFlush(event);
    }

    /**
     * Find all events for a tracking ID, ordered by timestamp
     */
    public Uni<List<AISDLCEvent>> findByTrackingId(String trackingId) {
        return find("trackingId = ?1 ORDER BY timestamp ASC", trackingId).list();
    }

    /**
     * Find all events for an issue number, ordered by timestamp DESC
     */
    public Uni<List<AISDLCEvent>> findByIssueNumber(Integer issueNumber) {
        return find("issueNumber = ?1 ORDER BY timestamp DESC", issueNumber).list();
    }

    /**
     * Find latest N events across all issues
     */
    public Uni<List<AISDLCEvent>> findLatest(int limit) {
        return find("ORDER BY timestamp DESC").page(0, limit).list();
    }

    /**
     * Find events by stage
     */
    public Uni<List<AISDLCEvent>> findByStage(EventStage stage, int limit) {
        return find("stage = ?1 ORDER BY timestamp DESC", stage)
                .page(0, limit)
                .list();
    }

    /**
     * Find events by event type
     */
    public Uni<List<AISDLCEvent>> findByEventType(String eventType, int limit) {
        return find("eventType = ?1 ORDER BY timestamp DESC", eventType)
                .page(0, limit)
                .list();
    }

    /**
     * Count total events
     */
    public Uni<Long> countAll() {
        return count();
    }

    /**
     * Count events by issue number
     */
    public Uni<Long> countByIssueNumber(Integer issueNumber) {
        return count("issueNumber = ?1", issueNumber);
    }

    /**
     * Count failed events
     */
    public Uni<Long> countFailed() {
        return count("status = 'FAILED'");
    }
}
