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
  echo "_No changes to commit._"
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
CTX="$WORKSPACE/.version-context"

if [ "$MANUAL" = true ]; then
  PREFIX="Manual commit"
  # For manual commits, prefer identity from version-context (set by capture hook)
  if [ -z "$USERS" ] || [ "$USERS" = "unknown" ]; then
    if [ -f "$CTX" ] && command -v jq &>/dev/null; then
      CTX_USER=$(jq -r '.user // ""' "$CTX" 2>/dev/null || true)
      [ -n "$CTX_USER" ] && [ "$CTX_USER" != "unknown" ] && USERS="$CTX_USER"
    fi
  fi
  if [ -z "$USERS" ] || [ "$USERS" = "unknown" ]; then USERS="skill invocation"; fi
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

echo "**Committed** \`$SHORT_HASH\` — $PREFIX by _${USERS}_"
echo "> $STAGED_FILES"

# ─── Push if remote is configured ────────────────────────────────────
GIT_REMOTE=$(jq -r '.git.remote // ""' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)
GIT_BRANCH=$(jq -r '.git.branch // "main"' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)

if [ -n "$GIT_REMOTE" ]; then
  if git push "$GIT_REMOTE" "$GIT_BRANCH" 2>/dev/null; then
    echo "_Pushed to \`$GIT_REMOTE\` ($GIT_BRANCH)_"
  else
    echo "> ⚠️ Push to \`$GIT_REMOTE\` failed — check your git auth and remote config."
  fi
fi
