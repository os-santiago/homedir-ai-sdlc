package io.opensourcesantiago.aisdlc.events.domain;

import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import org.hibernate.annotations.Type;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Event Store entity - immutable event log
 * Each event represents a single occurrence in the AI-SDLC pipeline
 */
@Entity
@Table(name = "ai_sdlc_events")
public class AISDLCEvent {

    @Id
    @GeneratedValue
    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "tracking_id", nullable = false, length = 100)
    private String trackingId;

    @Column(name = "action_id", nullable = false, length = 100)
    private String actionId;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Column(nullable = false)
    private Instant timestamp;

    @Column(name = "issue_number", nullable = false)
    private Integer issueNumber;

    @Column(name = "pr_number")
    private Integer prNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EventStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private EventStage stage;

    @Type(JsonBinaryType.class)
    @Column(columnDefinition = "jsonb", nullable = false)
    private Map<String, Object> metadata = new HashMap<>();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_event_id")
    private AISDLCEvent parentEvent;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (timestamp == null) {
            timestamp = Instant.now();
        }
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

    public String getActionId() {
        return actionId;
    }

    public void setActionId(String actionId) {
        this.actionId = actionId;
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

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata != null ? metadata : new HashMap<>();
    }

    public AISDLCEvent getParentEvent() {
        return parentEvent;
    }

    public void setParentEvent(AISDLCEvent parentEvent) {
        this.parentEvent = parentEvent;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    // Builder pattern
    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private final AISDLCEvent event = new AISDLCEvent();

        public Builder trackingId(String trackingId) {
            event.trackingId = trackingId;
            return this;
        }

        public Builder actionId(String actionId) {
            event.actionId = actionId;
            return this;
        }

        public Builder eventType(String eventType) {
            event.eventType = eventType;
            return this;
        }

        public Builder timestamp(Instant timestamp) {
            event.timestamp = timestamp;
            return this;
        }

        public Builder issueNumber(Integer issueNumber) {
            event.issueNumber = issueNumber;
            return this;
        }

        public Builder prNumber(Integer prNumber) {
            event.prNumber = prNumber;
            return this;
        }

        public Builder status(EventStatus status) {
            event.status = status;
            return this;
        }

        public Builder stage(EventStage stage) {
            event.stage = stage;
            return this;
        }

        public Builder metadata(Map<String, Object> metadata) {
            event.metadata = metadata != null ? new HashMap<>(metadata) : new HashMap<>();
            return this;
        }

        public Builder parentEvent(AISDLCEvent parentEvent) {
            event.parentEvent = parentEvent;
            return this;
        }

        public AISDLCEvent build() {
            if (event.trackingId == null) {
                throw new IllegalStateException("trackingId is required");
            }
            if (event.actionId == null) {
                throw new IllegalStateException("actionId is required");
            }
            if (event.eventType == null) {
                throw new IllegalStateException("eventType is required");
            }
            if (event.issueNumber == null) {
                throw new IllegalStateException("issueNumber is required");
            }
            if (event.status == null) {
                throw new IllegalStateException("status is required");
            }
            if (event.stage == null) {
                throw new IllegalStateException("stage is required");
            }
            return event;
        }
    }

    @Override
    public String toString() {
        return "AISDLCEvent{" +
                "eventId=" + eventId +
                ", trackingId='" + trackingId + '\'' +
                ", eventType='" + eventType + '\'' +
                ", issueNumber=" + issueNumber +
                ", status=" + status +
                ", stage=" + stage +
                '}';
    }
}
