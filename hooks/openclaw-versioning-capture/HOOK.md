---
name: openclaw-versioning-capture
description: "Captures sender identity before each agent turn for commit attribution"
metadata: { "openclaw": { "emoji": "📸", "events": ["message:received"], "requires": { "bins": ["git"] } } }
---

# OpenClaw Versioning — Capture

Writes sender identity to `.version-context` in the workspace before each agent turn. The companion `openclaw-versioning-commit` hook reads this to attribute git commits to the correct user.

Part of the `openclaw-versioning` skill. Install via `setup.sh`.
