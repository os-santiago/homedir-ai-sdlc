package io.opensourcesantiago.aisdlc.events.query;

import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.opensourcesantiago.aisdlc.events.projection.EventProjection;
import io.quarkus.hibernate.reactive.panache.Panache;
import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Query service for read models
 * Optimized queries over denormalized projections
 */
@ApplicationScoped
public class EventQueryService implements PanacheRepositoryBase<EventProjection, UUID> {

    /**
     * Get timeline for an issue (all events in chronological order)
     */
    public Uni<List<EventProjection>> getIssueTimeline(Integer issueNumber) {
        return find("issue_number = ?1 ORDER BY timestamp ASC", issueNumber).list();
    }

    /**
     * Get recent events across all issues
     */
    public Uni<List<EventProjection>> getRecentEvents(int limit) {
        return find("ORDER BY timestamp DESC").page(0, limit).list();
    }

    /**
     * Get events by stage
     */
    public Uni<List<EventProjection>> getEventsByStage(EventStage stage, int limit) {
        return find("stage = ?1 ORDER BY timestamp DESC", stage)
            .page(0, limit)
            .list();
    }

    /**
     * Get failed events for investigation
     */
    public Uni<List<EventProjection>> getFailedEvents(int limit) {
        return find("status = ?1 ORDER BY timestamp DESC", EventStatus.FAILED)
            .page(0, limit)
            .list();
    }

    /**
     * Get events in a time range
     */
    public Uni<List<EventProjection>> getEventsByTimeRange(Instant start, Instant end) {
        return find("timestamp BETWEEN ?1 AND ?2 ORDER BY timestamp ASC", start, end).list();
    }

    /**
     * Search events by tracking ID
     */
    public Uni<List<EventProjection>> getEventsByTracking(String trackingId) {
        return find("tracking_id = ?1 ORDER BY timestamp ASC", trackingId).list();
    }

    /**
     * Get active issues (materialized view)
     */
    public Uni<List<Map<String, Object>>> getActiveIssues() {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT * FROM active_issues ORDER BY last_event_at DESC",
                Map.class
            ).getResultList()
        ).map(list -> (List<Map<String, Object>>) (List<?>) list);
    }

    /**
     * Get stage statistics
     */
    public Uni<List<Map<String, Object>>> getStageStatistics() {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT * FROM stage_statistics ORDER BY " +
                "CASE stage " +
                "  WHEN 'DETECTION' THEN 1 " +
                "  WHEN 'ADMISSION' THEN 2 " +
                "  WHEN 'IMPLEMENTATION' THEN 3 " +
                "  WHEN 'PR_MANAGEMENT' THEN 4 " +
                "  WHEN 'CI_CHECKS' THEN 5 " +
                "  WHEN 'ERROR' THEN 6 " +
                "  ELSE 99 END",
                Map.class
            ).getResultList()
        ).map(list -> (List<Map<String, Object>>) (List<?>) list);
    }

    /**
     * Get admission decisions summary
     */
    public Uni<Map<String, Long>> getAdmissionDecisionsSummary() {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT decision, COUNT(*) as count " +
                "FROM event_projections " +
                "WHERE event_type = 'admission.completed' " +
                "GROUP BY decision",
                Map.class
            ).getResultList()
        ).map(results -> {
            return results.stream()
                .collect(java.util.stream.Collectors.toMap(
                    m -> (String) m.get("decision"),
                    m -> ((Number) m.get("count")).longValue()
                ));
        });
    }

    /**
     * Get average implementation duration
     */
    public Uni<Double> getAvgImplementationDuration() {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT AVG(files_changed) as avg_files, AVG(duration_ms) as avg_duration " +
                "FROM event_projections " +
                "WHERE event_type = 'implementation.completed' " +
                "AND duration_ms IS NOT NULL",
                Map.class
            ).getSingleResult()
        ).map(result -> {
            Object avgDuration = result.get("avg_duration");
            return avgDuration != null ? ((Number) avgDuration).doubleValue() : 0.0;
        });
    }

    /**
     * Get error rate by stage
     */
    public Uni<List<Map<String, Object>>> getErrorRateByStage() {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT " +
                "  stage, " +
                "  COUNT(*) FILTER (WHERE status = 'FAILED') as errors, " +
                "  COUNT(*) as total, " +
                "  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'FAILED') / COUNT(*), 2) as error_rate " +
                "FROM event_projections " +
                "GROUP BY stage " +
                "ORDER BY error_rate DESC",
                Map.class
            ).getResultList()
        ).map(list -> (List<Map<String, Object>>) (List<?>) list);
    }

    /**
     * Get issue throughput (issues completed per day)
     */
    public Uni<List<Map<String, Object>>> getIssueThroughput(int days) {
        return Panache.getSession().chain(session ->
            session.createNativeQuery(
                "SELECT " +
                "  DATE(timestamp) as date, " +
                "  COUNT(DISTINCT issue_number) as issues_completed " +
                "FROM event_projections " +
                "WHERE event_type = 'pr.merged' " +
                "AND timestamp > NOW() - INTERVAL '" + days + " days' " +
                "GROUP BY DATE(timestamp) " +
                "ORDER BY date DESC",
                Map.class
            ).getResultList()
        ).map(list -> (List<Map<String, Object>>) (List<?>) list);
    }

    /**
     * Count projections (for monitoring)
     */
    public Uni<Long> countProjections() {
        return count();
    }
}
