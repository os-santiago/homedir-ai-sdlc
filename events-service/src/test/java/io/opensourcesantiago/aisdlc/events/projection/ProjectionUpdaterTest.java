package io.opensourcesantiago.aisdlc.events.projection;

import io.opensourcesantiago.aisdlc.events.service.EventPublisher;
import io.opensourcesantiago.aisdlc.events.query.EventQueryService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for ProjectionUpdater
 */
@QuarkusTest
public class ProjectionUpdaterTest {

    @Inject
    EventPublisher eventPublisher;

    @Inject
    EventQueryService queryService;

    @Inject
    ProjectionUpdater projectionUpdater;

    @Test
    @Transactional
    public void testProjectionCreatedOnEventPublish() {
        // Given
        int issueNumber = 2000;

        // When - Publish event (should auto-create projection)
        eventPublisher.publishIssueDetected(issueNumber, Map.of("title", "Test"))
            .await().indefinitely();

        // Then - Projection should exist
        List<EventProjection> timeline = queryService.getIssueTimeline(issueNumber)
            .await().indefinitely();

        assertThat(timeline).hasSize(1);
        EventProjection projection = timeline.get(0);

        assertEquals(issueNumber, projection.getIssueNumber());
        assertEquals("issue.detected", projection.getEventType());
        assertEquals(Integer.valueOf(1), projection.getEventSequence());
        assertNotNull(projection.getTrackingStartedAt());
    }

    @Test
    @Transactional
    public void testMultipleProjections() {
        // Given
        int issueNumber = 2001;

        // When - Publish multiple events
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionStarted(issueNumber).await().indefinitely();
        eventPublisher.publishAdmissionCompleted(issueNumber, "ACCEPT", "Valid")
            .await().indefinitely();

        // Then - Timeline should have all events in order
        List<EventProjection> timeline = queryService.getIssueTimeline(issueNumber)
            .await().indefinitely();

        assertThat(timeline).hasSize(3);
        assertEquals("issue.detected", timeline.get(0).getEventType());
        assertEquals("admission.started", timeline.get(1).getEventType());
        assertEquals("admission.completed", timeline.get(2).getEventType());

        // Sequences should increment
        assertEquals(Integer.valueOf(1), timeline.get(0).getEventSequence());
        assertEquals(Integer.valueOf(2), timeline.get(1).getEventSequence());
        assertEquals(Integer.valueOf(3), timeline.get(2).getEventSequence());
    }

    @Test
    @Transactional
    public void testMetadataExtraction() {
        // Given
        int issueNumber = 2002;

        // When - Publish admission completed with decision
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionCompleted(issueNumber, "REJECT", "Invalid format")
            .await().indefinitely();

        // Then - Decision extracted to projection column
        List<EventProjection> timeline = queryService.getIssueTimeline(issueNumber)
            .await().indefinitely();

        EventProjection admission = timeline.stream()
            .filter(p -> p.getEventType().equals("admission.completed"))
            .findFirst()
            .orElseThrow();

        assertEquals("REJECT", admission.getDecision());
    }

    @Test
    @Transactional
    public void testStageStatisticsUpdated() {
        // Given
        int issueNumber = 2003;

        // When - Publish events
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();

        // Then - Statistics should be updated
        List<Map<String, Object>> stats = queryService.getStageStatistics()
            .await().indefinitely();

        assertThat(stats).isNotEmpty();

        Map<String, Object> detectionStats = stats.stream()
            .filter(s -> "DETECTION".equals(s.get("stage")))
            .findFirst()
            .orElseThrow();

        Long totalEvents = ((Number) detectionStats.get("total_events")).longValue();
        assertTrue(totalEvents >= 1, "Should have at least 1 detection event");
    }

    @Test
    @Transactional
    public void testRefreshMaterializedViews() {
        // Given
        int issueNumber = 2004;
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();

        // When - Refresh views
        projectionUpdater.refreshMaterializedViews().await().indefinitely();

        // Then - Active issues view should be accessible
        List<Map<String, Object>> activeIssues = queryService.getActiveIssues()
            .await().indefinitely();

        assertNotNull(activeIssues);
    }
}
