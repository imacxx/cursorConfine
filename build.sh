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

# Drop in the compiled icon assets. AppIcon.icns is what Finder, the App
# Switcher, and the initial Dock thumbnail use. The two PNGs ride along so
# AppIconAppearance.swift can swap NSApp.applicationIconImage at runtime
# based on the system appearance (macOS doesn't switch Dock icons natively).
cp "$BUILD_DIR/AssetCatalog/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp art/icon-light.png "$APP_BUNDLE/Contents/Resources/icon-light.png"
cp art/icon-dark.png  "$APP_BUNDLE/Contents/Resources/icon-dark.png"

# Strip any quarantine/extended attributes that would interfere with running
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo "==> Signing"
# Prefer the stable "CursorConfine Dev" identity if the user has run
# setup_signing_cert.sh. Falls back to ad-hoc (`-`), which works but
# breaks TCC trust on every rebuild because the cdhash changes.
STABLE_IDENTITY="CursorConfine Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$STABLE_IDENTITY\""; then
    SIGN_ARGS="--sign \"$STABLE_IDENTITY\""
    echo "  using stable identity: $STABLE_IDENTITY"
    codesign --force --deep --sign "$STABLE_IDENTITY" "$APP_BUNDLE"
else
    echo "  using ad-hoc signing (run setup_signing_cert.sh to get stable TCC trust)"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "==> Verifying signature"
codesign --verify --verbose=2 "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run with:  open '$APP_BUNDLE'"
echo "Or:         '$APP_BUNDLE/Contents/MacOS/$APP_NAME'"
