package io.opensourcesantiago.aisdlc.events.repository;

import io.opensourcesantiago.aisdlc.events.domain.EventStage;
import io.opensourcesantiago.aisdlc.events.domain.EventStatus;
import io.opensourcesantiago.aisdlc.events.domain.TrackingState;
import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;

/**
 * Repository for Tracking State (read model)
 */
@ApplicationScoped
public class TrackingStateRepository implements PanacheRepositoryBase<TrackingState, Integer> {

    /**
     * Find tracking state by tracking ID
     */
    public Uni<TrackingState> findByTrackingId(String trackingId) {
        return find("trackingId", trackingId).firstResult();
    }

    /**
     * Find all active issues (not completed)
     */
    public Uni<List<TrackingState>> findActive() {
        return find("status != ?1", EventStatus.COMPLETED).list();
    }

    /**
     * Find by stage
     */
    public Uni<List<TrackingState>> findByStage(EventStage stage) {
        return find("currentStage", stage).list();
    }

    /**
     * Count active issues
     */
    public Uni<Long> countActive() {
        return count("status != ?1", EventStatus.COMPLETED);
    }
}
