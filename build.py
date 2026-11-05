#!/usr/bin/env python3
"""Build Arcomium for macOS: ungoogled-chromium-macos + Arcomium patches.

Injects the patches of the arcomium submodule into ungoogled-chromium-macos'
patch series, arcomium/flags.gn into its GN flags and a step that copies
arcomium/src and arcomium/branding over the source tree after patching, runs the upstream
build.sh with ad-hoc signing, then restores the submodule. Extra arguments go
to the upstream build.sh (for example `-d` to reuse the downloaded sources).

  --fast   a quicker local build: no LTO, PGO or debug symbols

Chromium 156's linker cannot read the libraries of macOS SDK 27, so the build
uses SDK 26.5 from the Command Line Tools when it is installed, unless `-s`
names another one.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
UPSTREAM = ROOT / 'ungoogled-chromium-macos'
CORE = ROOT / 'arcomium'
OUR_PATCHES = CORE / 'patches'
OUR_FLAGS = CORE / 'flags.gn'
OUR_BRANDING = CORE / 'branding'
OUR_SOURCES = CORE / 'src'

OUR_RENAME = CORE / 'tools' / 'rename_product.py'

# Inserted into the upstream build.sh after its patches: Arcomium's own source
# files and binary branding files are copied over the tree, not patched in, and
# renaming the product in the strings moves hundreds of translations, which a
# script does better than a patch.
BRANDING_ANCHOR = 'python3 "$_main_repo/utils/domain_substitution.py"'
BRANDING_STEP = ('cp -R {sources!r}/. "$_src_dir/"\n'
                 'cp -R {branding!r}/. "$_src_dir/"\n'
                 'python3 {rename!r} "$_src_dir"\n')

# depot_tools needs Python 3.13 or older; Homebrew's python3 may be newer.
PYTHON = '/opt/homebrew/bin/python3.13'

# Chromium 156's official SDK; its lld rejects the .tbd files of SDK 27.
DEFAULT_SDK = Path('/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk')

FAST_FLAGS = """
# --fast: a quicker local build; releases use the flags above.
is_official_build=false
use_thin_lto=false
chrome_pgo_phase=0
symbol_level=0
blink_symbol_level=0
enable_precompiled_headers=false
disable_fieldtrial_testing_config=true
"""


def read_series(path):
    lines = path.read_text(encoding='utf-8').splitlines()
    return [line.strip() for line in lines if line.strip() and not line.startswith('#')]


def main():
    if not Path(PYTHON).exists():
        sys.exit(f'{PYTHON} not found: brew install python@3.13')
    args = sys.argv[1:]
    fast = '--fast' in args
    args = [a for a in args if a != '--fast']
    if '-s' not in args and DEFAULT_SDK.exists():
        args = ['-s', str(DEFAULT_SDK), *args]
    series = UPSTREAM / 'patches' / 'series'
    flags = UPSTREAM / 'flags.macos.gn'
    upstream_build = UPSTREAM / 'build.sh'
    injected = UPSTREAM / 'patches' / 'arcomium'
    originals = {p: p.read_text(encoding='utf-8')
                 for p in (series, flags, upstream_build)}

    try:
        if injected.exists():
            shutil.rmtree(injected)
        shutil.copytree(OUR_PATCHES, injected)
        ours = ['arcomium/' + p for p in read_series(OUR_PATCHES / 'series')]
        series.write_text(originals[series].rstrip('\n') + '\n' + '\n'.join(ours) + '\n',
                          encoding='utf-8')
        extra = OUR_FLAGS.read_text(encoding='utf-8') if OUR_FLAGS.exists() else ''
        if fast:
            extra += FAST_FLAGS
        flags.write_text(originals[flags].rstrip('\n') + '\n' + extra, encoding='utf-8')
        if OUR_BRANDING.exists():
            text = originals[upstream_build]
            if BRANDING_ANCHOR not in text:
                sys.exit('upstream build.sh changed: cannot add the branding step')
            step = BRANDING_STEP.format(sources=str(OUR_SOURCES), branding=str(OUR_BRANDING),
                                        rename=str(OUR_RENAME))
            upstream_build.write_text(text.replace(BRANDING_ANCHOR, step + BRANDING_ANCHOR, 1),
                                      encoding='utf-8')

        with tempfile.TemporaryDirectory() as shims:
            os.symlink(PYTHON, Path(shims) / 'python3')
            env = dict(os.environ)
            env['PATH'] = os.pathsep.join([shims, '/opt/homebrew/bin', env.get('PATH', '')])
            env.setdefault('MACOS_AD_HOC_SIGNING', '1')
            cmd = ['./build.sh', *args]
            return subprocess.run(cmd, cwd=UPSTREAM, env=env, check=False).returncode
    finally:
        for path, text in originals.items():
            path.write_text(text, encoding='utf-8')
        shutil.rmtree(injected, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
