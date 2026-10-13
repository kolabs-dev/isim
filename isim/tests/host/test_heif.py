"""isim's HEIF (HEIC) reader and writer (runtime/host_heif.c), compiled with a small driver: a picture written as HEIC
(ffmpeg's libx265 codes the HEVC frame, isim writes the container) decodes back to the same colours and size (an odd
width is padded for 4:2:0 and cropped again by the clean aperture); a grid of two tiles with a rotation — the layout
iPhones write — decodes to the composed, rotated picture; libheif, when installed, accepts the files isim writes."""
import ctypes
import shutil
import struct
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg") or not shutil.which("cc"), reason="needs ffmpeg and a C compiler")

DRIVER = r"""
#include <stdio.h>
#include <stdlib.h>
long isim_heif_encode_bgra(const unsigned char *bgra, int w, int h, int stride, double quality, unsigned char **out);
int isim_heif_decode(const void *data, long len, int *w, int *h, unsigned char **rgba);
int isim_heif_can_encode(void);
int main(int argc, char **argv) {
    if (argv[1][0] == 'e') {                       /* e W H OUT: left half red, right half blue */
        int w = atoi(argv[2]), h = atoi(argv[3]);
        unsigned char *px = malloc((size_t)w * h * 4);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            unsigned char *p = px + ((size_t)y * w + x) * 4; p[0] = x < w / 2 ? 0 : 255; p[1] = 0; p[2] = x < w / 2 ? 255 : 0; p[3] = 255;
        }
        unsigned char *out; long n = isim_heif_encode_bgra(px, w, h, w * 4, 0.9, &out);
        if (n <= 0) { printf("noencoder\n"); return 0; }
        FILE *f = fopen(argv[4], "wb"); fwrite(out, 1, (size_t)n, f); fclose(f);
        printf("encoded %ld\n", n);
        return 0;
    }
    FILE *f = fopen(argv[2], "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char *d = malloc((size_t)n); if (fread(d, 1, (size_t)n, f) != (size_t)n) return 1; fclose(f);
    int w, h; unsigned char *rgba;
    if (!isim_heif_decode(d, n, &w, &h, &rgba)) { printf("nodecode\n"); return 0; }
    printf("%dx%d", w, h);
    for (int i = 3; i + 1 < argc; i += 2) { unsigned char *p = rgba + ((size_t)atoi(argv[i + 1]) * w + atoi(argv[i])) * 4; printf(" %d,%d,%d", p[0], p[1], p[2]); }
    printf("\n");
    return 0;
}
"""


@pytest.fixture(scope="module")
def tool(tmp_path_factory):
    d = tmp_path_factory.mktemp("heif")
    (d / "driver.c").write_text(DRIVER)
    subprocess.run(["cc", "-O1", "-o", str(d / "heif"), str(d / "driver.c"), str(ROOT / "runtime" / "host_heif.c")], check=True)
    return d


def run(tool, *args):
    return subprocess.run([str(tool / "heif"), *map(str, args)], capture_output=True, text=True, check=True).stdout.strip()


def color(s):
    r, g, b = map(int, s.split(","))
    return "red" if r > 200 and g < 60 and b < 60 else "blue" if b > 200 and r < 60 and g < 60 else s


def libheif_size(path):
    try:
        lib = ctypes.CDLL("libheif.so.1")
    except OSError:
        return None

    class Err(ctypes.Structure):
        _fields_ = [("code", ctypes.c_int), ("subcode", ctypes.c_int), ("message", ctypes.c_char_p)]
    lib.heif_context_alloc.restype = ctypes.c_void_p
    lib.heif_context_read_from_file.restype = Err
    lib.heif_context_read_from_file.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_void_p]
    lib.heif_context_get_primary_image_handle.restype = Err
    lib.heif_context_get_primary_image_handle.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
    lib.heif_image_handle_get_width.argtypes = lib.heif_image_handle_get_height.argtypes = [ctypes.c_void_p]
    ctx = lib.heif_context_alloc()
    assert lib.heif_context_read_from_file(ctx, str(path).encode(), None).code == 0, "libheif reads the file"
    h = ctypes.c_void_p()
    assert lib.heif_context_get_primary_image_handle(ctx, ctypes.byref(h)).code == 0
    return lib.heif_image_handle_get_width(h), lib.heif_image_handle_get_height(h)


