# Arcomium for macOS

macOS builds of [Arcomium](https://github.com/VizzleTF/arcomium), an Arc-style browser
on ungoogled-chromium. This repository builds the
[arcomium](https://github.com/VizzleTF/arcomium) patch series on top of
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos);
both are git submodules.

Builds for Apple Silicon.

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

Updates do not install themselves: download the new dmg and repeat steps 2–3.

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
optimized build and takes longer.

`build.py` adds the Arcomium patches, `arcomium/flags.gn` and the branding files to
ungoogled-chromium-macos, runs its `build.sh` with ad-hoc signing and Python 3.13, and
restores the submodule afterwards. Other arguments go to `build.sh`.

### Package

```sh
./package.sh v0.1.0
```

Signs the app ad hoc and writes
`ungoogled-chromium-macos/build/arcomium_v0.1.0_macos_arm64.dmg`. Without a
Developer ID the bundles are signed without the hardened runtime: with it, macOS refuses
to load the ad hoc signed framework.

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
