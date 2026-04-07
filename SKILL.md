---
name: openclaw-versioning
description: Advanced handling for agent-versioning requests (history, diffs, restores, rollbacks, snapshots) using git and OpenClaw scripts with clear, user-focused summaries and outputs.
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["git"]}}}
---

# OpenClaw Versioning

OpenClaw tracks workspace file changes between turns and attributes them to the user who triggered the change. Use this skill to answer history and diff questions and to apply controlled restores or rollbacks.

## When To Use

Use this skill when the user asks about:
- What changed, who changed it, or when it changed
- Diffs between versions or commits
- Rolling back or restoring files
- Taking or inspecting snapshots or status
- Setting up or verifying auto-versioning

## Response Framework

1. **Clarify intent and scope.**
	- Determine whether the user wants a quick summary or raw output.
	- Pin down file(s), time range, and commit identifiers if needed.

2. **Choose the evidence source.**
	- Casual queries: use git to gather a compact view.
	- Explicit `/openclaw-versioning` invocations: run the matching script and return stdout verbatim.

3. **Present results clearly.**
	- Summarize what changed, who triggered it, and the rough size.
	- Offer the next most likely action (diff, restore, rollback, or log).

4. **Handle destructive actions safely.**
	- Always show what will change before a rollback or restore.
	- Prefer `restore` for single-file fixes; use `rollback` only when the user wants to revert everything.
	- If the target commit is ambiguous, ask a clarification question.

5. **Guide GitHub onboarding for setup.**
	- After `setup`, proactively ask: "ok do you want help with github?"
	- If yes, walk them through GitHub onboarding with no extra setup steps required on their side.
	- Confirm account status, git identity, auth method, and remote configuration.

## Output Style

- For summaries, keep it short and conversational.
- For script-driven output, do not reformat or summarize; if onboarding guidance is needed, provide it after the raw output.
- If an argument looks like a typo, confirm before running.

## Implementation Notes

- **Casual history or diff:** use a small git window (last 5-10 commits) and include stat output.
- **Slash commands:** use the scripts in `setup.sh` and `scripts/` with the user-provided arguments.
- **Setup:** run the setup script, then ask "ok do you want help with github?" and proceed if they confirm.
- **Restore or rollback:** locate the commit via `log`, then perform the change after showing what will be modified.

## Command Reference (Compact)

Use this only for explicit `/openclaw-versioning` invocations, and return stdout verbatim.

- `setup` -> `bash {baseDir}/setup.sh`
- `setup` follow-up -> GitHub onboarding guidance
- `status` -> `bash {baseDir}/scripts/status.sh`
- `log` -> `bash {baseDir}/scripts/log.sh [count] [--detail]`
- `diff` -> `bash {baseDir}/scripts/diff.sh [commit] [commit2]`
- `rollback` -> `bash {baseDir}/scripts/rollback.sh <commit> ["reason"]`
- `restore` -> `bash {baseDir}/scripts/restore.sh <file> <commit> ["reason"]`
- `commit` -> `bash {baseDir}/scripts/commit.sh --manual ["message"]`

## Auto-Versioning Overview

Two hooks capture and commit changes between turns and attribute them to the active user. Defaults can be overridden via `.openclaw-versioning.json`.

Tracked by default: `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md`, `BOOT.md`, `BOOTSTRAP.md`, `MEMORY.md`, `.gitignore`, `.openclaw-versioning.json`, `skills/`, `hooks/`.

To override, create `<workspace>/.openclaw-versioning.json`:
```json
{ "tracked": ["AGENTS.md", "SOUL.md", "skills/", "hooks/"] }
```

## GitHub Onboarding (Setup Add-on)

Use this flow after setup to help users connect the workspace to GitHub, without asking them to do extra prep work:

1. **Account and intent.** Confirm they have a GitHub account and want this repo linked.
2. **Git identity.** Ensure `user.name` and `user.email` are set for commits.
3. **Auth method.** Offer SSH or HTTPS; proceed with their preference.
4. **Remote and verify.** Ensure an `origin` remote exists and verify access.
5. **Next action.** Create or select the GitHub repo, then push or fetch as needed.

