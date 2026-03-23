#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Versioning: NOT INITIALIZED"
  echo "Run: bash {baseDir}/setup.sh"
  exit 0
fi

echo "=== OpenClaw Versioning Status ==="
echo ""

echo "Latest snapshot:"
git log --format="  %h  %ai  %an  %s" -1 2>/dev/null || echo "  (no snapshots yet)"
echo ""

CHANGES=$(git diff HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
  echo "Uncommitted changes ($CHANGES files):"
  git diff HEAD --name-only 2>/dev/null | while IFS= read -r file; do
    # Show file name and a one-line summary of what changed
    added=$(git diff HEAD -- "$file" 2>/dev/null | grep -c '^+[^+]' || true)
    removed=$(git diff HEAD -- "$file" 2>/dev/null | grep -c '^-[^-]' || true)
    printf "  %-45s +%s -%s\n" "$file" "$added" "$removed"
  done
else
  echo "No uncommitted changes."
fi
echo ""

echo "Tracked files:"
git ls-files | sed 's/^/  /'
