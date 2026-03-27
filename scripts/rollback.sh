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

# Restore only tracked files
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
  echo "**Rolled back** \`$CURRENT_SHORT\` → \`$TARGET_SHORT\` — new snapshot \`$NEW_SHORT\`"
  echo "> $TARGET_MSG"
else
  echo "_No differences — workspace is already at \`$TARGET_SHORT\`._"
  exit 0
fi

# Push if remote is configured
GIT_REMOTE=$(jq -r '.git.remote // ""' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)
GIT_BRANCH=$(jq -r '.git.branch // "main"' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null || true)

if [ -n "$GIT_REMOTE" ]; then
  if git push "$GIT_REMOTE" "$GIT_BRANCH" 2>/dev/null; then
    echo "_Pushed to \`$GIT_REMOTE\` ($GIT_BRANCH)_"
  else
    echo "> ⚠️ Push to \`$GIT_REMOTE\` failed — check your git auth and remote config."
  fi
fi
