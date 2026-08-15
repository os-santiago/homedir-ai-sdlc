package io.opensourcesantiago.aisdlc.events;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Service for querying AI-SDLC events from filesystem-based queues
 */
@ApplicationScoped
public class EventQueryService {

    private static final Logger LOG = Logger.getLogger(EventQueryService.class);

    @ConfigProperty(name = "sdlc.state-dir", defaultValue = "/var/lib/homedir-sdlc")
    String stateDir;

    @Inject
    ObjectMapper objectMapper;

    private Path getEventQueueDir() {
        return Paths.get(stateDir, "events");
    }

    private Path getAllEventsStream() {
        return getEventQueueDir().resolve("all-events.jsonl");
    }

    private Path getTrackingState() {
        return getEventQueueDir().resolve("tracking-state.json");
    }

    /**
     * Get tracking ID for an issue number
     */
    public String getTrackingIdForIssue(int issueNumber) throws IOException {
        Path trackingStatePath = getTrackingState();
        if (!Files.exists(trackingStatePath)) {
            return null;
        }

        Map<String, String> trackingState = objectMapper.readValue(
            trackingStatePath.toFile(),
            new TypeReference<Map<String, String>>() {}
        );

        return trackingState.get(String.valueOf(issueNumber));
    }

    /**
     * Get all events for a tracking ID
     */
    public List<Map<String, Object>> getEventsByTrackingId(String trackingId) throws IOException {
        List<Map<String, Object>> events = new ArrayList<>();

        // Search all queue directories for this tracking ID
        Path eventQueueDir = getEventQueueDir();
        if (!Files.exists(eventQueueDir)) {
            return events;
        }

        try (Stream<Path> paths = Files.walk(eventQueueDir)) {
            paths.filter(path -> path.toString().endsWith(trackingId + ".jsonl"))
                 .forEach(path -> {
                     try {
                         List<String> lines = Files.readAllLines(path);
                         for (String line : lines) {
                             Map<String, Object> event = objectMapper.readValue(
                                 line, new TypeReference<Map<String, Object>>() {}
                             );
                             events.add(event);
                         }
                     } catch (IOException e) {
                         LOG.error("Error reading events from " + path, e);
                     }
                 });
        }

        // Sort by timestamp
        events.sort(Comparator.comparing(e -> (String) e.get("timestamp")));

        return events;
    }

    /**
     * Get latest N events from all-events stream
     */
    public List<Map<String, Object>> getLatestEvents(int limit) throws IOException {
        Path allEventsPath = getAllEventsStream();
        if (!Files.exists(allEventsPath)) {
            return Collections.emptyList();
        }

        List<String> lines = Files.readAllLines(allEventsPath);
        int start = Math.max(0, lines.size() - limit);
        List<String> recentLines = lines.subList(start, lines.size());

        List<Map<String, Object>> events = new ArrayList<>();
        for (String line : recentLines) {
            events.add(objectMapper.readValue(line, new TypeReference<Map<String, Object>>() {}));
        }

        Collections.reverse(events); // Most recent first
        return events;
    }

    /**
     * Get events by stage
     */
    public List<Map<String, Object>> getEventsByStage(String stage, int limit) throws IOException {
        Path stageDir = getEventQueueDir().resolve(stage);
        if (!Files.exists(stageDir)) {
            return Collections.emptyList();
        }

        List<Map<String, Object>> events = new ArrayList<>();

        try (Stream<Path> paths = Files.list(stageDir)) {
            paths.filter(path -> path.toString().endsWith(".jsonl"))
                 .forEach(path -> {
                     try {
                         List<String> lines = Files.readAllLines(path);
                         for (String line : lines) {
                             Map<String, Object> event = objectMapper.readValue(
                                 line, new TypeReference<Map<String, Object>>() {}
                             );
                             events.add(event);
                         }
                     } catch (IOException e) {
                         LOG.error("Error reading events from " + path, e);
                     }
                 });
        }

        // Sort by timestamp descending
        events.sort((e1, e2) -> ((String) e2.get("timestamp")).compareTo((String) e1.get("timestamp")));

        return events.stream().limit(limit).collect(Collectors.toList());
    }

