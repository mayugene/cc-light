#!/bin/bash
# cc-light-hook.sh — Claude Code hook to update traffic light state
# Usage: cc-light-hook.sh <state>
# States: busy, waiting, idle
#
# Reads Claude Code's hook input (JSON on stdin) and writes a per-session
# state file to /tmp/cc-light/<session_id>.json containing the state, the
# session id, the working directory, and the transcript path. The Swift
# menu bar app reads these files to drive the traffic light.

set -e
STATE_DIR="/tmp/cc-light"
STATE="${1:-idle}"
mkdir -p "$STATE_DIR"

# Capture stdin (Claude Code hook input JSON) so we can pass it to python
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

python3 - "$STATE" "$STATE_DIR" "$INPUT" <<'PYEOF'
import json, os, sys, time

state_arg  = sys.argv[1]
state_dir  = sys.argv[2]
hook_json  = sys.argv[3] or ""

try:
    hook_input = json.loads(hook_json) if hook_json.strip() else {}
except Exception:
    hook_input = {}

session_id     = hook_input.get("session_id") or ""
cwd            = hook_input.get("cwd") or ""
transcript     = hook_input.get("transcript_path") or ""

key = session_id or "_default"
path = os.path.join(state_dir, key + ".json")

# SessionEnd and similar cleanup states: delete the per-session file
# entirely. The Swift app's stale filter exempts waiting states, so
# without this they'd linger forever after a clean exit.
if state_arg == "ended":
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    sys.exit(0)

state = {
    "state":           state_arg,
    "session_id":      session_id,
    "cwd":             cwd,
    "transcript_path": transcript,
    "ts":              int(time.time()),
}

with open(path, "w") as f:
    json.dump(state, f)
PYEOF
