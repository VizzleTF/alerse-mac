# Arcomium for macOS

macOS builds of [Arcomium](https://github.com/VizzleTF/arcomium), an Arc-style browser
on ungoogled-chromium. This repository builds the
[arcomium](https://github.com/VizzleTF/arcomium) patch series on top of
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos);
both are git submodules.

Work in progress: the first builds are being brought up on Apple Silicon.

## Build from source

### Requirements

- Apple Silicon Mac, Xcode with the macOS SDK, about 120 GB of free disk space
- Homebrew packages: `brew install python@3.13 ninja coreutils readline node esbuild typescript`
- `/opt/homebrew/bin/python3.13 -m pip install --break-system-packages PySocks httplib2`
- Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`

### Build

```sh
git clone --recurse-submodules https://github.com/VizzleTF/arcomium-mac.git
cd arcomium-mac
python3 build.py
```

`build.py` adds the Arcomium patches, `arcomium/flags.gn` and the branding files to
ungoogled-chromium-macos, runs its `build.sh` with ad-hoc signing and Python 3.13, and
restores the submodule afterwards. Extra arguments go to `build.sh`; `-d` reuses the
downloaded sources.

## License

BSD-3-Clause.
