#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

TARGET="${1:-}"
REASON="${2:-}"

if [ -z "$TARGET" ]; then
  echo "Usage: rollback.sh <commit-hash> [reason]"
  echo ""
  echo "Recent snapshots:"
  git log --format="  %h  %ai  %s" -10
  exit 1
fi

if ! git cat-file -e "$TARGET" 2>/dev/null; then
  echo "Error: Commit $TARGET not found."
  exit 1
fi

CURRENT_SHORT=$(git rev-parse --short HEAD)
TARGET_SHORT=$(git rev-parse --short "$TARGET")
TARGET_MSG=$(git log --format="%s" -1 "$TARGET")

# Restore only tracked files — consistent with commit.sh and snapshot.sh
while IFS= read -r f; do
  git checkout "$TARGET" -- "$f" 2>/dev/null || true
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

# Stage the same tracked files
while IFS= read -r f; do
  git add "$f" 2>/dev/null || true
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

if ! git diff --cached --quiet; then
  if [ -n "$REASON" ]; then
    COMMIT_MSG="Rollback to $TARGET_SHORT ($TARGET_MSG): $REASON"
  else
    COMMIT_MSG="Rollback to $TARGET_SHORT ($TARGET_MSG)"
  fi
  git commit -m "$COMMIT_MSG"
  NEW_SHORT=$(git rev-parse --short HEAD)
  echo "Rolled back from $CURRENT_SHORT to $TARGET_SHORT. New snapshot: $NEW_SHORT"
else
  echo "No differences — already at $TARGET_SHORT."
fi
