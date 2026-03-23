---
name: openclaw-versioning-commit
description: "Auto-commits workspace file changes with sender attribution after each agent turn"
metadata: { "openclaw": { "emoji": "📝", "events": ["message:sent"], "requires": { "bins": ["git"] } } }
---

# OpenClaw Versioning — Commit

After each outbound message, stages tracked workspace files and commits any changes with full sender attribution baked into the git author field.

Tracked by default: `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md`, `BOOT.md`, `BOOTSTRAP.md`, `MEMORY.md`, `.gitignore`, `skills/`, `hooks/`

Override by creating `.openclaw-versioning.json` in your workspace:
```json
{ "tracked": ["AGENTS.md", "SOUL.md", "skills/", "hooks/"] }
```

Part of the `openclaw-versioning` skill. Install via `setup.sh`.
