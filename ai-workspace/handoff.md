# Session Handoff

## Last Updated
2026-03-18

## Current State
- Project initialized with VS Code workspace and GitHub repo
- Repository: https://github.com/signatureofgod2018/Open-Claw-Nemo-Claw
- Branch: master
- Folder structure: `.claude/` (agents, skills, hooks, commands) + `ai-workspace/`
- Planning docs fully populated with real OpenClaw + NemoClaw platform details
- Security Sentinel agent created with OWASP Agentic Top 10 enforcement
- **Full security assessment completed** — see `ai-workspace/security-assessment.md`

## What We Built This Session
1. **Project scaffolding** — GitHub repo, `.claude/` structure, `ai-workspace/` planning docs
2. **Platform research** — identified OpenClaw and NemoClaw as real, documented platforms
3. **Planning docs** — vision, requirements, architecture, roadmap with real platform details
4. **Security Sentinel agent** — static code analysis + supply chain auditing + OWASP ASI enforcement
5. **Security assessment** — comprehensive gap analysis of OpenClaw vulnerabilities and NemoClaw limitations

## Critical Security Findings
OpenClaw has serious known vulnerabilities (512 found in Jan 2026 audit, 8 critical). NemoClaw adds useful runtime sandboxing but leaves critical gaps:

| Gap | Risk | Our Mitigation |
|-----|------|----------------|
| Prompt injection (ASI01) | Sandbox doesn't protect reasoning layer | Rule of Two, input sanitization |
| Memory poisoning (ASI06) | >95% injection success rate (MINJA) | Memory integrity validation |
| Malicious skills (ASI04) | 36.82% of ClawHub skills have flaws | Curated allowlist, no direct pulls |
| Confused deputy (ASI02) | Tools abused within granted scope | Per-request auth in tools |
| Inter-agent trust (ASI07) | No agent-to-agent authentication | mTLS, message signing |
| Sandbox escape | TOCTOU race ~25%, NVIDIA CVE-2025-23266 | CVE tracking, container hardening |
| Data exfiltration | Allowed tools = exfil channels | Output monitoring, strict URL allowlist |

**Full details:** `ai-workspace/security-assessment.md`

## Key Decisions
- OpenClaw is the agent framework — not building custom
- NemoClaw is the security layer — not building custom
- Security Sentinel is P0 — active from day one
- **No direct ClawHub skill installs** — curated allowlist only
- **Rule of Two enforced** — no agent gets untrusted input + sensitive data + external comms
- No unaudited dependencies — `/dependency-audit` required before adding packages
- No hardcoded secrets — enforced by pre-commit hook
- ST-Gabriel (Linux partition) = orchestration, Maria (ARK) = remote execution

## In Progress
- Phase 0 — Foundation (planning + security assessment complete, infra setup next)

## Next Steps
1. Integrate `security-check.sh` as a git pre-commit hook
2. Set up Linux partition on ST-Gabriel
3. Install Node.js 24 + OpenClaw (review OpenClaw hardening guide first)
4. Install NemoClaw with deny-all YAML policies
5. **Harden OpenClaw before enabling any features** — reference security assessment
6. Define curated skill allowlist before pulling from ClawHub
7. Define mTLS + message signing for ST-Gabriel ↔ Maria transport

## Blockers
- Linux partition not yet set up on ST-Gabriel
- GPU availability unknown (affects Nemotron local model viability)

## Key Resources
- OpenClaw docs: docs.openclaw.ai
- NemoClaw docs: docs.nvidia.com/nemoclaw/latest
- OpenClaw CVE tracker: github.com/jgamblin/OpenClawCVEs/
- OWASP Agentic Top 10: genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
- Adversa AI hardening guide: adversa.ai/blog/openclaw-security-101-vulnerabilities-hardening-2026/
- Snyk ToxicSkills audit: snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
- Simon Willison Lethal Trifecta: simonw.substack.com/p/the-lethal-trifecta-for-ai-agents
