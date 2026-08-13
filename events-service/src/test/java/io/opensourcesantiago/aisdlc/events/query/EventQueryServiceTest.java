package io.opensourcesantiago.aisdlc.events.query;

import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.projection.EventProjection;
import io.opensourcesantiago.aisdlc.events.service.EventPublisher;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for EventQueryService
 */
@QuarkusTest
public class EventQueryServiceTest {

    @Inject
    EventPublisher eventPublisher;

    @Inject
    EventQueryService queryService;

    @Test
    @Transactional
    public void testGetRecentEvents() {
        // Given - Publish events
        eventPublisher.publishIssueDetected(3000, Map.of()).await().indefinitely();
        eventPublisher.publishIssueDetected(3001, Map.of()).await().indefinitely();

        // When
        List<EventProjection> recent = queryService.getRecentEvents(10)
            .await().indefinitely();

        // Then
        assertThat(recent).hasSizeGreaterThanOrEqualTo(2);
        // Should be in DESC order
        assertTrue(recent.get(0).getTimestamp().isAfter(recent.get(1).getTimestamp()) ||
                   recent.get(0).getTimestamp().equals(recent.get(1).getTimestamp()));
    }

    @Test
    @Transactional
    public void testGetEventsByStage() {
        // Given
        eventPublisher.publishIssueDetected(3002, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionStarted(3002).await().indefinitely();

        // When
        List<EventProjection> admissionEvents = queryService
            .getEventsByStage(EventStage.ADMISSION, 10)
            .await().indefinitely();

        // Then
        assertThat(admissionEvents).hasSizeGreaterThanOrEqualTo(1);
        admissionEvents.forEach(event ->
            assertEquals(EventStage.ADMISSION, event.getStage())
        );
    }

    @Test
    @Transactional
    public void testGetIssueTimeline() {
        // Given
        int issueNumber = 3003;
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionStarted(issueNumber).await().indefinitely();
        eventPublisher.publishAdmissionCompleted(issueNumber, "ACCEPT", "OK")
            .await().indefinitely();

        // When
        List<EventProjection> timeline = queryService.getIssueTimeline(issueNumber)
            .await().indefinitely();

        // Then
        assertEquals(3, timeline.size());
        // Timeline should be chronological (ASC)
        assertTrue(timeline.get(0).getTimestamp().isBefore(timeline.get(1).getTimestamp()) ||
                   timeline.get(0).getTimestamp().equals(timeline.get(1).getTimestamp()));
    }

    @Test
    @Transactional
    public void testCountProjections() {
        // Given
        eventPublisher.publishIssueDetected(3004, Map.of()).await().indefinitely();

        // When
        Long count = queryService.countProjections().await().indefinitely();

        // Then
        assertTrue(count >= 1);
    }

    @Test
    @Transactional
    public void testGetStageStatistics() {
        // When
        List<Map<String, Object>> stats = queryService.getStageStatistics()
            .await().indefinitely();

        // Then
        assertThat(stats).hasSize(6); // 6 stages
        assertThat(stats.get(0)).containsKey("stage");
        assertThat(stats.get(0)).containsKey("total_events");
    }

    @Test
    @Transactional
    public void testGetActiveIssues() {
        // Given
        eventPublisher.publishIssueDetected(3005, Map.of()).await().indefinitely();

        // When
        List<Map<String, Object>> activeIssues = queryService.getActiveIssues()
            .await().indefinitely();

        // Then
        assertNotNull(activeIssues);
        // Should include our issue
        boolean found = activeIssues.stream()
            .anyMatch(issue -> Integer.valueOf(3005).equals(issue.get("issue_number")));
        assertTrue(found, "Active issues should include issue 3005");
    }
}
