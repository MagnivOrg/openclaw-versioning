#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "**Error:** Versioning not initialized. Run \`/openclaw-versioning setup\`."
  exit 1
fi

TARGET="${1:-}"
REASON="${2:-}"

if [ -z "$TARGET" ]; then
  echo "**Usage:** \`/openclaw-versioning rollback <commit> [reason]\`"
  echo ""
  echo "**Recent snapshots:**"
  while IFS= read -r hash; do
    date=$(git log --format="%ad" --date=format:"%b %d, %H:%M" -1 "$hash")
    subject=$(git log --format="%s" -1 "$hash")
    echo "- \`$hash\` · $date · $subject"
  done < <(git log --format="%h" -10)
  exit 1
fi

if ! git cat-file -e "$TARGET" 2>/dev/null; then
  echo "**Error:** Commit \`$TARGET\` not found."
  exit 1
fi

CURRENT_SHORT=$(git rev-parse --short HEAD)
TARGET_SHORT=$(git rev-parse --short "$TARGET")
TARGET_MSG=$(git log --format="%s" -1 "$TARGET")

# Read identity from version context
CTX="$WORKSPACE/.version-context"
ACTOR="unknown"
CHANNEL="unknown"
if [ -f "$CTX" ] && command -v jq &>/dev/null; then
  ACTOR=$(jq -r '.user // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
  CHANNEL=$(jq -r '.channel // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
fi
[ "$ACTOR" = "unknown" ] && ACTOR="skill invocation"

# Restore only tracked files
while IFS= read -r f; do
  git checkout "$TARGET" -- "$f" 2>/dev/null || true
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

# Stage the same tracked files
while IFS= read -r f; do
  git add "$f" 2>/dev/null || true
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

if ! git diff --cached --quiet; then
  LABEL="rollback to $TARGET_SHORT"
  [ -n "$REASON" ] && LABEL="$LABEL: $REASON"
  ENTRY=$(printf '{"ts":%s,"user":"%s","userId":"%s","channel":"%s","files":["%s"]}' \
    "$(date +%s000)" "$ACTOR" "$ACTOR" "$CHANNEL" "$LABEL")
  printf '%s\n' "$ENTRY" >> "$WORKSPACE/pending_commits.jsonl"

  echo "**Staged rollback** \`$CURRENT_SHORT\` → \`$TARGET_SHORT\`"
  echo "> $TARGET_MSG"
  echo "_Triggered by: $ACTOR — commit when ready with \`/openclaw-versioning commit\`_"
else
  echo "_No differences — workspace is already at \`$TARGET_SHORT\`._"
  exit 0
fi
