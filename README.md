# openclaw-versioning

A versioning skill for [OpenClaw](https://openclaw.dev) that keeps a clear history of workspace changes with sender attribution.

Use it to answer questions like:

- Who changed this file?
- What changed between two points in time?
- Can I roll back to a known good state?

## What you get

- Automatic capture of tracked file changes between turns
- Batched git commits every 10 minutes with per-sender attribution
- Chat/CLI commands for status, log, diff, rollback, and restore
- Optional push to your remote after each batched commit

## Quick start

Requirements: `git`, `jq`, Node.js

1. Add this repo to your workspace `skills/` directory.
2. In chat, run:

```text
/openclaw-versioning setup
```

3. Verify:

```text
/openclaw-versioning status
```

If `status` works, you're done.

## Everyday commands

Use these from any connected channel or CLI session.

| Command                                        | What it is for                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| `/openclaw-versioning status`                  | Check latest commit, pending changes, and tracked files                   |
| `/openclaw-versioning log [count] [--detail]`  | Browse recent commit history                                              |
| `/openclaw-versioning diff`                    | See uncommitted changes                                                   |
| `/openclaw-versioning diff <commit>`           | See what changed in one commit                                            |
| `/openclaw-versioning diff <from> <to>`        | Compare two commits                                                       |
| `/openclaw-versioning rollback <commit>`       | Restore all tracked files to a previous state (records a rollback commit) |
| `/openclaw-versioning restore <file> <commit>` | Restore one file from before a specific commit                            |
| `/openclaw-versioning snapshot [message]`      | Create a manual checkpoint commit                                         |

## Configuration

After setup, edit `.openclaw-versioning.json` in your workspace to change what files are tracked.

Default tracked files and folders:

```json
{
  "tracked": [
    "AGENTS.md",
    "SOUL.md",
    "IDENTITY.md",
    "USER.md",
    "TOOLS.md",
    "HEARTBEAT.md",
    "BOOT.md",
    "BOOTSTRAP.md",
    "MEMORY.md",
    ".gitignore",
    ".openclaw-versioning.json",
    "skills/",
    "hooks/"
  ]
}
```

If `git.remote` is not set, commits stay local.

## Optional remote setup

```bash
gh auth login
cd $OPENCLAW_WORKSPACE
git remote add origin <url>
```

Then set `git.remote` and `git.branch` in `.openclaw-versioning.json`.

Example:

```json
{ "git": { "remote": "origin", "branch": "main" } }
```

## In one minute: how it behaves

- On `message:received`, sender details are captured.
- On `message:sent`, tracked file changes are staged and queued with attribution.
- Every 10 minutes, queued entries are committed together with grouped attribution.

This gives you low-noise, attributable history without manual git bookkeeping every turn.

## Workspace files

| File                        | Purpose                                                                       |
| --------------------------- | ----------------------------------------------------------------------------- |
| `.openclaw-versioning.json` | Your tracked-files and git push configuration                                 |
| `.version-context`          | Temporary sender handoff between hooks (not committed)                        |
| `pending_commits.jsonl`     | Pending attribution entries waiting for the next batch commit (not committed) |
