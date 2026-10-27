"""The capture pipeline on the simulated camera and microphone (HelloCapture). The camera shows a generated picture: grey
with a green middle, an Aztec code and a Data Matrix code (made by zxing-cpp's ZXingWriter when installed); the front
camera a blue / yellow picture; the depth source is white (near) on the left and black (far) on the right; the scene
declares a face and a body (ISIM_CAMERA_OBJECTS); the microphone plays a 0.5 sine. Checks: discovery (virtual, depth
and microphone devices, multi-cam sets), HEIC / flash / RAW (Bayer + DNG) / depth / bracketed photos, Live Photo
movies with sound, video and audio data outputs, metadata (faces, bodies, Aztec, Data Matrix), movies with sound,
digital zoom and the torch, depth data with a synchronizer, a multi-cam session with mirrored front preview, and the
interruption when the app goes to the background. Needs ffmpeg."""
import re
import shutil
import struct
import subprocess

import pytest
from isimtest import rgb
from PIL import Image

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the simulated camera needs ffmpeg")
ZXING = bool(shutil.which("ZXingWriter")) and bool(shutil.which("ZXingReader"))


@pytest.fixture
def media(tmp_path):
    img = Image.new("RGB", (640, 480), (128, 128, 128))
    img.paste((0, 200, 0), (140, 100, 500, 380))
    if ZXING:
        for kind, text, at in (("Aztec", "hello aztec", (20, 20)), ("DataMatrix", "hello dm", (20, 360))):
            out = tmp_path / f"{kind}.png"
            subprocess.run(["ZXingWriter", "-size", "100x100", "-margin", "10", kind, text, str(out)], check=True)
            img.paste(Image.open(out).convert("RGB"), at)
    img.save(tmp_path / "camera.png")
    front = Image.new("RGB", (320, 240), (0, 0, 230))
    front.paste((230, 230, 0), (160, 0, 320, 240))
    front.save(tmp_path / "front.png")
    depth = Image.new("L", (320, 240), 255)
    depth.paste(0, (160, 0, 320, 240))
    depth.save(tmp_path / "depth.png")
    tone = tmp_path / "mic.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "aevalsrc=0.5*sin(2*PI*440*t):s=48000:d=30", str(tone)], check=True)
    return {"ISIM_CAMERA": str(tmp_path / "camera.png"), "ISIM_CAMERA_FRONT": str(tmp_path / "front.png"),
            "ISIM_CAMERA_DEPTH": str(tmp_path / "depth.png"), "ISIM_AUDIO_INPUT": str(tone),
            "ISIM_CAMERA_OBJECTS": "face:0.3,0.25,0.15,0.2;humanBody:0.25,0.2,0.3,0.7",
            "ISIM_CAMERA_PERMISSION": "allow", "ISIM_MICROPHONE_PERMISSION": "allow", "SDL_AUDIO_DRIVER": "dummy"}


def has_heic_encoder():
    out = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    return "libx265" in out


