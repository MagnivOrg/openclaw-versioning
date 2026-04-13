---
name: agent-changelog
description: Advanced handling for agent-changelog requests (history, diffs, restores, rollbacks, snapshots) using git and OpenClaw scripts with clear, user-focused summaries and outputs.
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["git","jq","node"],"env":["OPENCLAW_WORKSPACE","OPENCLAW_CONFIG"]}}}
---

# Agent Changelog

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
	- Explicit `/agent-changelog` invocations: run the matching script and return stdout verbatim.

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

## File Content Rules

**Never embed attribution metadata inside file content.** Do not add inline annotations like `(updated by X on date)`, `# changed by Y`, status footnotes, or any other authorship/timestamp markers into the files you edit. Attribution belongs exclusively in the git commit message, which is handled automatically by the hooks and `commit.sh`. Files should contain only their actual content — clean, annotation-free.

## Implementation Notes

- **Casual history or diff:** use a small git window (last 5-10 commits) and include stat output.
- **Slash commands:** use the scripts in `setup.sh` and `scripts/` with the user-provided arguments.
- **Setup:** run the setup script, then ask "ok do you want help with github?" and proceed if they confirm.
- **Restore or rollback:** locate the commit via `log`, then perform the change after showing what will be modified.
- **Semantic summary:** before every commit, run a quick diff and generate a sparse one-line summary of what changed and why (e.g. "added rate-limit rule to AGENTS.md, updated memory skill"). Always pass it via `--summary` and always include it in any history output presented to the user.
- **Log output:** `log.sh` outputs raw structured data — present it conversationally based on what the user asked. Don't dump raw script output. Format each entry using the `│`-prefixed box style (same as status output), one entry per block.

## Command Reference (Compact)

Use this only for explicit `/agent-changelog` invocations, and return stdout verbatim.

- `setup` -> `bash {baseDir}/setup.sh`
- `setup` follow-up -> GitHub onboarding guidance
- `status` -> `bash {baseDir}/scripts/status.sh`
- `log` -> `bash {baseDir}/scripts/log.sh [count]`
- `diff` -> `bash {baseDir}/scripts/diff.sh [commit] [commit2]`
- `rollback` -> `bash {baseDir}/scripts/rollback.sh <commit> ["reason"]`
- `restore` -> `bash {baseDir}/scripts/restore.sh <file> <commit> ["reason"]`
- `commit` (user-requested) -> `bash {baseDir}/scripts/commit.sh --manual ["message"] [--summary "one-line semantic summary"]`
- `commit` (cron-triggered) -> `bash {baseDir}/scripts/commit.sh [--summary "one-line semantic summary"]`

## Auto-Versioning Overview

Two hooks capture and commit changes between turns and attribute them to the active user. Defaults can be overridden via `.agent-changelog.json`.

Tracked by default: `.` (entire workspace). Secrets and runtime files are excluded via the `.gitignore` that setup creates — note that if a `.gitignore` already exists in the workspace, setup leaves it untouched, so ensure it covers secrets before enabling tracking.

To track a specific subset instead, edit `<workspace>/.agent-changelog.json` with a `tracked` array (this fully replaces the default):
```json
{ "tracked": ["<file-or-folder>", "<file-or-folder>"] }
```

## GitHub Onboarding (Setup Add-on)

Use this flow after setup to help users connect the workspace to GitHub. The user will need to authenticate (SSH key or HTTPS credential) — walk them through it step by step:

1. **Account and intent.** Confirm they have a GitHub account and want this repo linked.
2. **Git identity.** Ensure `user.name` and `user.email` are set for commits.
3. **Auth method.** Offer SSH or HTTPS; proceed with their preference.
4. **Remote and verify.** Ensure an `origin` remote exists and verify access.
5. **Next action.** Create or select the GitHub repo, then push or fetch as needed.

