# Open-Claw-Nemo-Claw

## Project Structure

```
.claude/
  agents/
    security-sentinel.md   # Security agent — static analysis + supply chain auditing
  skills/
    dependency-audit/       # On-demand package dependency security audit
  hooks/
    hooks.json              # Lifecycle hook configuration
    security-check.sh       # Pre-commit security scanning script
  commands/
ai-workspace/
  handoff.md               # Session handoff for continuity between conversations
  vision.md                # Project vision and platform details
  requirements.md          # Functional and non-functional requirements
  architecture.md          # System architecture diagrams
  roadmap.md               # Phased delivery plan
```

## Conventions

- Agents are markdown files with YAML frontmatter (name, description, model, tools)
- Skills live in subdirectories under `.claude/skills/` with a `SKILL.md` entry point
- Hooks are configured via `.claude/hooks/hooks.json`
- Session handoff notes go in `ai-workspace/handoff.md` — update at end of each session

## Security Policy

**The Security Sentinel agent is active from day one.** All code and dependencies must pass security review.

- **No hardcoded secrets** — ever. Use environment variables or NemoClaw-managed secrets.
- **No unaudited dependencies** — run `/dependency-audit <pkg>` before adding any package.
- **Pre-commit checks** — `.claude/hooks/security-check.sh` scans for secrets, dangerous patterns, and suspicious install scripts.
- **Supply chain vigilance** — flag packages with single maintainers, recent maintainer changes, or suspicious `postinstall` scripts. Remember XZ Utils (CVE-2024-3094).
- **OWASP Top 10** — all code reviewed for injection, broken auth, sensitive data exposure, etc.
