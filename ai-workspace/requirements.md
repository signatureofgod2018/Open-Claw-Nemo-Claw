# Requirements — AgenticOS

## Functional Requirements

### OpenClaw Setup
- FR-01: [ ] Install Node.js 24 (or 22 LTS) on ST-Gabriel Linux partition
- FR-02: [ ] Install and configure OpenClaw Gateway (`openclaw onboard`)
- FR-03: [ ] Configure at least one LLM provider (API key)
- FR-04: [ ] Verify Gateway starts and accepts connections
- FR-05: [ ] Install and test at least one skill from ClawHub

### NemoClaw Setup
- FR-10: [ ] Install NemoClaw on ST-Gabriel Linux partition (`curl -fsSL https://nvidia.com/nemoclaw.sh | bash`)
- FR-11: [ ] Run `nemoclaw onboard` to create OpenShell sandbox
- FR-12: [ ] Configure YAML security policies (file access, network, cloud services)
- FR-13: [ ] Verify OpenClaw runs inside NemoClaw sandbox
- FR-14: [ ] Test privacy router with at least one cloud model + one local Nemotron model

### Orchestration (ST-Gabriel → Maria)
- FR-20: [ ] Define task dispatch format (OpenClaw Gateway protocol or custom)
- FR-21: [ ] Establish secure transport to Maria (ARK)
- FR-22: [ ] Remote task execution and result retrieval
- FR-23: [ ] Error handling and retry logic

### Security Sentinel (Development Security)
- FR-50: [x] Create Security Sentinel agent (`.claude/agents/security-sentinel.md`)
- FR-51: [x] Create pre-commit security check script (`.claude/hooks/security-check.sh`)
- FR-52: [x] Create dependency-audit skill (`.claude/skills/dependency-audit/`)
- FR-53: [ ] Integrate security-check.sh as git pre-commit hook
- FR-54: [ ] Static code analysis on all new code (OWASP Top 10)
- FR-55: [ ] Supply chain audit on every new dependency before install
- FR-56: [ ] Block commits containing hardcoded secrets
- FR-57: [ ] Block dependencies with known critical CVEs
- FR-58: [ ] Flag dependencies with single/new maintainers (XZ Utils lesson)
- FR-59: [ ] Audit `postinstall` scripts on all npm packages (event-stream lesson)
- FR-60: [ ] Maintain security audit log in `ai-workspace/security-audit-log.md`

### Custom Skills & Plugins
- FR-30: [x] Create first custom SKILL.md for this project (dependency-audit)
- FR-31: [ ] Create first custom plugin (TypeScript)
- FR-32: [ ] Register custom skills in local ClawHub or project directory

### PostgreSQL Telemetry Persistence
- FR-70: [ ] Install PostgreSQL on ST-Gabriel Linux partition
- FR-71: [x] Create `telemetry` schema (security_events, audit_log, agent_baselines, skill_allowlist, alert_history, network_requests)
- FR-72: [x] Monthly table partitioning for security_events and network_requests
- FR-73: [x] Integrity-chained audit log (SHA-256 trigger)
- FR-74: [x] Least-privilege roles: telemetry_writer (INSERT), telemetry_reader (SELECT), telemetry_admin (ALL)
- FR-75: [x] Pre-built Grafana views (critical events, OWASP trends, agent risk scores, top hosts, hourly rates)
- FR-76: [ ] Connect OTel Collector → PostgreSQL (telemetry_writer role)
- FR-77: [ ] Connect Grafana → PostgreSQL (telemetry_reader role)
- FR-78: [ ] Configure pg_cron for auto-partition creation and retention enforcement
- FR-79: [ ] 12-month retention policy with automated partition cleanup

### Claude Code Integration
- FR-40: [ ] Maintain `.claude/` directory with agents, skills, hooks for dev workflow
- FR-41: [ ] Keep `ai-workspace/handoff.md` updated for session continuity
- FR-42: [ ] Bridge Claude Code skills with OpenClaw skills where useful

## Non-Functional Requirements
- NFR-01: [ ] Must run on Linux (ST-Gabriel partition)
- NFR-02: [ ] All agent communication sandboxed via NemoClaw/OpenShell
- NFR-03: [ ] Declarative security policies — no hardcoded secrets or permissions
- NFR-04: [ ] Observable — OpenClaw Gateway logs + NemoClaw audit trail
- NFR-05: [ ] Reproducible setup — documented install steps for both machines

## Constraints
- ST-Gabriel: Windows 11 primary, Linux partition for OpenClaw/NemoClaw
- NemoClaw is alpha — expect breaking changes
- GPU availability on ST-Gabriel TBD (affects local Nemotron model viability)

## Priorities

### P0 — Must have for MVP
- FR-01 through FR-04 (OpenClaw running on ST-Gabriel)
- FR-10 through FR-13 (NemoClaw wrapping OpenClaw)
- FR-50 through FR-59 (Security Sentinel — active from day one)
- FR-70 through FR-77 (PostgreSQL telemetry persistence)
- NFR-01, NFR-02

### P1 — Important
- FR-05 (ClawHub skill)
- FR-14 (privacy router)
- FR-30, FR-31 (custom skill + plugin)
- FR-60 (security audit log)
- FR-78, FR-79 (auto-partition, retention)
- NFR-03, NFR-04

### P2 — Nice to have (Phase 2+)
- FR-20 through FR-23 (Maria dispatch)
- FR-40 through FR-42 (Claude Code bridge)
- NFR-05
