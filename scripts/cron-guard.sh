#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

if [ ! -d "$WORKSPACE/.git" ]; then
  exit 0
fi

_trigger_commit() {
  local job_id
  job_id=$(openclaw cron list --json 2>/dev/null | jq -r '.jobs[] | select(.name == "agent-changelog-commit") | .id' | tail -1)
  [ -n "$job_id" ] && openclaw cron run "$job_id"
}

cd "$WORKSPACE"

# Cheapest check first: anything already staged?
if ! git diff --cached --quiet 2>/dev/null; then
  _trigger_commit
  exit 0
fi

# Load tracked paths from config (default to entire workspace)
TRACKED=()
if command -v jq &>/dev/null && [ -f "$WORKSPACE/.agent-changelog.json" ]; then
  while IFS= read -r item; do
    [ -n "$item" ] && TRACKED+=("$item")
  done < <(jq -r '.tracked[]?' "$WORKSPACE/.agent-changelog.json" 2>/dev/null || true)
fi
[ ${#TRACKED[@]} -eq 0 ] && TRACKED=(".")

# Any unstaged changes to tracked paths?
for f in "${TRACKED[@]}"; do
  if [ -n "$(git status --porcelain "$f" 2>/dev/null)" ]; then
    _trigger_commit
    exit 0
  fi
done

exit 0
