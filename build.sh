#!/bin/bash
# Build CursorConfine.app as an ad-hoc-signed macOS application bundle.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="CursorConfine"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Compiling Swift package ($CONFIG, arm64)"
swift build -c "$CONFIG" --arch arm64

BIN_PATH=$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)

echo "==> Building app icon Asset Catalog (light / dark / tinted)"
./build_icon.sh > "$BUILD_DIR/icon_build.log" 2>&1 || {
    echo "Icon build failed — see $BUILD_DIR/icon_build.log"
    tail -20 "$BUILD_DIR/icon_build.log"
    exit 1
}

echo "==> Assembling .app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Drop in the compiled icon assets. Assets.car carries the multi-appearance
# variants (used in macOS 14+); AppIcon.icns is the classic single-appearance
# fallback (used by Finder thumbnails on older macOS / non-asset-catalog paths).
cp "$BUILD_DIR/AssetCatalog/Assets.car"    "$APP_BUNDLE/Contents/Resources/Assets.car"
cp "$BUILD_DIR/AssetCatalog/AppIcon.icns"  "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Strip any quarantine/extended attributes that would interfere with running
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --verbose=2 "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run with:  open '$APP_BUNDLE'"
echo "Or:         '$APP_BUNDLE/Contents/MacOS/$APP_NAME'"
