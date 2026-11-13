#!/usr/bin/env bash
# Makes the self-signed code signing identity that package.sh signs Alerse
# with, once per build Mac. Keep it: macOS ties a keychain item's "Always
# Allow" to the signing certificate, so builds signed with the same one keep
# access to "Chromium Safe Storage" across updates, where ad hoc signatures
# asked for the login password after every update.
#
#   ./signing-identity.sh          # makes it, unless it exists
#   ./signing-identity.sh export   # prints a base64 PKCS#12 backup to stdout
#
# The identity lives in its own keychain, unlocked with a random password kept
# next to it (mode 600), so packaging needs no prompt and the login keychain
# stays untouched.

set -euo pipefail

NAME="Alerse Self-Signed"
DIR="$HOME/.alerse-signing"
KEYCHAIN="$DIR/alerse-signing.keychain-db"
PASS_FILE="$DIR/keychain-password"

if [[ "${1:-}" == export ]]; then
  security unlock-keychain -p "$(cat "$PASS_FILE")" "$KEYCHAIN"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  security export -k "$KEYCHAIN" -t identities -f pkcs12 -P "$(cat "$PASS_FILE")" \
    -o "$tmp/alerse-signing.p12" >/dev/null
  base64 < "$tmp/alerse-signing.p12"
  exit 0
fi

if [[ -f "$KEYCHAIN" ]]; then
  echo "exists: $KEYCHAIN"
  exit 0
fi

mkdir -p "$DIR"
chmod 700 "$DIR"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/cert.cnf" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
O=The Alerse Authors
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
openssl req -x509 -newkey rsa:3072 -nodes -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
  -days 7300 -config "$tmp/cert.cnf" 2>/dev/null
pass=$(openssl rand -hex 24)
openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" \
  -passout "pass:$pass" -legacy 2>/dev/null ||
  openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" \
    -passout "pass:$pass"
(umask 077 && printf '%s' "$pass" > "$PASS_FILE")
security create-keychain -p "$pass" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"   # no automatic lock
security unlock-keychain -p "$pass" "$KEYCHAIN"
security import "$tmp/id.p12" -k "$KEYCHAIN" -P "$pass" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$pass" "$KEYCHAIN" >/dev/null
echo "made: $NAME in $KEYCHAIN"
echo "Back it up: ./signing-identity.sh export > alerse-signing.p12.b64 (holds the private key)"
