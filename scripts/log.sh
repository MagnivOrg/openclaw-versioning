#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "⚠️ Versioning not initialized"
  echo "Run \`/openclaw-versioning setup\` to get started."
  exit 1
fi

DETAIL=false
COUNT=5

for arg in "$@"; do
  case "$arg" in
    --detail) DETAIL=true ;;
    [0-9]*) COUNT="$arg" ;;
  esac
done

[ "${COUNT:-0}" -le 0 ] && COUNT=5

OUTPUT="📜 **Version History** (last $COUNT)\n\n"

if [ "$DETAIL" = true ]; then
  while IFS= read -r hash; do
    date=$(git log --format="%ad" --date=format:"%b %d, %H:%M" -1 "$hash")
    subject=$(git log --format="%s" -1 "$hash")
    body=$(git log --format="%b" -1 "$hash")
    triggered=$(echo "$body" | grep "^Triggered by:" | sed 's/Triggered by: //' || true)
    turns=$(echo "$body" | grep "^Turns:" | sed 's/Turns: //' || true)
    changelog=$(echo "$body" | awk '/^--- Change log ---/{found=1; next} found{print}' || true)

    OUTPUT="${OUTPUT}\`$hash\` · $date\n"
    OUTPUT="${OUTPUT}**$subject**\n"
    if [ -n "$triggered" ]; then
      DETAIL_LINE="_by $triggered"
      [ -n "$turns" ] && DETAIL_LINE="${DETAIL_LINE} · $turns turns"
      OUTPUT="${OUTPUT}${DETAIL_LINE}_\n"
    fi
    if [ -n "$changelog" ]; then
      OUTPUT="${OUTPUT}\`\`\`\n${changelog}\n\`\`\`\n"
    fi
    OUTPUT="${OUTPUT}\n"
  done < <(git log --format="%h" -n "$COUNT")
else
  while IFS= read -r hash; do
    date=$(git log --format="%ad" --date=format:"%b %d, %H:%M" -1 "$hash")
    subject=$(git log --format="%s" -1 "$hash")
    triggered=$(git log --format="%b" -1 "$hash" | grep "^Triggered by:" | sed 's/Triggered by: //' | tr -d '\n' || true)
    if [ -n "$triggered" ]; then
      OUTPUT="${OUTPUT}• \`$hash\` $date\n  $subject _($triggered)_\n"
    else
      OUTPUT="${OUTPUT}• \`$hash\` $date\n  $subject\n"
    fi
  done < <(git log --format="%h" -n "$COUNT")
fi

printf '%b' "$OUTPUT"
