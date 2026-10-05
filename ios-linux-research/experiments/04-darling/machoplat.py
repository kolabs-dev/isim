#!/usr/bin/env python3
"""Rewrite the platform field of LC_BUILD_VERSION (and LC_VERSION_MIN_*) in x86_64 Mach-O slices.

DIAGNOSTIC TOOL ONLY. Used in experiments/04-darling to separate "dyld platform gate" failures
from deeper runtime failures. Binaries relabelled with this tool are NOT evidence of iOS
compatibility; outputs are always written to new, clearly suffixed files.

usage: machoplat.py <platform-number> <in> <out>
       machoplat.py --tree <platform-number> <dir>   (in place, every Mach-O under dir)
platform numbers: 1=macOS 2=iOS 7=iOS-simulator
"""
import os, struct, sys

LC_BUILD_VERSION = 0x32
LC_VERSION_MIN = {0x24: "macosx", 0x25: "iphoneos"}
MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
CPU_X86_64 = 0x01000007


def patch_slice(buf, off, plat):
    magic, cpu, _sub, _ft, ncmds, _sz, _fl, _r = struct.unpack_from("<8I", buf, off)
    if magic != MH_MAGIC_64 or cpu != CPU_X86_64:
        return 0
    p, n = off + 32, 0
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", buf, p)
        if cmd == LC_BUILD_VERSION:
            struct.pack_into("<I", buf, p + 8, plat); n += 1
        elif cmd in LC_VERSION_MIN:
            # macOS -> 0x24, iOS/iOS-sim -> 0x25 (x86_64 + iphoneos min == simulator)
            struct.pack_into("<I", buf, p, 0x24 if plat == 1 else 0x25); n += 1
        p += cmdsize
    return n


def patch_file(path_in, path_out, plat):
    with open(path_in, "rb") as f:
        buf = bytearray(f.read())
    if len(buf) < 32:
        return 0
    n = 0
    (m_be,) = struct.unpack_from(">I", buf, 0)
    if m_be == FAT_MAGIC:
        (nfat,) = struct.unpack_from(">I", buf, 4)
        for i in range(nfat):
            _cpu, _sub, off, _size, _al = struct.unpack_from(">5I", buf, 8 + 20 * i)
            n += patch_slice(buf, off, plat)
    else:
        n += patch_slice(buf, 0, plat)
    if n:
        with open(path_out, "wb") as f:
            f.write(buf)
        os.chmod(path_out, os.stat(path_in).st_mode)
    return n


if __name__ == "__main__":
    if sys.argv[1] == "--tree":
        plat, root, total = int(sys.argv[2]), sys.argv[3], 0
        for d, _, fs in os.walk(root):
            for fn in fs:
                fp = os.path.join(d, fn)
                if os.path.islink(fp) or not os.path.isfile(fp):
                    continue
                c = patch_file(fp, fp, plat)
                if c:
                    total += 1
        print(f"patched {total} Mach-O files under {root} to platform {plat}")
    else:
        c = patch_file(sys.argv[2], sys.argv[3], int(sys.argv[1]))
        print(f"{sys.argv[3]}: {c} load command(s) patched to platform {sys.argv[1]}")
