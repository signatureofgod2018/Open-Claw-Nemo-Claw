# Session Handoff

## Last Updated
2026-03-18

## Current State
- Repository: https://github.com/signatureofgod2018/Open-Claw-Nemo-Claw
- Branch: master
- Phase 0 — Foundation: **complete**

## What We Built This Session

### 1. Project Scaffolding
GitHub repo, `.claude/` structure, `ai-workspace/` planning docs

### 2. Platform Research
OpenClaw + NemoClaw documented. Full security gap analysis (512 CVEs, 9 NemoClaw gaps, OWASP ASI01-ASI10)

### 3. Security Sentinel
- Agent: `.claude/agents/security-sentinel.md`
- Pre-commit: `.claude/hooks/security-check.sh`
- Skill: `.claude/skills/dependency-audit/SKILL.md`
- Assessment: `ai-workspace/security-assessment.md`

### 4. Design-Time Test Harness (CI/CD)
- GitHub Actions 6-stage pipeline
- JSON Schemas for all config formats
- Validation + security scripts
- Pre-commit with gitleaks
- Test fixtures + integration tests
- Merge safety detector

### 5. Runtime Telemetry Harness
- OTel Collector → Prometheus + Loki + PostgreSQL
- Fluent Bit log collection (per-machine)
- 12 Prometheus alert rules (OWASP-mapped)
- 12 anomaly detection rules with automated actions
- Grafana dashboards (planned: 3 dashboards)

### 6. PostgreSQL Telemetry Persistence
- **Database**: `openclaw_telemetry`, schema: `telemetry`
- **Tables**: security_events (partitioned monthly), audit_log (integrity-chained), agent_baselines, skill_allowlist, alert_history, network_requests (partitioned monthly)
- **Views**: 7 pre-built Grafana views — critical events 24h, event summary, OWASP trends, agent risk scores, open alerts, top hosts, hourly event rate
- **Roles**: telemetry_writer (INSERT only), telemetry_reader (SELECT only), telemetry_admin (maintenance)
- **Integrity**: SHA-256 hash chain on audit_log via trigger (tamper detection)
- **Retention**: 12-month default, automated partition drop
- **Scripts**: `setup-postgres.sh`, `run-migrations.sh`

## Architecture Summary
```
Grafana ← Prometheus (metrics) ← OTel Collector ← Fluent Bit ← OpenClaw/NemoClaw
       ← Loki (logs)          ←                ←            ←
       ← PostgreSQL (critical) ←                ←            ←
```

## Key Decisions
- PostgreSQL is P0 — required infrastructure for trend analysis and compliance
- All FOS stack: PostgreSQL, Grafana, Prometheus, Loki, Fluent Bit, OTel Collector
- Three persistence tiers: Prometheus (metrics/hot), Loki (logs/warm), PostgreSQL (critical/long-term)
- Least-privilege DB roles — Grafana gets SELECT only, exporters get INSERT only
- Audit log is append-only with integrity hashing — even DB admins can't tamper undetected

## Next Steps (Phase 1)
1. Set up Linux partition on ST-Gabriel
2. Install PostgreSQL, run telemetry schema migrations
3. Install Node.js 24 + OpenClaw (harden first)
4. Install NemoClaw with deny-all policies
5. Deploy full telemetry stack (Fluent Bit → OTel → Prometheus/Loki/PostgreSQL → Grafana)
6. Define curated skill allowlist (populate skill_allowlist table)

## Blockers
- Linux partition not yet set up on ST-Gabriel
- GPU availability unknown (affects Nemotron local model viability)

## Key Resources
- OpenClaw docs: docs.openclaw.ai
- NemoClaw docs: docs.nvidia.com/nemoclaw/latest
- OpenClaw CVE tracker: github.com/jgamblin/OpenClawCVEs/
- OWASP Agentic Top 10: genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
- PostgreSQL docs: postgresql.org/docs/current/
- Grafana PostgreSQL plugin: grafana.com/docs/grafana/latest/datasources/postgres/
