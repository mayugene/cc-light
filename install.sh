#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# EXEC_NAME is the SwiftPM target's binary name. Must match the `name:`
# of the executable target in Package.swift — swift build produces a
# binary with this exact name in the build directory.
EXEC_NAME="cc-light"
# BUNDLE_NAME is the user-facing name shown in Finder / Activity Monitor
# / Dock. The .app directory name, the renamed binary inside
# Contents/MacOS, and CFBundleName / CFBundleDisplayName all come from
# this. Using a space + capitalised form here is what makes the
# installed app look polished in macOS UI.
BUNDLE_NAME="CC Light"
INSTALL_DIR="$HOME/Applications"
HOOKS_DIR="$SCRIPT_DIR/hooks"
ICON_FILE="$SCRIPT_DIR/cc-light-app/Resources/cc-light.icns"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_DIR="/tmp/cc-light"

echo "🚦 Installing $BUNDLE_NAME..."

# 1. Build the Swift app
echo "  → Building menu bar app..."
cd "$SCRIPT_DIR/cc-light-app"
swift build -c release 2>&1 | tail -3
BUILD_PATH=$(swift build -c release --show-bin-path)/$EXEC_NAME

# 2. Create .app bundle
APP_BUNDLE="$INSTALL_DIR/$BUNDLE_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 2-pre. Migrate from a previous install at the old lowercase bundle
#     name. We kill the old binary and remove the old directory so it
#     doesn't keep showing up in Finder / Activity Monitor as a ghost.
#     The pkill pattern matches both the old bundle path and the new
#     one (which uses the renamed binary), since both contain the
#     word "cc-light".
OLD_APP_BUNDLE="$INSTALL_DIR/cc-light.app"
if [ -d "$OLD_APP_BUNDLE" ] && [ "$OLD_APP_BUNDLE" != "$APP_BUNDLE" ]; then
    pkill -f "cc-light" 2>/dev/null || true
    rm -rf "$OLD_APP_BUNDLE"
    echo "  → Removed old bundle $OLD_APP_BUNDLE"
fi

# Always nuke the existing MacOS/ contents — a previous install may
# have left a stale `cc-light` binary behind from before we renamed
# the in-bundle binary to $BUNDLE_NAME. Leaving it around means
# Activity Monitor still shows the old name and Spotlight indexes a
# ghost app.
rm -f "$APP_BUNDLE/Contents/MacOS/"*

# Copy the SwiftPM binary in as $BUNDLE_NAME (with space) so
# Activity Monitor shows the user-facing name, not the SwiftPM target
# name. CFBundleExecutable below points to it.
cp "$BUILD_PATH" "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME"

# 2a. Drop the app icon into the bundle (if we have one). It's optional
#     in the sense that the app runs fine without it, but it's expected
#     to be present in source — build it with cc-light-app/Resources/build-icon.sh.
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/cc-light.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.cc-light.app</string>
    <key>CFBundleName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>cc-light</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "  → Installed app to $APP_BUNDLE"

