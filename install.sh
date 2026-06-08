#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="cc-light"
INSTALL_DIR="$HOME/Applications"
HOOKS_DIR="$SCRIPT_DIR/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_FILE="/tmp/cc-light-state.json"

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

# 3. Initialize state file
echo '{"state":"idle","session_id":"","ts":0}' > "$STATE_FILE"

# 4. Configure Claude Code hooks
HOOK_CMD="$HOOKS_DIR/cc-light-hook.sh"
echo "  → Configuring Claude Code hooks..."

mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ] || [ "$(cat "$SETTINGS_FILE")" = "{}" ]; then
    cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "$HOOK_CMD busy" }] }
    ],
    "Notification": [
      { "matcher": "idle_prompt|permission_prompt", "hooks": [{ "type": "command", "command": "$HOOK_CMD waiting" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "$HOOK_CMD idle" }] }
    ]
  }
}
EOF
    echo "  → Wrote hooks to $SETTINGS_FILE"
else
    echo "  ⚠️  $SETTINGS_FILE already has content."
    echo "     Please manually add hooks (see README.md for config)."
fi

# 5. Launch
echo "  → Launching cc-light..."
open "$APP_BUNDLE"

echo ""
echo "✅ Done! Look for the 🟢 in your menu bar."
echo "   cc-light will turn 🔴 when Claude Code is working."
