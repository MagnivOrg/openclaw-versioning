---
name: openclaw-versioning
description: Version control for the agent's own workspace files — tracks who changed what and when, with git commits attributed to the user who triggered each change. Use when asked to check version history, view diffs, roll back files, take a snapshot, or set up auto-versioning. Triggers on phrases like "what changed", "undo that change", "roll back to", "show history", "take a snapshot", "set up versioning", "who changed".
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["git"]}}}
---

# OpenClaw Versioning

Auto-commits workspace config changes after every agent turn, attributed to whoever sent the message.

> **Output rule:** Every command runs a bash script. Always execute the script and send its complete output to the user. Never summarize, skip, or say "same as before" — run it fresh every time.

## Onboarding

**Step 1** — Install hooks and initialize the git repo:
```bash
bash {baseDir}/setup.sh
```
This copies the hooks, initializes the git repo if needed, and takes a first snapshot. Tell the user to restart their openclaw gateway after this completes.

**Step 2** — After the gateway restarts, register the commit cron by calling the `cron.add` tool:
```json
{
  "name": "openclaw-versioning-commit",
  "cron": "*/10 * * * *",
  "message": "bash {baseDir}/scripts/commit.sh",
  "session": "isolated"
}
```
Confirm with the user once the cron appears in `openclaw cron list`.

To verify hooks are active:
```bash
openclaw hooks list | grep openclaw-versioning
```

## Commands

### `setup`
Register the auto-commit cron if not already present. Call the `cron.add` tool:
```json
{
  "name": "openclaw-versioning-commit",
  "cron": "*/10 * * * *",
  "message": "bash {baseDir}/scripts/commit.sh",
  "session": "isolated"
}
```
Skip if `openclaw cron list` already shows `openclaw-versioning-commit`.

### `status`
Show current versioning state — latest snapshot, uncommitted changes, tracked files. Print the output verbatim.
```bash
bash {baseDir}/scripts/status.sh
```

### `log [count]`
Show version history. Default: last 20 entries. Run the script and print the output verbatim — do not summarize or reformat it.
```bash
bash {baseDir}/scripts/log.sh [count]
```

### `diff [commit] [commit2]`
Show changes. No args = uncommitted. One arg = what changed in that commit. Two args = diff between commits. Print the output verbatim.
```bash
bash {baseDir}/scripts/diff.sh [commit] [commit2]
```

### `rollback <commit>`
Restore ALL tracked files to a previous version. Creates a new commit recording the rollback.
**Always show the user what will change before rolling back.**
```bash
bash {baseDir}/scripts/rollback.sh <commit>
```

### `restore <file> <commit>`
Restore a **single file** to its state before a specific commit — without touching anything else. Use this when the user wants to undo a specific file's change.

To find the right commit: run `log`, read the `--- Change log ---` section in each commit body to identify which turn changed the file, then pass that commit hash.
```bash
bash {baseDir}/scripts/restore.sh <file> <commit>
```

**Example undo flow:**
1. User says "undo Noam's change to AGENTS.md from earlier"
2. Run `log` to find the commit containing Noam's change to AGENTS.md
3. Read the change log in that commit body to confirm the right entry
4. Run `restore.sh AGENTS.md <hash>`

### `snapshot <message>`
Manually create a named checkpoint.
```bash
bash {baseDir}/scripts/snapshot.sh "description"
```

### `commit`
Flush pending changes now as a manual commit. Commits are labeled "Manual commit" to distinguish from auto-commits by the cron.
```bash
bash {baseDir}/scripts/commit.sh --manual
```

## Auto-Versioning

The two installed hooks handle everything automatically:
- `openclaw-versioning-capture` fires on `message:received` — saves sender identity to `.version-context`
- `openclaw-versioning-commit` fires on `message:sent` — stages tracked files, commits with sender attribution if anything changed

Tracked by default: `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md`, `BOOT.md`, `BOOTSTRAP.md`, `MEMORY.md`, `.gitignore`, `skills/`, `hooks/`

To override, create `<workspace>/.openclaw-versioning.json`:
```json
{ "tracked": ["AGENTS.md", "SOUL.md", "skills/", "hooks/"] }
```

## When to Manually Snapshot

- Before risky changes (clean rollback point)
- After a significant milestone ("v2 of triage prompt")
- When the user explicitly asks to save or checkpoint
