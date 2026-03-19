# Session Handoff

## Last Updated
2026-03-18

## Current State
- Repository: https://github.com/signatureofgod2018/AgenticOS
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
- **Core tables**: security_events, audit_log (SHA-256 chain), agent_baselines, skill_allowlist, alert_history, network_requests
- **Canary tables**: performance_snapshots, performance_baselines, package_inventory, package_changes, package_activation, network_latency, dns_observations, resource_utilization, process_inventory
- **Views**: 14 pre-built Grafana views — critical events, OWASP trends, risk scores, performance anomalies, dormant package activations, network latency drift, DNS changes, resource spikes, new processes
- **Roles**: telemetry_writer (INSERT), telemetry_reader (SELECT), telemetry_admin (ALL)
- **Integrity**: SHA-256 hash chain on audit_log via trigger
- **Retention**: 12-month, automated partition drop
- 3 migrations, setup + migration runner scripts

### 7. Behavioral Canaries ("Hacks reveal themselves in silly things")
- **Philosophy**: Every system metric is a potential security signal. Breaches show up as performance drift, package bloat, dormant activations, latency shifts — not just security alerts.
- **17 new anomaly detection rules** covering: latency drift, unexplained CPU, memory creep, disk prediction, file descriptor surges, DNS changes, dormant package activation, package size increases, maintainer changes, install script additions, new processes, listening ports
- **17 new Prometheus alerts** in canary groups: performance drift, network behavior, package supply chain, process anomaly
- Reference: XZ Utils caught by 500ms SSH latency — not a security scan

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

### 8. Ollama Local Inference Infrastructure
- **Model**: Mistral Small 3.2 (24B MoE) at Q4_K_M quantization (~14 GB VRAM)
- **Runtime**: Ollama with AMD ROCm support (HSA_OVERRIDE_GFX_VERSION=10.3.0)
- **Monitoring**: ollama-metrics proxy → Prometheus → Grafana → PostgreSQL
- **Alerts**: 10 Prometheus rules — inference latency drift, throughput drops, memory growth, unknown agents, rate bursts, large prompts
- **Database**: Migration 004 — inference_requests (partitioned), model_lifecycle, inference_baselines
- **Views**: inference latency trend (p50/p95/p99), anomalies (z-score), token usage by agent, model load frequency
- **GPU note**: AMD RX 6900 XT — no NVIDIA/CUDA, no Nemotron. Mistral via Ollama/ROCm instead.

### 9. Whole House Monitoring (Prometheus Exporters)
- **node_exporter** (:9100) — OS: CPU, RAM, disk, network, systemd services, file descriptors
- **cAdvisor** (:8081) — Docker: per-container CPU, memory, network, disk I/O, OOM kills
- **postgres_exporter** (:9187) — PostgreSQL: connections, query latency, deadlocks, replication
- **smartctl_exporter** (:9633) — Disk: SMART health, temperature, SSD wear level
- **Fluent Bit OS logs** — syslog, auth.log, kern.log, apt history, dpkg, systemd journals
- **28 new alert rules** across OS health, OS security, Docker, PostgreSQL, disk hardware
- All feeding into: Prometheus → Grafana → PostgreSQL (critical events)

## System Profile (ST-Gabriel)
- CPU: AMD Ryzen 7 5800X3D (8c/16t)
- RAM: 32 GB
- GPU: AMD Radeon RX 6900 XT (16 GB VRAM) — RDNA 2, ROCm
- SSD: Samsung 980 PRO 1TB (NVMe) + 870 EVO 2TB (SATA)
- OS: Windows 11 Pro + WSL2 Ubuntu 24.04 LTS
- Docker: Engine 29.3.0 natively in Ubuntu (NOT Docker Desktop — see Known Issues)

### 10. Ubuntu 24.04 LTS on WSL2 — Installed & Hardened
- **Distro**: Ubuntu 24.04.4 LTS (Noble Numbat) — default WSL2 distro
- **User**: `agenticos` (uid 1000, sudo, passwordless sudo for setup)
- **Resources**: 15 GB RAM, 955 GB disk, 16 CPUs, systemd enabled
- **Hardening applied**:
  - Root account locked
  - Home directory 700 (owner only)
  - SSH hardened config (no root, no password auth, max 3 tries)
  - Kernel: IP forwarding disabled, ASLR enabled, SYN cookies, no ICMP redirects
  - Core dumps disabled, umask 027, file descriptor limit 65536
  - /opt/agenticos/ created with restricted permissions (certs dir 700)
  - Windows PATH stripped (appendWindowsPath=false)
  - Login banner: "AgenticOS — ST-GABRIEL — Guarded by St. Michael"

### 11. Live Services Installed on Ubuntu 24.04
- **PostgreSQL 16.13** (:5432) — `openclaw_telemetry` DB, 36 tables, 4 migrations applied
- **Prometheus 3.3.0** (:9090) — scraping node_exporter + self, 30-day retention
- **node_exporter 1.9.1** (:9100) — OS metrics with systemd + process collectors
- **Grafana 12.4.1** (:3000) — accessible from Windows browser via localhost
- **Docker Engine 29.3.0** — installed, disabled by default (`sudo systemctl start docker` when needed)
- Data sources: Prometheus + PostgreSQL wired to Grafana (may need re-adding after DB reset)

### 12. Docker Desktop vs Docker Engine (CRITICAL)
- **Docker Desktop on Windows MUST be quit** before using WSL2 services
- Docker Desktop's `docker-desktop` WSL distro disrupts the Hyper-V virtual switch
- Even with WSL integration unchecked, it interferes with port forwarding
- **Solution**: Docker Engine installed natively inside Ubuntu — use `systemctl start docker` instead
- Docker Desktop can be uninstalled once confirmed unnecessary

## Known Issues
- **WSL2 auto-shutdown**: WSL2 kills the distro when no terminal is open. **MUST keep a WSL terminal open** (minimized is fine) or services die. Fix next session: add keepalive process.
- **WSL2 networking**: After WSL shutdown/restart, services need manual restart: `sudo systemctl start postgresql prometheus node_exporter grafana-server`
- **Docker Desktop conflict**: Kills WSL2 port forwarding. Must quit Docker Desktop before using WSL2 services from Windows browser.
- **Grafana DB reset**: Data sources not yet wired — add Prometheus (`http://localhost:9090`) and PostgreSQL (`telemetry_reader` / `grafana_reader_2026`) via Grafana UI → Connections → Data sources.
- **Grafana password**: Was reset from default. User set their own password.

## Quick Start (after reboot or WSL drop)
```bash
# 1. Quit Docker Desktop if running
# 2. Open PowerShell:
wsl -d Ubuntu-24.04
# 3. Inside Ubuntu (LEAVE THIS TERMINAL OPEN):
sudo systemctl start postgresql prometheus node_exporter grafana-server
# 4. Browser: http://localhost:3000 (Grafana) / http://localhost:9090 (Prometheus)
```

## Blockers
- AMD GPU — no Nemotron local models (NVIDIA only), using Mistral via Ollama instead
- Ollama not yet installed — next priority after stabilizing base stack

## Key Resources
- OpenClaw docs: docs.openclaw.ai
- NemoClaw docs: docs.nvidia.com/nemoclaw/latest
- OpenClaw CVE tracker: github.com/jgamblin/OpenClawCVEs/
- OWASP Agentic Top 10: genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
- PostgreSQL docs: postgresql.org/docs/current/
- Grafana PostgreSQL plugin: grafana.com/docs/grafana/latest/datasources/postgres/
