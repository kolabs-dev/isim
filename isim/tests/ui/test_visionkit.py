"""VisionKit (HelloVisionKit, issue #379): DataScannerViewController, Live Text and the document camera on the simulated
camera. ISIM_CAMERA is the sample's scene.png (a page with "HELLO ISIM" and a QR code on a dark desk, made by the build
with ImageMagick and qrencode): the scanner finds the code (zbar or zxing-cpp) and the text (tesseract) with highlights,
a tap on an item reports it, capturePhoto; Live Text reads the picture, the Live Text button highlights the items and a
tap selects a line; the document camera finds the page and scans it perspective-corrected. Without a camera the scanner
and the document camera are unsupported, like the Simulator."""
import re
import shutil
import subprocess

import pytest
from isimtest import APPS

APP = APPS / "HelloVisionKit.app"
P = "HelloVisionKit: "


def has_zbar():
    out = subprocess.run(["ldconfig", "-p"], capture_output=True, text=True).stdout
    return "libzbar.so.0" in out or "libZXing.so" in out


@pytest.fixture
def scene():
    if not (APP / "HelloVisionKit").exists():
        pytest.skip("HelloVisionKit not built")
    if not (APP / "scene.png").exists():
        pytest.skip("scene.png needs ImageMagick and qrencode at build time")
    if not shutil.which("ffmpeg"):
        pytest.skip("the simulated camera needs ffmpeg")
    return APP / "scene.png"


def test_visionkit_camera(launch, tmp_path, scene):
    app = launch("HelloVisionKit", env={"ISIM_CAMERA": str(scene), "ISIM_CAMERA_PERMISSION": "allow"})
    app.wait_log(P + r"scanner supported=true available=true documentCamera=true analyzer=true")

    # the data scanner: items with highlights, a tap, a photo
    app.tap_id("scan")
    app.wait_log(P + r"scanning=true zoom=1\.0\.\.\.\d")
    center = None
    if has_zbar():
        m = app.wait_log(P + r"added barcode:isim live text center=(\d+),(\d+)", timeout=30)
        center = int(m.group(1)), int(m.group(2))
    if shutil.which("tesseract"):
        app.wait_log(P + r"added text:HELLO ISIM center=", timeout=30)
    if center or shutil.which("tesseract"):
        app.wait_log(P + r"stream items=[12]")
        app.screenshot("scanner")
    if center:
        app.tap(*center)
        app.wait_log(P + r"tapped barcode:isim live text")
    app.tap_id("photo")
    app.wait_log(P + r"photo 640x480")
    app.tap_id("done")
    app.wait_log(P + r"stopped scanning=false")

    # the document camera: the page is found (blue overlay), shot and saved perspective-corrected
    app.tap_id("document")
    app.wait_view(r"id=documentcamera-hint text=Ready to scan\.", timeout=30)
    app.screenshot("documentcamera")
    app.tap_id("documentcamera-shutter")
    app.wait_view(r"id=documentcamera-save text=Save \(1\)")
    app.tap_id("documentcamera-save")
    m = app.wait_log(P + r"document pages=1 title=Scanned Document page=(\d+)x(\d+)")
    w, h = int(m.group(1)), int(m.group(2))
    assert 400 <= w <= 480 and 380 <= h <= 420, f"the page is the paper, perspective-corrected: {w}x{h}"

    # Live Text on the picture
    app.tap_id("livetext")
    if shutil.which("tesseract"):
        codes = "true" if has_zbar() else "false"
        app.wait_log(P + rf"analysis transcript=HELLO ISIM text=true codes={codes} button=true", timeout=30)
        m = app.wait_log(P + r"text center=(\d+),(\d+) hasText=true corner=false")
        app.tap_id("imageanalysis-livetext")
        app.wait_log(P + r"highlighted=true")
        app.screenshot("livetext")
        app.tap(int(m.group(1)), int(m.group(2)))
        app.wait_log(P + r"selected=HELLO ISIM ranges=1")
    else:
        app.wait_log(P + r"analysis transcript= text=false")
    assert app.quit() == 0


def test_visionkit_without_camera(launch, monkeypatch):
    if not (APP / "HelloVisionKit").exists():
        pytest.skip("HelloVisionKit not built")
    monkeypatch.delenv("ISIM_CAMERA", raising=False)
    app = launch("HelloVisionKit")
    app.wait_log(P + r"scanner supported=false available=false documentCamera=false analyzer=true")
    app.tap_id("scan")
    app.wait_log(P + r"startScanning throws unsupported")
    app.wait_log(r"DataScannerViewController is not supported: the device has no camera")
    app.tap_id("done")
    app.tap_id("document")
    app.wait_log(P + r"document camera unsupported")
    assert re.search(r"scanner supported=false", app.log)
