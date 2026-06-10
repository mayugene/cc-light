#!/bin/bash
# Builds resources/cc-light.icns from a 1024x1024 source PNG.
# One-time setup: run this once to produce cc-light.icns, then commit
# the result. install.sh will copy it into the .app bundle.
#
# Usage: ./build-icon.sh
#
# Requires: macOS (uses sips + iconutil), and Swift to render the
# source PNG via generate-icon-3lights-v2.swift.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR=$(mktemp -d)
SRC_PNG="$TMP_DIR/icon-1024.png"
ICNS_OUT="$SCRIPT_DIR/cc-light.icns"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# 1. Render the 1024x1024 source PNG with CoreGraphics.
#    Vertical traffic-light housing on a white rounded-square canvas.
echo "  → Rendering source PNG (vertical traffic light)…"
swift "$SCRIPT_DIR/generate-icon-3lights-v2.swift" "$SRC_PNG" vertical

# 2. Build the .iconset folder at all the sizes macOS expects.
#    (iconutil insists on this exact naming scheme.)
ICONSET="$TMP_DIR/cc-light.iconset"
mkdir -p "$ICONSET"
echo "  → Sizing for .icns…"
sips -z   16   16 "$SRC_PNG" --out "$ICONSET/icon_16x16.png"       > /dev/null
sips -z   32   32 "$SRC_PNG" --out "$ICONSET/icon_16x16@2x.png"    > /dev/null
sips -z   32   32 "$SRC_PNG" --out "$ICONSET/icon_32x32.png"       > /dev/null
sips -z   64   64 "$SRC_PNG" --out "$ICONSET/icon_32x32@2x.png"    > /dev/null
sips -z  128  128 "$SRC_PNG" --out "$ICONSET/icon_128x128.png"     > /dev/null
sips -z  256  256 "$SRC_PNG" --out "$ICONSET/icon_128x128@2x.png"  > /dev/null
sips -z  256  256 "$SRC_PNG" --out "$ICONSET/icon_256x256.png"     > /dev/null
sips -z  512  512 "$SRC_PNG" --out "$ICONSET/icon_256x256@2x.png"  > /dev/null
sips -z  512  512 "$SRC_PNG" --out "$ICONSET/icon_512x512.png"     > /dev/null
cp "$SRC_PNG" "$ICONSET/icon_512x512@2x.png"

# 3. Pack the .iconset into a single .icns.
echo "  → Packing .icns…"
iconutil -c icns "$ICONSET" -o "$ICNS_OUT"
echo "✅ Wrote $ICNS_OUT"
