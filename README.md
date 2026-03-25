# openclaw-versioning

A versioning skill for [OpenClaw](https://openclaw.dev) agents. Between turns, tracked workspace files are diffed and staged with sender attribution. A cron job batches those staged changes into a git commit every 10 minutes. Gives you a full audit trail of who changed what and when, with rollback and diff tools accessible directly from chat.

---

## How it works

Two hooks handle everything automatically:

1. **`openclaw-versioning-capture`** fires on `message:received` — writes sender identity (name, ID, channel) to `.version-context` in the workspace.

2. **`openclaw-versioning-commit`** fires on `message:sent` — diffs tracked files against HEAD, appends an attribution entry to `pending_commits.jsonl`, and stages any changes.

A cron job fires every 10 minutes and runs `commit.sh`, which reads the pending log, builds a commit message with full attribution and a per-turn changelog, commits, and clears the log.

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

**1.** Run setup:
```bash
bash setup.sh
```
Copies hooks into the workspace, initializes the git repo, writes `.openclaw-versioning.json`, and takes a first snapshot. setup.sh will prompt you to optionally connect a GitHub remote.

**2.** Restart your openclaw gateway to load the hooks.

**3.** Say `/openclaw-versioning setup` to register the auto-commit cron.

**4.** Verify:
```
/openclaw-versioning status
```

**5. (Optional) Push commits to a remote**

```bash
gh auth login          # if using GitHub via gh CLI
# or: set up an SSH key, or use an HTTPS token in the remote URL
```

```bash
cd $OPENCLAW_WORKSPACE
git remote add origin <url>
```

Then add to `.openclaw-versioning.json`:
```json
{ "git": { "remote": "origin", "branch": "main" } }
```

`remote` is the git remote name. If absent, commits stay local — no push, no error.

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

The skill calls `git push` directly — set up your remote and auth (SSH key, `gh auth login`, or HTTPS token) before enabling this. No auth handling is done by the skill itself.

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
| `.version-context` | Temporary file written by the capture hook, read by the commit hook, then deleted. Never committed. |
| `pending_commits.jsonl` | Append-only log of attribution entries since the last commit. Cleared after each `commit.sh` run. Never committed. |

