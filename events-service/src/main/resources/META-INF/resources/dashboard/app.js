// AI-SDLC Dashboard App with REST Polling

class DashboardApp {
    constructor() {
        this.pollingInterval = null;
        this.isConnected = false;
        this.lastUpdate = null;
    }

    init() {
        console.log('Dashboard initializing...');
        this.startPolling();
        this.setupRefreshButton();
    }

    startPolling() {
        // Initial fetch
        this.fetchDashboardData();

        // Poll every 5 seconds
        this.pollingInterval = setInterval(() => {
            this.fetchDashboardData();
        }, 5000);
    }

    async fetchDashboardData() {
        try {
            const response = await fetch('/api/dashboard/snapshot');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            console.log('Dashboard data received', data);
            this.isConnected = true;
            this.updateConnectionStatus(true);
            this.updateDashboard(data);
        } catch (error) {
            console.error('Error fetching dashboard data:', error);
            this.isConnected = false;
            this.updateConnectionStatus(false);
        }
    }

    updateConnectionStatus(connected) {
        const statusEl = document.getElementById('connection-status');
        if (connected) {
            statusEl.textContent = 'Connected';
            statusEl.className = 'status-badge connected';
        } else {
            statusEl.textContent = 'Disconnected';
            statusEl.className = 'status-badge disconnected';
        }
    }

    updateDashboard(data) {
        this.lastUpdate = new Date();
        document.getElementById('last-update').textContent =
            `Last update: ${this.lastUpdate.toLocaleTimeString()}`;

        this.updateStageStatistics(data.stageStatistics || []);
        this.updateActiveIssues(data.activeIssues || []);
        this.updateRecentEvents(data.recentEvents || []);
        this.updateMetrics(data.stageStatistics || []);
    }

    updateStageStatistics(stats) {
        const container = document.getElementById('stage-stats');

        if (!stats.length) {
            container.innerHTML = '<div class="loading">No statistics available</div>';
            return;
        }

        container.innerHTML = stats.map(stat => `
            <div class="stat-card">
                <div class="stat-stage">${stat.stage}</div>
                <div class="stat-values">
                    <div class="stat-item">
                        <div class="stat-label">Total</div>
                        <div class="stat-value">${stat.total_events || 0}</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-label">Completed</div>
                        <div class="stat-value success">${stat.completed_events || 0}</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-label">Failed</div>
                        <div class="stat-value error">${stat.failed_events || 0}</div>
                    </div>
                </div>
                ${stat.avg_duration_ms ? `
                    <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                        Avg duration: ${this.formatDuration(stat.avg_duration_ms)}
                    </div>
                ` : ''}
            </div>
        `).join('');
    }

    updateActiveIssues(issues) {
        const container = document.getElementById('active-issues');
        document.getElementById('active-count').textContent = issues.length;

        if (!issues.length) {
            container.innerHTML = '<div class="loading">No active issues</div>';
            return;
        }

        container.innerHTML = issues.map(issue => `
            <div class="list-item">
                <div class="list-item-header">
                    <span class="list-item-title">Issue #${issue.issue_number}</span>
                    <span class="badge stage-${issue.current_stage}">${issue.current_stage}</span>
                </div>
                <div class="list-item-meta">
                    <span>Events: ${issue.event_count}</span>
                    <span>Duration: ${this.formatDuration(issue.total_duration_ms)}</span>
                    ${issue.error_count > 0 ? `<span class="badge error">Errors: ${issue.error_count}</span>` : ''}
                    ${issue.pr_number ? `<span>PR #${issue.pr_number}</span>` : ''}
                </div>
            </div>
        `).join('');
    }

    updateRecentEvents(events) {
        const container = document.getElementById('recent-events');
        document.getElementById('events-count').textContent = events.length;

        if (!events.length) {
            container.innerHTML = '<div class="loading">No recent events</div>';
            return;
        }

        container.innerHTML = events.map(event => `
            <div class="list-item">
                <div class="list-item-header">
                    <span class="list-item-title">${event.eventType}</span>
                    <span class="badge ${this.getStatusClass(event.status)}">${event.status}</span>
                </div>
                <div class="list-item-meta">
                    <span>Issue #${event.issueNumber}</span>
                    <span class="badge stage-${event.stage}">${event.stage}</span>
                    <span>${this.formatTimestamp(event.timestamp)}</span>
                </div>
            </div>
        `).join('');
    }

    updateMetrics(stats) {
        let totalEvents = 0;
        let completedEvents = 0;
        let failedEvents = 0;

        stats.forEach(stat => {
            totalEvents += stat.total_events || 0;
            completedEvents += stat.completed_events || 0;
            failedEvents += stat.failed_events || 0;
        });

        document.getElementById('total-events').textContent = totalEvents;
        document.getElementById('completed-events').textContent = completedEvents;
        document.getElementById('failed-events').textContent = failedEvents;

        const successRate = totalEvents > 0
            ? ((completedEvents / totalEvents) * 100).toFixed(1)
            : 0;
        document.getElementById('success-rate').textContent = `${successRate}%`;
    }

    formatDuration(ms) {
        if (!ms) return '-';

        const seconds = Math.floor(ms / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);

        if (hours > 0) {
            return `${hours}h ${minutes % 60}m`;
        } else if (minutes > 0) {
            return `${minutes}m ${seconds % 60}s`;
        } else {
            return `${seconds}s`;
        }
    }

    formatTimestamp(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);

        if (diffMins < 1) {
            return 'Just now';
        } else if (diffMins < 60) {
            return `${diffMins}m ago`;
        } else if (diffMins < 1440) {
            const hours = Math.floor(diffMins / 60);
            return `${hours}h ago`;
        } else {
            return date.toLocaleDateString();
        }
    }

    getStatusClass(status) {
        switch (status) {
            case 'COMPLETED': return 'success';
            case 'FAILED': return 'error';
            case 'IN_PROGRESS': return 'warning';
            default: return '';
        }
    }

    setupRefreshButton() {
        // Add manual refresh on header click
        document.querySelector('h1').style.cursor = 'pointer';
        document.querySelector('h1').addEventListener('click', () => {
            console.log('Manual refresh triggered');
            this.connectSSE();
        });
    }

    destroy() {
        if (this.eventSource) {
            this.eventSource.close();
        }
    }
}

// Initialize dashboard when DOM is ready
const app = new DashboardApp();

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => app.init());
} else {
    app.init();
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => app.destroy());
