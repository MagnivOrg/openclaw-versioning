# openclaw-versioning

A versioning skill for [OpenClaw](https://openclaw.dev) agents. Between turns, tracked workspace files are diffed and staged with sender attribution. A cron job batches those staged changes into a git commit every 10 minutes. Gives you a full audit trail of who changed what and when, with rollback and diff tools accessible directly from chat.

---

## How it works

Two hooks handle everything automatically:

1. **`openclaw-versioning-capture`** fires on `message:received` and writes sender identity (name, ID, channel) to `.version-context`. This is a temporary handoff, by the time `message:sent` fires, the sender context is gone, so it's captured here first.

2. **`openclaw-versioning-commit`** fires on `message:sent`. Diffs tracked files against HEAD, appends an attribution entry to `pending_commits.jsonl`, and stages any changes. Each turn appends independently, so multiple users across multiple channels accumulate before the next commit.

A cron job fires every 10 minutes and runs `commit.sh`, which reads the full pending log, collects all unique senders, builds a commit message with grouped attribution and a per-turn changelog, commits, and clears the log.

```
message:received  →  capture hook  →  .version-context written
      ↓
  agent turn (files may change)
      ↓
message:sent  →  commit hook  →  pending_commits.jsonl appended, files staged
      ↓
  cron (every 10 min)  →  commit.sh  →  git commit with full attribution + changelog
```

The skill commands (`/openclaw-versioning log`, `diff`, `rollback`, etc.) are available in any connected channel or CLI session.

---

## Install

**Requirements:** `git`, `jq`, Node.js (for hook handlers)

**1.** Add this repo to your workspace `skills/` directory.

**2.** Say `/openclaw-versioning setup` to your agent.

**3.** Verify:
```
/openclaw-versioning status
```

**(Optional) Push commits to a remote:**

```bash
gh auth login
cd $OPENCLAW_WORKSPACE
git remote add origin <url>
```

Then add to `.openclaw-versioning.json`:

```json
{ "git": { "remote": "origin", "branch": "main" } }
```

If `remote` is absent, commits stay local.

---

## Configuration

After install, `.openclaw-versioning.json` will exist in your workspace. Edit it to customize.

Default tracked files:

```json
{ "tracked": ["AGENTS.md", "SOUL.md", "IDENTITY.md", "USER.md", "TOOLS.md", "HEARTBEAT.md", "BOOT.md", "BOOTSTRAP.md", "MEMORY.md", ".gitignore", ".openclaw-versioning.json", "skills/", "hooks/"] }
```

Override by editing `.openclaw-versioning.json` in your workspace:

```json
{ "tracked": ["AGENTS.md", "SOUL.md", "skills/", "hooks/"] }
```

Push commits to a remote after each cron commit:

```json
{ "git": { "remote": "origin", "branch": "main" } }
```

The skill calls `git push` directly. You can set up your remote and auth (SSH key, `gh auth login`, or HTTPS token) before enabling this.

The tracked file defaults are inlined in `setup.sh` and written on first install.

---

## Scripts

Scripts live in `scripts/` and are called by the agent via `bash {baseDir}/scripts/<name>.sh`.

| Script | Purpose |
|---|---|
| `commit.sh` | Flush `pending_commits.jsonl` into a git commit with full attribution. Called by the cron every 10 min. Pass `--manual` to trigger outside the cron. |
| `snapshot.sh` | Create a clean named checkpoint. Takes an optional message. Does not touch the pending log — use this for milestone markers ("v2 launch config", "before experiment"). |
| `status.sh` | Show latest commit, uncommitted changes with line counts, and tracked files. |
| `log.sh` | Show commit history. Accepts a count and `--detail` flag for full commit bodies. |
| `diff.sh` | Show diffs. No args = uncommitted changes. One arg = what changed in that commit. Two args = between two commits. |
| `rollback.sh` | Restore all tracked files to a prior commit. Creates a new commit recording the rollback. |
| `restore.sh` | Restore a single file to its state before a specific commit. Stages the change and appends to pending log for attribution on next commit. |

---

## Hooks

Hooks live in `hooks/` and are installed into the workspace during setup.

| Hook | Event | What it does |
|---|---|---|
| `openclaw-versioning-capture` | `message:received` | Writes sender identity to `.version-context` |
| `openclaw-versioning-commit` | `message:sent` | Stages tracked files, appends attribution to `pending_commits.jsonl` |

Each hook directory contains a `HOOK.md` with frontmatter required for OpenClaw hook registration, and a `handler.ts` with the implementation.

---

## Workspace files

| File | Description |
|---|---|
| `.openclaw-versioning.json` | Tracked files config. Written by `setup.sh` on first install. Edit to customize. |
| `.version-context` | Temporary handoff between the two hooks. The capture hook writes sender identity here on `message:received`; the commit hook reads it on `message:sent` to attribute changes to the right person, then deletes it. Never committed. |
| `pending_commits.jsonl` | Append-only log of attribution entries since the last commit. Cleared after each `commit.sh` run. Never committed. |

