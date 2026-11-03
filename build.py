#!/usr/bin/env python3
"""Build Arcomium for macOS: ungoogled-chromium-macos + Arcomium patches.

Injects the patches of the arcomium submodule into ungoogled-chromium-macos'
patch series, arcomium/flags.gn into its GN flags and a step that copies
arcomium/branding over the source tree after patching, runs the upstream
build.sh with ad-hoc signing, then restores the submodule. Extra arguments go
to the upstream build.sh (for example `-d` to reuse the downloaded sources).
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

# Inserted into the upstream build.sh after its patches: binary branding files
# cannot travel in patches.
BRANDING_ANCHOR = 'python3 "$_main_repo/utils/domain_substitution.py"'
BRANDING_STEP = 'cp -R {branding!r}/. "$_src_dir/"\n'

# depot_tools needs Python 3.13 or older; Homebrew's python3 may be newer.
PYTHON = '/opt/homebrew/bin/python3.13'


def read_series(path):
    lines = path.read_text(encoding='utf-8').splitlines()
    return [line.strip() for line in lines if line.strip() and not line.startswith('#')]


def main():
    if not Path(PYTHON).exists():
        sys.exit(f'{PYTHON} not found: brew install python@3.13')
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
        if OUR_FLAGS.exists():
            flags.write_text(originals[flags].rstrip('\n') + '\n' +
                             OUR_FLAGS.read_text(encoding='utf-8'), encoding='utf-8')
        if OUR_BRANDING.exists():
            text = originals[upstream_build]
            if BRANDING_ANCHOR not in text:
                sys.exit('upstream build.sh changed: cannot add the branding step')
            step = BRANDING_STEP.format(branding=str(OUR_BRANDING))
            upstream_build.write_text(text.replace(BRANDING_ANCHOR, step + BRANDING_ANCHOR, 1),
                                      encoding='utf-8')

        with tempfile.TemporaryDirectory() as shims:
            os.symlink(PYTHON, Path(shims) / 'python3')
            env = dict(os.environ)
            env['PATH'] = os.pathsep.join([shims, '/opt/homebrew/bin', env.get('PATH', '')])
            env.setdefault('MACOS_AD_HOC_SIGNING', '1')
            cmd = ['./build.sh', *sys.argv[1:]]
            return subprocess.run(cmd, cwd=UPSTREAM, env=env, check=False).returncode
    finally:
        for path, text in originals.items():
            path.write_text(text, encoding='utf-8')
        shutil.rmtree(injected, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
