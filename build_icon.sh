#!/bin/bash
# Compile the CursorConfine AppIcon.
#
# macOS Dock icons don't natively switch with system appearance — the
# `Assets.car` multi-appearance variants we tried earlier are silently
# dropped by actool for the mac idiom. Instead we:
#   1. Produce a single AppIcon.icns from art/icon-dark.png (the better
#      default — dark mode is more common now and the dark glassmorphic
#      design reads well in both light and dark Docks).
#   2. Ship both art/icon-light.png and art/icon-dark.png as Resources;
#      AppIconAppearance.swift swaps NSApp.applicationIconImage at runtime
#      so the running app's Dock icon matches the system appearance.
#
# Source:
#   art/icon-dark.png   — 1024×1024 dark-appearance master (becomes .icns)
set -euo pipefail

cd "$(dirname "$0")"

BUILD="$(pwd)/build"
OUT="$BUILD/AssetCatalog"
XCASSETS="$BUILD/Assets.xcassets"
APPICON="$XCASSETS/AppIcon.appiconset"
ART="$(pwd)/art"

if [[ ! -f "$ART/icon-dark.png" ]]; then
    echo "Missing art/icon-dark.png" >&2
    exit 1
fi

rm -rf "$OUT" "$XCASSETS"
mkdir -p "$APPICON" "$OUT"

echo "==> Building all standard mac icon sizes from dark master"
SIZES=(16 32 64 128 256 512 1024)
for sz in "${SIZES[@]}"; do
    sips -z "$sz" "$sz" "$ART/icon-dark.png" \
         --out "$APPICON/icon-${sz}.png" > /dev/null
done

cat > "$XCASSETS/Contents.json" <<'EOF'
{ "info" : { "author" : "xcode", "version" : 1 } }
EOF

cat > "$APPICON/Contents.json" <<'EOF'
{
  "images" : [
    {"filename":"icon-16.png",   "idiom":"mac", "size":"16x16",   "scale":"1x"},
    {"filename":"icon-32.png",   "idiom":"mac", "size":"16x16",   "scale":"2x"},
    {"filename":"icon-32.png",   "idiom":"mac", "size":"32x32",   "scale":"1x"},
    {"filename":"icon-64.png",   "idiom":"mac", "size":"32x32",   "scale":"2x"},
    {"filename":"icon-128.png",  "idiom":"mac", "size":"128x128", "scale":"1x"},
    {"filename":"icon-256.png",  "idiom":"mac", "size":"128x128", "scale":"2x"},
    {"filename":"icon-256.png",  "idiom":"mac", "size":"256x256", "scale":"1x"},
    {"filename":"icon-512.png",  "idiom":"mac", "size":"256x256", "scale":"2x"},
    {"filename":"icon-512.png",  "idiom":"mac", "size":"512x512", "scale":"1x"},
    {"filename":"icon-1024.png", "idiom":"mac", "size":"512x512", "scale":"2x"}
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

echo "==> Compiling AppIcon.icns with actool"
xcrun actool "$XCASSETS" \
    --compile "$OUT" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --include-all-app-icons \
    --output-partial-info-plist "$OUT/AppIcon-partial.plist" \
    --output-format human-readable-text \
    --target-device mac \
    --notices --warnings --errors

echo ""
echo "Output:"
ls -la "$OUT"
