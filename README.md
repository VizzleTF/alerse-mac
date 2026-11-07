# Arcomium for macOS

macOS builds of [Arcomium](https://github.com/VizzleTF/arcomium), an Arc-style browser
on ungoogled-chromium. This repository builds the
[arcomium](https://github.com/VizzleTF/arcomium) patch series on top of
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos);
both are git submodules.

Builds for Apple Silicon, on Chromium 156 until ungoogled-chromium-macos releases 157.
Builds are made locally, not in CI; the releases so far are `--fast` pre-releases,
without LTO or PGO.

On macOS Arcomium keeps the platform's look, as Arc does there: the window buttons and
the menu bar stay, the sidebar's logo opens Chromium's app menu, and there is no Arc for
Windows top bar and no Alt+1 to Alt+9 (Option+digit types characters). The profile is
in `~/Library/Application Support/Arcomium`, Arcomium's own bundle ID; a profile from
older builds in `Chromium` there is moved on first start.

## Install

1. Download `arcomium_<version>_macos_arm64.dmg` from
   [Releases](https://github.com/VizzleTF/arcomium-mac/releases).
2. Open it and drag Arcomium to Applications.
3. Remove the quarantine flag. The app is signed without an Apple certificate, so macOS
   otherwise reports it as damaged:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Arcomium.app
   ```
4. Open Arcomium. To sync with your other devices, open `chrome://arcomium-sync`.

Updates do not install themselves: download the new dmg and repeat steps 2–3. The
current pre-release builds show no update notice, so check the Releases page by hand.
The app menu's "Update to Arcomium X.Y.Z" item (and Import from Another Browser) come
with the first macOS build on Chromium 157, and the notice offers only full releases,
never pre-releases.

## Build from source

### Requirements

- Apple Silicon Mac, about 150 GB of free disk space
- Xcode, and the Command Line Tools with macOS SDK 26.5
  (`/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`)
- `brew install python@3.13 ninja coreutils readline node esbuild typescript`
- `/opt/homebrew/bin/python3.13 -m pip install --break-system-packages PySocks httplib2`
- `xcodebuild -downloadComponent MetalToolchain`

### Build

```sh
git clone --recurse-submodules https://github.com/VizzleTF/arcomium-mac.git
cd arcomium-mac
python3 build.py --fast arm64
```

The browser is `ungoogled-chromium-macos/build/src/out/Default/Arcomium.app`. A first
`--fast` build takes about 5 hours on an M1 Max; without `--fast` it is an official,
optimized build (ThinLTO and PGO) and takes longer. `--fast` builds without LTO, PGO,
debug symbols, precompiled headers and Chromium's field trial testing config.

`build.py` adds the Arcomium patches, `arcomium/flags.gn` and the branding files to
ungoogled-chromium-macos, runs its `build.sh` with ad-hoc signing and Python 3.13, and
restores the submodule afterwards. Other arguments go to `build.sh`.

### Package

```sh
./package.sh v0.1.0
```

Signs the app ad hoc and writes
`ungoogled-chromium-macos/build/arcomium_v0.1.0_macos_arm64.dmg`. The bundles keep the
hardened runtime, but without a Developer ID library validation would reject the ad hoc
signed framework (the Team IDs differ), so they are signed without the `library` option
and with the `disable-library-validation` entitlement. The app is not notarized.
`package.sh` stops if Chromium's signing script changes upstream.

### Resume or rebuild

| Situation | Command |
|---|---|
| The build stopped after the sources were patched | `./resume.sh` (no patching; `NINJA_JOBS` sets the parallel jobs, 10 by default) |
| Rebuild after changing a source file | `./resume.sh` |

## Common build errors

| Error | Cause | Fix |
|---|---|---|
| `could not load TAPI file ... unknown target` while linking `bindgen` | Chromium 156's linker cannot read macOS SDK 27 | Install SDK 26.5 with the Command Line Tools; `build.py` and `resume.sh` pick it |
| `missing 'export module' declaration` in `precompile.h` | Precompiled headers in a non-official build | `--fast` turns them off; add `enable_precompiled_headers=false` to `args.gn` otherwise |

## Change the patches

Patches live in the `arcomium` submodule; see
[Writing and refreshing patches](https://github.com/VizzleTF/arcomium/blob/main/docs/patching.md).

## License

BSD-3-Clause.
