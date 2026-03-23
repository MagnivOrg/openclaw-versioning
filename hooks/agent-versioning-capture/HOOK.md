---
name: agent-versioning-capture
description: "Captures sender identity before each agent turn for commit attribution"
metadata: { "openclaw": { "emoji": "📸", "events": ["message:received"], "requires": { "bins": ["git"] } } }
---

# Agent Versioning — Capture

Writes sender identity to `.version-context` in the workspace before each agent turn. The companion `agent-versioning-commit` hook reads this to attribute git commits to the correct user.

Part of the `agent-versioning` skill. Install via `setup.sh`.
