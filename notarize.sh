#!/bin/bash
# CursorConfine — signed + notarized release build for direct distribution.
#
# Produces a notarized, stapled CursorConfine.app (and a distributable .zip)
# that opens with NO Gatekeeper warning and NO trip through
# System Settings → Privacy & Security → "Open Anyway".
#
# How it differs from release.sh:
#   release.sh   → quick ad-hoc/self-signed zip (still needs "Open Anyway").
#   notarize.sh  → Developer ID + hardened runtime + Apple notarization +
#                  stapled ticket. Double-click just works.
#
# Prereqs (one-time):
#   • "Developer ID Application: Nicky Audenaerde (RU6DL9DFXW)" cert in the
#     login keychain  (security find-identity -v -p codesigning).
#   • A notarytool keychain profile. By default we reuse the same Apple
#     account's profile created for ElyraRift ("elyra-notary"). To make a
#     dedicated one:
#       xcrun notarytool store-credentials cursorconfine-notary \
#         --apple-id <apple-id> --team-id RU6DL9DFXW --password <app-specific-pw>
#     then run:  NOTARY_PROFILE=cursorconfine-notary ./notarize.sh
#     (The app-specific password lives only in the keychain, never in git.)
set -uo pipefail
cd "$(dirname "$0")"

IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Nicky Audenaerde (RU6DL9DFXW)}"
PROFILE="${NOTARY_PROFILE:-elyra-notary}"
APP_NAME="CursorConfine"
APP="$(pwd)/build/$APP_NAME.app"

# 1) Build the bundle (reuses build.sh: swift build → icons → assemble .app).
echo "▸ Building release bundle…"
./build.sh release

# 2) Re-sign with Developer ID + hardened runtime + secure timestamp.
#    NO entitlements on purpose: it drops the debug `get-task-allow` that Apple
#    rejects during notarization, and the app needs none — Accessibility and
#    Screen Recording are TCC permissions (not entitlements), and it sends no
#    Apple Events (focus is observed via NSWorkspace notifications). Single
#    Mach-O with no embedded frameworks, so no --deep.
echo "▸ Signing with Developer ID (hardened runtime)…"
echo "  identity: $IDENTITY"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP" || { echo "✗ signature verify failed"; exit 1; }

# 3) Submit to Apple's notary service.
echo "▸ Zipping for submission…"
ZIP="build/$APP_NAME-submit.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Submitting to Apple notary service (profile: $PROFILE — can take a few minutes)…"
OUT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait 2>&1)
echo "$OUT"
STATUS=$(echo "$OUT" | awk -F': ' '/  status:/{print $2; exit}')
SUBID=$(echo "$OUT" | awk -F': ' '/  id:/{print $2; exit}')

if [ "$STATUS" != "Accepted" ]; then
    echo "✗ Notarization not accepted (status: ${STATUS:-unknown}). Log:"
    [ -n "$SUBID" ] && xcrun notarytool log "$SUBID" --keychain-profile "$PROFILE" 2>&1 | head -80
    rm -f "$ZIP"
    exit 1
fi

# 4) Staple the ticket so Gatekeeper accepts it even offline.
echo "▸ Stapling ticket to the app…"
xcrun stapler staple "$APP"

echo "▸ Final Gatekeeper verdict:"
spctl -a -vvv "$APP" 2>&1 | head -4

# 5) Package the distributable zip (version-stamped, same convention as release.sh).
VERSION=$(plutil -extract CFBundleShortVersionString raw Info.plist)
DIST="$(pwd)/dist"
mkdir -p "$DIST"
OUTZIP="$DIST/$APP_NAME-${VERSION}-arm64.zip"
rm -f "$OUTZIP" "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTZIP"

echo ""
echo "✓ Notarized + stapled → $OUTZIP"
ls -lh "$OUTZIP"
echo ""
echo "Upload to GitHub releases. Recipients just:"
echo "  1. Download $APP_NAME-${VERSION}-arm64.zip"
echo "  2. Double-click to extract → drag $APP_NAME.app to /Applications"
echo "  3. Double-click to open — no Gatekeeper warning."
echo "  4. Grant Accessibility when the Permissions tab asks."
