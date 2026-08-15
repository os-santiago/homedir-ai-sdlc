# Simple HTTP Server - Serve dashboard with mock API
# Uses Python's built-in HTTP server

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     AI-SDLC Dashboard - Simple Server                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if events exist
if (-not (Test-Path "local-state\events\all-events.jsonl")) {
    Write-Host "No events found. Generating sample events..." -ForegroundColor Yellow
    Write-Host ""

    if (Test-Path "scripts\generate-sample-events.sh") {
        bash scripts/generate-sample-events.sh

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to generate events" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: generate-sample-events.sh not found" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
}

# Create simple web directory structure
$webRoot = "web-dashboard"
$apiDir = "$webRoot\api\sdlc\events"

Write-Host "Setting up web directory..." -ForegroundColor Green

New-Item -ItemType Directory -Force -Path $webRoot | Out-Null
New-Item -ItemType Directory -Force -Path $apiDir | Out-Null
New-Item -ItemType Directory -Force -Path "$webRoot\sdlc\events" | Out-Null

# Copy dashboard files
if (Test-Path "dashboard\quarkus-app\src\main\resources\META-INF\resources\sdlc\events\index.html") {
    Copy-Item "dashboard\quarkus-app\src\main\resources\META-INF\resources\sdlc\events\index.html" `
              "$webRoot\sdlc\events\" -Force
    Copy-Item "dashboard\quarkus-app\src\main\resources\META-INF\resources\sdlc\events\events-dashboard.js" `
              "$webRoot\sdlc\events\" -Force

    Write-Host "✓ Dashboard files copied" -ForegroundColor Green
}

# Generate API JSON files from events
Write-Host "Generating API responses..." -ForegroundColor Green

# API: /latest
$latestEvents = Get-Content "local-state\events\all-events.jsonl" -Tail 50 |
    ForEach-Object { $_ } |
    ConvertFrom-Json |
    ConvertTo-Json -Depth 10 -AsArray

Set-Content -Path "$apiDir\latest" -Value $latestEvents

# API: /stats
$allEvents = Get-Content "local-state\events\all-events.jsonl" |
    ForEach-Object { ConvertFrom-Json $_ }

$stats = @{
    total_events = $allEvents.Count
    error_count = ($allEvents | Where-Object { $_.status -eq "failed" }).Count
    by_type = @{}
    by_stage = @{}
    by_status = @{}
}

$allEvents | Group-Object event_type | ForEach-Object {
    $stats.by_type[$_.Name] = $_.Count
}

$allEvents | Group-Object stage | ForEach-Object {
    $stats.by_stage[$_.Name] = $_.Count
}

$allEvents | Group-Object status | ForEach-Object {
    $stats.by_status[$_.Name] = $_.Count
}

$stats | ConvertTo-Json -Depth 5 | Set-Content "$apiDir\stats"

Write-Host "✓ API files generated" -ForegroundColor Green

# Create server script
$serverScript = @'
import http.server
import socketserver
import json
import os
from urllib.parse import urlparse, parse_qs

PORT = 8081

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Parse URL
        parsed = urlparse(self.path)
        path = parsed.path

        # Serve API endpoints
        if path.startswith('/api/'):
            self.serve_api(path, parsed.query)
        else:
            # Serve static files
            super().do_GET()

    def serve_api(self, path, query):
        # Map API paths to JSON files
        if path == '/api/sdlc/events/latest':
            self.send_json_file('api/sdlc/events/latest')
        elif path == '/api/sdlc/events/stats':
            self.send_json_file('api/sdlc/events/stats')
        elif path == '/api/sdlc/events/active':
            # Mock active issues
            active = [
                {
                    "issue_number": 1361,
                    "tracking_id": "track_1361_20260809143000",
                    "current_stage": "implementation",
                    "last_event_type": "implementation.started",
                    "last_event_time": "2026-08-09T14:30:00Z",
                    "event_count": 5
                },
                {
                    "issue_number": 1362,
                    "tracking_id": "track_1362_20260809143100",
                    "current_stage": "ci_checks",
                    "last_event_type": "ci.check.failed",
                    "last_event_time": "2026-08-09T14:35:00Z",
                    "event_count": 8
                }
            ]
            self.send_json(active)
        else:
            self.send_error(404, "API endpoint not found")

    def send_json_file(self, filepath):
        try:
            with open(filepath, 'r') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(content.encode())
        except FileNotFoundError:
            self.send_error(404, "File not found")

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

os.chdir('web-dashboard')

with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    print(f"Server running at http://localhost:{PORT}/")
    print(f"Dashboard: http://localhost:{PORT}/sdlc/events/")
    print(f"API Stats: http://localhost:{PORT}/api/sdlc/events/stats")
    print("")
    print("Press Ctrl+C to stop")
    httpd.serve_forever()
'@

Set-Content -Path "server.py" -Value $serverScript

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

Write-Host "Starting server on http://localhost:8081/" -ForegroundColor Green
Write-Host ""
Write-Host "URLs:" -ForegroundColor Cyan
Write-Host "  Dashboard: http://localhost:8081/sdlc/events/" -ForegroundColor White
Write-Host "  API Stats: http://localhost:8081/api/sdlc/events/stats" -ForegroundColor White
Write-Host "  API Latest: http://localhost:8081/api/sdlc/events/latest" -ForegroundColor White
Write-Host ""
Write-Host "Sample issues:" -ForegroundColor Cyan
Write-Host "  1360 - Completed ✓" -ForegroundColor Green
Write-Host "  1361 - In Progress ⏳" -ForegroundColor Yellow
Write-Host "  1362 - CI Failed ⚠" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 2

python server.py
