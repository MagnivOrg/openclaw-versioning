#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "⚠️ Versioning not initialized"
  echo "Run \`/openclaw-versioning setup\` to get started."
  exit 0
fi

HASH=$(git log --format="%h" -1 2>/dev/null || true)

if [ -z "$HASH" ]; then
  echo "📸 No commits yet"
else
  DATE=$(git log --format="%ad" --date=format:"%b %d, %H:%M" -1)
  SUBJECT=$(git log --format="%s" -1)
  BODY=$(git log --format="%b" -1)

  # Parse commit type from subject prefix
  if echo "$SUBJECT" | grep -qi "^auto-commit"; then
    TYPE="Auto"
    FILES=$(echo "$SUBJECT" | sed 's/^[Aa]uto-commit[^:]*: //')
  elif echo "$SUBJECT" | grep -qi "^manual commit"; then
    TYPE="Manual"
    FILES=$(echo "$SUBJECT" | sed 's/^[Mm]anual commit[^:]*: //')
  elif echo "$SUBJECT" | grep -qi "^snapshot"; then
    TYPE="Snapshot"
    FILES=$(echo "$SUBJECT" | sed 's/^[Ss]napshot[^:]*: //')
  elif echo "$SUBJECT" | grep -qi "^rollback"; then
    TYPE="Rollback"
    FILES=""
  else
    TYPE=""
    FILES="$SUBJECT"
  fi

  # Parse identity from commit body
  IDENTITY=$(echo "$BODY" | grep "^Triggered by:" | sed 's/Triggered by: //' | tr -d '\n' | sed 's/cli/CLI/g' || true)

  # Build output line
  echo "📸 \`$HASH\` · $DATE"

  META_PARTS=()
  [ -n "$TYPE" ] && META_PARTS+=("$TYPE")
  [ -n "$IDENTITY" ] && META_PARTS+=("by $IDENTITY")
  [ -n "$FILES" ] && META_PARTS+=("$FILES")
  if [ ${#META_PARTS[@]} -gt 0 ]; then
    IFS=' · ' eval 'META="${META_PARTS[*]}"'
    echo "_${META}_"
  fi
fi

echo ""

CHANGES=$(git diff HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
  LABEL=$([ "$CHANGES" -eq 1 ] && echo "file" || echo "files")
  echo "✏️ **$CHANGES uncommitted $LABEL:**"
  git diff HEAD --name-only 2>/dev/null | while IFS= read -r file; do
    added=$(git diff HEAD -- "$file" 2>/dev/null | grep -c '^+[^+]' || true)
    removed=$(git diff HEAD -- "$file" 2>/dev/null | grep -c '^-[^-]' || true)
    echo "• \`$file\` +$added/-$removed"
  done
else
  echo "✓ No uncommitted changes"
fi
