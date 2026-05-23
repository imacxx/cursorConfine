#!/bin/bash
# Builds the CursorConfine app icon Asset Catalog from the master PNGs in
# art/. Produces light + dark + tinted variants at all standard mac icon
# sizes (16…1024 px) and compiles to Assets.car + AppIcon.icns via actool.
#
# Sources:
#   art/icon-light.png   — 1024×1024 light-appearance master
#   art/icon-dark.png    — 1024×1024 dark-appearance master (also the basis
#                          for the tinted variant — desaturated at build time)
set -euo pipefail

cd "$(dirname "$0")"

BUILD="$(pwd)/build"
OUT="$BUILD/AssetCatalog"
XCASSETS="$BUILD/Assets.xcassets"
APPICON="$XCASSETS/AppIcon.appiconset"
TMPMASTERS="$BUILD/icon_masters"
ART="$(pwd)/art"

if [[ ! -f "$ART/icon-light.png" || ! -f "$ART/icon-dark.png" ]]; then
    echo "Missing art/icon-light.png or art/icon-dark.png" >&2
    exit 1
fi

rm -rf "$OUT" "$XCASSETS" "$TMPMASTERS"
mkdir -p "$APPICON" "$OUT" "$TMPMASTERS"

echo "==> Preparing 1024×1024 master PNGs"
cp "$ART/icon-light.png" "$TMPMASTERS/light-1024.png"
cp "$ART/icon-dark.png"  "$TMPMASTERS/dark-1024.png"

echo "==> Deriving tinted variant from dark master"
swift make_tinted.swift "$TMPMASTERS/dark-1024.png" "$TMPMASTERS/tinted-1024.png" > /dev/null

echo "==> Scaling each variant to mac icon sizes"
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

write_slots () {
    local variant="$1"
    local prefix=""
    if [[ "$variant" != "light" ]]; then
        prefix=",\"appearances\":[{\"appearance\":\"luminosity\",\"value\":\"$variant\"}]"
    fi
    cat <<EOF
    {"filename":"${variant}-16.png",   "idiom":"mac", "size":"16x16",   "scale":"1x" $prefix},
    {"filename":"${variant}-32.png",   "idiom":"mac", "size":"16x16",   "scale":"2x" $prefix},
    {"filename":"${variant}-32.png",   "idiom":"mac", "size":"32x32",   "scale":"1x" $prefix},
    {"filename":"${variant}-64.png",   "idiom":"mac", "size":"32x32",   "scale":"2x" $prefix},
    {"filename":"${variant}-128.png",  "idiom":"mac", "size":"128x128", "scale":"1x" $prefix},
    {"filename":"${variant}-256.png",  "idiom":"mac", "size":"128x128", "scale":"2x" $prefix},
    {"filename":"${variant}-256.png",  "idiom":"mac", "size":"256x256", "scale":"1x" $prefix},
    {"filename":"${variant}-512.png",  "idiom":"mac", "size":"256x256", "scale":"2x" $prefix},
    {"filename":"${variant}-512.png",  "idiom":"mac", "size":"512x512", "scale":"1x" $prefix},
    {"filename":"${variant}-1024.png", "idiom":"mac", "size":"512x512", "scale":"2x" $prefix}
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
