#!/usr/bin/env bash
# Resumes an Arcomium macOS build after build.sh stopped past patching.
set -eux
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
SRC=$(cd "$(dirname "$0")" && pwd)/ungoogled-chromium-macos/build/src
SHIMS=$(mktemp -d)
ln -s /opt/homebrew/bin/python3.13 $SHIMS/python3
export PATH=$SHIMS:/opt/homebrew/bin:$PATH SDKROOT=$SDK
cd $SRC
if ! grep -q selected_macos_sdk out/Default/args.gn; then
  mkdir -p out/Default/sdk
  ln -sfn $SDK out/Default/sdk/selected_macos_sdk
  echo 'mac_sdk_path = "//out/Default/sdk/selected_macos_sdk"' >> out/Default/args.gn
fi
[ -x third_party/rust-toolchain/bin/bindgen ] || ./tools/rust/build_bindgen.py --skip-test
./out/Default/gn gen out/Default --fail-on-unused-args
ninja -C out/Default -j ${NINJA_JOBS:-10} chrome chromedriver
echo BUILD_DONE
