#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
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

# ─── Build output ─────────────────────────────────────────────────────
OUTPUT=""
if [ "$DETAIL" = true ]; then
  OUTPUT=$(git log --format="commit %h  %ai  [%s]%n%b%n" -n "$COUNT")
else
  while IFS= read -r hash; do
    date=$(git log --format="%ai" -1 "$hash")
    subject=$(git log --format="%s" -1 "$hash")
    triggered=$(git log --format="%b" -1 "$hash" | grep "^Triggered by:" | sed 's/Triggered by: //' | tr -d '\n' || true)
    if [ -n "$triggered" ]; then
      OUTPUT="${OUTPUT}${hash}  ${date}  ${subject}  [${triggered}]\n"
    else
      OUTPUT="${OUTPUT}${hash}  ${date}  ${subject}\n"
    fi
  done < <(git log --format="%h" -n "$COUNT")
fi

# ─── Post directly to channel if context available, else stdout ───────
CTX="$WORKSPACE/.version-context"
CHANNEL_TYPE=""
CHANNEL_TARGET=""

if [ -f "$CTX" ] && command -v jq &>/dev/null; then
  CHANNEL_TYPE=$(jq -r '.channelType // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
  CHANNEL_TARGET=$(jq -r '.channel // "unknown"' "$CTX" 2>/dev/null || echo "unknown")
fi

if [ "$CHANNEL_TYPE" != "unknown" ] && [ "$CHANNEL_TARGET" != "unknown" ] && command -v openclaw &>/dev/null; then
  openclaw message send \
    --channel "$CHANNEL_TYPE" \
    --target "$CHANNEL_TARGET" \
    --message "$(printf '%b' "$OUTPUT")" 2>/dev/null && exit 0
fi

# Fallback: print to stdout for agent to relay
printf '%b' "$OUTPUT"
