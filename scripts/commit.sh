#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

MANUAL=false
[ "${1:-}" = "--manual" ] && MANUAL=true

PENDING="$WORKSPACE/pending_commits.jsonl"

# ─── Resolve tracked files ────────────────────────────────────────────
TRACKED=()
while IFS= read -r item; do
  TRACKED+=("$item")
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

# ─── Stage any unstaged changes to tracked files ─────────────────────
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
STAGED_FILES=$(git diff --cached --name-only | tr '\n' ' ' | sed 's/ $//')
USERS=""
COUNT=0
HAS_PENDING=false
CHANGELOG=""

if [ -f "$PENDING" ] && [ -s "$PENDING" ]; then
  HAS_PENDING=true
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    COUNT=$((COUNT + 1))

    if command -v jq &>/dev/null; then
      user=$(echo "$line" | jq -r '.user // "unknown"' 2>/dev/null || echo "unknown")
      ts=$(echo "$line" | jq -r '.ts // 0' 2>/dev/null || echo "0")
      channel=$(echo "$line" | jq -r '.channel // "unknown"' 2>/dev/null || echo "unknown")
      files=$(echo "$line" | jq -r '(.files // []) | join(", ")' 2>/dev/null || echo "")
    else
      user=$(echo "$line" | grep -o '"user":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
      ts="0"; channel="unknown"; files=""
    fi

    # Format timestamp as readable date
    if [ "$ts" != "0" ] && command -v date &>/dev/null; then
      ts_sec=$((ts / 1000))
      readable=$(date -r "$ts_sec" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts")
    else
      readable="$ts"
    fi

    # Accumulate unique users
    if [ -n "$user" ] && [ "$user" != "unknown" ]; then
      if [ -z "$USERS" ]; then
        USERS="$user"
      elif ! echo "$USERS" | grep -qF "$user"; then
        USERS="$USERS, $user"
      fi
    fi

    # Build per-turn changelog line
    CHANGELOG="${CHANGELOG}  [$readable] $user ($channel): $files\n"
  done < "$PENDING"
fi

# ─── Determine prefix ─────────────────────────────────────────────────
if [ "$MANUAL" = true ]; then
  PREFIX="Manual commit"
elif [ "$HAS_PENDING" = false ] || [ "$COUNT" -eq 0 ]; then
  PREFIX="Auto-commit (cli)"
  USERS="cli"
else
  PREFIX="Auto-commit"
fi

if [ -z "$USERS" ]; then USERS="unknown"; fi

# ─── Assemble full message ────────────────────────────────────────────
if [ -n "$CHANGELOG" ]; then
  MSG="${PREFIX}: $STAGED_FILES

Triggered by: ${USERS}
Turns: ${COUNT}

--- Change log ---
$(printf "%b" "$CHANGELOG")"
else
  MSG="${PREFIX}: $STAGED_FILES

Triggered by: ${USERS}
Turns: ${COUNT}"
fi

git commit -m "$MSG"
SHORT_HASH=$(git rev-parse --short HEAD)

[ -f "$PENDING" ] && > "$PENDING"

echo "Committed $SHORT_HASH — $PREFIX by: $USERS ($STAGED_FILES)"

# ─── Push to remote if configured ────────────────────────────────────
CFG="$WORKSPACE/.openclaw-versioning.json"
GIT_REMOTE=""
GIT_BRANCH="main"
if [ -f "$CFG" ] && command -v jq &>/dev/null; then
  GIT_REMOTE=$(jq -r '.git.remote // ""' "$CFG" 2>/dev/null || true)
  GIT_BRANCH=$(jq -r '.git.branch // "main"' "$CFG" 2>/dev/null || true)
fi

if [ -n "$GIT_REMOTE" ]; then
  PUSH_ERR=$(git push origin "$GIT_BRANCH" 2>&1)
  if [ $? -eq 0 ]; then
    echo "Pushed to $GIT_REMOTE ($GIT_BRANCH)"
  else
    if echo "$PUSH_ERR" | grep -qiE "permission denied|authentication failed|repository not found|invalid username|could not read username"; then
      echo "Warning: push failed — auth error. Run \`gh auth login\` or check your SSH key."
    elif echo "$PUSH_ERR" | grep -qiE "could not resolve|connection timed out|network|unreachable|failed to connect"; then
      echo "Warning: push failed — connection error. Will retry on next commit."
    else
      echo "Warning: push failed — $PUSH_ERR"
    fi
  fi
fi
