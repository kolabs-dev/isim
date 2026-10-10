"""Renders isim's app icon (icons/*.svg) to the hicolor PNG sizes with librsvg and cairo, the libraries the runtime
already links (no rsvg-convert or ImageMagick SVG support needed):

    python3 buildlib/icons.py icons/isim.svg icons/isim-small.svg OUT_DIR

writes OUT_DIR/<N>x<N>/apps/dev.isim.Simulator.png for every size in SIZES (the small variant up to SMALL_MAX px) and
OUT_DIR/scalable/apps/dev.isim.Simulator.svg."""
import ctypes
import ctypes.util
import os
import shutil
import sys

APP_ID = "dev.isim.Simulator"
SIZES = (16, 24, 32, 48, 64, 128, 256, 512)
SMALL_MAX = 32                     # isim-small.svg up to this size, isim.svg above


class RsvgRectangle(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double), ("width", ctypes.c_double), ("height", ctypes.c_double)]


def _lib(name, soname):
    return ctypes.CDLL(ctypes.util.find_library(name) or soname)


def render(svg, size, png):
    rsvg, cairo, gobject = _lib("rsvg-2", "librsvg-2.so.2"), _lib("cairo", "libcairo.so.2"), _lib("gobject-2.0", "libgobject-2.0.so.0")
    rsvg.rsvg_handle_new_from_file.restype = ctypes.c_void_p
    rsvg.rsvg_handle_new_from_file.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
    rsvg.rsvg_handle_render_document.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(RsvgRectangle), ctypes.c_void_p]
    cairo.cairo_image_surface_create.restype = ctypes.c_void_p
    cairo.cairo_create.restype = ctypes.c_void_p
    cairo.cairo_create.argtypes = [ctypes.c_void_p]
    cairo.cairo_destroy.argtypes = [ctypes.c_void_p]
    cairo.cairo_surface_write_to_png.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    cairo.cairo_surface_destroy.argtypes = [ctypes.c_void_p]
    gobject.g_object_unref.argtypes = [ctypes.c_void_p]

    handle = rsvg.rsvg_handle_new_from_file(svg.encode(), None)
    if not handle:
        raise SystemExit(f"icons.py: librsvg cannot read {svg}")
    surface = cairo.cairo_image_surface_create(0, size, size)          # CAIRO_FORMAT_ARGB32, transparent
    cr = cairo.cairo_create(surface)
    ok = rsvg.rsvg_handle_render_document(handle, cr, ctypes.byref(RsvgRectangle(0, 0, size, size)), None)
    cairo.cairo_destroy(cr)
    status = cairo.cairo_surface_write_to_png(surface, png.encode()) if ok else -1
    cairo.cairo_surface_destroy(surface)
    gobject.g_object_unref(handle)
    if status != 0:
        raise SystemExit(f"icons.py: cannot render {svg} at {size} px to {png}")


def outputs(out):
    """every file main() writes (the build graph's outputs)"""
    return [f"{out}/{s}x{s}/apps/{APP_ID}.png" for s in SIZES] + [f"{out}/scalable/apps/{APP_ID}.svg"]


def main(argv):
    big, small, out = argv
    for s in SIZES:
        d = os.path.join(out, f"{s}x{s}", "apps")
        os.makedirs(d, exist_ok=True)
        render(small if s <= SMALL_MAX else big, s, os.path.join(d, f"{APP_ID}.png"))
    d = os.path.join(out, "scalable", "apps")
    os.makedirs(d, exist_ok=True)
    shutil.copyfile(big, os.path.join(d, f"{APP_ID}.svg"))


if __name__ == "__main__":
    main(sys.argv[1:])
