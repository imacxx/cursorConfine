#!/bin/bash
# Builds the CursorConfine app icon as an Asset Catalog with three luminosity
# variants (light / dark / tinted), each at all standard mac sizes
# (16 → 1024 px), and compiles it to Assets.car via actool.
set -euo pipefail

cd "$(dirname "$0")"

BUILD="$(pwd)/build"
OUT="$BUILD/AssetCatalog"
XCASSETS="$BUILD/Assets.xcassets"
APPICON="$XCASSETS/AppIcon.appiconset"
TMPMASTERS="$BUILD/icon_masters"

rm -rf "$OUT" "$XCASSETS" "$TMPMASTERS"
mkdir -p "$APPICON" "$OUT" "$TMPMASTERS"

echo "==> Rendering 1024×1024 master PNGs"
swift make_icon.swift light  "$TMPMASTERS/light-1024.png"  > /dev/null
swift make_icon.swift dark   "$TMPMASTERS/dark-1024.png"   > /dev/null
swift make_icon.swift tinted "$TMPMASTERS/tinted-1024.png" > /dev/null

echo "==> Scaling each variant to all mac icon sizes"
SIZES=(16 32 64 128 256 512 1024)
for variant in light dark tinted; do
    for sz in "${SIZES[@]}"; do
        sips -z "$sz" "$sz" "$TMPMASTERS/${variant}-1024.png" \
             --out "$APPICON/${variant}-${sz}.png" > /dev/null
    done
done

cat > "$XCASSETS/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

# Emit the appiconset Contents.json — 10 standard mac slots per appearance.
write_slots () {
    local variant="$1"     # light | dark | tinted
    local prefix=""
    if [[ "$variant" != "light" ]]; then
        prefix=",\"appearances\":[{\"appearance\":\"luminosity\",\"value\":\"$variant\"}]"
    fi
    cat <<EOF
    {"filename":"${variant}-16.png",   "idiom":"mac", "size":"16x16",     "scale":"1x" $prefix},
    {"filename":"${variant}-32.png",   "idiom":"mac", "size":"16x16",     "scale":"2x" $prefix},
    {"filename":"${variant}-32.png",   "idiom":"mac", "size":"32x32",     "scale":"1x" $prefix},
    {"filename":"${variant}-64.png",   "idiom":"mac", "size":"32x32",     "scale":"2x" $prefix},
    {"filename":"${variant}-128.png",  "idiom":"mac", "size":"128x128",   "scale":"1x" $prefix},
    {"filename":"${variant}-256.png",  "idiom":"mac", "size":"128x128",   "scale":"2x" $prefix},
    {"filename":"${variant}-256.png",  "idiom":"mac", "size":"256x256",   "scale":"1x" $prefix},
    {"filename":"${variant}-512.png",  "idiom":"mac", "size":"256x256",   "scale":"2x" $prefix},
    {"filename":"${variant}-512.png",  "idiom":"mac", "size":"512x512",   "scale":"1x" $prefix},
    {"filename":"${variant}-1024.png", "idiom":"mac", "size":"512x512",   "scale":"2x" $prefix}
EOF
}

{
    echo "{"
    echo '  "images" : ['
    write_slots light
    echo ","
    write_slots dark
    echo ","
    write_slots tinted
    echo "  ],"
    echo '  "info" : { "author" : "xcode", "version" : 1 }'
    echo "}"
} > "$APPICON/Contents.json"

echo "==> Compiling Asset Catalog with actool"
xcrun actool "$XCASSETS" \
    --compile "$OUT" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --include-all-app-icons \
    --output-partial-info-plist "$OUT/AppIcon-partial.plist" \
    --output-format human-readable-text \
    --target-device mac \
    --notices --warnings --errors

echo ""
echo "Output:"
ls -la "$OUT"
echo ""
echo "Partial Info.plist contents:"
plutil -p "$OUT/AppIcon-partial.plist" || cat "$OUT/AppIcon-partial.plist"
