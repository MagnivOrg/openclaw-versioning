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
2. In your terminal, restart the gateway so the skill is picked up:

```bash
openclaw gateway restart
```

3. In chat, run:

```text
/openclaw-versioning setup
```

4. Restart the gateway again to activate the installed hooks:

```bash
openclaw gateway restart
```

5. Verify:

```text
/openclaw-versioning status
```

## Everyday commands

Use these from any connected channel or CLI session.

| Command                                        | What it is for                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| `/openclaw-versioning status`                  | Check latest commit and pending changes                                   |
| `/openclaw-versioning log [count] [--detail]`  | Browse recent commit history                                              |
| `/openclaw-versioning diff`                    | Show tracked file changes not yet committed                               |
| `/openclaw-versioning diff <commit>`           | Show exactly what was added/removed in a specific commit                  |
| `/openclaw-versioning diff <from> <to>`        | Show what changed between two commits                                     |
| `/openclaw-versioning rollback <commit> [reason]` | Restore all tracked files to a previous state, staged for next commit  |
| `/openclaw-versioning restore <file> <commit> [reason]` | Restore one file from before a specific commit, staged for next commit |
| `/openclaw-versioning commit [message]`           | Flush pending staged changes as a manual commit, with optional label   |

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

If you want to back up your workspace to GitHub:

1. Create a new repository on GitHub.

2. Add the remote from your workspace:

```bash
gh auth login  # if not already authenticated
gh auth setup-git # if not already linked
cd ~/.openclaw/workspace  # or your custom workspace path
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

3. Set `git.remote` and `git.branch` in `.openclaw-versioning.json`.

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
