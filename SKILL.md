---
name: openclaw-versioning
description: Version control for the agent's own workspace files — tracks who changed what and when, with git commits attributed to the user who triggered each change. Use when asked to check version history, view diffs, roll back files, take a snapshot, or set up auto-versioning. Triggers on phrases like "what changed", "undo that change", "roll back to", "show history", "take a snapshot", "set up versioning", "who changed".
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["git"]}}}
---

# OpenClaw Versioning

Between turns, tracked workspace files are diffed and staged with sender attribution. A cron job batches those staged changes into a git commit every 10 minutes.

> **Output rule:** Every command runs a bash script. Always execute the script and send its complete output to the user. Never summarize, skip, or say "same as before" — run it fresh every time.

## Onboarding

**Step 1** — Run setup and restart the gateway:
```bash
bash {baseDir}/setup.sh
```
Installs the hooks, initializes the git repo, and takes a first snapshot. Tell the user to restart their openclaw gateway after this completes.

**Step 2** — After the gateway restarts, register the commit cron:
```bash
openclaw cron add --name "openclaw-versioning-commit" --cron "*/10 * * * *" --message "bash {baseDir}/scripts/commit.sh" --session isolated --announce --best-effort-deliver
```
Confirm with the user once the cron appears in `openclaw cron list`.

## Commands

### `status`
Show current versioning state — latest snapshot, uncommitted changes, tracked files. Print the output verbatim.
```bash
bash {baseDir}/scripts/status.sh
```

### `log [count] [--detail]`
Show version history. Run the script and print the output verbatim — do not summarize or reformat it, do not run any additional git commands.

```bash
# Default: no args — script defaults to 5 commits
bash {baseDir}/scripts/log.sh

# With full body per commit
bash {baseDir}/scripts/log.sh --detail

# User specifies a count
bash {baseDir}/scripts/log.sh 10

# User specifies count and detail
bash {baseDir}/scripts/log.sh 10 --detail
```

### `diff [commit] [commit2]`
Show changes. No args = uncommitted. One arg = what changed in that commit. Two args = diff between commits. Print the output verbatim.
```bash
bash {baseDir}/scripts/diff.sh [commit] [commit2]
```

### `rollback <commit> [reason]`
Restore ALL tracked files to a previous version. Creates a new commit recording the rollback. The optional reason is appended to the commit message and should capture why the rollback was done.
**Always show the user what will change before rolling back.**
```bash
bash {baseDir}/scripts/rollback.sh <commit> ["reason"]
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
- `openclaw-versioning-commit` fires on `message:sent` — diffs tracked files against HEAD, appends attribution to `pending_commits.jsonl`, and stages any changes

Tracked by default: `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md`, `BOOT.md`, `BOOTSTRAP.md`, `MEMORY.md`, `.gitignore`, `.openclaw-versioning.json`, `skills/`, `hooks/`

To override, create `<workspace>/.openclaw-versioning.json`:
```json
{ "tracked": ["AGENTS.md", "SOUL.md", "skills/", "hooks/"] }
```

## When to Manually Snapshot

- Before risky changes (clean rollback point)
- After a significant milestone ("v2 of triage prompt")
- When the user explicitly asks to save or checkpoint
