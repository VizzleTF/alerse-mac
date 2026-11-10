<p align="center">
  <img src="https://raw.githubusercontent.com/VizzleTF/alerse/main/artwork/alerse_256.png" width="120" alt="The Alerse icon">
</p>

<h1 align="center">Alerse for macOS</h1>

<p align="center">The macOS build of Alerse, a sidebar browser for people moving from Arc.</p>

macOS builds of [Alerse](https://github.com/VizzleTF/alerse), an Arc-style browser on
ungoogled-chromium. This repository builds the
[alerse](https://github.com/VizzleTF/alerse) patch series on top of
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos);
both are git submodules.

Builds for Apple Silicon, on Chromium 156 until ungoogled-chromium-macos releases 157.
Builds are made locally, not in CI. Releases are pre-releases; up to 0.1.0 they were
`--fast` builds, from 0.1.7 official ones (ThinLTO and PGO).

On macOS Alerse keeps the platform's look, as Arc does there: the window buttons and
the menu bar stay, the sidebar's logo opens Chromium's app menu, and there is no Arc for
Windows top bar and no Alt+1 to Alt+9 (Option+digit types characters). The sidebar,
the Space bar, the command bar and the rest are the same on every platform; see
[Features](https://github.com/VizzleTF/alerse#features) and
[Differences from Arc](https://github.com/VizzleTF/alerse#differences-from-arc). The profile is
in `~/Library/Application Support/Alerse`, with Alerse's own bundle ID,
`io.github.vizzletf.alerse`.

A release before 0.1.8 is a different app: quit it and open Alerse, whose first start
moves its profile to `~/Library/Application Support/Alerse`, then drag the old app to the
Trash. See [Name](https://github.com/VizzleTF/alerse/blob/main/docs/design.md#name).

![Alerse on macOS: the Personal Space with pinned items, a Reading folder and favorites](https://raw.githubusercontent.com/VizzleTF/alerse/main/docs/images/sidebar.png)

## Install

1. Download `alerse_<version>_macos_arm64.dmg` from
   [Releases](https://github.com/VizzleTF/alerse-mac/releases).
2. Open it and drag Alerse to Applications.
3. Remove the quarantine flag. The app is signed without an Apple certificate, so macOS
   otherwise reports it as damaged:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Alerse.app
   ```
4. Open Alerse. To sync with your other devices, open `chrome://alerse-sync`.

Updates do not install themselves: download the new dmg and repeat steps 2–3. The
app menu's "Update to Alerse X.Y.Z" item offers only full releases, never
pre-releases, so while macOS builds are pre-releases check the Releases page by hand.
Import from Another Browser is in the app menu from 0.1.7.

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
git clone --recurse-submodules https://github.com/VizzleTF/alerse-mac.git
cd alerse-mac
python3 build.py --fast arm64
```

The browser is `ungoogled-chromium-macos/build/src/out/Default/Alerse.app`. A first
`--fast` build takes about 5 hours on an M1 Max; without `--fast` it is an official,
optimized build (ThinLTO and PGO) and takes longer. `--fast` builds without LTO, PGO,
debug symbols, precompiled headers and Chromium's field trial testing config.

`build.py` adds the Alerse patches, `alerse/flags.gn` and the branding files to
ungoogled-chromium-macos, runs its `build.sh` with ad-hoc signing and Python 3.13, and
restores the submodule afterwards. Other arguments go to `build.sh`.

### Release build next to a `--fast` tree

0.1.7 was built in the `--fast` tree's sources, in a second output directory with the
release flags: `out/Release/args.gn` is `out/Default/args.gn` without the `--fast`
block, with `mac_sdk_path = "//out/Release/sdk/selected_macos_sdk"` (a link to SDK
26.5). `gn gen out/Release`, then `ninja -C out/Release -j 10 chrome` took about
4 hours on an M1 Max (54,359 steps).

### Package

```sh
./package.sh v0.1.8                      # out/Default
OUT_DIR=out/Release ./package.sh v0.1.8  # an official build in out/Release
```

Signs the app ad hoc and writes
`ungoogled-chromium-macos/build/alerse_v0.1.8_macos_arm64.dmg`. The bundles keep the
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

Patches live in the `alerse` submodule; see
[Writing and refreshing patches](https://github.com/VizzleTF/alerse/blob/main/docs/patching.md).

## License

BSD-3-Clause.
