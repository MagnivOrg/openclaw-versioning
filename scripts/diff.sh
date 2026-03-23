#!/bin/bash
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE"

if [ ! -d .git ]; then
  echo "Error: Versioning not initialized. Run: bash {baseDir}/setup.sh"
  exit 1
fi

if [ $# -eq 0 ]; then
  git diff HEAD 2>/dev/null || git diff
elif [ $# -eq 1 ]; then
  git show "$1" --stat --patch
elif [ $# -eq 2 ]; then
  git diff "$1" "$2"
fi
