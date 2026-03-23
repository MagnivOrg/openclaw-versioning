#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

MESSAGE="${1:-}"

TRACKED=(
  "AGENTS.md" "SOUL.md" "IDENTITY.md" "USER.md" "TOOLS.md"
  "HEARTBEAT.md" "BOOT.md" "BOOTSTRAP.md" "MEMORY.md"
  ".gitignore" "skills/" "hooks/"
)

# Merge in any custom tracked list from .openclaw-versioning.json
if [ -f "$WORKSPACE/.openclaw-versioning.json" ] && command -v jq &>/dev/null; then
  CUSTOM=$(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)
  if [ -n "$CUSTOM" ]; then
    while IFS= read -r item; do
      TRACKED+=("$item")
    done <<< "$CUSTOM"
  fi
fi

for f in "${TRACKED[@]}"; do
  git add "$f" 2>/dev/null || true
done

if git diff --cached --quiet; then
  echo "No changes to snapshot."
  exit 0
fi

if [ -z "$MESSAGE" ]; then
  CHANGED_FILES=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/,$//')
  MESSAGE="Snapshot: $CHANGED_FILES"
fi

git commit -m "$MESSAGE"
SHORT_HASH=$(git rev-parse --short HEAD)
echo "Snapshot $SHORT_HASH: $MESSAGE"
