"""Core Image (HelloCoreImage): the gallery pages as screenshots. The filters page (photo filters), the generators
page (its QR, Aztec, Code 128 and PDF417 symbols must decode with zxing-cpp's ZXingReader from the screenshot) and
the kernels page (kernels, the face detector's box, RAW, ...)."""
import shutil
import subprocess

import pytest
from PIL import Image
from isimtest import TIMEOUT, rgb


def page(launch, name):
    app = launch("HelloCoreImage", env={"HELLOCI_PAGE": name})
    app.wait_log(rf"ci page {name} shown", timeout=TIMEOUT * 3)
    app.wait_shot_still()
    return app


def colorful(s, box):
    """a tile drew something: several distinct colors in it"""
    x0, y0, x1, y1 = box
    seen = {rgb(s, x, y) for x in range(x0, x1, 9) for y in range(y0, y1, 9)}
    return len(seen) > 8


def test_filters_page(launch):
    app = page(launch, "filters")
    s = app.screenshot()
    w = s.width
    # the 15 tiles (3 columns, 5 rows) each show a filtered photo
    for i in range(15):
        x, y = 16 + (i % 3) * 128, 96 + (i // 3) * 146
        assert colorful(s, (x + 10, y + 10, x + 106, y + 106)), f"tile {i} drawn ({w} px wide)"
    assert app.quit() == 0


@pytest.mark.skipif(not shutil.which("ZXingReader"), reason="decoding the symbols needs ZXingReader (zxing-cpp-tools)")
def test_generators_page(launch, tmp_path):
    app = page(launch, "generators")
    s = app.screenshot()
    log = app.log
    assert "ci generators qr 0,0,27x27 aztec 0,0,21x21 code128 0,0,93x32 pdf417 0,0,107x25" in log
    # each symbol's tile, enlarged (screenshots are 1 px per point; the symbols use about one point per module)
    want = {0: ("QRCode", "https://isim.dev"), 1: ("Aztec", "isim aztec"), 2: ("Code128", "isim"), 3: ("PDF417", "isim417")}
    for i, (fmt, text) in want.items():
        x, y = 16 + (i % 3) * 128, 96 + (i // 3) * 146
        tile = tmp_path / f"tile{i}.png"
        s.crop((x - 4, y - 4, x + 120, y + 120)).resize((124 * 4, 124 * 4), Image.NEAREST).save(tile)
        out = subprocess.run(["ZXingReader", "-format", fmt, str(tile)], capture_output=True, text=True).stdout
        assert f'Text:       "{text}"' in out, f"{fmt} decodes: {out}"
    assert app.quit() == 0


def test_kernels_page(launch):
    app = page(launch, "kernels")
    assert app.wait_log(r"ci kernels page tiles (\d+)/12").group(1) == "12", "every kernel / detector tile has an image"
    s = app.screenshot()
    for i in range(12):
        x, y = 16 + (i % 3) * 128, 96 + (i // 3) * 146
        assert colorful(s, (x + 10, y + 10, x + 106, y + 106)) or i in (8, 10), f"tile {i} drawn"   # histogram, RAW: flat areas
    assert app.quit() == 0
