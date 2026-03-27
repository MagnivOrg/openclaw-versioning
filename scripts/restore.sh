#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "**Error:** Versioning not initialized. Run \`/openclaw-versioning setup\`."
  exit 1
fi

FILE="${1:-}"
COMMIT="${2:-}"
REASON="${3:-}"

if [ -z "$FILE" ] || [ -z "$COMMIT" ]; then
  echo "**Usage:** \`/openclaw-versioning restore <file> <commit> [reason]\`"
  echo ""
  echo "Restores a single file to its state before the given commit."
  echo "To find the right commit, run \`/openclaw-versioning log\`."
  exit 1
fi

if ! git cat-file -e "$COMMIT" 2>/dev/null; then
  echo "**Error:** Commit \`$COMMIT\` not found."
  exit 1
fi

if ! git show "$COMMIT" -- "$FILE" | grep -q "." 2>/dev/null; then
  echo "**Error:** \`$FILE\` was not changed in commit \`$COMMIT\`."
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
ENTRY=$(printf '{"ts":%s,"user":"%s","userId":"%s","channel":"%s","action":"restore","file":"%s","from":"%s","reason":"%s","files":[]}' "$(date +%s000)" "$USER" "$USER" "$CHANNEL" "$FILE" "$TARGET_SHORT" "$REASON")
printf '%s\n' "$ENTRY" >> "$WORKSPACE/pending_commits.jsonl"

echo "**Staged restore** — \`$FILE\` to before \`$TARGET_SHORT\`"
echo "_Triggered by: $USER — commit when ready with \`/openclaw-versioning commit\`_"