def test_capture_photos(launch, media):
    app = launch("HelloCapture", env=media)
    app.wait_log(r"running=true")
    app.wait_log(r"frame corner=gray")
    for button, done in (("photo-heic", "heic"), ("photo-flash", "flash"), ("photo-raw", "raw"), ("photo-depth", "depth"), ("photo-bracket", "bracket")):
        app.tap_id(button)
        app.wait_log(rf"capture finished {done}", timeout=20)
    app.tap_id("zoom")
    app.wait_log(r"frame corner=green")                                     # 2x digital zoom: the green middle fills the frame
    app.tap_id("zoom")
    app.wait_log(r"frame corner=gray lum=0\.5")
    app.tap_id("torch")
    app.wait_log(r"frame corner=gray lum=0\.[89]")                          # the torch lights the scene
    app.tap_id("torch")
    app.wait_log(r"torch off")
    if ZXING:
        app.wait_log(r"metadata aztec 'hello aztec'", timeout=20)
        app.wait_log(r"metadata datamatrix 'hello dm'", timeout=20)
    app.wait_log(r"metadata face id=1")
    shot = app.screenshot("capture")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"devices Back Camera,Back Ultra Wide Camera,Back Dual Wide Camera,Front Camera,Front TrueDepth Camera,iPhone Microphone"), "discovery"
    assert has(r"depth cameras Back Dual Wide Camera,Front TrueDepth Camera"), "depth-capable cameras"
    assert has(r"microphone iPhone Microphone type=microphone audio=true"), "microphone capture device"
    assert has(r"multicam supported=true sets=[1-9]"), "multi-cam device sets"
    assert has(r"camera Back Dual Wide Camera virtual=true constituents=Back Ultra Wide Camera\+Back Camera depthFormats=4"), "virtual depth camera"
    assert has(r"audioChannels=1 live=true depth=true codecs=.*jpeg raw=1 flash=3"), "outputs configured"
    assert has(r"first frame 640x480"), "video data output"
    heic = "heic" if has_heic_encoder() else "jpeg"
    assert has(rf"photo heic {heic} image=640x480 corner=gray lum=0\.5\d exifFlash=16 live=false"), "default photo: HEIC (or JPEG without libx265)"
    assert has(r"will capture flash flash=true expected=1") and has(r"photo flash jpeg image=640x480 corner=gray lum=0\.[789]\d exifFlash=25"), \
        "flash fires and lights the photo"
    assert has(r"will capture raw flash=false expected=2"), "RAW + processed: two photos"
    m = has(r"raw 640x480 format=rggb dng=II\* bytes=(\d+) rggb=(\d+),(\d+),(\d+)")
    assert m and int(m.group(1)) > 640 * 480 * 2, "RAW: 14-bit Bayer pixel buffer and DNG data"
    assert all(3300 < int(m.group(i)) < 3800 for i in (2, 3, 4)), "RAW: grey 128 linearized (~0.216 of 16383) on every site"
    assert has(r"photo raw jpeg image=640x480"), "RAW: processed JPEG too"
    assert has(r"photo depth type=hdis accuracy=absolute left=2\.00 right=0\.20"), "photo depth (disparity of ISIM_CAMERA_DEPTH)"
    b = has(r"bracket lums=([\d.]+),([\d.]+),([\d.]+) sequence=3")
    assert b and float(b.group(1)) < float(b.group(2)) < float(b.group(3)), "bracketed exposures get brighter"
    assert has(r"zoom 2\.00") and has(r"torch on active=true"), "zoom and torch"
    assert has(r"metadata face id=1 x=0\.30") and has(r"metadata body id=1"), "faces and bodies declared by the scene"
    assert rgb(shot, 25, 115)[1] < 140, "preview shows the camera"
    dng = (app.data / "Containers").rglob("photo.dng")
    path = next(iter(dng), None)
    if path:
        d = path.read_bytes()
        assert d[:4] == b"II*\x00", "DNG is a little-endian TIFF"
        ifd = struct.unpack("<I", d[4:8])[0]
        n = struct.unpack("<H", d[ifd:ifd + 2])[0]
        tags = {struct.unpack("<H", d[ifd + 2 + 12 * i:ifd + 4 + 12 * i])[0] for i in range(n)}
        assert {256, 257, 262, 33421, 33422, 50706, 50721}.issubset(tags), "DNG tags (size, CFA, DNG version, colour matrix)"


def test_capture_audio_movie_live(launch, media):
    app = launch("HelloCapture", env=media)
    app.wait_log(r"running=true")
    app.wait_log(r"audio buffers=60 peak=0\.3[4-6] level=-1[1-3]dB", timeout=20)   # the mono tone comes in at -3 dB (stereo upmix)
    app.tap_id("record")
    app.wait_log(r"movie finished=", timeout=30)
    app.wait_log(r"frame corner=gray")
    app.tap_id("photo-live")
    app.wait_log(r"live movie error=", timeout=30)
    app.wait_log(r"capture finished live")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"audio 1ch 48000Hz 16bit frames=1024"), "audio data output: mono 16-bit 48 kHz buffers"
    assert has(r"movie finished=true duration=(0\.9\d|1\.\d\d) video=1 audio=1 connections=2"), "movie with sound, ends at its maximum"
    assert has(r"photo live jpeg .*live=true"), "Live Photo still carries the content identifier"
    assert has(r"live movie recorded live\.mov dims=640x480"), "Live Photo movie recorded"
    m = has(r"live movie error=none duration=([\d.]+) display=([\d.]+) file=([\d.]+) video=1 audio=1")
    assert m and 2.5 < float(m.group(1)) < 3.6 and 0.8 < float(m.group(2)) < 1.7, "Live Photo movie: ~1.5 s each side, with sound"


def test_capture_multicam_sync(launch, media):
    app = launch("HelloCapture", env=media)
    app.wait_log(r"running=true")
    app.tap_id("sync")
    app.wait_log(r"sync video=true depth=\d+x\d+ sameTime=true", timeout=20)
    app.tap_id("multicam")
    app.wait_log(r"multicam running=true")
    app.wait_log(r"multicam back=gray front=blue", timeout=20)
    shot = app.wait_shot(lambda s: rgb(s, 275, 150)[0] > 150 and rgb(s, 375, 150)[2] > 150, "front preview mirrored (yellow left, blue right)")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"synchronizer outputs=2 depthConnection=true"), "synchronizer"
    assert has(r"sync video=true depth=320x240 sameTime=true left=2\.00 right=0\.20"), "synchronized video and depth"
    assert has(r"multicam connections=4 frontMirrored=true cost=0\.\d\d"), "multi-cam connections, front preview mirrored"
    assert shot


