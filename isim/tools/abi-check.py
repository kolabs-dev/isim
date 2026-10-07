#!/usr/bin/env python3
"""ABI check: every symbol exported by a released isim SDK must still be exported by this build, so apps
built with an older isim keep running.

  abi-check.py [SDK_DIR]            compare SDK_DIR (default out/sdk) with every abi/v*.txt.gz baseline
  abi-check.py --record VER [SDK]   write abi/vVER.txt.gz from SDK_DIR (run on the release tarball's sdk/)

Baselines list "<binary path inside the SDK> <symbol>" for the dylibs under usr/lib and the framework binaries
under System/Library/Frameworks. abi/allowlist.txt names symbols that were deliberately dropped (one
"<binary path> <symbol>" per line, '#' comments say why); keep it short."""
import gzip, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ABI = os.path.join(ROOT, 'abi')


def binaries(sdk):
    for top in ('usr/lib', 'System/Library/Frameworks'):
        for d, _, files in os.walk(os.path.join(sdk, top)):
            for f in files:
                p = os.path.join(d, f)
                if os.path.islink(p):
                    continue
                if f.endswith('.dylib') or ('.' not in f and d.endswith('.framework') and f == os.path.basename(d)[:-10]):
                    yield os.path.relpath(p, sdk)


def exports(sdk):
    out = set()
    for rel in sorted(binaries(sdk)):
        r = subprocess.run(['llvm-nm', '-gU', '--defined-only', '-j', os.path.join(sdk, rel)],
                           capture_output=True, text=True)
        out.update(f'{rel} {s}' for s in r.stdout.split())
    return out


def main(argv):
    if argv[:1] == ['--record']:
        ver, sdk = argv[1], (argv[2] if len(argv) > 2 else os.path.join(ROOT, 'out', 'sdk'))
        syms = exports(sdk)
        path = os.path.join(ABI, f'v{ver}.txt.gz')
        with gzip.open(path, 'wt') as f:
            f.write(''.join(s + '\n' for s in sorted(syms)))
        print(f'abi: recorded {len(syms)} symbols -> {os.path.relpath(path, ROOT)}')
        return 0
    sdk = argv[0] if argv else os.path.join(ROOT, 'out', 'sdk')
    allow = set()
    ap = os.path.join(ABI, 'allowlist.txt')
    if os.path.exists(ap):
        allow = {l.split('#')[0].strip() for l in open(ap) if l.split('#')[0].strip()}
    now = exports(sdk)
    bad = 0
    for name in sorted(os.listdir(ABI)):
        if not name.endswith('.txt.gz'):
            continue
        with gzip.open(os.path.join(ABI, name), 'rt') as f:
            base = {l.rstrip('\n') for l in f if l.strip()}
        missing = sorted(base - now - allow)
        print(f'abi {name[:-7]}: {len(base)} symbols, {len(missing)} missing')
        for m in missing[:40]:
            print(f'  MISSING {m}')
        if len(missing) > 40:
            print(f'  ... and {len(missing) - 40} more')
        bad += len(missing)
    print('abi check: ' + ('OK' if not bad else f'FAILED ({bad} missing; restore them or justify in abi/allowlist.txt)'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
