package io.opensourcesantiago.aisdlc.events.projection;

import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Read Model: Projection of events optimized for queries
 * Denormalized view combining event data with tracking context
 */
@Entity
@Table(name = "event_projections", indexes = {
    @Index(name = "idx_projection_timestamp", columnList = "timestamp DESC"),
    @Index(name = "idx_projection_issue", columnList = "issue_number"),
    @Index(name = "idx_projection_stage", columnList = "stage"),
    @Index(name = "idx_projection_status", columnList = "status")
})
public class EventProjection {

    @Id
    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "tracking_id", nullable = false, length = 100)
    private String trackingId;

    @Column(name = "issue_number", nullable = false)
    private Integer issueNumber;

    @Column(name = "pr_number")
    private Integer prNumber;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Column(nullable = false)
    private Instant timestamp;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EventStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private EventStage stage;

    // Denormalized tracking data
    @Column(name = "event_sequence", nullable = false)
    private Integer eventSequence; // Event number in this tracking_id

    @Column(name = "tracking_started_at", nullable = false)
    private Instant trackingStartedAt;

    @Column(name = "duration_ms")
    private Long durationMs; // Time since tracking started

    // Metadata summary (extracted from JSONB for fast queries)
    private String decision; // admission.completed decision

    @Column(name = "error_message")
    private String errorMessage; // error.occurred message

    @Column(name = "files_changed")
    private Integer filesChanged; // implementation.completed files

    @Column(name = "pr_url")
    private String prUrl; // pr.created URL

    // Timestamps
    @Column(name = "projected_at", nullable = false, updatable = false)
    private Instant projectedAt;

    // Constructors

    public EventProjection() {
        this.projectedAt = Instant.now();
    }

    // Getters and Setters

    public UUID getEventId() {
        return eventId;
    }

    public void setEventId(UUID eventId) {
        this.eventId = eventId;
    }

    public String getTrackingId() {
        return trackingId;
    }

    public void setTrackingId(String trackingId) {
        this.trackingId = trackingId;
    }

    public Integer getIssueNumber() {
        return issueNumber;
    }

    public void setIssueNumber(Integer issueNumber) {
        this.issueNumber = issueNumber;
    }

    public Integer getPrNumber() {
        return prNumber;
    }

    public void setPrNumber(Integer prNumber) {
        this.prNumber = prNumber;
    }

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String eventType) {
        this.eventType = eventType;
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Instant timestamp) {
        this.timestamp = timestamp;
    }

    public EventStatus getStatus() {
        return status;
    }

    public void setStatus(EventStatus status) {
        this.status = status;
    }

    public EventStage getStage() {
        return stage;
    }

    public void setStage(EventStage stage) {
        this.stage = stage;
    }

    public Integer getEventSequence() {
        return eventSequence;
    }

    public void setEventSequence(Integer eventSequence) {
        this.eventSequence = eventSequence;
    }

    public Instant getTrackingStartedAt() {
        return trackingStartedAt;
    }

    public void setTrackingStartedAt(Instant trackingStartedAt) {
        this.trackingStartedAt = trackingStartedAt;
    }

    public Long getDurationMs() {
        return durationMs;
    }

    public void setDurationMs(Long durationMs) {
        this.durationMs = durationMs;
    }

    public String getDecision() {
        return decision;
    }

    public void setDecision(String decision) {
        this.decision = decision;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public Integer getFilesChanged() {
        return filesChanged;
    }

    public void setFilesChanged(Integer filesChanged) {
        this.filesChanged = filesChanged;
    }

    public String getPrUrl() {
        return prUrl;
    }

    public void setPrUrl(String prUrl) {
        this.prUrl = prUrl;
    }

    public Instant getProjectedAt() {
        return projectedAt;
    }

    public void setProjectedAt(Instant projectedAt) {
        this.projectedAt = projectedAt;
    }
}
