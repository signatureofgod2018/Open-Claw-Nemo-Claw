# Open-Claw-Nemo-Claw

## Project Structure

```
.claude/
  agents/
    security-sentinel.md       # Security agent — static analysis + supply chain + OWASP ASI
  skills/
    dependency-audit/           # On-demand package dependency security audit
  hooks/
    hooks.json                  # Lifecycle hook configuration
    security-check.sh           # Pre-commit security scanning script
  commands/
ai-workspace/
  handoff.md                   # Session handoff for continuity between conversations
  vision.md                    # Project vision and platform details
  requirements.md              # Functional and non-functional requirements
  architecture.md              # System architecture diagrams
  roadmap.md                   # Phased delivery plan
  security-assessment.md       # OpenClaw + NemoClaw gap analysis
infra/
  ci/                          # Design-Time Test Harness (CI/CD)
    schemas/                   # JSON Schema for agents, skills, hooks, NemoClaw policies
    scripts/                   # Validation and security scanning scripts
    pre-commit/                # Pre-commit framework config
  test/
    fixtures/                  # Valid/invalid test fixtures for schema validation
    integration/               # Integration test scripts
  database/                    # PostgreSQL Telemetry Persistence
    migrations/                # SQL migrations (001_schema, 002_roles, 003_canaries, 004_inference)
  ollama/                      # Local Inference (Mistral Small 3.2 on AMD GPU)
    config/                    # Ollama env, docker-compose for metrics proxy, Prometheus alerts
    scripts/                   # Setup script (Ollama + ROCm + ollama-metrics)
  exporters/                   # Whole House Prometheus Exporters
    config/                    # Scrape targets, OS/Docker/Postgres/disk alert rules
    scripts/                   # Exporter setup (node_exporter, cAdvisor, postgres, smartctl)
    scripts/                   # Setup and migration runner scripts
  telemetry/                   # Runtime Harness (Health & Security Telemetry)
    config/                    # OTel Collector, Fluent Bit, Prometheus alerts, Grafana dashboards
    schemas/                   # Telemetry event and audit log schemas
    policies/                  # Anomaly detection rules and alert routing
    scripts/                   # Setup scripts for telemetry stack
    exporters/                 # Custom TypeScript exporters (planned)
.github/
  workflows/
    ci-pipeline.yml            # 6-stage CI: lint → validate → security → deps → merge safety → tests
```

## Conventions

- Agents are markdown files with YAML frontmatter — validated by `infra/ci/schemas/agent-schema.json`
- Skills live in subdirectories under `.claude/skills/` with a `SKILL.md` entry point — validated by `infra/ci/schemas/skill-schema.json`
- Hooks are configured via `.claude/hooks/hooks.json` — validated by `infra/ci/schemas/hooks-schema.json`
- NemoClaw policies must use `baseline: deny-all` — validated by `infra/ci/schemas/nemoclaw-policy-schema.json`
- Session handoff notes go in `ai-workspace/handoff.md` — update at end of each session

## Security Policy

**The Security Sentinel agent is active from day one.** All code and dependencies must pass security review.

- **No hardcoded secrets** — ever. Use environment variables or NemoClaw-managed secrets.
- **No unaudited dependencies** — run `/dependency-audit <pkg>` before adding any package.
- **No direct ClawHub skill installs** — curated allowlist only (36.82% of ClawHub skills have flaws).
- **Rule of Two** — no agent simultaneously processes untrusted input + accesses sensitive data + communicates externally.
- **Pre-commit checks** — `.pre-commit-config.yaml` runs security scanning, secret detection, and format validation.
- **CI pipeline** — 6-stage GitHub Actions pipeline validates every push and PR.
- **Runtime telemetry** — all agent actions monitored, anomalies detected per OWASP ASI01-ASI10.
- **OWASP Agentic Top 10** — all code reviewed against ASI01 through ASI10.
