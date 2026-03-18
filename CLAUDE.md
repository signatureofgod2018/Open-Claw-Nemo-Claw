# Open-Claw-Nemo-Claw

## Project Structure

```
.claude/
  agents/       # Autonomous agent definitions (.md with YAML frontmatter)
  skills/       # Reusable skills (subdirectories with SKILL.md)
  hooks/        # Lifecycle hooks (scripts + hooks.json)
  commands/     # Custom CLI commands
ai-workspace/
  handoff.md    # Session handoff notes for continuity between conversations
```

## Conventions

- Agents are markdown files with YAML frontmatter (name, description, model, tools)
- Skills live in subdirectories under `.claude/skills/` with a `SKILL.md` entry point
- Hooks are configured via `.claude/hooks/hooks.json`
- Session handoff notes go in `ai-workspace/handoff.md` — update at end of each session
