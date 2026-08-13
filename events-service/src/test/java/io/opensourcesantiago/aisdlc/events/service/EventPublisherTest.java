package io.opensourcesantiago.aisdlc.events.service;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.opensourcesantiago.aisdlc.events.domain.TrackingState;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import io.opensourcesantiago.aisdlc.events.repository.TrackingStateRepository;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for EventPublisher
 */
@QuarkusTest
public class EventPublisherTest {

    @Inject
    EventPublisher eventPublisher;

    @Inject
    EventRepository eventRepo;

    @Inject
    TrackingStateRepository trackingRepo;

    @Test
    @Transactional
    public void testPublishIssueDetected() {
        // Given
        int issueNumber = 1360;
        Map<String, Object> metadata = Map.of("title", "Test issue", "labels", "bug");

        // When
        AISDLCEvent event = eventPublisher.publishIssueDetected(issueNumber, metadata)
                .await().indefinitely();

        // Then
        assertNotNull(event.getEventId());
        assertEquals("issue.detected", event.getEventType());
        assertEquals(Integer.valueOf(issueNumber), event.getIssueNumber());
        assertEquals(EventStatus.COMPLETED, event.getStatus());
        assertEquals(EventStage.DETECTION, event.getStage());
        assertTrue(event.getTrackingId().startsWith("track_1360_"));

        // Verify tracking state was created
        TrackingState tracking = trackingRepo.findById(issueNumber)
                .await().indefinitely();

        assertNotNull(tracking);
        assertEquals(event.getTrackingId(), tracking.getTrackingId());
        assertEquals(EventStage.DETECTION, tracking.getCurrentStage());
        assertEquals(Integer.valueOf(1), tracking.getEventCount());
    }

    @Test
    @Transactional
    public void testPublishAdmissionFlow() {
        // Given
        int issueNumber = 1361;

        // When - Issue detected
        AISDLCEvent detected = eventPublisher.publishIssueDetected(issueNumber, Map.of())
                .await().indefinitely();

        // When - Admission started
        AISDLCEvent admissionStarted = eventPublisher.publishAdmissionStarted(issueNumber)
                .await().indefinitely();

        // When - Admission completed
        AISDLCEvent admissionCompleted = eventPublisher.publishAdmissionCompleted(
                issueNumber, "ACCEPT", "Meets criteria")
                .await().indefinitely();

        // Then
        assertEquals(detected.getTrackingId(), admissionStarted.getTrackingId());
        assertEquals(detected.getTrackingId(), admissionCompleted.getTrackingId());

        // Verify tracking state updated
        TrackingState tracking = trackingRepo.findById(issueNumber)
                .await().indefinitely();

        assertEquals(EventStage.ADMISSION, tracking.getCurrentStage());
        assertEquals(EventStatus.COMPLETED, tracking.getStatus());
        assertEquals(Integer.valueOf(3), tracking.getEventCount());
    }

    @Test
    @Transactional
    public void testPublishPRCreated() {
        // Given
        int issueNumber = 1362;
        int prNumber = 1450;
        String prUrl = "https://github.com/org/repo/pull/1450";

        // When
        eventPublisher.publishIssueDetected(issueNumber, Map.of())
                .await().indefinitely();

        AISDLCEvent prEvent = eventPublisher.publishPRCreated(issueNumber, prNumber, prUrl)
                .await().indefinitely();

        // Then
        assertEquals("pr.created", prEvent.getEventType());
        assertEquals(Integer.valueOf(prNumber), prEvent.getPrNumber());
        assertEquals(prUrl, prEvent.getMetadata().get("pr_url"));

        // Verify tracking state has PR number
        TrackingState tracking = trackingRepo.findById(issueNumber)
                .await().indefinitely();

        assertEquals(Integer.valueOf(prNumber), tracking.getPrNumber());
    }

    @Test
    @Transactional
    public void testPublishError() {
        // Given
        int issueNumber = 1363;
        String errorMessage = "SCC execution failed";

        // When
        AISDLCEvent errorEvent = eventPublisher.publishError(issueNumber, errorMessage)
                .await().indefinitely();

        // Then
        assertEquals("error.occurred", errorEvent.getEventType());
        assertEquals(EventStatus.FAILED, errorEvent.getStatus());
        assertEquals(EventStage.ERROR, errorEvent.getStage());
        assertEquals(errorMessage, errorEvent.getMetadata().get("error_message"));

        // Verify error count incremented
        TrackingState tracking = trackingRepo.findById(issueNumber)
                .await().indefinitely();

        assertEquals(Integer.valueOf(1), tracking.getErrorCount());
    }

    @Test
    @Transactional
    public void testMultipleEvents_TrackingStateUpdates() {
        // Given
        int issueNumber = 1364;

        // When - Publish multiple events
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishIssueClaimed(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionStarted(issueNumber).await().indefinitely();
        eventPublisher.publishAdmissionCompleted(issueNumber, "ACCEPT", "OK").await().indefinitely();
        eventPublisher.publishImplementationStarted(issueNumber).await().indefinitely();

        // Then
        TrackingState tracking = trackingRepo.findById(issueNumber)
                .await().indefinitely();

        assertEquals(EventStage.IMPLEMENTATION, tracking.getCurrentStage());
        assertEquals(EventStatus.IN_PROGRESS, tracking.getStatus());
        assertEquals(Integer.valueOf(5), tracking.getEventCount());
        assertNotNull(tracking.getFirstEventAt());
        assertNotNull(tracking.getLastEventAt());
        assertTrue(tracking.getLastEventAt().isAfter(tracking.getFirstEventAt()) ||
                   tracking.getLastEventAt().equals(tracking.getFirstEventAt()));
    }

    @Test
    @Transactional
    public void testImplementationCompletedWithMetrics() {
        // Given
        int issueNumber = 1365;
        long durationMs = 8234L;
        int filesChanged = 3;

        // When
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        AISDLCEvent implEvent = eventPublisher.publishImplementationCompleted(
                issueNumber, durationMs, filesChanged)
                .await().indefinitely();

        // Then
        assertEquals("implementation.completed", implEvent.getEventType());
        assertEquals(Long.valueOf(durationMs), implEvent.getMetadata().get("duration_ms"));
        assertEquals(Integer.valueOf(filesChanged), implEvent.getMetadata().get("files_changed"));
    }
}
