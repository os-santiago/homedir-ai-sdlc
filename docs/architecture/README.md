# AI-SDLC Architecture

Sistema autónomo de desarrollo que gestiona el ciclo completo de issues en GitHub desde admission hasta deployment.

## Overview

AI-SDLC automatiza el flujo completo de desarrollo:
- **Admission:** Valida y acepta issues para procesamiento autónomo
- **Planning:** Genera plan de implementación
- **Implementation:** Usa SCC para generar código
- **PR Creation:** Crea pull request con cambios
- **CI Remediation:** Corrige errores de CI automáticamente
- **Auto-Merge:** Mergea cuando CI pasa
- **Deployment:** Verifica deployment en producción

**Autonomía actual:** 99%  
**Tiempo E2E:** 16-20 minutos (issue → merged → deployed)

---

## Component Architecture

```mermaid
graph TB
    subgraph "GitHub"
        Issues[Issues]
        PRs[Pull Requests]
        Actions[GitHub Actions]
    end

    subgraph "AI-SDLC System"
        Worker[Worker Bash<br/>2,476 lines<br/>Systemd Timer]
        Dashboard[Dashboard<br/>Quarkus App<br/>Port 8081]
        Events[Events Service<br/>Quarkus App<br/>REST API]
        
        subgraph "Storage"
            StateFS[State Files<br/>JSON]
            Journal[Event Journal<br/>JSONL]
        end
        
        subgraph "Configuration"
            Policy[Decision Policy<br/>YAML - 723 lines]
            WorkerEnv[Worker Config<br/>.env]
        end
    end

    subgraph "External Services"
        SCC[SCC<br/>Software Construction<br/>Copilot]
        GitHub[GitHub API<br/>gh CLI]
    end

    subgraph "VPS Infrastructure"
        Podman[Podman Containers]
        Systemd[Systemd Services]
        Nginx[Nginx Reverse Proxy]
    end

    %% Interactions
    Worker -->|Polls| Issues
    Worker -->|Creates| PRs
    Worker -->|Calls| SCC
    Worker -->|Uses| GitHub
    Worker -->|Reads/Writes| StateFS
    Worker -->|Appends| Journal
    Worker -->|Reads| Policy
    Worker -->|Publishes| Events
    
    Dashboard -->|Reads| StateFS
    Dashboard -->|Reads| Journal
    Dashboard -->|Subscribes| Events
    
    Actions -->|Triggers| Worker
    PRs -->|CI Status| Worker
    
    Podman -->|Runs| Worker
    Podman -->|Runs| Dashboard
    Systemd -->|Manages| Worker
    Nginx -->|Proxies| Dashboard

    style Worker fill:#4CAF50
    style Dashboard fill:#2196F3
    style Events fill:#9C27B0
    style SCC fill:#FF9800
```

---

## Autonomous Workflow

```mermaid
flowchart LR
    Start([New Issue]) --> Admission{Admission<br/>Check}
    
    Admission -->|Valid| Planning[Planning<br/>Generate Plan]
    Admission -->|Invalid| Reject([Reject Issue])
    
    Planning --> Implementation[Implementation<br/>SCC Generate Code]
    
    Implementation --> PR[PR Creation<br/>Create Pull Request]
    
    PR --> CI{CI Check}
    
    CI -->|Pass| Merge[Auto-Merge<br/>Merge to main]
    CI -->|Fail| Remediation[CI Remediation<br/>Fix Errors]
    
    Remediation --> CI
    Remediation -->|Max Retries| Manual([Needs Human])
    
    Merge --> Deploy[Deployment<br/>Verify Production]
    
    Deploy --> End([Complete])
    
    style Start fill:#4CAF50
    style End fill:#4CAF50
    style Reject fill:#f44336
    style Manual fill:#FF9800
```

**Typical Timeline:**
- 00:00 - Issue created
- 00:03 - Admitted
- 00:06 - Implementation complete
- 00:15 - PR created
- 00:19 - CI passed
- 00:20 - Merged & Deployed

---

## State Machine

Complete issue lifecycle with state transitions:

```mermaid
stateDiagram-v2
    [*] --> new: Issue Created
    
    new --> admitted: Passes Validation
    new --> rejected: Fails Validation
    
    admitted --> planning: Worker Starts
    
    planning --> implementing: Plan Generated
    planning --> needs_human: Planning Failed
    
    implementing --> pr_created: Code Generated
    implementing --> needs_human: Implementation Failed
    
    pr_created --> ci_passing: CI Success
    pr_created --> ci_failing: CI Failed
    
    ci_failing --> ci_passing: Remediation Success
    ci_failing --> needs_human: Max Retries Exceeded
    
    ci_passing --> merged: Auto-Merge
    
    merged --> deployed: Health Check Pass
    merged --> deployment_failed: Health Check Fail
    
    deployed --> [*]
    rejected --> [*]
    needs_human --> [*]
    deployment_failed --> [*]
    
    note right of needs_human
        Requires manual intervention
        Label: needs-human
    end note
```

**State Descriptions:**

