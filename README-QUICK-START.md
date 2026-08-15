# AI-SDLC Event System - Quick Start Guide

Get the event dashboard running in **5 minutes**.

---

## 🚀 One-Command Start

```powershell
cd D:\git\homedir-ai-sdlc
.\scripts\quick-start.ps1
```

This will:
1. ✅ Generate sample events (5 realistic issue lifecycles)
2. ✅ Build Quarkus dashboard
3. ✅ Start dashboard on port 8081

Then open: **http://localhost:8081/sdlc/events/**

---

## 📊 Sample Issues Included

| Issue | Status | Description |
|-------|--------|-------------|
| **#1360** | ✅ Completed | Full lifecycle: detection → PR → merged → deployed |
| **#1361** | ⏳ In Progress | Currently implementing (SCC running) |
| **#1362** | ⚠️ CI Failed | PR created but tests failing, in remediation |
| **#1363** | ❌ Rejected | Rejected at admission (question type) |
| **#1364** | ⚪ Queued | Just detected, waiting to be claimed |

---

## 🎯 What You'll See

### Dashboard Features

#### 1. **Statistics**
- Total events count
- Error count
- Active issues

#### 2. **Active Issues Grid**
Cards showing issues currently in pipeline:
```
┌─────────────┐  ┌─────────────┐
│   #1361     │  │   #1362     │
│ Implementing│  │ Remediation │
│  5m ago     │  │  3m ago     │
└─────────────┘  └─────────────┘
```

#### 3. **Pipeline Stages**
Visual progress bar:
```
Detection → Admission → Implementation → PR Mgmt → CI Checks → Remediation → Deploy
   ✓           ✓             ▶              ○          ○            ○          ○
```

#### 4. **Event Timeline**
Chronological list of all events:
```
⏱️ 2m ago    pr.created         #1362  [completed]
⏱️ 5m ago    implementation... #1361  [in_progress]
⏱️ 8m ago    admission.comp... #1360  [completed]
```

#### 5. **Search**
Type issue number → See full timeline for that issue

---

## 🔧 Alternative: Step-by-Step

### Option A: Just Events (No Build)

```powershell
# Generate sample events
bash scripts/generate-sample-events.sh

# Events saved to: local-state/events/
```

### Option B: Build Only (No Run)

```powershell
# Build dashboard
.\scripts\run-all-phases.ps1 -BuildOnly
```

### Option C: Full Setup (All Phases)

```powershell
# Run all phases: infrastructure → integration → API → dashboard
.\scripts\run-all-phases.ps1
```

---

## 🧪 Testing the Dashboard

### 1. Homepage Loads
- Visit: http://localhost:8081/sdlc/events/
- Should see statistics, pipeline, timeline

### 2. Search by Issue
- Enter `1360` in search box
- Timeline should update to show only #1360 events
- Pipeline should show: Detection ✓ → ... → Deploy ✓

### 3. Active Issues
- Click on issue card (#1361 or #1362)
- Should load that issue's timeline

### 4. Auto-Refresh
- Toggle auto-refresh ON
- Statistics should update every 15s
- Heartbeat events should appear

### 5. API Endpoints

```powershell
# Latest events
curl http://localhost:8081/api/sdlc/events/latest?limit=10 | jq .

# Statistics
curl http://localhost:8081/api/sdlc/events/stats | jq .

# Issue timeline
curl http://localhost:8081/api/sdlc/events/issue/1360 | jq .

# Active issues
curl http://localhost:8081/api/sdlc/events/active | jq .
```

---

## 📂 Project Structure

```
homedir-ai-sdlc/
├── scripts/
│   ├── quick-start.ps1              ← One-command start
│   ├── generate-sample-events.sh    ← Create test data
│   ├── run-all-phases.ps1           ← Full setup
│   ├── phase2-setup.ps1             ← Infrastructure
│   ├── phase3-integrate.ps1         ← Worker integration
│   ├── phase5-deploy-api.ps1        ← API build
│   └── phase6-deploy-dashboard.ps1  ← Dashboard start
│
├── platform/
│   ├── scripts/
│   │   ├── event-emitter.sh         ← Event emission logic
│   │   └── integrate-events-to-worker.sh  ← Integration guide
│   └── config/
│       └── event-schema.json        ← Event structure
│
├── dashboard/quarkus-app/
│   ├── src/main/java/.../events/
│   │   ├── EventApiResource.java   ← REST endpoints
│   │   └── EventQueryService.java  ← Query logic
│   └── src/main/resources/.../sdlc/events/
│       ├── index.html              ← Dashboard UI
│       └── events-dashboard.js     ← Frontend logic
│
├── local-state/events/              ← Generated events
│   ├── all-events.jsonl
│   ├── tracking-state.json
│   └── [stage-queues]/
│
└── docs/
    ├── EVENT-TRACEABILITY-SYSTEM.md  ← Complete docs
    └── IMPLEMENTATION-ROADMAP.md     ← Phase-by-phase guide
```

---

## 🐛 Troubleshooting

### Dashboard won't start

**Check Java version**:
```powershell
java -version
# Need Java 21+
```

**Check port 8081**:
```powershell
netstat -ano | findstr :8081
# If occupied, kill process or change port
```

### No events showing

**Check events directory**:
```powershell
ls local-state/events/
cat local-state/events/all-events.jsonl
```

**Re-generate events**:
```powershell
bash scripts/generate-sample-events.sh
```

### Build fails

**Clean Maven cache**:
```powershell
cd dashboard/quarkus-app
./mvnw clean
./mvnw package -DskipTests
```

### API returns empty

**Check state directory config**:
```powershell
# In application.properties
sdlc.state-dir=./local-state
```

Should point to where events were generated.

---

## 📚 Next Steps

### For Development

1. **Modify Dashboard**:
   - Edit: `dashboard/.../resources/sdlc/events/index.html`
   - Hot reload is enabled in `quarkus:dev`

2. **Add API Endpoints**:
   - Edit: `EventApiResource.java`
   - Add method with `@GET @Path("/new-endpoint")`

3. **Generate More Events**:
   - Edit: `scripts/generate-sample-events.sh`
   - Add new issue scenarios

### For Production

1. **Integrate with Worker**:
   - Follow: `IMPLEMENTATION-ROADMAP.md`
   - Phase 3: Worker Integration

2. **Deploy to VPS**:
   - Build JAR: `./mvnw package -DskipTests`
   - Copy: `scp target/quarkus-app/quarkus-run.jar vps:~/`
   - Run: `java -jar quarkus-run.jar`

3. **Monitor Events**:
   - Check: `/var/lib/homedir-sdlc/events/`
   - Tail: `tail -f all-events.jsonl`

---

## 🎯 Success Criteria

After running quick-start, you should have:

- ✅ Dashboard accessible at http://localhost:8081/sdlc/events/
- ✅ 5 sample issues with realistic lifecycles
- ✅ ~50+ events in timeline
- ✅ Pipeline visualization working
- ✅ Search by issue number working
- ✅ All API endpoints responding
- ✅ Auto-refresh toggle working
- ✅ No console errors in browser

---

**Estimated Time**: 5 minutes  
**Prerequisites**: Java 21+, Bash (Git Bash on Windows)  
**Difficulty**: Easy

---

For detailed documentation, see:
- **Complete Guide**: `docs/EVENT-TRACEABILITY-SYSTEM.md`
- **Implementation**: `IMPLEMENTATION-ROADMAP.md`
- **Integration**: `platform/scripts/integrate-events-to-worker.sh`