@pytest.mark.parametrize("w,h", [(100, 60), (101, 61), (10, 6)])
def test_heif_round_trip(tool, tmp_path, w, h):
    out = tmp_path / "t.heic"
    if run(tool, "e", w, h, out) == "noencoder":
        pytest.skip("no libx265 in the host's ffmpeg")
    data = out.read_bytes()
    assert data[4:12] == b"ftypheic", "a HEIC file"
    res = run(tool, "d", out, 1, 1, w - 2, h - 2).split()
    assert res[0] == f"{w}x{h}", "decodes at the original size (clean aperture crops the padding)"
    assert color(res[1]) == "red" and color(res[2]) == "blue", "colours survive"
    size = libheif_size(out)
    if size:
        assert size in ((w, h), (max(16, w + w % 2), max(16, h + h % 2))), "libheif reads isim's container"


def box(t, payload):
    return struct.pack(">I", 8 + len(payload)) + t + payload


def full(t, v, f, payload):
    return box(t, struct.pack(">I", v << 24 | f) + payload)


def find(d, path):
    off = 0
    while off < len(d):
        n, t = struct.unpack(">I4s", d[off:off + 8])
        if t == path[0]:
            return d[off + 8:off + n] if len(path) == 1 else find(d[off + 8:off + n], path[1:])
        off += n


def hevc_tile(tmp_path, colour):
    mp4 = tmp_path / f"{colour}.mp4"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", f"color=c={colour}:s=64x64", "-frames:v", "1",
                    "-c:v", "libx265", "-x265-params", "log-level=none", "-tag:v", "hvc1", "-pix_fmt", "yuv420p", str(mp4)], check=True)
    d = mp4.read_bytes()
    stbl = find(d, [b"moov", b"trak", b"mdia", b"minf", b"stbl"])
    hvcc = find(find(find(stbl, [b"stsd"])[8:], [b"hvc1"])[78:], [b"hvcC"])
    stsz = find(stbl, [b"stsz"])
    size = struct.unpack(">I", stsz[4:8])[0] or struct.unpack(">I", stsz[12:16])[0]
    off = struct.unpack(">I", find(stbl, [b"stco"])[8:12])[0]
    return hvcc, d[off:off + size]


def test_heif_grid_rotation(tool, tmp_path):
    if run(tool, "e", 64, 64, tmp_path / "probe.heic") == "noencoder":
        pytest.skip("no libx265 in the host's ffmpeg")
    (hvcc, red), (_, blue) = hevc_tile(tmp_path, "red"), hevc_tile(tmp_path, "blue")
    grid = struct.pack(">BBBBHH", 0, 0, 0, 1, 100, 64)               # 1 row, 2 columns, 100x64 output (the second tile cropped)

    def infe(i, t):
        return full(b"infe", 2, 0, struct.pack(">HH", i, 0) + t + b"\0")
    iinf = full(b"iinf", 0, 0, struct.pack(">H", 3) + infe(1, b"grid") + infe(2, b"hvc1") + infe(3, b"hvc1"))
    iref = full(b"iref", 0, 0, box(b"dimg", struct.pack(">HHHH", 1, 2, 2, 3)))
    ipco = box(b"ipco", box(b"hvcC", hvcc) + full(b"ispe", 0, 0, struct.pack(">II", 64, 64)) + full(b"ispe", 0, 0, struct.pack(">II", 100, 64))
               + box(b"irot", b"\x01"))
    ipma = full(b"ipma", 0, 0, struct.pack(">I", 3) + struct.pack(">HBBB", 1, 2, 3, 0x84) + struct.pack(">HBBB", 2, 2, 0x81, 2)
                + struct.pack(">HBBB", 3, 2, 0x81, 2))

    def build(base):
        iloc = full(b"iloc", 1, 0, bytes([0x44, 0x00]) + struct.pack(">H", 3)
                    + struct.pack(">HHHH", 1, 1, 0, 1) + struct.pack(">II", 0, len(grid))          # the grid descriptor in idat
                    + struct.pack(">HHHH", 2, 0, 0, 1) + struct.pack(">II", base, len(red))
                    + struct.pack(">HHHH", 3, 0, 0, 1) + struct.pack(">II", base + len(red), len(blue)))
        meta = full(b"meta", 0, 0, full(b"hdlr", 0, 0, b"\0" * 4 + b"pict" + b"\0" * 13) + full(b"pitm", 0, 0, struct.pack(">H", 1))
                    + iloc + iinf + iref + box(b"iprp", ipco + ipma) + box(b"idat", grid))
        return box(b"ftyp", b"heic\0\0\0\0mif1heic") + meta
    head = build(len(build(0)) + 8)
    path = tmp_path / "grid.heic"
    path.write_bytes(head + box(b"mdat", red + blue))
    res = run(tool, "d", path, 10, 10, 10, 90).split()
    # 100x64 turned a quarter anticlockwise: 64x100, the blue tile on top, the red one below
    assert res[0] == "64x100" and color(res[1]) == "blue" and color(res[2]) == "red", f"grid composed and rotated: {res}"
