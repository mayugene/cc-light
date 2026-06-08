#!/bin/bash
set -e

APP_BUNDLE="$HOME/Applications/cc-light.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_FILE="/tmp/cc-light-state.json"

echo "🚦 Uninstalling cc-light..."

# Kill running instance
pkill -f "cc-light.app" 2>/dev/null || true

# Remove app
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
    echo "  → Removed $APP_BUNDLE"
fi

# Remove state file
rm -f "$STATE_FILE"
echo "  → Removed state file"

echo ""
echo "✅ cc-light removed."
echo "   Note: hooks in $SETTINGS_FILE were not removed. Edit manually if needed."
