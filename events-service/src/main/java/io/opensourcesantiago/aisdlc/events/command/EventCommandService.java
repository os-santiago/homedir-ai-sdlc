package io.opensourcesantiago.aisdlc.events.command;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;
import java.util.Map;

/**
 * Command service for publishing events to the event store
 * Write side of CQRS pattern
 */
@ApplicationScoped
public class EventCommandService {

    @Inject
    EventRepository eventRepository;

    /**
     * Publish a new event to the event store
     * This is the ONLY way to write events (append-only, immutable)
     */
    public Uni<AISDLCEvent> publishEvent(
        String trackingId,
        String actionId,
        String eventType,
        Integer issueNumber,
        Integer prNumber,
        EventStatus status,
        EventStage stage,
        Map<String, Object> metadata
    ) {
        AISDLCEvent event = new AISDLCEvent();
        event.setTrackingId(trackingId);
        event.setActionId(actionId);
        event.setEventType(eventType);
        event.setIssueNumber(issueNumber);
        event.setPrNumber(prNumber);
        event.setStatus(status);
        event.setStage(stage);
        event.setMetadata(metadata != null ? metadata : Map.of());
        event.setTimestamp(Instant.now());

        Log.infof("Publishing event: %s for issue #%d (tracking: %s)", eventType, issueNumber, trackingId);

        return eventRepository.persist(event)
            .invoke(persisted -> Log.infof("Event persisted: %s", persisted.getEventId()));
    }
}
