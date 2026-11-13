#!/usr/bin/env bash
# Signs the built Alerse.app, with the build Mac's own identity or else ad
# hoc, and packages it into a dmg, with the
# upstream sign_and_package_app.sh, which names the bundles Chromium.
#
#   ./package.sh [VERSION]   # build/alerse_VERSION_macos_arm64.dmg
#
# OUT_DIR picks the build's output directory under build/src (out/Default by
# default; out/Release for an official build next to a --fast one).

set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
UPSTREAM=$ROOT/ungoogled-chromium-macos
VERSION=${1:-$(cat "$UPSTREAM/ungoogled-chromium/chromium_version.txt")}
DMG=$UPSTREAM/build/alerse_${VERSION}_macos_$(uname -m).dmg
OUT_DIR=${OUT_DIR:-out/Default}

# Without a Developer ID, library validation rejects the ad hoc signed
# framework: the Team IDs differ. The bundles keep the hardened runtime and
# turn library validation off with an entitlement instead of the "library"
# signing option. The upstream script resolves its other files next to itself.
ALERSE_ENTITLEMENTS=$(mktemp -d)
script=$UPSTREAM/.alerse_package.sh
trap 'rm -rf "$script" "$ALERSE_ENTITLEMENTS"' EXIT
for plist in "$UPSTREAM"/entitlements/*.plist; do
  cp "$plist" "$ALERSE_ENTITLEMENTS/"
done
cat > "$ALERSE_ENTITLEMENTS/library.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
for plist in "$ALERSE_ENTITLEMENTS"/*.plist; do
  key=:com.apple.security.cs.disable-library-validation
  /usr/libexec/PlistBuddy -c "Set $key true" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add $key bool true" "$plist"
done
export ALERSE_ENTITLEMENTS

sed -e 's/Chromium/Alerse/g' \
  -e "s|/out/Default/|/$OUT_DIR/|" \
  -e 's/--options=restrict,library,runtime,kill/--options restrict,runtime,kill/' \
  -e 's/restrict,library,runtime,kill/restrict,runtime,kill/g' \
  -e 's|"\$_root_dir/entitlements/|"$ALERSE_ENTITLEMENTS/|g' \
  -e 's|--options restrict,runtime,kill "|--options restrict,runtime,kill --entitlements "$ALERSE_ENTITLEMENTS/library.plist" "|' \
  "$UPSTREAM/sign_and_package_app.sh" > "$script"
# Fail rather than sign differently when the upstream script changes.
if grep -q 'library,' "$script" || grep -q '\$_root_dir/entitlements' "$script" ||
   [ "$(grep -c 'ALERSE_ENTITLEMENTS/library.plist' "$script")" -lt 7 ]; then
  echo "package.sh: sign_and_package_app.sh changed upstream; update package.sh" >&2
  exit 1
fi
# Sign with the build Mac's own identity (signing-identity.sh) when it has one:
# its certificate stays the same from build to build, so macOS keeps the
# keychain access a user allowed once. Ad hoc signatures change with every
# build, and macOS asked for the login password after each update.
SIGN_KEYCHAIN=$HOME/.alerse-signing/alerse-signing.keychain-db
if [[ -f "$SIGN_KEYCHAIN" ]]; then
  security unlock-keychain -p "$(cat "$HOME/.alerse-signing/keychain-password")" "$SIGN_KEYCHAIN"
  python3 - "$script" "$SIGN_KEYCHAIN" <<'PY'
import sys
path, keychain = sys.argv[1], sys.argv[2]
text = open(path).read()
old = 'codesign --sign - --force "$@"'
if text.count(old) != 1:
    sys.exit("package.sh: the ad hoc sign() of sign_and_package_app.sh changed; update package.sh")
new = 'codesign --sign "Alerse Self-Signed" --keychain "%s" --force "$@"' % keychain
open(path, 'w').write(text.replace(old, new))
PY
fi
chmod +x "$script"

rm -f "$DMG"
MACOS_AD_HOC_SIGNING=1 CHROMIUM_SRC_DIR="$UPSTREAM/build/src" "$script" "$DMG"
echo "$DMG"
