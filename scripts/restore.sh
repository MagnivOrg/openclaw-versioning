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

CURRENT_SHORT=$(git rev-parse --short HEAD)
TARGET_SHORT=$(git rev-parse --short "$COMMIT")

# Restore file to its state before the target commit
git checkout "${COMMIT}^" -- "$FILE"
git add "$FILE"
git commit -m "Restore $FILE to before $TARGET_SHORT

Reverted: $FILE
From commit: $TARGET_SHORT
Previous HEAD: $CURRENT_SHORT
Triggered by: restore"

NEW_SHORT=$(git rev-parse --short HEAD)
echo "Restored $FILE to its state before $TARGET_SHORT. New commit: $NEW_SHORT"
