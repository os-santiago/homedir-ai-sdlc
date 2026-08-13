package io.opensourcesantiago.aisdlc.events.service;

import io.opensourcesantiago.aisdlc.events.domain.TrackingState;
import io.opensourcesantiago.aisdlc.events.repository.TrackingStateRepository;
import io.quarkus.logging.Log;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * Service for managing tracking IDs
 * Generates and maintains tracking state for issues
 */
@ApplicationScoped
public class TrackingService {

    private static final DateTimeFormatter TIMESTAMP_FORMAT =
        DateTimeFormatter.ofPattern("yyyyMMddHHmmss").withZone(ZoneId.of("UTC"));

    @Inject
    TrackingStateRepository trackingRepo;

    /**
     * Get or create tracking ID for an issue
     * Format: track_{issue_number}_{timestamp}
     */
    public Uni<String> getOrCreateTrackingId(Integer issueNumber) {
        return trackingRepo.findById(issueNumber)
            .onItem().transform(tracking -> {
                if (tracking != null) {
                    return tracking.getTrackingId();
                } else {
                    return generateTrackingId(issueNumber);
                }
            });
    }

    /**
     * Generate new tracking ID
     */
    public String generateTrackingId(Integer issueNumber) {
        String timestamp = TIMESTAMP_FORMAT.format(Instant.now());
        return String.format("track_%d_%s", issueNumber, timestamp);
    }

    /**
     * Generate action ID
     * Format: act_{action_type}_{timestamp}
     */
    public String generateActionId(String actionType) {
        String timestamp = TIMESTAMP_FORMAT.format(Instant.now());
        return String.format("act_%s_%s", actionType, timestamp);
    }

    /**
     * Check if tracking exists for an issue
     */
    public Uni<Boolean> trackingExists(Integer issueNumber) {
        return trackingRepo.findById(issueNumber)
            .onItem().transform(state -> state != null);
    }

    /**
     * Get tracking state by issue number
     */
    public Uni<TrackingState> getTrackingState(Integer issueNumber) {
        return trackingRepo.findById(issueNumber);
    }
}
