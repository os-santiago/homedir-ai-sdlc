package io.opensourcesantiago.aisdlc.events.service;

import io.opensourcesantiago.aisdlc.events.domain.AISDLCEvent;
import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.opensourcesantiago.aisdlc.events.domain.TrackingState;
import io.opensourcesantiago.aisdlc.events.observability.EventMetrics;
import io.opensourcesantiago.aisdlc.events.projection.ProjectionUpdater;
import io.opensourcesantiago.aisdlc.events.repository.EventRepository;
import io.opensourcesantiago.aisdlc.events.repository.TrackingStateRepository;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.time.Instant;
import java.util.Map;

/**
 * Event Publisher Service
 * Publishes events to the event store and updates tracking state
 */
@ApplicationScoped
public class EventPublisher {

    @Inject
    EventRepository eventRepo;

    @Inject
    TrackingStateRepository trackingRepo;

    @Inject
    TrackingService trackingService;

    @Inject
    ProjectionUpdater projectionUpdater;

    @Inject
    EventMetrics metrics;

    /**
     * Publish issue detected event
     */
    @Transactional
    public Uni<AISDLCEvent> publishIssueDetected(Integer issueNumber, Map<String, Object> metadata) {
        return publishEvent(
            issueNumber,
            null,
            "issue.detected",
            EventStatus.COMPLETED,
            EventStage.DETECTION,
            metadata
        );
    }

    /**
     * Publish issue claimed event
     */
    @Transactional
    public Uni<AISDLCEvent> publishIssueClaimed(Integer issueNumber, Map<String, Object> metadata) {
        return publishEvent(
            issueNumber,
            null,
            "issue.claimed",
            EventStatus.COMPLETED,
            EventStage.DETECTION,
            metadata
        );
    }

    /**
     * Publish admission started event
     */
    @Transactional
    public Uni<AISDLCEvent> publishAdmissionStarted(Integer issueNumber) {
        return publishEvent(
            issueNumber,
            null,
            "admission.started",
            EventStatus.IN_PROGRESS,
            EventStage.ADMISSION,
            Map.of()
        );
    }

    /**
     * Publish admission completed event
     */
    @Transactional
    public Uni<AISDLCEvent> publishAdmissionCompleted(Integer issueNumber, String decision, String reason) {
        return publishEvent(
            issueNumber,
            null,
            "admission.completed",
            EventStatus.COMPLETED,
            EventStage.ADMISSION,
            Map.of("decision", decision, "reason", reason)
        );
    }

    /**
     * Publish implementation started event
     */
    @Transactional
    public Uni<AISDLCEvent> publishImplementationStarted(Integer issueNumber) {
        return publishEvent(
            issueNumber,
            null,
            "implementation.started",
            EventStatus.IN_PROGRESS,
            EventStage.IMPLEMENTATION,
            Map.of()
        );
    }

    /**
     * Publish implementation completed event
     */
    @Transactional
    public Uni<AISDLCEvent> publishImplementationCompleted(Integer issueNumber, Long durationMs, Integer filesChanged) {
        return publishEvent(
            issueNumber,
            null,
            "implementation.completed",
            EventStatus.COMPLETED,
            EventStage.IMPLEMENTATION,
            Map.of("duration_ms", durationMs, "files_changed", filesChanged)
        );
    }

    /**
     * Publish PR created event
     */
    @Transactional
    public Uni<AISDLCEvent> publishPRCreated(Integer issueNumber, Integer prNumber, String prUrl) {
        return publishEvent(
            issueNumber,
            prNumber,
            "pr.created",
            EventStatus.COMPLETED,
            EventStage.PR_MANAGEMENT,
            Map.of("pr_url", prUrl)
        );
    }

    /**
     * Publish PR merged event
     */
    @Transactional
    public Uni<AISDLCEvent> publishPRMerged(Integer issueNumber, Integer prNumber, String commitSha) {
        return publishEvent(
            issueNumber,
            prNumber,
            "pr.merged",
            EventStatus.COMPLETED,
            EventStage.PR_MANAGEMENT,
            Map.of("commit_sha", commitSha)
        );
    }