def test_capture_interruption(launch, media):
    dev = launch(None, install=["HelloCapture"], env=media)
    dev.send("launch dev.isim.samples.HelloCapture")
    dev.wait_log(r"HelloCapture: running=true")
    dev.send("home")
    dev.wait_log(r"HelloCapture: interrupted reason=1")
    dev.send("launch dev.isim.samples.HelloCapture")
    dev.wait_log(r"HelloCapture: interruption ended")
    assert dev.quit() == 0


def test_capture_camera_control_and_mattes(launch, media, tmp_path):
    """Issue #382 on an iPhone 16 Pro: the Camera Control's controls (system zoom and exposure bias sliders, a slider,
    an index picker) through `cameracontrol`, capture events from the Camera Control and the volume buttons (they no
    longer change the volume), system pressure (KVO, the shutdown interruption), and a photo's portrait and hair
    mattes (ISIM_CAMERA_MATTE*: white on the left) with calibration data."""
    left = Image.new("L", (320, 240), 0)
    left.paste(255, (0, 0, 160, 240))
    left.save(tmp_path / "matte.png")
    left.save(tmp_path / "hair.png")
    env = dict(media, ISIM_CAMERA_MATTE=str(tmp_path / "matte.png"), ISIM_CAMERA_MATTE_HAIR=str(tmp_path / "hair.png"))
    app = launch("HelloCapture", env=env, device="iphone16pro")
    app.wait_log(r"controls supported=true max=6")
    app.wait_log(r"controls count=4")
    app.wait_log(r"running=true")
    app.send("cameracontrol")
    app.wait_log(r"cameracontrol controls=4 active=0 selected=0 \[0\] Zoom=0\.5x \[1\] Exposure=\+0\.0 \[2\] Intensity=0 \[3\] Style=Natural")
    app.send("cameracontrol lightpress")
    app.wait_log(r"controls active")
    app.wait_log(r"controls fullscreen")
    app.send("cameracontrol swipe 3")                    # the zoom slider: 10% a detent
    app.wait_log(r"zoom slider 0\.67")
    app.send("cameracontrol select 1")
    app.send("cameracontrol swipe 3")                    # exposure bias: 1/3 EV a detent
    app.wait_log(r"\[1\] Exposure=\+1\.0")
    app.send("cameracontrol select 2")
    app.send("cameracontrol swipe 2")
    app.wait_log(r"intensity 2")
    app.send("cameracontrol select 3")
    app.send("cameracontrol swipe 1")
    app.wait_log(r"style Vivid")
    app.send("cameracontrol set 2")
    app.wait_log(r"style Mono")
    app.send("cameracontrol dismiss")
    app.wait_log(r"controls exit fullscreen")
    app.wait_log(r"controls inactive")
    # capture events: the Camera Control and volume down are primary, volume up secondary
    app.send("cameracontrol press")
    app.wait_log(r"capture event primary began")
    app.wait_log(r"capture event primary ended")
    app.send("volume up")
    app.wait_log(r"capture event secondary ended")
    assert "isim: volume" not in app.log, "the volume buttons capture instead of changing the volume"
    # system pressure
    app.send("camerapressure serious temperature")
    app.wait_log(r"pressure serious factors=1")
    app.send("camerapressure shutdown power")
    app.wait_log(r"interrupted reason=5")
    app.send("camerapressure nominal")
    app.wait_log(r"interruption ended")
    app.wait_log(r"pressure nominal factors=0")
    # mattes and calibration
    app.tap_id("photo-matte")
    app.wait_log(r"photo matte 320x240 left=255 right=0 format=L008", timeout=20)
    app.wait_log(r"photo semantic hair=255 teeth=none")
    app.wait_log(r"photo calibration fx=4\d\d cx=320 reference=640x480 depth=true")


def test_capture_without_camera_control(launch, media):
    """An iPhone 15 has no Camera Control: no controls, and `cameracontrol` says so."""
    app = launch("HelloCapture", env=media, device="iphone15")
    app.wait_log(r"controls supported=false")
    app.wait_log(r"running=true")
    app.send("cameracontrol lightpress")
    app.wait_log(r"isim: cameracontrol: .* has no Camera Control")


def test_capture_events_swiftui_and_directions(launch, media):
    """iOS 26 / 27.1 additions (under iOS 27.1): a capture event plays the shutter sound, SwiftUI's onCameraCaptureEvent
    takes the events once enabled, and AVCaptureDeviceDirectionCoordinator maps the back cameras forward and the front
    ones backward."""
    app = launch("HelloCapture", env=media, device="iphone16pro", os_version="27.1")
    app.wait_log(r"directions forward=Back Camera backward=Front Camera,Front TrueDepth Camera")
    app.wait_log(r"running=true")
    app.send("cameracontrol press")
    app.wait_log(r"capture sound played=true")
    app.wait_log(r"isim: capture event sound cameraShutter")
    app.tap_id("swiftui-events")
    app.wait_log(r"swiftui events on")
    app.send("volume down")
    app.wait_log(r"swiftui capture event began")
    app.wait_log(r"swiftui capture event ended")
