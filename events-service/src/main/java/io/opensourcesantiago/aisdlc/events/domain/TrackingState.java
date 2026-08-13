package io.opensourcesantiago.aisdlc.events.domain;

import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import org.hibernate.annotations.Type;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Tracking State - Read Model / Projection
 * Maintains current state of each issue being tracked
 */
@Entity
@Table(name = "tracking_state")
public class TrackingState {

    @Id
    @Column(name = "issue_number")
    private Integer issueNumber;

    @Column(name = "tracking_id", unique = true, nullable = false, length = 100)
    private String trackingId;

    @Enumerated(EnumType.STRING)
    @Column(name = "current_stage", nullable = false, length = 30)
    private EventStage currentStage;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EventStatus status;

    @Column(name = "first_event_at", nullable = false)
    private Instant firstEventAt;

    @Column(name = "last_event_at", nullable = false)
    private Instant lastEventAt;

    @Column(name = "pr_number")
    private Integer prNumber;

    @Column(name = "event_count", nullable = false)
    private Integer eventCount = 0;

    @Column(name = "error_count", nullable = false)
    private Integer errorCount = 0;

    @Type(JsonBinaryType.class)
    @Column(columnDefinition = "jsonb", nullable = false)
    private Map<String, Object> metadata = new HashMap<>();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    @PrePersist
    protected void onCreate() {
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }

    // Getters and Setters

    public Integer getIssueNumber() {
        return issueNumber;
    }

    public void setIssueNumber(Integer issueNumber) {
        this.issueNumber = issueNumber;
    }

    public String getTrackingId() {
        return trackingId;
    }

    public void setTrackingId(String trackingId) {
        this.trackingId = trackingId;
    }

    public EventStage getCurrentStage() {
        return currentStage;
    }

    public void setCurrentStage(EventStage currentStage) {
        this.currentStage = currentStage;
    }

    public EventStatus getStatus() {
        return status;
    }

    public void setStatus(EventStatus status) {
        this.status = status;
    }

    public Instant getFirstEventAt() {
        return firstEventAt;
    }

    public void setFirstEventAt(Instant firstEventAt) {
        this.firstEventAt = firstEventAt;
    }

    public Instant getLastEventAt() {
        return lastEventAt;
    }

    public void setLastEventAt(Instant lastEventAt) {
        this.lastEventAt = lastEventAt;
    }

    public Integer getPrNumber() {
        return prNumber;
    }

    public void setPrNumber(Integer prNumber) {
        this.prNumber = prNumber;
    }

    public Integer getEventCount() {
        return eventCount;
    }

    public void setEventCount(Integer eventCount) {
        this.eventCount = eventCount;
    }

    public Integer getErrorCount() {
        return errorCount;
    }

    public void setErrorCount(Integer errorCount) {
        this.errorCount = errorCount;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata != null ? metadata : new HashMap<>();
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    @Override
    public String toString() {
        return "TrackingState{" +
                "issueNumber=" + issueNumber +
                ", trackingId='" + trackingId + '\'' +
                ", currentStage=" + currentStage +
                ", status=" + status +
                ", eventCount=" + eventCount +
                '}';
    }
}
