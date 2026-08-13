package io.opensourcesantiago.aisdlc.events.repository;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for EventRepository
 */
@QuarkusTest
public class EventRepositoryTest {

    @Inject
    EventRepository repository;

    @Test
    @Transactional
    public void testPersistEvent() {
        // Given
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("title", "Test issue");
        metadata.put("labels", List.of("bug"));

        AISDLCEvent event = AISDLCEvent.builder()
                .trackingId("track_1360_20260809")
                .actionId("act_issue_detected_20260809")
                .eventType("issue.detected")
                .timestamp(Instant.now())
                .issueNumber(1360)
                .status(EventStatus.COMPLETED)
                .stage(EventStage.DETECTION)
                .metadata(metadata)
                .build();

        // When
        AISDLCEvent persisted = repository.persistEvent(event)
                .await().indefinitely();

        // Then
        assertNotNull(persisted.getEventId());
        assertEquals("track_1360_20260809", persisted.getTrackingId());
        assertEquals("issue.detected", persisted.getEventType());
        assertEquals(Integer.valueOf(1360), persisted.getIssueNumber());
        assertEquals(EventStatus.COMPLETED, persisted.getStatus());
        assertEquals(EventStage.DETECTION, persisted.getStage());
        assertNotNull(persisted.getCreatedAt());
        assertEquals("Test issue", persisted.getMetadata().get("title"));
    }

    @Test
    @Transactional
    public void testFindByTrackingId() {
        // Given
        String trackingId = "track_1361_20260809";

        AISDLCEvent event1 = createEvent(trackingId, "issue.detected", 1361, EventStage.DETECTION);
        AISDLCEvent event2 = createEvent(trackingId, "issue.claimed", 1361, EventStage.DETECTION);

        repository.persistEvent(event1).await().indefinitely();
        repository.persistEvent(event2).await().indefinitely();

        // When
        List<AISDLCEvent> events = repository.findByTrackingId(trackingId)
                .await().indefinitely();

        // Then
        assertThat(events).hasSize(2);
        assertThat(events).extracting(AISDLCEvent::getEventType)
                .containsExactly("issue.detected", "issue.claimed");
    }

    @Test
    @Transactional
    public void testFindByIssueNumber() throws InterruptedException {
        // Given
        int issueNumber = 1362;

        AISDLCEvent event1 = createEvent("track_1362_a", "issue.detected", issueNumber, EventStage.DETECTION);
        AISDLCEvent event2 = createEvent("track_1362_b", "pr.created", issueNumber, EventStage.PR_MANAGEMENT);

        repository.persistEvent(event1).await().indefinitely();
        Thread.sleep(10); // Ensure different timestamps
        repository.persistEvent(event2).await().indefinitely();

        // When
        List<AISDLCEvent> events = repository.findByIssueNumber(issueNumber)
                .await().indefinitely();

        // Then
        assertThat(events).hasSizeGreaterThanOrEqualTo(2);
        assertThat(events.get(0).getEventType()).isEqualTo("pr.created"); // DESC order
    }

    @Test
    @Transactional
    public void testFindLatest() throws InterruptedException {
        // Given
        for (int i = 0; i < 5; i++) {
            AISDLCEvent event = createEvent("track_" + i, "event_" + i, 2000 + i, EventStage.DETECTION);
            repository.persistEvent(event).await().indefinitely();
            Thread.sleep(5); // Ensure different timestamps
        }

        // When
        List<AISDLCEvent> latest = repository.findLatest(3)
                .await().indefinitely();

        // Then
        assertThat(latest).hasSizeLessThanOrEqualTo(3);
    }

    @Test
    @Transactional
    public void testCountEvents() {
        // Given
        AISDLCEvent event1 = createEvent("track_count_1", "event.type", 3000, EventStage.DETECTION);
        AISDLCEvent event2 = createEvent("track_count_2", "event.type", 3001, EventStage.DETECTION);

        repository.persistEvent(event1).await().indefinitely();
        repository.persistEvent(event2).await().indefinitely();

        // When
        Long count = repository.countAll().await().indefinitely();
        Long issueCount = repository.countByIssueNumber(3000).await().indefinitely();

        // Then
        assertThat(count).isGreaterThanOrEqualTo(2);
        assertThat(issueCount).isGreaterThanOrEqualTo(1);
    }

    @Test
    @Transactional
    public void testEventWithParent() {
        // Given
        AISDLCEvent parentEvent = createEvent("track_parent", "parent.event", 4000, EventStage.DETECTION);
        AISDLCEvent savedParent = repository.persistEvent(parentEvent).await().indefinitely();

        AISDLCEvent childEvent = AISDLCEvent.builder()
                .trackingId("track_parent")
                .actionId("act_child")
                .eventType("child.event")
                .timestamp(Instant.now())
                .issueNumber(4000)
                .status(EventStatus.COMPLETED)
                .stage(EventStage.ADMISSION)
                .parentEvent(savedParent)
                .build();

        // When
        AISDLCEvent savedChild = repository.persistEvent(childEvent).await().indefinitely();

        // Then
        assertNotNull(savedChild.getParentEvent());
        assertEquals(savedParent.getEventId(), savedChild.getParentEvent().getEventId());
    }

    // Helper methods

    private AISDLCEvent createEvent(String trackingId, String eventType, int issueNumber, EventStage stage) {
        return AISDLCEvent.builder()
                .trackingId(trackingId)
                .actionId("act_" + eventType + "_" + System.currentTimeMillis())
                .eventType(eventType)
                .timestamp(Instant.now())
                .issueNumber(issueNumber)
                .status(EventStatus.COMPLETED)
                .stage(stage)
                .metadata(new HashMap<>())
                .build();
    }
}
