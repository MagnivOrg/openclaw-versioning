---
name: openclaw-versioning
description: Version control for the agent's own workspace files — tracks who changed what and when, with git commits attributed to the user who triggered each change. Use when asked to check version history, view diffs, roll back files, take a snapshot, or set up auto-versioning. Triggers on phrases like "what changed", "undo that change", "roll back to", "show history", "take a snapshot", "set up versioning", "who changed".
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["git"]}}}
---

# OpenClaw Versioning

Between turns, tracked workspace files are diffed and staged with sender attribution. A cron job batches those staged changes into a git commit every 10 minutes.

> **Output rule:** Every command runs a bash script. Always execute the script and send its complete output to the user. Never summarize, skip, or say "same as before" — run it fresh every time.

## Output Contract

For every command in this skill:

1. Run exactly the documented script command for that action.
2. Return the script's stdout verbatim — do not reformat, summarize, or paraphrase it. The scripts output markdown directly.
3. Do not wrap the output in a code block. Render it as markdown so it displays properly.
4. You may append a brief addendum only if it adds necessary context (e.g., a next-step suggestion or error clarification). Keep it to one line.
5. If output is too long for one message, send it in ordered chunks labeled `Part 1/N`, `Part 2/N`, etc., without omitting lines.

## Commands

### `setup`
Run first-time setup. Installs hooks, enables them in config, restarts the gateway, registers the cron, initializes the git repo, and takes a first snapshot.
Return the full setup output exactly as produced by the script (no truncation and no summarization).
```bash
bash {baseDir}/setup.sh
```

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
Restore ALL tracked files to a previous version. Stages the changes and defers the commit — same flow as `restore`. The optional reason is recorded in the pending log for attribution.
**Always show the user what will change before rolling back.**
```bash
bash {baseDir}/scripts/rollback.sh <commit> ["reason"]
```

### `restore <file> <commit> [reason]`
Restore a **single file** to its state before a specific commit — without touching anything else. Use this when the user wants to undo a specific file's change. The optional reason is recorded in the pending log for attribution.

To find the right commit: run `log`, read the `--- Change log ---` section in each commit body to identify which turn changed the file, then pass that commit hash.
```bash
bash {baseDir}/scripts/restore.sh <file> <commit>
```

**Example undo flow:**
1. User says "undo Noam's change to AGENTS.md from earlier"
2. Run `log` to find the commit containing Noam's change to AGENTS.md
3. Read the change log in that commit body to confirm the right entry
4. Run `restore.sh AGENTS.md <hash>`

### `commit [message]`
Flush pending staged changes as a manual commit. If a message is provided it becomes the commit subject — useful for named checkpoints. Without a message the subject lists the staged files.
```bash
bash {baseDir}/scripts/commit.sh --manual
# or with a message:
bash {baseDir}/scripts/commit.sh --manual "before big prompt rewrite"
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

