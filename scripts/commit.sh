#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

PENDING="$WORKSPACE/pending_commits.jsonl"

# ─── Resolve tracked files ────────────────────────────────────────────
CFG="$WORKSPACE/.openclaw-versioning.json"
TRACKED=()
if [ -f "$CFG" ] && command -v jq &>/dev/null; then
  while IFS= read -r item; do
    TRACKED+=("$item")
  done < <(jq -r '.tracked[]?' "$CFG" 2>/dev/null)
fi
if [ ${#TRACKED[@]} -eq 0 ]; then
  TRACKED=(
    "AGENTS.md" "SOUL.md" "IDENTITY.md" "USER.md" "TOOLS.md"
    "HEARTBEAT.md" "BOOT.md" "BOOTSTRAP.md" "MEMORY.md"
    ".gitignore" "skills/" "hooks/"
  )
fi

# ─── Stage any unstaged changes to tracked files ─────────────────────
# This catches CLI-initiated changes that bypassed the message hooks
for f in "${TRACKED[@]}"; do
  git add "$f" 2>/dev/null || true
done

# ─── Nothing staged at all → nothing to do ───────────────────────────
if git diff --cached --quiet 2>/dev/null; then
  [ -f "$PENDING" ] && > "$PENDING"
  echo "No changes to commit."
  exit 0
fi

# ─── Build commit message ─────────────────────────────────────────────
USERS=""
FILES=""
COUNT=0
HAS_PENDING=false

if [ -f "$PENDING" ] && [ -s "$PENDING" ]; then
  HAS_PENDING=true
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    COUNT=$((COUNT + 1))

    if command -v jq &>/dev/null; then
      user=$(echo "$line" | jq -r '.user // "unknown"' 2>/dev/null || echo "unknown")
      files=$(echo "$line" | jq -r '(.files // []) | join(", ")' 2>/dev/null || echo "")
    else
      user=$(echo "$line" | grep -o '"user":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
      files=""
    fi

    if [ -n "$user" ] && [ "$user" != "unknown" ]; then
      if [ -z "$USERS" ]; then
        USERS="$user"
      elif ! echo "$USERS" | grep -qF "$user"; then
        USERS="$USERS, $user"
      fi
    fi

    if [ -n "$files" ]; then
      FILES="${FILES:+$FILES, }$files"
    fi
  done < "$PENDING"
fi

# Always use the actual staged file list as the source of truth
STAGED_FILES=$(git diff --cached --name-only | tr '\n' ' ' | sed 's/ $//')

# If no pending log entries, changes came from the CLI
if [ "$HAS_PENDING" = false ] || [ "$COUNT" -eq 0 ]; then
  MSG="Auto-commit (cli): $STAGED_FILES

Triggered by: cli
Turns: 0"
else
  if [ -z "$USERS" ]; then USERS="unknown"; fi
  MSG="Auto-commit: $STAGED_FILES

Triggered by: ${USERS}
Turns: ${COUNT}"
fi

git commit -m "$MSG"
SHORT_HASH=$(git rev-parse --short HEAD)

[ -f "$PENDING" ] && > "$PENDING"

if [ "$HAS_PENDING" = false ] || [ "$COUNT" -eq 0 ]; then
  echo "Committed $SHORT_HASH — cli changes"
else
  echo "Committed $SHORT_HASH — $COUNT pending turn(s) by: $USERS"
fi