    /**
     * Get event timeline formatted for visualization
     */
    public Map<String, Object> getEventTimeline(int issueNumber) throws IOException {
        String trackingId = getTrackingIdForIssue(issueNumber);
        if (trackingId == null) {
            throw new IllegalArgumentException("No tracking ID found for issue " + issueNumber);
        }

        List<Map<String, Object>> events = getEventsByTrackingId(trackingId);

        // Build timeline structure
        Map<String, Object> timeline = new LinkedHashMap<>();
        timeline.put("issue_number", issueNumber);
        timeline.put("tracking_id", trackingId);
        timeline.put("total_events", events.size());

        if (events.isEmpty()) {
            timeline.put("stages", Collections.emptyList());
            return timeline;
        }

        // Group events by stage
        Map<String, List<Map<String, Object>>> byStage = events.stream()
            .collect(Collectors.groupingBy(e -> (String) e.get("stage")));

        // Calculate stage durations
        List<Map<String, Object>> stages = new ArrayList<>();
        String[] stageOrder = {"detection", "admission", "implementation", "pr_management", "ci_checks", "remediation", "deployment"};

        for (String stage : stageOrder) {
            List<Map<String, Object>> stageEvents = byStage.getOrDefault(stage, Collections.emptyList());
            if (stageEvents.isEmpty()) continue;

            Map<String, Object> stageInfo = new LinkedHashMap<>();
            stageInfo.put("stage", stage);
            stageInfo.put("event_count", stageEvents.size());

            String firstTimestamp = (String) stageEvents.get(0).get("timestamp");
            String lastTimestamp = (String) stageEvents.get(stageEvents.size() - 1).get("timestamp");

            stageInfo.put("started_at", firstTimestamp);
            stageInfo.put("completed_at", lastTimestamp);

            // Calculate duration
            try {
                ZonedDateTime start = ZonedDateTime.parse(firstTimestamp, DateTimeFormatter.ISO_DATE_TIME);
                ZonedDateTime end = ZonedDateTime.parse(lastTimestamp, DateTimeFormatter.ISO_DATE_TIME);
                long durationMs = ChronoUnit.MILLIS.between(start, end);
                stageInfo.put("duration_ms", durationMs);
            } catch (Exception e) {
                LOG.warn("Could not parse timestamps for duration calculation", e);
            }

            stageInfo.put("events", stageEvents);
            stages.add(stageInfo);
        }

        timeline.put("stages", stages);

        // Overall metrics
        String firstEventTime = (String) events.get(0).get("timestamp");
        String lastEventTime = (String) events.get(events.size() - 1).get("timestamp");
        timeline.put("started_at", firstEventTime);
        timeline.put("last_event_at", lastEventTime);

        try {
            ZonedDateTime start = ZonedDateTime.parse(firstEventTime, DateTimeFormatter.ISO_DATE_TIME);
            ZonedDateTime end = ZonedDateTime.parse(lastEventTime, DateTimeFormatter.ISO_DATE_TIME);
            long totalDurationMs = ChronoUnit.MILLIS.between(start, end);
            timeline.put("total_duration_ms", totalDurationMs);
        } catch (Exception e) {
            LOG.warn("Could not calculate total duration", e);
        }

        return timeline;
    }

    /**
     * Get event statistics
     */
    public Map<String, Object> getEventStatistics() throws IOException {
        List<Map<String, Object>> allEvents = getLatestEvents(1000);

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("total_events", allEvents.size());

        // Events by type
        Map<String, Long> byType = allEvents.stream()
            .collect(Collectors.groupingBy(e -> (String) e.get("event_type"), Collectors.counting()));
        stats.put("by_type", byType);

        // Events by stage
        Map<String, Long> byStage = allEvents.stream()
            .collect(Collectors.groupingBy(e -> (String) e.get("stage"), Collectors.counting()));
        stats.put("by_stage", byStage);

        // Events by status
        Map<String, Long> byStatus = allEvents.stream()
            .collect(Collectors.groupingBy(e -> (String) e.get("status"), Collectors.counting()));
        stats.put("by_status", byStatus);

        // Recent errors
        long errorCount = allEvents.stream()
            .filter(e -> "failed".equals(e.get("status")) || "error".equals(e.get("stage")))
            .count();
        stats.put("error_count", errorCount);

        return stats;
    }

    /**
     * Get active trackings (issues currently in pipeline)
     */
    public List<Map<String, Object>> getActiveTrackings() throws IOException {
        Path trackingStatePath = getTrackingState();
        if (!Files.exists(trackingStatePath)) {
            return Collections.emptyList();
        }

        Map<String, String> trackingState = objectMapper.readValue(
            trackingStatePath.toFile(),
            new TypeReference<Map<String, String>>() {}
        );

        List<Map<String, Object>> active = new ArrayList<>();

        for (Map.Entry<String, String> entry : trackingState.entrySet()) {
            int issueNumber = Integer.parseInt(entry.getKey());
            String trackingId = entry.getValue();

            List<Map<String, Object>> events = getEventsByTrackingId(trackingId);
            if (events.isEmpty()) continue;

            // Check if still active (no deployment.completed or pr.merged)
            boolean hasDeployment = events.stream()
                .anyMatch(e -> "deployment.completed".equals(e.get("event_type")));
            boolean hasMerged = events.stream()
                .anyMatch(e -> "pr.merged".equals(e.get("event_type")));

            if (!hasDeployment && !hasMerged) {
                Map<String, Object> lastEvent = events.get(events.size() - 1);

                Map<String, Object> tracking = new LinkedHashMap<>();
                tracking.put("issue_number", issueNumber);
                tracking.put("tracking_id", trackingId);
                tracking.put("current_stage", lastEvent.get("stage"));
                tracking.put("last_event_type", lastEvent.get("event_type"));
                tracking.put("last_event_time", lastEvent.get("timestamp"));
                tracking.put("event_count", events.size());

                active.add(tracking);
            }
        }

        return active;
    }
}
