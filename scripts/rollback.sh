#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: rollback.sh <commit-hash>"
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

git checkout "$TARGET" -- . 2>/dev/null

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Rollback to $TARGET_SHORT ($TARGET_MSG)"
  NEW_SHORT=$(git rev-parse --short HEAD)
  echo "Rolled back from $CURRENT_SHORT to $TARGET_SHORT. New snapshot: $NEW_SHORT"
else
  echo "No differences — already at $TARGET_SHORT."
fi
