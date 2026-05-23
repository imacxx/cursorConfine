#!/bin/bash
# One-time setup: creates a self-signed code-signing certificate named
# "CursorConfine Dev" in the user's login Keychain so build.sh can sign
# with a stable identity. This makes TCC trust (Accessibility, Screen
# Recording) survive rebuilds — without it every `codesign --sign -`
# changes the cdhash and macOS forgets the previous grant.
#
# Re-running is safe (no-op if cert already exists).
set -euo pipefail

CERT_NAME="CursorConfine Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# If the cert already exists in the keychain we're done.
if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "Code-signing identity '$CERT_NAME' already exists in the login keychain."
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo "==> Generating private key + self-signed certificate"
cat > "$TMP/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
prompt             = no
[ dn ]
CN = $CERT_NAME
O  = CursorConfine
[ v3 ]
basicConstraints      = critical, CA:FALSE
keyUsage              = critical, digitalSignature
extendedKeyUsage      = critical, codeSigning
subjectKeyIdentifier  = hash
EOF

openssl req -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" \
    -x509 -days 3650 -sha256 \
    -out "$TMP/cert.pem" \
    -config "$TMP/openssl.cnf" \
    -extensions v3 \
    2>/dev/null

echo "==> Packaging as PKCS#12"
# `-legacy` keeps PKCS12 v1 MAC/encryption (RC2/SHA-1) which Apple's
# `security import` understands. The default in OpenSSL 3 is AES-256/SHA-256
# which Keychain rejects with "MAC verification failed".
PASS="cursorconfine"
openssl pkcs12 -export -legacy \
    -name "$CERT_NAME" \
    -in "$TMP/cert.pem" \
    -inkey "$TMP/key.pem" \
    -out "$TMP/cert.p12" \
    -passout pass:"$PASS" \
    2>/dev/null

echo "==> Importing into login.keychain (private key + cert)"
security import "$TMP/cert.p12" \
    -k "$KEYCHAIN" \
    -P "$PASS" \
    -A          # allow ALL apps to access the key (so codesign won't prompt)

# Mark the cert as trusted for code signing on this Mac.
# `add-trusted-cert` for user trust doesn't need sudo and is enough for
# codesign (which only checks that the cert is in the keychain and has
# a private key — TCC will then track by the stable cert identity,
# not the cdhash).
echo "==> Trusting cert for codesigning in the user trust settings"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" 2>&1 \
    | grep -v "SecTrustSettingsSetTrustSettings" || true

echo ""
echo "Done. Code-signing identity now available:"
security find-identity -v -p codesigning "$KEYCHAIN" | grep "$CERT_NAME" || true
echo ""
echo "Next: rebuild the app (./build.sh) — it'll sign with '$CERT_NAME'"
echo "and TCC permissions will survive future rebuilds."
echo ""
echo "Note: the FIRST signed run will still need you to re-grant"
echo "Accessibility / Screen Recording (since the previous ad-hoc"
echo "trust was keyed to a different identity)."
