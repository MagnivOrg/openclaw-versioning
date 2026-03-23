#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Versioning: NOT INITIALIZED"
  echo "Run: bash {baseDir}/setup.sh"
  exit 0
fi

echo "=== Agent Versioning Status ==="
echo ""

echo "Latest snapshot:"
git log --oneline --format="  %h  %ai  %an  %s" -1 2>/dev/null || echo "  (no snapshots yet)"
echo ""

TOTAL=$(git rev-list --count HEAD 2>/dev/null || echo "0")
echo "Total snapshots: $TOTAL"
echo ""

CHANGES=$(git diff HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
  echo "Uncommitted changes ($CHANGES files):"
  git diff HEAD --name-only 2>/dev/null | sed 's/^/  /'
else
  echo "No uncommitted changes."
fi
echo ""

echo "Tracked files:"
git ls-files | sed 's/^/  /'