| State | Description | Next Actions |
|-------|-------------|--------------|
| `new` | Newly created issue | Validation check |
| `admitted` | Accepted for processing | Start planning |
| `planning` | Generating implementation plan | Execute plan |
| `implementing` | SCC generating code | Create PR |
| `pr_created` | Pull request created | Wait for CI |
| `ci_failing` | CI checks failing | Remediate or escalate |
| `ci_passing` | All CI checks passed | Auto-merge |
| `merged` | PR merged to main | Verify deployment |
| `deployed` | Verified in production | Complete |
| `needs_human` | Requires manual intervention | Human resolves |
| `rejected` | Invalid issue format | No action |

---

## Deployment Architecture

Infrastructure and CI/CD pipeline:

```mermaid
graph TB
    subgraph "GitHub"
        Repo[Repository<br/>homedir-ai-sdlc]
        GHCR[GitHub Container<br/>Registry]
    end

    subgraph "CI/CD Pipeline"
        Push[Push to main]
        Build[Build Containers<br/>Worker + Dashboard]
        Publish[Publish to GHCR]
    end

    subgraph "VPS: 72.60.141.165"
        subgraph "Podman Containers"
            WorkerC[ai-sdlc-worker<br/>Latest]
            DashC[ai-sdlc-dashboard<br/>Latest]
        end
        
        subgraph "Systemd Services"
            WorkerTimer[homedir-sdlc-worker.timer<br/>Every 3 min]
            DashService[homedir-sdlc-dashboard.service<br/>Always running]
        end
        
        subgraph "Storage"
            WorkData[/var/lib/homedir-sdlc]
            Logs[/var/log/homedir-sdlc]
        end
        
        NginxVPS[Nginx<br/>:443]
    end

    subgraph "External Access"
        Browser[Browser<br/>Dashboard UI]
        API[API Clients]
    end

    %% CI/CD Flow
    Repo -->|git push| Push
    Push -->|trigger| Build
    Build -->|push images| Publish
    Publish --> GHCR

    %% Deployment Flow
    GHCR -->|podman pull| WorkerC
    GHCR -->|podman pull| DashC
    
    %% Runtime
    WorkerTimer -->|executes| WorkerC
    DashService -->|runs| DashC
    
    WorkerC -->|reads/writes| WorkData
    DashC -->|reads| WorkData
    
    WorkerC -->|logs| Logs
    DashC -->|logs| Logs
    
    NginxVPS -->|proxy :8081| DashC
    
    Browser -->|HTTPS| NginxVPS
    API -->|HTTPS| NginxVPS

    style WorkerC fill:#4CAF50
    style DashC fill:#2196F3
    style GHCR fill:#9C27B0
```

**Deployment Flow:**
1. Developer pushes to `main`
2. GitHub Actions builds containers
3. Publishes to GHCR
4. VPS pulls latest images
5. Systemd restarts services with new containers

---

## Data Flow

Sequence of interactions during autonomous workflow:

```mermaid
sequenceDiagram
    participant I as Issue
    participant W as Worker
    participant S as State FS
    participant J as Journal
    participant SCC as SCC
    participant GH as GitHub
    participant D as Dashboard

    I->>W: New issue detected
    W->>S: Read current state
    W->>J: Log: admission_started
    W->>W: Validate issue
    W->>S: Write: state=admitted
    W->>J: Log: admitted
    
    W->>SCC: Generate code
    SCC-->>W: Code + plan
    W->>J: Log: implementation_complete
    
    W->>GH: Create PR
    GH-->>W: PR #123
    W->>S: Write: pr_number=123
    W->>J: Log: pr_created
    
    W->>GH: Check CI status
    GH-->>W: CI passing
    W->>J: Log: ci_passed
    
    W->>GH: Merge PR
    GH-->>W: Merged
    W->>S: Write: state=merged
    W->>J: Log: merged
    
    W->>J: Publish: deployment_verified
    
    D->>S: Poll state
    D->>J: Tail events
    D-->>D: Render UI
```

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Worker** | Bash + gh CLI + jq | Autonomous workflow orchestration |
| **Dashboard** | Quarkus 3.x + Qute | Real-time monitoring UI |
| **Events** | Quarkus + SSE | Event streaming |
| **Storage** | JSON + JSONL | State persistence |
| **AI** | SCC (Software Construction Copilot) | Code generation |
| **Container** | Podman | Containerization |
| **Orchestration** | Systemd timers | Scheduling |
| **Proxy** | Nginx | Reverse proxy + SSL |
| **VPS** | Ubuntu 24.04 | Host OS |

---

## Directory Structure

```
homedir-ai-sdlc/
├── platform/
│   ├── scripts/
│   │   └── homedir-sdlc-worker.sh          # Main worker (2,476 lines)
│   └── config/
│       └── autonomous-decision-policy.yaml # Policy (723 lines)
├── dashboard/
│   └── quarkus-app/                        # Dashboard UI
├── events-service/                         # Events API
├── container/
│   ├── Containerfile.worker                # Worker container
│   └── Containerfile.dashboard             # Dashboard container
├── docs/
│   ├── architecture/                       # This directory
│   ├── deployment/                         # Deployment guides
│   └── development/                        # Dev guides
└── state/                                  # Runtime state (gitignored)
    ├── current-state.json
    └── events.jsonl
```

---

## Further Reading

- [Getting Started](../GETTING-STARTED.md) - How to use the system
- [Development](../development/) - Contributing guide

---

**Last Updated:** 2026-08-28  
**Version:** Production (Podman deployment)
