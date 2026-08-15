// AI-SDLC Events Dashboard JavaScript

const API_BASE = '/api/sdlc/events';
let autoRefreshInterval = null;

// Stage icons
const STAGE_ICONS = {
    detection: '🔍',
    admission: '✅',
    implementation: '⚙️',
    pr_management: '📋',
    ci_checks: '🧪',
    remediation: '🔧',
    deployment: '🚀'
};

// Stage names
const STAGE_NAMES = {
    detection: 'Detection',
    admission: 'Admission',
    implementation: 'Implementation',
    pr_management: 'PR Management',
    ci_checks: 'CI Checks',
    remediation: 'Remediation',
    deployment: 'Deployment'
};

// Format timestamp
function formatTimestamp(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return `${seconds}s ago`;
}

// Format duration
function formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) return `${hours}h ${minutes % 60}m`;
    if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
    return `${seconds}s`;
}

// Render statistics
function renderStats(stats) {
    const statsDiv = document.getElementById('stats');

    const html = `
        <div class="stat-box">
            <span class="stat-label">Total Events</span>
            <span class="stat-value">${stats.total_events || 0}</span>
        </div>
        <div class="stat-box">
            <span class="stat-label">Errors</span>
            <span class="stat-value" style="color: ${stats.error_count > 0 ? '#f44336' : '#4caf50'}">${stats.error_count || 0}</span>
        </div>
        <div class="stat-box">
            <span class="stat-label">Active Issues</span>
            <span class="stat-value" style="color: #ff9800">${stats.active_count || 0}</span>
        </div>
    `;

    statsDiv.innerHTML = html;
}

// Render active issues
function renderActiveIssues(activeIssues) {
    const container = document.getElementById('activeIssues');

    if (!activeIssues || activeIssues.length === 0) {
        container.innerHTML = '<p style="color: #999; text-align: center;">No active issues</p>';
        return;
    }

    const html = activeIssues.map(issue => `
        <div class="issue-card" onclick="loadIssueTimeline(${issue.issue_number})">
            <div class="issue-number">#${issue.issue_number}</div>
            <div class="issue-stage">${STAGE_NAMES[issue.current_stage] || issue.current_stage}</div>
            <div class="event-time">${formatTimestamp(issue.last_event_time)}</div>
        </div>
    `).join('');

    container.innerHTML = html;
}

// Render pipeline
function renderPipeline(currentStage, completedStages) {
    const pipelineDiv = document.getElementById('pipeline');
    const stages = ['detection', 'admission', 'implementation', 'pr_management', 'ci_checks', 'remediation', 'deployment'];

    const html = stages.map(stage => {
        const isActive = stage === currentStage;
        const isCompleted = completedStages && completedStages.includes(stage);
        const className = isActive ? 'active' : isCompleted ? 'completed' : '';

        return `
            <div class="stage ${className}">
                <div class="stage-icon">${STAGE_ICONS[stage]}</div>
                <div class="stage-name">${STAGE_NAMES[stage]}</div>
            </div>
        `;
    }).join('');

    pipelineDiv.innerHTML = html;
}

