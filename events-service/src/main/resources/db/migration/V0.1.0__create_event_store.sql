-- AI-SDLC Event Store Schema
-- Version: 0.1.0
-- Description: Event Sourcing foundation with event store and tracking state

-- Event Store (single source of truth)
CREATE TABLE ai_sdlc_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracking_id VARCHAR(100) NOT NULL,
    action_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    issue_number INTEGER NOT NULL,
    pr_number INTEGER,
    status VARCHAR(20) NOT NULL,
    stage VARCHAR(30) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    parent_event_id UUID REFERENCES ai_sdlc_events(event_id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_events_tracking_id ON ai_sdlc_events(tracking_id, timestamp DESC);
CREATE INDEX idx_events_issue_number ON ai_sdlc_events(issue_number);
CREATE INDEX idx_events_timestamp ON ai_sdlc_events(timestamp DESC);
CREATE INDEX idx_events_type_stage ON ai_sdlc_events(event_type, stage);
CREATE INDEX idx_events_status ON ai_sdlc_events(status) WHERE status = 'FAILED';

-- Tracking State (read model / projection)
CREATE TABLE tracking_state (
    issue_number INTEGER PRIMARY KEY,
    tracking_id VARCHAR(100) UNIQUE NOT NULL,
    current_stage VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    first_event_at TIMESTAMPTZ NOT NULL,
    last_event_at TIMESTAMPTZ NOT NULL,
    pr_number INTEGER,
    event_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for active issues
CREATE INDEX idx_tracking_state_status ON tracking_state(status) WHERE status != 'COMPLETED';
CREATE INDEX idx_tracking_state_stage ON tracking_state(current_stage);

-- Comments for documentation
COMMENT ON TABLE ai_sdlc_events IS 'Event Store - immutable log of all AI-SDLC events';
COMMENT ON TABLE tracking_state IS 'Tracking State - current state projection for each issue';

COMMENT ON COLUMN ai_sdlc_events.event_id IS 'Unique event identifier (UUID v4)';
COMMENT ON COLUMN ai_sdlc_events.tracking_id IS 'Issue lifecycle tracking ID (track_<issue>_<timestamp>)';
COMMENT ON COLUMN ai_sdlc_events.action_id IS 'Action identifier (act_<type>_<timestamp>)';
COMMENT ON COLUMN ai_sdlc_events.event_type IS 'Event type (e.g., issue.detected, pr.created)';
COMMENT ON COLUMN ai_sdlc_events.metadata IS 'Event-specific metadata as JSON';
COMMENT ON COLUMN ai_sdlc_events.parent_event_id IS 'Parent event for causality chain';
