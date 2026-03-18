# Architecture — Open-Claw-Nemo-Claw

## High-Level Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  ST-Gabriel (Linux partition)                                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  NemoClaw (OpenShell Sandbox)                              │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  OpenClaw Gateway (WebSocket server)                 │  │  │
│  │  │                                                      │  │  │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────────┐   │  │  │
│  │  │  │   Tools    │ │   Skills   │ │    Plugins     │   │  │  │
│  │  │  │ fs, web,   │ │ SKILL.md   │ │  TypeScript    │   │  │  │
│  │  │  │ runtime,   │ │ from       │ │  modules       │   │  │  │
│  │  │  │ browser,   │ │ ClawHub +  │ │  (custom +     │   │  │  │
│  │  │  │ memory,    │ │ custom     │ │   community)   │   │  │  │
│  │  │  │ messaging  │ │            │ │                │   │  │  │
│  │  │  └────────────┘ └────────────┘ └────────────────┘   │  │  │
│  │  └──────────────────────┬───────────────────────────────┘  │  │
│  │                         │                                  │  │
│  │  ┌─────────────────┐   │   ┌───────────────────────────┐  │  │
│  │  │  Privacy Router  │◄──┘   │  YAML Security Policies  │  │  │
│  │  │  (cloud ↔ local) │       │  - file access rules     │  │  │
│  │  └────────┬────────┘       │  - network allowlist     │  │  │
│  │           │                 │  - cloud service rules   │  │  │
│  │           ▼                 └───────────────────────────┘  │  │
│  │  ┌─────────────────┐                                      │  │
│  │  │ Nemotron (local) │  ←── runs locally if GPU available  │  │
│  │  └─────────────────┘                                      │  │
│  └────────────────────────────────────────────────────────────┘  │
│                         │                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │ (secure transport — TBD)
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│  Maria / ARK                                                     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  NemoClaw (OpenShell Sandbox)                              │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  OpenClaw Gateway (receives dispatched tasks)        │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Component Details

### OpenClaw Gateway
- Long-lived WebSocket server — the central control plane
- Coordinates: clients (CLI, web UI), messaging channels, agent runtime
- Handles: auth, config, session routing, multi-agent isolation, service lifecycle
- Tool groups: `fs`, `runtime`, `web`, `ui`, `automation`, `memory`, `sessions`, `messaging`
- Config via `openclaw.json` — tool allow/deny lists, integrations, provider keys

### NemoClaw / OpenShell Sandbox
- Each agent runs in an isolated kernel-level container
- Declarative YAML policies control:
  - **File access**: which paths agents can read/write
  - **Network**: which hosts/ports agents can connect to
  - **Cloud services**: which APIs agents can call
- Versioned blueprints manage sandbox creation and updates

### Privacy Router
- Sits between agents and LLM providers
- Routes requests to local Nemotron models vs. cloud frontier models
- Enforces privacy guardrails — sensitive data stays local
- Evaluates available compute to decide local vs. cloud

### Nemotron (Local Models)
- NVIDIA's open models (e.g., Nemotron 3 Super 120B)
- Runs locally for privacy and cost efficiency
- Requires GPU — availability on ST-Gabriel TBD

## Observability Stack

```
┌─────────────────────────────────────────────────────────────┐
│  ST-Gabriel (Linux partition) — Telemetry Aggregation       │
│                                                             │
│  OpenClaw + NemoClaw ──► Fluent Bit ──► OTel Collector      │
│                                            │                │
│                              ┌─────────────┼────────────┐   │
│                              ▼             ▼            ▼   │
│                         Prometheus       Loki     PostgreSQL │
│                          (metrics)      (logs)  (critical   │
│                              │             │     telemetry)  │
│                              └──────┬──────┘        │       │
│                                     ▼               │       │
│                                  Grafana ◄──────────┘       │
│                               (dashboards)                  │
└─────────────────────────────────────────────────────────────┘
                              ▲
        Maria (Fluent Bit) ───┘ (mTLS)
```

### PostgreSQL (`openclaw_telemetry` database)
- **Schema**: `telemetry` — isolated from future application schemas
- **Tables**: security_events, audit_log, agent_baselines, skill_allowlist, alert_history, network_requests
- **Partitioned**: security_events and network_requests partitioned by month for efficient time-range queries
- **Integrity**: audit_log entries chained with SHA-256 hashes (tamper detection)
- **Views**: pre-built Grafana queries — critical events, OWASP trends, agent risk scores, top hosts
- **Roles**: telemetry_writer (INSERT), telemetry_reader (SELECT), telemetry_admin (maintenance)
- **Retention**: configurable (default 12 months), enforced by partition drop

## Technology Stack
| Component | Technology |
|-----------|-----------|
| Agent runtime | OpenClaw (TypeScript/Node.js 24) |
| Security sandbox | NemoClaw / NVIDIA OpenShell |
| Local models | NVIDIA Nemotron (if GPU available) |
| Cloud models | Configurable (Claude, GPT, etc.) via API keys |
| Skill format | SKILL.md with YAML frontmatter |
| Plugin format | TypeScript modules (jiti loader) |
| Config | `openclaw.json` + NemoClaw YAML policies |
| Dev workflow | Claude Code (`.claude/` agents, skills, hooks) |
| Database | PostgreSQL (telemetry persistence, trend analysis) |
| Metrics | Prometheus (time-series, alerting) |
| Logs | Loki (structured log aggregation) |
| Log collection | Fluent Bit (per-machine, forwards to OTel) |
| Telemetry pipeline | OpenTelemetry Collector (vendor-neutral) |
| Dashboards | Grafana (Prometheus + Loki + PostgreSQL data sources) |
| CI/CD | GitHub Actions (6-stage pipeline) |

## Transport (ST-Gabriel ↔ Maria) — TBD
Options to evaluate:
- **Gateway-to-Gateway**: OpenClaw native, if supported
- **SSH tunnel**: Simple, proven, encrypted
- **gRPC**: Structured, typed, bidirectional streaming
- **NATS/message queue**: Decoupled, resilient, async
