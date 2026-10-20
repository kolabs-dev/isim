"""ImageIO metadata (issue #272): ImageIOTest.app reads the EXIF / TIFF / GPS tags Pillow wrote into the fixtures
(make_fixtures.py) with their IPTC and XMP, works the CGImageMetadata model, and writes images with metadata. The
JPEG it writes is read here by Pillow, independently of isim."""
import base64
import io
import re

from PIL import Image

from isimtest import need_apps, selftest


def test_imageio(device_data):
    need_apps("ImageIOTest")
    r = selftest("ImageIOTest", data=device_data)
    m = re.search(r"WROTE-JPEG (\S+)", r.output)
    assert m, "the written JPEG"
    im = Image.open(io.BytesIO(base64.b64decode(m.group(1))))
    e = im.getexif()
    assert e[0x010F] == "Written" and e[0x0110] == "By isim" and e[0x0112] == 6, "IFD0: Make, Model, Orientation"
    x = e.get_ifd(0x8769)
    assert x[0x9003] == "2025:01:02 03:04:05" and abs(float(x[0x829D]) - 1.8) < 1e-6 and x[0x8827] == 200, "Exif IFD"
    assert abs(float(x[0x829A]) - 0.01) < 1e-9 and x[0x9000] == b"0232", "ExposureTime 1/100, ExifVersion"
    g = e.get_ifd(0x8825)
    lat = sum(float(v) / 60 ** i for i, v in enumerate(g[2]))
    assert g[1] == "N" and abs(lat - 48.8584) < 1e-4 and g[3] == "E" and abs(float(g[6]) - 35) < 1e-6, f"GPS IFD {g}"
    from PIL import IptcImagePlugin
    iptc = IptcImagePlugin.getiptcinfo(im)
    assert iptc[(2, 25)] == [b"a", b"b"] and iptc[(2, 90)] == b"Paris", f"IPTC {iptc}"
    assert im.size == (24, 16), "the image"
