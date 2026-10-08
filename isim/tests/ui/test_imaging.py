"""ImageIO, Core Image and UIImage extras (HelloImaging): animated GIF written and read back (frames, delays, loop
count) and played by UIImageView, PNG/JPEG destinations and thumbnails, EXIF orientation, Core Image filters /
generators / compositing on the CPU, a QR code (decoded with zbarimg when the host has it), nine-slice resizable
images, flipped and rotated orientations, UIImageView.animationImages. Port of tests/ui/imaging.sh."""
import re
import shutil
import subprocess

import pytest
from isimtest import close, rgb


@pytest.fixture(scope="module")
def imaging(launch_module, tmp_path_factory):
    data = tmp_path_factory.mktemp("imaging")
    app = launch_module("HelloImaging")
    app.wait_log(r"animationImages \d+ animating")
    app.wait_log(r"rotated orientation")
    a = app.wait_shot(lambda s: close(s, 20, 344, (255, 0, 0)) and close(s, 88, 80, (0, 0, 255), 5000), "drawn")
    app.sleep(0.25)                                       # the GIF and animationImages advance a frame (0.25 s)
    b = app.screenshot()
    app.sleep(0.25)
    c = app.screenshot()
    app.view_dump()
    rc = app.quit()
    return app.log, rc, a, b, c, data


def test_imageio(imaging):
    log, rc, a, b, c, _ = imaging
    assert rc == 0, "exits cleanly"
    assert "gif finalize true GIF89a" in log, "GIF destination (3 frames)"
    assert "gif type com.compuserve.gif count 3 size 40x40 delay 0.25 loop 0" in log, \
        "GIF source: count, size, delay, loop"
    assert "gif frame colors [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255]]" in log, "GIF frames decoded"
    assert "animated image frames 3 duration 0.75 playing true" in log and \
        rgb(a, 41, 99) != rgb(b, 41, 99) and rgb(b, 41, 99) != rgb(c, 41, 99), "animated UIImage plays in UIImageView"
    assert re.search(r"png type public.png 64x32 alpha [01] thumb 16x8", log), "PNG destination + properties + thumbnail"
    assert re.search(r"jpeg true type public.jpeg pixel \[1[0-9][0-9], [0-9], 1[0-9][0-9], 255\]", log), \
        "JPEG destination"
    assert re.search(r"exif orientation 6 raw 8x4 upright 4x8 top \[[0-9], [0-9], 2[0-9][0-9], 255\] "
                     r"bottom \[2[0-9][0-9], [0-9], [0-9], 255\]", log) and \
        close(a, 88, 80, (0, 0, 255), 5000) and close(a, 88, 118, (255, 0, 0), 5000), \
        "EXIF orientation + thumbnail transform"
    assert "junk count 0 status -3" in log, "unknown data"


def test_core_image(imaging):
    log, _, a, *_ = imaging
    assert "ciimage extent (0.0, 0.0, 60.0, 60.0)" in log, "Core Image extent"
    assert "ci sepia top [199, 177, 138, 255]" in log and close(a, 46, 140, (199, 177, 138)), "CISepiaTone"
    assert "ci mono top [146, 146, 146, 255] bottom [120, 120, 120, 255]" in log, "CIColorControls saturation 0"
    assert "ci invert top [0, 127, 255, 255] bottom [255, 102, 102, 255]" in log and \
        close(a, 178, 140, (0, 127, 255)), "CIColorInvert (CIFilter(name:))"
    assert re.search(r"ci blur top .* edge \[1[0-9][0-9], 1[0-9][0-9], [0-9]+, 255\]", log), \
        "CIGaussianBlur mixes the halves"
    assert re.search(r"ci noir top \[([0-9]+), \1, \1, 255\]", log), "CIPhotoEffectNoir"
    assert "ci composite 60x60 corner [51, 51, 51, 255] center [153, 26, 26, 255]" in log, \
        "generator + compositing + UIImage(ciImage:)"
    assert "ci transformed extent (0.0, 0.0, 30.0, 30.0)" in log and "has blur true" in log, \
        "transform + builtin filter names"
    assert "qr extent (0.0, 0.0, 27.0, 27.0)" in log, "CIQRCodeGenerator (27 modules incl. border)"


@pytest.mark.skipif(not shutil.which("zbarimg"), reason="QR decode needs zbarimg on the host")
def test_qr_decodes(imaging):
    *_, a, _b, _c, data = imaging
    qr = data / "qr.png"
    a.crop((76, 194, 196, 314)).resize((360, 360)).save(qr)
    out = subprocess.run(["zbarimg", "-q", "--raw", str(qr)], capture_output=True, text=True).stdout.strip()
    assert out == "https://isim.dev", "QR code decodes"


def test_uiimage(imaging):
    log, _, a, b, c, _ = imaging
    assert "resizable caps 10.0 mode 1" in log and close(a, 20, 344, (255, 0, 0)) and close(a, 90, 344, (0, 255, 0)) \
        and close(a, 90, 370, (0, 0, 255)) and close(a, 162, 396, (255, 0, 0)) and close(a, 20, 370, (0, 255, 0)), \
        "resizable image: nine slices"
    assert "flipped orientation 4 size (40.0, 20.0)" in log and close(a, 185, 350, (255, 0, 0)) and \
        close(a, 185, 380, (0, 0, 255)) and close(a, 215, 380, (255, 0, 0)), "withHorizontallyFlippedOrientation"
    assert "rotated orientation 3 size (20.0, 40.0)" in log and close(a, 240, 345, (255, 0, 0)) and \
        close(a, 240, 375, (0, 0, 255)), "imageOrientation .right swaps size, rotates"
    assert "animationImages 3 animating true" in log and \
        (rgb(a, 290, 360) != rgb(b, 290, 360) or rgb(b, 290, 360) != rgb(c, 290, 360)), "UIImageView.animationImages"
