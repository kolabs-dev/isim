#!/usr/bin/env python3
"""Writes HelloCoreImage's RAW fixture: a small uncompressed Bayer (RGGB) DNG, made here (no camera image):
96x64 sensor pixels, 12-bit, of a synthetic scene (a white patch, a warm gradient, four color bars) lit by a
5000 K illuminant. The camera's primaries are sRGB's (ColorMatrix1 is XYZ -> linear sRGB), AsShotNeutral is the
illuminant, so a correct decode has a neutral white patch and an as-shot temperature near 5000 K.
Usage: gen_dng.py OUT.dng"""
import struct
import sys

W, H = 96, 64
XYZ_TO_SRGB = (3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560, 0.0556434, -0.2040259, 1.0572252)


def illuminant(T):
    """linear sRGB color of a blackbody at T kelvin (Kim et al.'s Planckian locus), green = 1"""
    t = 1e3 / T
    x = -0.2661239 * t**3 - 0.2343589 * t**2 + 0.8776956 * t + 0.179910 if T <= 4000 else \
        -3.0258469 * t**3 + 2.1070379 * t**2 + 0.2226347 * t + 0.240390
    y = -0.9549476 * x**3 - 1.37418593 * x**2 + 2.09137015 * x - 0.16748867 if T <= 4000 else \
        3.0817580 * x**3 - 5.87338670 * x**2 + 3.75112997 * x - 0.37001483
    X, Y, Z = x / y, 1.0, (1 - x - y) / y
    m = XYZ_TO_SRGB
    rgb = [m[0] * X + m[1] * Y + m[2] * Z, m[3] * X + m[4] * Y + m[5] * Z, m[6] * X + m[7] * Y + m[8] * Z]
    return [c / rgb[1] for c in rgb]


def scene(x, y):
    """surface reflectance (linear sRGB)"""
    if x < 16 and y < 16:
        return (0.8, 0.8, 0.8)
    if x < W // 2:
        t = x / (W / 2)
        return (0.6 * t + 0.05, 0.35 * t + 0.05, 0.15 * t + 0.05)
    return [(0.7, 0.1, 0.1), (0.1, 0.6, 0.1), (0.1, 0.1, 0.7), (0.6, 0.6, 0.1)][(y * 4) // H]


def main(out):
    light = illuminant(5000)
    peak = max(light)
    pix = bytearray()
    for y in range(H):
        for x in range(W):
            c = [0, 1, 1, 2][(y % 2) * 2 + (x % 2)]           # RGGB
            v = scene(x, y)[c] * light[c] / peak
            pix += struct.pack('<H', min(4095, int(v * 3800 + 64)))
    entries = []

    def add(tag, typ, vals):
        entries.append((tag, typ, vals))

    def rat(n, d=10000):
        return (int(round(n * d)), d)
    model = b'isim Test Sensor\0'
    add(254, 4, [0]); add(256, 4, [W]); add(257, 4, [H]); add(258, 3, [16]); add(259, 3, [1]); add(262, 3, [32803])
    add(271, 2, b'isim\0'); add(272, 2, model); add(273, 4, [0]); add(274, 3, [1]); add(277, 3, [1]); add(278, 4, [H])
    add(279, 4, [len(pix)]); add(284, 3, [1]); add(305, 2, b'isim test fixture\0'); add(306, 2, b'2026:10:13 12:00:00\0')
    add(33421, 3, [2, 2]); add(33422, 1, [0, 1, 1, 2])
    add(33434, 5, [(1, 60)]); add(33437, 5, [(28, 10)])
    add(50706, 1, [1, 4, 0, 0]); add(50707, 1, [1, 1, 0, 0]); add(50708, 2, model)
    add(50714, 3, [64]); add(50717, 3, [4095])
    add(50721, 10, [rat(v) for v in XYZ_TO_SRGB])          # ColorMatrix1
    add(50728, 5, [rat(v) for v in light])                 # AsShotNeutral
    add(50778, 3, [21])                                    # CalibrationIlluminant1: D65
    entries.sort()
    data_off = 8 + 2 + len(entries) * 12 + 4
    blobs, ifd, pix_slot = bytearray(), bytearray(), None
    for tag, typ, vals in entries:
        if typ == 2:
            raw = bytes(vals); cnt = len(raw)
        elif typ in (5, 10):
            raw = b''.join(struct.pack('<ii' if typ == 10 else '<II', a, b) for a, b in vals); cnt = len(vals)
        else:
            raw = b''.join(struct.pack({1: '<B', 3: '<H', 4: '<I'}[typ], v) for v in vals); cnt = len(vals)
        if tag == 273:
            pix_slot = len(ifd) + 8
        if len(raw) <= 4:
            field = raw.ljust(4, b'\0')
        else:
            field = struct.pack('<I', data_off + len(blobs)); blobs += raw
            if len(blobs) % 2:
                blobs += b'\0'
        ifd += struct.pack('<HHI', tag, typ, cnt) + field
    ifd[pix_slot:pix_slot + 4] = struct.pack('<I', data_off + len(blobs))
    with open(out, 'wb') as f:
        f.write(b'II*\0' + struct.pack('<IH', 8, len(entries)) + bytes(ifd) + b'\0\0\0\0' + bytes(blobs) + bytes(pix))


if __name__ == '__main__':
    main(sys.argv[1])
