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
- [ ] Integrate security-check.sh as git pre-commit hook
- [ ] Set up Linux partition on ST-Gabriel
- [ ] Determine GPU availability for local Nemotron models

## Phase 1 — OpenClaw on ST-Gabriel
- [ ] Install Node.js 24 on Linux partition
- [ ] Install OpenClaw: `openclaw onboard`
- [ ] Configure LLM provider (API key)
- [ ] Start Gateway, verify it runs
- [ ] Explore built-in tools (fs, web, runtime, memory)
- [ ] Install and test a skill from ClawHub
- [ ] Create first custom SKILL.md

## Phase 2 — NemoClaw Security Layer
- [ ] Install NemoClaw: `curl -fsSL https://nvidia.com/nemoclaw.sh | bash`
- [ ] Run `nemoclaw onboard` — sandbox creation
- [ ] Write first YAML security policy (file access, network rules)
- [ ] Verify OpenClaw runs inside NemoClaw sandbox
- [ ] Test privacy router (cloud model + local Nemotron if GPU available)
- [ ] Audit logging — verify interaction traces

## Phase 3 — Custom Skills & Plugins
- [ ] Build first custom TypeScript plugin
- [ ] Create project-specific skills for orchestration tasks
- [ ] Enable integrations (GitHub, messaging, etc.)
- [ ] Bridge Claude Code workflow with OpenClaw skills

## Phase 4 — Remote Dispatch (ST-Gabriel → Maria)
- [ ] Choose transport protocol
- [ ] Set up Maria (ARK) with OpenClaw + NemoClaw
- [ ] Establish secure link between ST-Gabriel and Maria
- [ ] Test task dispatch and result retrieval end-to-end
- [ ] Error handling and retry logic

## Phase 5 — Multi-Agent Orchestration
- [ ] Multiple agents discovering and invoking tools
- [ ] Per-agent permission scoping via NemoClaw policies
- [ ] Cross-machine agent coordination
- [ ] Full audit trail across both machines

## Phase 6 — Hardening & Production
- [ ] Threat modeling and security review
- [ ] Observability (logging, metrics, tracing)
- [ ] Documentation and onboarding guide
- [ ] Reproducible setup scripts for both machines
