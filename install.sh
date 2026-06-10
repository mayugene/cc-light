#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="cc-light"
INSTALL_DIR="$HOME/Applications"
HOOKS_DIR="$SCRIPT_DIR/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_DIR="/tmp/cc-light"

echo "🚦 Installing cc-light..."

# 1. Build the Swift app
echo "  → Building menu bar app..."
cd "$SCRIPT_DIR/cc-light-app"
swift build -c release 2>&1 | tail -3
BUILD_PATH=$(swift build -c release --show-bin-path)/$APP_NAME

# 2. Create .app bundle
APP_BUNDLE="$INSTALL_DIR/cc-light.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.cc-light.app</string>
    <key>CFBundleName</key>
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

# 3. Initialize state directory
mkdir -p "$STATE_DIR"
echo '{"state":"idle","session_id":"","cwd":"","transcript_path":"","ts":0}' \
  > "$STATE_DIR/_default.json"

# 4. Configure Claude Code hooks by deep-merging into settings.json.
#    Idempotent: re-running install.sh will not duplicate hooks.
HOOK_CMD="$HOOKS_DIR/cc-light-hook.sh"
echo "  → Configuring Claude Code hooks..."

mkdir -p "$(dirname "$SETTINGS_FILE")"
python3 - "$SETTINGS_FILE" "$HOOK_CMD" <<'PYEOF'
import json, os, sys

settings_path = sys.argv[1]
hook_cmd      = sys.argv[2]

existing = {}
if os.path.exists(settings_path) and os.path.getsize(settings_path) > 0:
    try:
        with open(settings_path) as f:
            existing = json.load(f)
    except Exception as e:
        print(f"  ⚠️  Could not parse {settings_path}: {e}")
        print("     Backing it up to {path}.bak and starting fresh.")
        os.rename(settings_path, settings_path + ".bak")
        existing = {}

hooks = existing.setdefault("hooks", {})

def has_command(arr, cmd):
    for entry in arr:
        for h in entry.get("hooks", []):
            if h.get("command") == cmd:
                return True
    return False

def add(event, matcher, cmd):
    arr = hooks.setdefault(event, [])
    if has_command(arr, cmd):
        return
    entry = {"hooks": [{"type": "command", "command": cmd}]}
    if matcher:
        entry["matcher"] = matcher
    arr.append(entry)

add("PreToolUse",  None,                            f"{hook_cmd} busy")
add("Notification","idle_prompt|permission_prompt", f"{hook_cmd} waiting")
add("Stop",        None,                            f"{hook_cmd} idle")

with open(settings_path, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
print(f"  → Wrote hooks to {settings_path}")
PYEOF

# 5. Launch
echo "  → Launching cc-light..."
open "$APP_BUNDLE"

echo ""
echo "✅ Done! Look for the 🟢 in your menu bar."
echo "   cc-light will turn 🔴 when Claude Code is working."
echo ""
echo "   Note: the same hooks fire for every Claude Code client on this"
echo "   machine (CLI, VSCode extension, JetBrains plugins). The menu"
echo "   lists each active session with its project name."
