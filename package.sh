#!/usr/bin/env bash
# Signs the built Arcomium.app ad hoc and packages it into a dmg, with the
# upstream sign_and_package_app.sh, which names the bundles Chromium.
#
#   ./package.sh [VERSION]   # build/arcomium_VERSION_macos_arm64.dmg

set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
UPSTREAM=$ROOT/ungoogled-chromium-macos
VERSION=${1:-$(cat "$UPSTREAM/ungoogled-chromium/chromium_version.txt")}
DMG=$UPSTREAM/build/arcomium_${VERSION}_macos_$(uname -m).dmg

# The upstream script resolves its other files next to itself. Without a
# Developer ID, library validation (which the hardened runtime turns on too)
# rejects the ad hoc signed framework: the Team IDs differ. So the bundles are
# signed without both.
script=$UPSTREAM/.arcomium_package.sh
trap 'rm -f "$script"' EXIT
sed -e 's/Chromium/Arcomium/g' -e 's/,library,/,/' -e 's/,runtime//' \
  "$UPSTREAM/sign_and_package_app.sh" > "$script"
chmod +x "$script"

rm -f "$DMG"
MACOS_AD_HOC_SIGNING=1 CHROMIUM_SRC_DIR="$UPSTREAM/build/src" "$script" "$DMG"
echo "$DMG"
