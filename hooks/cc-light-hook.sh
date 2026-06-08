#!/bin/bash
# cc-light-hook.sh — Claude Code hook to update traffic light state
# Usage: cc-light-hook.sh <state>
# States: busy, waiting, idle

STATE_DIR="/tmp/cc-light"
STATE="${1:-idle}"

mkdir -p "$STATE_DIR"

# Read session_id from stdin if available
SESSION_ID=""
if [ -t 0 ]; then
  : # no stdin
else
  INPUT=$(cat)
  SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

# Write per-session state file
if [ -n "$SESSION_ID" ]; then
  cat > "$STATE_DIR/${SESSION_ID}.json" <<EOF
{"state":"${STATE}","session_id":"${SESSION_ID}","ts":$(date +%s)}
EOF
else
  # Fallback: write to default if no session_id
  cat > "$STATE_DIR/_default.json" <<EOF
{"state":"${STATE}","session_id":"","ts":$(date +%s)}
EOF
fi
