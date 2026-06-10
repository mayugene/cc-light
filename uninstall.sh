#!/bin/bash
set -e

APP_BUNDLE="$HOME/Applications/cc-light.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_DIR="/tmp/cc-light"

echo "🚦 Uninstalling cc-light..."

# Kill running instance
pkill -f "cc-light.app" 2>/dev/null || true

# Remove app
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
    echo "  → Removed $APP_BUNDLE"
fi

# Remove state directory (per-session JSON files written by the hooks)
rm -rf "$STATE_DIR"
echo "  → Removed $STATE_DIR"

echo ""
echo "✅ cc-light removed."
echo "   Note: hooks in $SETTINGS_FILE were not removed. Edit manually if needed."
