---
name: openclaw-versioning-commit
description: "Auto-commits workspace file changes with sender attribution after each agent turn"
metadata: { "openclaw": { "emoji": "📝", "events": ["message:sent"], "requires": { "bins": ["git"] } } }
---

# OpenClaw Versioning — Commit

After each outbound message, stages tracked workspace files and commits any changes with full sender attribution baked into the git author field.

Tracked files are read from `.openclaw-versioning.json` in the workspace, written by `setup.sh` on install.

Part of the `openclaw-versioning` skill. Install via `setup.sh`.
