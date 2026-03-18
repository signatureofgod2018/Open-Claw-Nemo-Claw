# Session Handoff

## Last Updated
2026-03-18

## Current State
- Repository: https://github.com/signatureofgod2018/Open-Claw-Nemo-Claw
- Branch: master
- Phase 0 — Foundation: **complete** (planning, security, CI/CD, telemetry all scaffolded)

## What We Built This Session

### 1. Project Scaffolding
- GitHub repo, `.claude/` structure, `ai-workspace/` planning docs

### 2. Platform Research
- OpenClaw (agent framework) and NemoClaw (NVIDIA security layer) documented
- Full security gap analysis: 512 OpenClaw CVEs, 9 NemoClaw gaps, OWASP ASI01-ASI10

### 3. Security Sentinel
- Agent: `.claude/agents/security-sentinel.md` (OWASP Top 10 + Agentic Top 10 + CVE tracking)
- Pre-commit: `.claude/hooks/security-check.sh`
- Skill: `.claude/skills/dependency-audit/SKILL.md`
- Assessment: `ai-workspace/security-assessment.md`

### 4. Design-Time Test Harness (CI/CD)
- **GitHub Actions pipeline** (`.github/workflows/ci-pipeline.yml`): 6 stages — lint, format validation, security scan, dependency audit, merge safety, integration tests
- **JSON Schemas** (`infra/ci/schemas/`): agent, skill, hooks, NemoClaw policy validation
- **CI scripts** (`infra/ci/scripts/`): validate-agent, validate-skill, validate-hooks, run-security-sentinel, merge-conflict-detector
- **Pre-commit** (`.pre-commit-config.yaml`): security checks, secret detection (gitleaks), YAML/JSON lint, private key detection
- **Test fixtures** (`infra/test/`): valid/invalid agents, skills, NemoClaw policies + integration test runner
- **.gitignore**: secrets, credentials, node_modules, NemoClaw artifacts

### 5. Runtime Telemetry Harness
- **OTel Collector** (`infra/telemetry/config/otel-collector-config.yml`): mTLS, multi-machine aggregation, exports to Prometheus + Loki
- **Fluent Bit** (`infra/telemetry/config/fluentbit-config.conf`): parses OpenClaw + NemoClaw logs on each machine
- **Prometheus alerts** (`infra/telemetry/config/prometheus-alerts.yml`): 12 alert rules mapped to OWASP ASI01-ASI10
- **Anomaly rules** (`infra/telemetry/policies/anomaly-rules.yml`): 12 detection rules with automated actions (halt, block, throttle)
- **Alert routing** (`infra/telemetry/policies/alert-routing.yml`): severity-based with escalation
- **Schemas** (`infra/telemetry/schemas/`): telemetry events + integrity-chained audit log
- **Setup script** (`infra/telemetry/scripts/setup-telemetry-stack.sh`): installs full stack
- **Grafana dashboards** planned: gateway health, security telemetry, cross-machine
- **Custom exporters** planned: openclaw-metrics, nemoclaw-audit, transport-monitor

## Key Decisions
- OpenClaw + NemoClaw are the foundation — not building custom
- Security Sentinel is P0 — active from day one
- No direct ClawHub installs — curated allowlist only
- Rule of Two enforced on all agent configs
- ST-Gabriel = orchestrator + telemetry aggregation point
- Maria = executor + forwards telemetry to ST-Gabriel
- Schemas are single source of truth — same validation in pre-commit and CI
- OpenTelemetry for vendor-neutral telemetry pipeline
- Integrity-chained audit logs (SHA-256) for tamper detection

## Next Steps (Phase 1)
1. Set up Linux partition on ST-Gabriel
2. Install Node.js 24 + OpenClaw (harden first, reference security assessment)
3. Install NemoClaw with deny-all policies
4. Deploy telemetry stack
5. Define curated skill allowlist
6. Generate mTLS certs for future ST-Gabriel ↔ Maria transport

## Blockers
- Linux partition not yet set up on ST-Gabriel
- GPU availability unknown (affects Nemotron local model viability)

## Key Resources
- OpenClaw docs: docs.openclaw.ai
- NemoClaw docs: docs.nvidia.com/nemoclaw/latest
- OpenClaw CVE tracker: github.com/jgamblin/OpenClawCVEs/
- OWASP Agentic Top 10: genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
- Snyk ToxicSkills: snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
- Adversa AI hardening: adversa.ai/blog/openclaw-security-101-vulnerabilities-hardening-2026/
