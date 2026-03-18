# Roadmap — Open-Claw-Nemo-Claw

## Phase 0 — Foundation (current)
- [x] Project repo and workspace created
- [x] Folder structure for agents, skills, hooks
- [x] Planning docs scaffolded
- [x] Researched OpenClaw and NemoClaw platforms
- [x] Updated vision, requirements, architecture with real platform details
- [x] Created Security Sentinel agent (`.claude/agents/security-sentinel.md`)
- [x] Created pre-commit security check script (`.claude/hooks/security-check.sh`)
- [x] Created dependency-audit skill (`.claude/skills/dependency-audit/`)
- [x] Completed security gap analysis (`ai-workspace/security-assessment.md`)
- [x] Built Design-Time Test Harness (CI/CD pipeline)
  - [x] JSON Schemas for agents, skills, hooks, NemoClaw policies
  - [x] Validation scripts (agent, skill, hooks, NemoClaw policy, security)
  - [x] GitHub Actions CI pipeline (6 stages)
  - [x] Pre-commit config (security + linting + secret detection)
  - [x] Test fixtures (valid + invalid) and integration tests
  - [x] Merge safety detector for cross-project merges
- [x] Built Runtime Telemetry Harness
  - [x] OpenTelemetry Collector config (mTLS, multi-machine)
  - [x] Fluent Bit log collector config
  - [x] Prometheus alerting rules (mapped to OWASP ASI01-ASI10)
  - [x] Anomaly detection rules (12 rules, 8 automated actions)
  - [x] Alert routing config (severity-based, with escalation)
  - [x] Telemetry event + audit log schemas (integrity-chained)
  - [x] Setup script for telemetry stack
- [x] .gitignore and .pre-commit-config.yaml
- [x] PostgreSQL telemetry persistence layer
  - [x] Telemetry schema with 6 tables (security_events, audit_log, agent_baselines, skill_allowlist, alert_history, network_requests)
  - [x] Monthly partitioning for security_events and network_requests
  - [x] Integrity-chained audit log (SHA-256 trigger)
  - [x] Least-privilege roles (writer, reader, admin)
  - [x] Pre-built Grafana views (7 views for dashboarding)
  - [x] Auto-partition creation and retention enforcement functions
  - [x] Setup and migration scripts
  - [x] OTel Collector updated to export to PostgreSQL
- [ ] Set up Linux partition on ST-Gabriel
- [ ] Determine GPU availability for local Nemotron models

## Phase 1 — OpenClaw + PostgreSQL on ST-Gabriel
- [ ] Install PostgreSQL: `infra/database/scripts/setup-postgres.sh`
- [ ] Run telemetry schema migrations
- [ ] Install Node.js 24 on Linux partition
- [ ] Install OpenClaw: `openclaw onboard`
- [ ] Harden OpenClaw before enabling features (reference security assessment)
- [ ] Configure LLM provider (API key)
- [ ] Start Gateway, verify it runs
- [ ] Explore built-in tools (fs, web, runtime, memory)
- [ ] Create curated skill allowlist before pulling any skills
- [ ] Create first custom SKILL.md

## Phase 2 — NemoClaw Security Layer
- [ ] Install NemoClaw: `curl -fsSL https://nvidia.com/nemoclaw.sh | bash`
- [ ] Run `nemoclaw onboard` — sandbox creation
- [ ] Write deny-all YAML security policy (validated by schema)
- [ ] Verify OpenClaw runs inside NemoClaw sandbox
- [ ] Test privacy router (cloud model + local Nemotron if GPU available)
- [ ] Deploy telemetry stack on ST-Gabriel (`setup-telemetry-stack.sh`)
- [ ] Verify Fluent Bit → OTel Collector → Prometheus/Loki pipeline
- [ ] Import Grafana dashboards

## Phase 3 — Custom Skills & Plugins
- [ ] Build first custom TypeScript plugin
- [ ] Create project-specific skills for orchestration tasks
- [ ] Build custom telemetry exporters (openclaw-metrics, nemoclaw-audit)
- [ ] Enable integrations (GitHub, messaging, etc.)
- [ ] Bridge Claude Code workflow with OpenClaw skills

## Phase 4 — Remote Dispatch (ST-Gabriel → Maria)
- [ ] Choose transport protocol
- [ ] Generate mTLS certificates for inter-machine transport
- [ ] Set up Maria (ARK) with OpenClaw + NemoClaw
- [ ] Deploy Fluent Bit on Maria, point at ST-Gabriel OTel Collector
- [ ] Build transport-monitor exporter
- [ ] Test task dispatch and result retrieval end-to-end
- [ ] Verify cross-machine Grafana dashboard

## Phase 5 — Multi-Agent Orchestration
- [ ] Multiple agents discovering and invoking tools
- [ ] Per-agent permission scoping via NemoClaw policies
- [ ] Cross-machine agent coordination
- [ ] Full audit trail across both machines
- [ ] Anomaly detection tuning (baseline calibration)

## Phase 6 — Multi-Project Merge
- [ ] Define project namespace convention
- [ ] Create skill-registry.json and agent-registry.json
- [ ] Test merge safety detector with second project space
- [ ] Extend Grafana dashboards with per-project labels
- [ ] Policy composition rules for merged NemoClaw configs

## Phase 7 — Hardening & Production
- [ ] Threat modeling and security review
- [ ] Anomaly detection rule tuning
- [ ] Documentation and onboarding guide
- [ ] Reproducible setup scripts for both machines
