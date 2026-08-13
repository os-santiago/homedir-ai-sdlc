-- Release 0.3: Event Projections and Read Models
-- Denormalized views optimized for queries

CREATE TABLE event_projections (
    event_id UUID PRIMARY KEY REFERENCES ai_sdlc_events(event_id),
    tracking_id VARCHAR(100) NOT NULL,
    issue_number INTEGER NOT NULL,
    pr_number INTEGER,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,
    stage VARCHAR(30) NOT NULL,

    -- Denormalized tracking context
    event_sequence INTEGER NOT NULL,
    tracking_started_at TIMESTAMPTZ NOT NULL,
    duration_ms BIGINT,

    -- Extracted metadata for fast queries
    decision VARCHAR(50),
    error_message TEXT,
    files_changed INTEGER,
    pr_url TEXT,

    -- Projection metadata
    projected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX idx_projection_timestamp ON event_projections(timestamp DESC);
CREATE INDEX idx_projection_issue ON event_projections(issue_number);
CREATE INDEX idx_projection_stage ON event_projections(stage);
CREATE INDEX idx_projection_status ON event_projections(status);
CREATE INDEX idx_projection_tracking ON event_projections(tracking_id);

-- Statistics aggregation table
CREATE TABLE stage_statistics (
    stage VARCHAR(30) PRIMARY KEY,
    total_events BIGINT NOT NULL DEFAULT 0,
    completed_events BIGINT NOT NULL DEFAULT 0,
    failed_events BIGINT NOT NULL DEFAULT 0,
    in_progress_events BIGINT NOT NULL DEFAULT 0,
    avg_duration_ms BIGINT,
    min_duration_ms BIGINT,
    max_duration_ms BIGINT,
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Initialize statistics for all stages
INSERT INTO stage_statistics (stage) VALUES
    ('DETECTION'),
    ('ADMISSION'),
    ('IMPLEMENTATION'),
    ('PR_MANAGEMENT'),
    ('CI_CHECKS'),
    ('ERROR');

-- Timeline view: chronological event flow per issue
CREATE MATERIALIZED VIEW issue_timeline AS
SELECT
    ep.issue_number,
    ep.tracking_id,
    ep.event_id,
    ep.event_type,
    ep.timestamp,
    ep.stage,
    ep.status,
    ep.event_sequence,
    ep.duration_ms,
    ep.decision,
    ep.error_message,
    ep.pr_number,
    ep.pr_url
FROM event_projections ep
ORDER BY ep.issue_number, ep.timestamp ASC;

CREATE INDEX idx_timeline_issue ON issue_timeline(issue_number);

-- Active issues view: current state of in-progress issues
CREATE MATERIALIZED VIEW active_issues AS
SELECT
    ts.issue_number,
    ts.tracking_id,
    ts.current_stage,
    ts.status,
    ts.pr_number,
    ts.event_count,
    ts.error_count,
    ts.first_event_at,
    ts.last_event_at,
    EXTRACT(EPOCH FROM (NOW() - ts.first_event_at)) * 1000 AS total_duration_ms,
    EXTRACT(EPOCH FROM (NOW() - ts.last_event_at)) * 1000 AS idle_duration_ms
FROM tracking_state ts
WHERE ts.status IN ('IN_PROGRESS', 'PENDING')
ORDER BY ts.last_event_at DESC;

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_read_models()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY issue_timeline;
    REFRESH MATERIALIZED VIEW CONCURRENTLY active_issues;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE event_projections IS 'Denormalized event view optimized for queries';
COMMENT ON TABLE stage_statistics IS 'Aggregated metrics per pipeline stage';
COMMENT ON MATERIALIZED VIEW issue_timeline IS 'Chronological event flow per issue';
COMMENT ON MATERIALIZED VIEW active_issues IS 'Current state of in-progress issues';
