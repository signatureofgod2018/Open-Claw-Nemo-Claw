# Vision — Open-Claw-Nemo-Claw

## Purpose
A workspace for deploying and integrating **OpenClaw** (open-source AI agent framework) with **NVIDIA NemoClaw** (enterprise security layer) to orchestrate secure AI agent activities between ST-Gabriel and Maria (ARK).

## Core Components

### OpenClaw — AI Agent Framework
- Open-source autonomous AI agent platform (github.com/openclaw/openclaw)
- 61k+ GitHub stars, 320k+ lines of TypeScript
- **Gateway**: Central WebSocket server coordinating agents, clients, and messaging
- **Tools**: Grouped capabilities — filesystem, web, browser, runtime, memory, messaging, automation
- **Skills**: Modular SKILL.md files with YAML frontmatter, shared via ClawHub (5,400+ skills)
- **Plugins**: TypeScript modules loaded at runtime, no build step needed
- **50+ integrations**: WhatsApp, Slack, Discord, Telegram, GitHub, and more
- Requires: Node.js 24 (recommended) or Node.js 22 LTS

| Resource | URL |
|----------|-----|
| Docs | docs.openclaw.ai |
| GitHub | github.com/openclaw/openclaw |
| Skills | docs.openclaw.ai/tools/skills |
| ClawHub (skill registry) | github.com/openclaw/clawhub |
| Skill format spec | github.com/openclaw/clawhub/blob/main/docs/skill-format.md |
| Plugin docs | docs.openclaw.ai/tools/plugin |

### NVIDIA NemoClaw — Security Layer
- Wraps OpenClaw with enterprise-grade privacy and security (github.com/NVIDIA/NemoClaw)
- Announced at NVIDIA GTC 2026 — currently **alpha**, Apache 2.0 license
- **OpenShell**: Kernel-level sandboxing — each agent runs in an isolated container
- **Privacy Router**: Monitors agent behavior, enforces guardrails on cloud model access
- **Nemotron**: NVIDIA's local models for privacy-sensitive workloads
- **Declarative YAML policies**: Control file access, network connections, cloud service calls
- Hardware-agnostic but optimized for NVIDIA GPUs
- Install: `curl -fsSL https://nvidia.com/nemoclaw.sh | bash`

| Resource | URL |
|----------|-----|
| Docs | docs.nvidia.com/nemoclaw/latest |
| GitHub | github.com/NVIDIA/NemoClaw |
| Product page | nvidia.com/en-us/ai/nemoclaw |
| OpenShell blog | developer.nvidia.com/blog/run-autonomous-self-evolving-agents-more-safely-with-nvidia-openshell |
| Forums | forums.developer.nvidia.com/t/introducing-nvidia-nemoclaw/363701 |

## Infrastructure

### ST-Gabriel (Orchestration)
- Windows 11 machine with planned Linux partition
- Role: Run OpenClaw Gateway + NemoClaw sandbox, orchestrate tasks
- Will host the OpenClaw Gateway process as the central control plane
- NemoClaw's OpenShell sandbox isolates agent execution

### Maria / ARK (Execution)
- Remote target machine
- Role: Receive dispatched tasks, execute in NemoClaw sandbox
- Can run its own OpenClaw Gateway or act as a remote execution endpoint
- Questions to resolve:
  - [ ] What OS/environment does Maria run?
  - [ ] Transport: OpenClaw Gateway-to-Gateway, SSH tunnel, or other?
  - [ ] Does Maria run its own NemoClaw instance or connect to ST-Gabriel's?

## Non-Goals (for now)
- Not building a new agent framework — leveraging OpenClaw as-is
- Not replacing NemoClaw's security model — using it as the security layer
- Not targeting production deployment yet — this is a learning/integration workspace

## Answered Questions
- [x] ~~What does a tool definition look like?~~ → OpenClaw tool groups with grouped capabilities
- [x] ~~How are tools discovered and registered?~~ → OpenClaw plugin system + ClawHub skill registry
- [x] ~~How do agents request and invoke tools?~~ → OpenClaw Gateway routes tool invocations
- [x] ~~Is this language/runtime agnostic?~~ → TypeScript/Node.js core, but tools can shell out to anything
- [x] ~~What existing standards does this build on?~~ → OpenClaw's own SKILL.md format, compatible with Claude Code conventions
- [x] ~~What is the threat model?~~ → NemoClaw/OpenShell handles: sandboxing, network isolation, file access control, privacy routing
- [x] ~~How are agents authenticated/authorized?~~ → NemoClaw declarative YAML policies
- [x] ~~Are there existing projects to build on?~~ → Yes — OpenClaw + NemoClaw are the foundation

## Remaining Open Questions
- [ ] What's the MVP? Smallest useful thing to prove the loop works?
- [ ] What GPU/compute is available on ST-Gabriel for local Nemotron models?
- [ ] What integrations to enable first? (messaging, GitHub, etc.)
- [ ] What custom skills/plugins will this project need?
