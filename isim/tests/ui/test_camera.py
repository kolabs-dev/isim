"""The simulated camera (HelloCamera). ISIM_CAMERA is a generated picture (red, with a QR code made by the host's
qrencode in the middle), then a generated two-colour video. Checks: device discovery, the camera permission alert
(tapped), preview layer pixels, BGRA video frames, QR decoding by AVCaptureMetadataOutput (host zbar), photo capture
shown on screen, movie recording, stopRunning, a denied permission, and no camera without ISIM_CAMERA. Needs ffmpeg;
the QR checks need qrencode and libzbar. Port of tests/ui/camera.sh."""
import re
import shutil
import subprocess

import pytest
from isimtest import APPS, rgb
from PIL import Image

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="HelloCamera needs ffmpeg")

COLORS = {
    "red": lambda c: c[0] > 200 and c[1] < 60 and c[2] < 60,
    "green": lambda c: c[1] > 200 and c[0] < 60 and c[2] < 60,
    "blue": lambda c: c[2] > 200 and c[0] < 60 and c[1] < 60,
    "black": lambda c: c[0] < 30 and c[1] < 30 and c[2] < 30,
}


def is_(img, x, y, color):
    return COLORS[color](rgb(img, x, y))


def has_zbar():
    out = subprocess.run(["ldconfig", "-p"], capture_output=True, text=True).stdout
    return bool(shutil.which("qrencode")) and "libzbar.so.0" in out


@pytest.fixture(scope="module")
def media(tmp_path_factory):
    if not (APPS / "HelloCamera.app" / "HelloCamera").exists():
        pytest.skip("HelloCamera not built")
    d = tmp_path_factory.mktemp("camera")
    pic = d / "camera.png"
    img = Image.new("RGB", (640, 480), (255, 0, 0))
    qr = has_zbar()
    if qr:
        subprocess.run(["qrencode", "-o", str(d / "qr.png"), "-s", "6", "-m", "3", "isim camera QR test"], check=True)
        code = Image.open(d / "qr.png").convert("RGB")
        img.paste(code, ((640 - code.width) // 2, (480 - code.height) // 2))
    img.save(pic)
    video = d / "camera.mp4"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=0x00FF00:s=320x240:r=30:d=1",
                    "-f", "lavfi", "-i", "color=c=blue:s=320x240:r=30:d=1", "-filter_complex",
                    "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p", "-c:v", "libx264", "-preset", "veryfast",
                    str(video)], check=True)
    return pic, video, qr


def camera(launch, ios, tmp_path, name, **env):
    """HelloCamera on its own device data (iPhone 17 unless --device)."""
    (tmp_path / name).mkdir()
    return launch("HelloCamera", device=ios[1] or "iphone17", data=tmp_path / name, env=env)


def test_camera_picture(launch, ios, tmp_path, media):
    pic, _, qr = media
    app = camera(launch, ios, tmp_path, "picture", ISIM_CAMERA=str(pic))
    alert = app.wait_view(r"text=Allow")
    alert_shot = app.screenshot("alert")
    app.tap_text("Allow")
    app.wait_log(r"session running=")
    preview = app.wait_shot(lambda s: is_(s, 30, 130, "red") and is_(s, 370, 380, "red"),
                            "preview layer shows the camera (pixels)")
    app.wait_log(r"first frame ")
    app.tap_id("takephoto")
    app.wait_log(r"^.*photo \d+x\d+ jpeg=")
    app.tap_id("record")
    app.wait_log(r"recorded error=")
    photo = app.wait_shot(lambda s: is_(s, 25, 505, "red"), "photo output: JPEG shown on screen")
    if qr:
        app.wait_log(r"metadata qr ")
        app.wait_view(r"id=code text=isim camera QR test")
    app.tap_id("stop")
    app.wait_log(r"session stopped")
    frames = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"device Back Camera position=1 discovered=Back Camera,Front Camera status=0") and \
        has(r"format 640x480 fps=30"), "simulated cameras (back + front), 640x480 format"
    assert has(r"configured focus"), "lockForConfiguration"
    assert "text=“Camera Demo” Would Like to Access the Camera" in alert and has(r"access true"), \
        "camera permission alert, then allowed"
    assert is_(alert_shot, 30, 130, "black"), "preview is black until access is granted"
    assert has(r"session running=true inputs=1 outputs=4"), "session runs with input and 4 outputs"
    assert is_(preview, 30, 130, "red") and is_(preview, 370, 380, "red"), "preview layer shows the camera (pixels)"
    assert has(r"first frame 640x480 format=BGRA corner=red") and re.search(r"id=frames text=[0-9]+ frames", frames), \
        "video data output: BGRA frames"
    assert has(r"photo 640x480 jpeg=ffd8 cg=640") and is_(photo, 25, 505, "red"), "photo output: JPEG shown on screen"
    assert has(r"recording started") and has(r"recorded error=none duration=(0.9|1.0|1.1) size=640x480"), \
        "movie file output records 1 s"
    assert has(r"session stopped running=false"), "stopRunning"
    if qr:
        assert has(r"metadata types available qr=true") and \
            has(r"metadata qr .isim camera QR test. corners=4 inPreview=true center=1(7[5-9]|8[0-9]),1(3[0-9]|4[0-2])"), \
            "metadata output decodes the QR code (zbar)"


def test_camera_video(launch, ios, tmp_path, media):
    _, video, _ = media
    app = camera(launch, ios, tmp_path, "video", ISIM_CAMERA=str(video), ISIM_CAMERA_PERMISSION="allow")
    app.wait_shot(lambda s: is_(s, 30, 130, "green"), "video file as the camera: first colour")
    app.wait_shot(lambda s: is_(s, 30, 130, "blue"), "video file as the camera: frames change colour")
    app.wait_log(r"frame colors green,blue")
    assert app.quit() == 0, "exits cleanly"


def test_camera_denied(launch, ios, tmp_path, media):
    pic, _, _ = media
    app = camera(launch, ios, tmp_path, "denied", ISIM_CAMERA=str(pic), ISIM_CAMERA_PERMISSION="deny")
    app.wait_log(r"input error -11852")                                 # denied permission: input fails
    assert app.quit() == 0, "exits cleanly"
    assert "access false" in app.log, "denied permission: input fails (-11852)"


def test_no_camera(launch, ios, tmp_path, monkeypatch):
    monkeypatch.delenv("ISIM_CAMERA", raising=False)
    app = camera(launch, ios, tmp_path, "none")
    app.wait_log(r"device none position=0 discovered= status=0")        # no ISIM_CAMERA: no camera (like the Simulator)
    assert app.quit() == 0, "exits cleanly"
