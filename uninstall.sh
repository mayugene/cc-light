#!/bin/bash
set -e

# New name (post-rename) takes precedence. The old `cc-light.app` path
# is checked too so users upgrading from a previous version can still
# uninstall cleanly.
NEW_APP_BUNDLE="$HOME/Applications/CC Light.app"
OLD_APP_BUNDLE="$HOME/Applications/cc-light.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_DIR="/tmp/cc-light"

echo "🚦 Uninstalling CC Light..."

# Kill running instance. Match on the executable name to avoid nuking
# unrelated processes that happen to share words like "cc-light".
pkill -f "cc-light.app/Contents/MacOS/cc-light" 2>/dev/null || true

# Remove both bundle names if present.
for bundle in "$NEW_APP_BUNDLE" "$OLD_APP_BUNDLE"; do
    if [ -d "$bundle" ]; then
        rm -rf "$bundle"
        echo "  → Removed $bundle"
    fi
done

# Remove state directory (per-session JSON files written by the hooks)
rm -rf "$STATE_DIR"
echo "  → Removed $STATE_DIR"

echo ""
echo "✅ CC Light removed."
echo "   Note: hooks in $SETTINGS_FILE were not removed. Edit manually if needed."
