package io.opensourcesantiago.aisdlc.events.api.dto;

import jakarta.validation.constraints.NotNull;

import java.util.HashMap;
import java.util.Map;

/**
 * Request DTO for publishing events
 */
public class PublishEventRequest {

    @NotNull
    private String eventType;

    @NotNull
    private Integer issueNumber;

    private Integer prNumber;

    private Map<String, Object> metadata = new HashMap<>();

    // Getters and Setters

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String eventType) {
        this.eventType = eventType;
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

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata != null ? metadata : new HashMap<>();
    }

    @Override
    public String toString() {
        return "PublishEventRequest{" +
                "eventType='" + eventType + '\'' +
                ", issueNumber=" + issueNumber +
                ", prNumber=" + prNumber +
                '}';
    }
}
