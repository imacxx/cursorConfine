#!/bin/bash
# Build CursorConfine.app and package it as a ZIP suitable for uploading to
# a GitHub release. Uses `ditto` instead of `zip` because plain zip strips
# xattrs/permissions that the code signature relies on — extract a zip-zipped
# .app and macOS will refuse to launch it ("damaged").
#
# Output: dist/CursorConfine-<version>-arm64.zip
set -euo pipefail
cd "$(dirname "$0")"

# Make sure the .app is up-to-date.
./build.sh

VERSION=$(plutil -extract CFBundleShortVersionString raw Info.plist)
DIST="$(pwd)/dist"
APP="$(pwd)/build/CursorConfine.app"
ZIP="$DIST/CursorConfine-${VERSION}-arm64.zip"

mkdir -p "$DIST"
rm -f "$ZIP"

echo "==> Packaging with ditto (preserves signature + metadata)"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo ""
echo "Created: $ZIP"
ls -lh "$ZIP"
echo ""
echo "Upload to GitHub releases. Recipients should:"
echo "  1. Download CursorConfine-${VERSION}-arm64.zip"
echo "  2. Double-click to extract → drag CursorConfine.app to /Applications"
echo "  3. First launch: macOS will block it. Go to:"
echo "     System Settings → Privacy & Security → scroll to bottom"
echo "     Click \"Open Anyway\" next to the CursorConfine notice."
echo "  4. Grant Accessibility when prompted (Permissions tab in the app)."