# 3. Initialize state directory.
#    Clear stale per-session files from previous installs so the menu
#    doesn't start with a graveyard of zombie sessions; the app's own
#    30s stale-threshold would filter them out of the icon, but the
#    files would still sit on disk. Active sessions will rewrite
#    their own files within seconds of the new app starting.
rm -f "$STATE_DIR"/*.json
mkdir -p "$STATE_DIR"
echo '{"state":"idle","session_id":"","cwd":"","transcript_path":"","ts":0}' \
  > "$STATE_DIR/_default.json"

# 4. Configure Claude Code hooks by deep-merging into settings.json.
#    Idempotent: re-running install.sh will not duplicate hooks.
HOOK_CMD="$HOOKS_DIR/cc-light-hook.sh"
echo "  → Configuring Claude Code hooks..."

mkdir -p "$(dirname "$SETTINGS_FILE")"
python3 - "$SETTINGS_FILE" "$HOOK_CMD" <<'PYEOF'
import json, os, shlex, sys

settings_path = sys.argv[1]
hook_path     = sys.argv[2]
hook_cmd      = shlex.quote(hook_path)  # shell-safe even if path has spaces

existing = {}
if os.path.exists(settings_path) and os.path.getsize(settings_path) > 0:
    try:
        with open(settings_path) as f:
            existing = json.load(f)
    except Exception as e:
        print(f"  ⚠️  Could not parse {settings_path}: {e}")
        print(f"     Backing it up to {settings_path}.bak and starting fresh.")
        os.rename(settings_path, settings_path + ".bak")
        existing = {}

hooks = existing.setdefault("hooks", {})

def strip_legacy(arr, bare):
    """Drop hook entries that point to `bare` without a guard prefix.
    Older versions of install.sh registered the hook command directly
    (e.g. '/path/to/cc-light-hook.sh busy'); we don't want to leave
    those around alongside the new guarded form."""
    out = []
    for entry in arr:
        kept = [h for h in entry.get("hooks", [])
                if h.get("command") != bare
                and not h.get("command", "").startswith(bare + " ")]
        if kept:
            out.append({**entry, "hooks": kept})
    return out

def is_cc_light_entry(entry):
    """True if this entry was placed by a previous install.sh — matched
    by command containing the hook script path. Used to wipe our own
    entries before re-adding so matcher changes don't accumulate."""
    return any(hook_path in h.get("command", "")
               for h in entry.get("hooks", []))

def reset_event(event):
    """Remove all cc-light entries from this event, leaving user-installed
    hooks (e.g. rtk hook claude) intact. Re-run safe."""
    if event in hooks:
        hooks[event] = [e for e in hooks[event] if not is_cc_light_entry(e)]

def guarded(arg):
    # [ -x path ] && path arg || true  —  if the hook script is missing
    # the guard short-circuits and the command exits 0 with no output,
    # so uninstalled-but-not-cleaned hooks don't spam "command not found".
    return f"[ -x {hook_cmd} ] && {hook_cmd} {arg} || true"

def has_command(arr, cmd):
    return any(h.get("command") == cmd
               for entry in arr
               for h in entry.get("hooks", []))

def add(event, matcher, arg):
    arr = hooks.setdefault(event, [])
    reset_event(event)  # wipe our own entry first — matcher may have changed
    arr = hooks[event]
    cmd = guarded(arg)
    if not has_command(arr, cmd):
        entry = {"hooks": [{"type": "command", "command": cmd}]}
        if matcher:
            entry["matcher"] = matcher
        arr.append(entry)
    hooks[event] = arr

# Busy hooks: every event that means "Claude is still working". The more
# events we cover, the longer the red light stays alive between events
# (the app drops sessions older than 5min). Pure thinking / pure text
# generation in Claude Code is a black box to hooks — no event fires
# during model output — so we need to cover every "Claude did something"
# hook to keep the busy state fresh.
add("UserPromptSubmit",   None,             "busy")
add("PreToolUse",         None,             "busy")
add("PostToolUse",        None,             "busy")
add("PostToolUseFailure", None,             "busy")
add("PostToolBatch",      None,             "busy")
add("SubagentStart",      None,             "busy")
add("SubagentStop",       None,             "busy")
add("TaskCreated",        None,             "busy")
add("TaskCompleted",      None,             "busy")
add("MessageDisplay",     None,             "busy")
add("WorktreeCreate",     None,             "busy")
add("WorktreeRemove",     None,             "busy")
# PermissionRequest is a separate event (not a Notification variant) — it
# fires when Claude needs you to allow a tool. Distinguishing it from
# idle_prompt lets the menu show what kind of attention is needed.
add("PermissionRequest",  None,             "waitingPermission")
# Notification still carries idle_prompt (Claude finished and is sitting
# idle waiting for your next message). permission_prompt was removed from
# the matcher because it's handled by PermissionRequest above.
add("Notification",       "idle_prompt",    "waitingInput")
# Stop fires when Claude finishes its turn normally; StopFailure fires
# when the turn ended with an error (rate limit, overload, etc.) — either
# way the round is over, the light goes back to idle.
add("Stop",               None,             "idle")
add("StopFailure",        None,             "idle")
# SessionEnd means the user closed Claude Code entirely (or it exited
# on its own). Delete this session's state file outright — the Swift
# app exempts waiting states from the stale filter so they'd otherwise
# linger forever after a clean exit.
add("SessionEnd",         None,             "ended")

with open(settings_path, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
print(f"  → Wrote hooks to {settings_path}")
PYEOF

# 5. Launch
#    Kill any previous instance first — `open` will reuse the running
#    process if its bundle path is unchanged, which is fine in
#    principle, but our binary name (and sometimes the bundle path)
#    change between installs, and a stale process is harder to debug
#    than a clean restart.
pkill -f "CC Light.app/Contents/MacOS" 2>/dev/null || true
pkill -f "cc-light.app/Contents/MacOS" 2>/dev/null || true
echo "  → Launching $BUNDLE_NAME..."
open "$APP_BUNDLE"

echo ""
echo "✅ Done! Look for the 🟢 in your menu bar."
echo "   $BUNDLE_NAME will turn 🔴 when Claude Code is working."
echo ""
echo "   Note: the same hooks fire for every Claude Code client on this"
echo "   machine (CLI, VSCode extension, JetBrains plugins). The menu"
echo "   lists each active session with its project name."
