#!/bin/bash
# Usage: reset-session.sh <session-name>
# Deletes a gif session from the openclaw session store so each tape run starts clean.
SESSION_KEY="agent:main:$1"
SESSIONS_FILE="$HOME/.openclaw/agents/main/sessions/sessions.json"
jq "del(.\"$SESSION_KEY\")" "$SESSIONS_FILE" > /tmp/sessions_clean.json \
  && mv /tmp/sessions_clean.json "$SESSIONS_FILE"
