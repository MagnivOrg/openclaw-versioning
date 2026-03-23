#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

COUNT="${1:-20}"

echo '```'
for hash in $(git log --format="%h" -n "$COUNT"); do
  date=$(git log --format="%ai" -1 "$hash")
  subject=$(git log --format="%s" -1 "$hash")
  triggered=$(git log --format="%b" -1 "$hash" | grep "^Triggered by:" | sed 's/Triggered by: //' | tr -d '\n' || true)

  if [ -n "$triggered" ]; then
    printf "%s  %s  %s  [%s]\n" "$hash" "$date" "$subject" "$triggered"
  else
    printf "%s  %s  %s\n" "$hash" "$date" "$subject"
  fi
done
echo '```'
