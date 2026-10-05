#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
compiler="${CLANG:-clang}"
command -v "$compiler" >/dev/null || { echo 'Missing Clang: set CLANG to its executable path.' >&2; exit 2; }
command -v python3 >/dev/null || { echo 'Missing Python 3.' >&2; exit 2; }
mkdir -p build
"$compiler" --version > build/compiler.txt
# iOS 15 is an experimental code-generation target, not an App Store SDK claim.
"$compiler" -target x86_64-apple-ios15.0-simulator -ffreestanding -fno-stack-protector -c probe.c -o build/simulator.o
"$compiler" -target arm64-apple-ios15.0 -ffreestanding -fno-stack-protector -c probe.c -o build/device.o
python3 - <<'PY'
import struct
from pathlib import Path
for name, cpu, platform in [('simulator', 0x01000007, 7), ('device', 0x0100000c, 2)]:
    data = Path(f'build/{name}.o').read_bytes()
    magic, actual_cpu, _, kind, ncmds, sizeofcmds, _, _ = struct.unpack_from('<8I', data)
    assert magic == 0xfeedfacf and actual_cpu == cpu and kind == 1, name
    offset = 32
    platforms = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<2I', data, offset)
        assert size >= 8 and offset + size <= 32 + sizeofcmds <= len(data)
        if cmd == 0x32:
            platforms.append(struct.unpack_from('<I', data, offset + 8)[0])
        offset += size
    assert offset == 32 + sizeofcmds and platforms == [platform], (name, platforms)
    print(f'PASS: {name} is a Mach-O object with expected CPU and platform.')
print('Object generation only: linking, execution, UIKit, signing and upload remain unproven.')
PY
