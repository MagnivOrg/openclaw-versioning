#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

MESSAGE="${1:-}"

TRACKED=()
while IFS= read -r item; do
  TRACKED+=("$item")
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

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

# ─── Push if remote is configured ────────────────────────────────
GIT_REMOTE=$(jq -r '.git.remote // ""' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)
GIT_BRANCH=$(jq -r '.git.branch // "main"' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)

if [ -n "$GIT_REMOTE" ]; then
  if git push "$GIT_REMOTE" "$GIT_BRANCH" 2>/dev/null; then
    echo "Pushed to $GIT_REMOTE ($GIT_BRANCH)"
  else
    echo "Warning: push to $GIT_REMOTE failed — check your git auth and remote config"
  fi
fi