// Render timeline
function renderTimeline(events) {
    const timelineDiv = document.getElementById('timeline');

    if (!events || events.length === 0) {
        timelineDiv.innerHTML = '<p style="color: #999;">No events to display</p>';
        return;
    }

    const html = events.map(event => {
        const statusClass = event.status === 'completed' ? 'completed' :
                           event.status === 'failed' ? 'failed' :
                           event.status === 'in_progress' ? 'in-progress' : '';

        const badgeClass = event.status === 'completed' ? 'badge-completed' :
                          event.status === 'failed' ? 'badge-failed' :
                          'badge-in-progress';

        const metadata = event.metadata || {};
        const metaInfo = [];

        if (metadata.decision) metaInfo.push(`Decision: ${metadata.decision}`);
        if (metadata.reason) metaInfo.push(`Reason: ${metadata.reason}`);
        if (metadata.duration_ms) metaInfo.push(`Duration: ${formatDuration(metadata.duration_ms)}`);
        if (metadata.pr_url) metaInfo.push(`PR: <a href="${metadata.pr_url}" target="_blank">${metadata.pr_url}</a>`);
        if (metadata.error_message) metaInfo.push(`Error: ${metadata.error_message}`);
        if (metadata.check_name) metaInfo.push(`Check: ${metadata.check_name}`);
        if (metadata.files_changed) metaInfo.push(`Files: ${metadata.files_changed}`);

        return `
            <div class="timeline-item ${statusClass}">
                <div class="event-header">
                    <span class="event-type">${event.event_type}</span>
                    <span class="event-time">${formatTimestamp(event.timestamp)}</span>
                </div>
                <div>
                    <span class="badge ${badgeClass}">${event.status}</span>
                    <span class="badge" style="background: #667eea20; color: #667eea">${STAGE_NAMES[event.stage] || event.stage}</span>
                    ${event.pr_number ? `<span class="badge" style="background: #76c7c020; color: #76c7c0">PR #${event.pr_number}</span>` : ''}
                </div>
                ${metaInfo.length > 0 ? `
                    <div class="event-meta">
                        ${metaInfo.join(' • ')}
                    </div>
                ` : ''}
                <div class="event-id">
                    Event: ${event.event_id}<br>
                    Tracking: ${event.tracking_id}<br>
                    Action: ${event.action_id}
                </div>
            </div>
        `;
    }).join('');

    timelineDiv.innerHTML = html;
}

// Load dashboard data
async function loadDashboard() {
    try {
        document.getElementById('error').style.display = 'none';

        // Load statistics
        const statsResponse = await fetch(`${API_BASE}/stats`);
        const stats = await statsResponse.json();

        // Load active issues
        const activeResponse = await fetch(`${API_BASE}/active`);
        const active = await activeResponse.json();

        stats.active_count = active.length;

        // Load latest events
        const eventsResponse = await fetch(`${API_BASE}/latest?limit=50`);
        const events = await eventsResponse.json();

        // Determine current stage from latest event
        let currentStage = null;
        let completedStages = [];
        if (events.length > 0) {
            currentStage = events[0].stage;
            // Mark stages before current as completed
            const stageOrder = ['detection', 'admission', 'implementation', 'pr_management', 'ci_checks', 'remediation', 'deployment'];
            const currentIndex = stageOrder.indexOf(currentStage);
            if (currentIndex > 0) {
                completedStages = stageOrder.slice(0, currentIndex);
            }
        }

        // Render components
        renderStats(stats);
        renderActiveIssues(active);
        renderPipeline(currentStage, completedStages);
        renderTimeline(events);

        document.getElementById('loading').style.display = 'none';
        document.getElementById('content').style.display = 'block';

    } catch (error) {
        console.error('Error loading dashboard:', error);
        document.getElementById('error').textContent = `Error loading dashboard: ${error.message}`;
        document.getElementById('error').style.display = 'block';
        document.getElementById('loading').style.display = 'none';
    }
}

// Load issue timeline
async function loadIssueTimeline(issueNumber) {
    if (!issueNumber) {
        issueNumber = document.getElementById('issueSearch').value;
    }

    if (!issueNumber) return;

    try {
        const response = await fetch(`${API_BASE}/timeline/${issueNumber}`);
        const timeline = await response.json();

        // Flatten all events from stages
        const allEvents = [];
        if (timeline.stages) {
            timeline.stages.forEach(stage => {
                if (stage.events) {
                    allEvents.push(...stage.events);
                }
            });
        }

        // Update pipeline based on stages
        const completedStages = [];
        let currentStage = null;
        if (timeline.stages && timeline.stages.length > 0) {
            currentStage = timeline.stages[timeline.stages.length - 1].stage;
            timeline.stages.forEach(s => {
                if (s.stage !== currentStage) {
                    completedStages.push(s.stage);
                }
            });
        }

        renderPipeline(currentStage, completedStages);
        renderTimeline(allEvents.reverse()); // Most recent first

        // Update search input
        document.getElementById('issueSearch').value = issueNumber;

        // Scroll to timeline
        document.getElementById('timeline').scrollIntoView({ behavior: 'smooth' });

    } catch (error) {
        console.error('Error loading issue timeline:', error);
        alert(`Error loading timeline for issue #${issueNumber}: ${error.message}`);
    }
}

// Auto-refresh toggle
document.getElementById('autoRefresh').addEventListener('change', (e) => {
    if (e.target.checked) {
        startAutoRefresh();
    } else {
        stopAutoRefresh();
    }
});

function startAutoRefresh() {
    if (autoRefreshInterval) return;

    autoRefreshInterval = setInterval(() => {
        loadDashboard();
    }, 15000); // 15 seconds
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

// Initialize dashboard
window.addEventListener('DOMContentLoaded', () => {
    loadDashboard();
    startAutoRefresh();
});

// Handle visibility change (pause refresh when tab not visible)
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        stopAutoRefresh();
    } else {
        const checkbox = document.getElementById('autoRefresh');
        if (checkbox.checked) {
            startAutoRefresh();
            loadDashboard();
        }
    }
});