    /**
     * Publish CI check failed event
     */
    @Transactional
    public Uni<AISDLCEvent> publishCICheckFailed(Integer issueNumber, Integer prNumber, String checkName, String errorMessage) {
        return publishEvent(
            issueNumber,
            prNumber,
            "ci.check.failed",
            EventStatus.FAILED,
            EventStage.CI_CHECKS,
            Map.of("check_name", checkName, "error_message", errorMessage)
        );
    }

    /**
     * Publish error event
     */
    @Transactional
    public Uni<AISDLCEvent> publishError(Integer issueNumber, String errorMessage) {
        return publishEvent(
            issueNumber,
            null,
            "error.occurred",
            EventStatus.FAILED,
            EventStage.ERROR,
            Map.of("error_message", errorMessage)
        );
    }

    /**
     * Core publish method
     * Creates event and updates tracking state in a single transaction
     */
    @Transactional
    public Uni<AISDLCEvent> publishEvent(
            Integer issueNumber,
            Integer prNumber,
            String eventType,
            EventStatus status,
            EventStage stage,
            Map<String, Object> metadata
    ) {
        Log.debugf("Publishing event: type=%s, issue=%d, status=%s, stage=%s",
            eventType, issueNumber, status, stage);

        return trackingService.getOrCreateTrackingId(issueNumber)
            .chain(trackingId -> {
                // Build event
                AISDLCEvent event = AISDLCEvent.builder()
                    .trackingId(trackingId)
                    .actionId(trackingService.generateActionId(eventType.replace(".", "_")))
                    .eventType(eventType)
                    .timestamp(Instant.now())
                    .issueNumber(issueNumber)
                    .prNumber(prNumber)
                    .status(status)
                    .stage(stage)
                    .metadata(metadata)
                    .build();

                // Persist event
                return eventRepo.persistEvent(event)
                    .chain(persistedEvent -> {
                        // Update tracking state
                        return updateTrackingState(persistedEvent)
                            .replaceWith(persistedEvent);
                    })
                    .chain(persistedEvent -> {
                        // Update projection (async)
                        return projectionUpdater.projectEvent(persistedEvent)
                            .replaceWith(persistedEvent);
                    });
            })
            .onItem().invoke(event -> {
                Log.infof("Event published: id=%s, type=%s, issue=%d",
                    event.getEventId(), event.getEventType(), event.getIssueNumber());
                metrics.recordEventPublished(event.getEventType(), event.getStage(), event.getStatus());
            })
            .onFailure().invoke(throwable ->
                Log.errorf(throwable, "Failed to publish event: type=%s, issue=%d", eventType, issueNumber)
            );
    }

    /**
     * Update tracking state based on event
     */
    private Uni<Void> updateTrackingState(AISDLCEvent event) {
        return trackingRepo.findById(event.getIssueNumber())
            .onItem().ifNull().continueWith(() -> createTrackingState(event))
            .chain(tracking -> {
                // Update tracking state
                tracking.setCurrentStage(event.getStage());
                tracking.setStatus(event.getStatus());
                tracking.setLastEventAt(event.getTimestamp());
                tracking.setEventCount(tracking.getEventCount() + 1);

                if (event.getStatus() == EventStatus.FAILED) {
                    tracking.setErrorCount(tracking.getErrorCount() + 1);
                }

                if (event.getPrNumber() != null) {
                    tracking.setPrNumber(event.getPrNumber());
                }

                return trackingRepo.persistAndFlush(tracking);
            })
            .replaceWithVoid();
    }

    /**
     * Create new tracking state
     */
    private TrackingState createTrackingState(AISDLCEvent event) {
        TrackingState tracking = new TrackingState();
        tracking.setIssueNumber(event.getIssueNumber());
        tracking.setTrackingId(event.getTrackingId());
        tracking.setCurrentStage(event.getStage());
        tracking.setStatus(event.getStatus());
        tracking.setFirstEventAt(event.getTimestamp());
        tracking.setLastEventAt(event.getTimestamp());
        tracking.setEventCount(0);
        tracking.setErrorCount(0);

        return tracking;
    }
}
