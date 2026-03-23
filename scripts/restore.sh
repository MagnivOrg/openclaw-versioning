#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

FILE="${1:-}"
COMMIT="${2:-}"

if [ -z "$FILE" ] || [ -z "$COMMIT" ]; then
  echo "Usage: restore.sh <file> <commit>"
  echo ""
  echo "Restores a single file to its state before the given commit."
  echo "Example: restore.sh AGENTS.md a1b2c3d"
  echo ""
  echo "To find the right commit, run: /openclaw-versioning log"
  exit 1
fi

if ! git cat-file -e "$COMMIT" 2>/dev/null; then
  echo "Error: Commit $COMMIT not found."
  exit 1
fi

if ! git show "$COMMIT" -- "$FILE" | grep -q "." 2>/dev/null; then
  echo "Error: $FILE was not changed in commit $COMMIT."
  exit 1
fi

TARGET_SHORT=$(git rev-parse --short "$COMMIT")

# Read sender identity from capture hook context
USER="unknown"
CHANNEL="unknown"
CTX="$WORKSPACE/.version-context"
if [ -f "$CTX" ] && command -v jq &>/dev/null; then
  USER=$(jq -r '.user // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
  CHANNEL=$(jq -r '.channel // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
fi

# Restore file to its state before the target commit and stage it
git checkout "${COMMIT}^" -- "$FILE"
git add "$FILE"

# Log to pending so the next commit includes restore attribution
ENTRY=$(printf '{"ts":%s,"user":"%s","userId":"%s","channel":"%s","files":["restore: %s"]}' "$(date +%s000)" "$USER" "$USER" "$CHANNEL" "$FILE")
printf '%s\n' "$ENTRY" >> "$WORKSPACE/pending_commits.jsonl"

echo "Staged restore of $FILE to before $TARGET_SHORT (triggered by: $USER) — commit when ready with /openclaw-versioning commit"
