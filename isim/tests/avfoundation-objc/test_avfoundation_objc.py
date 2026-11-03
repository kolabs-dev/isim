"""AVFoundation capture and editing from Objective-C (issue #707): AVFoundationObjCTest.app writes a movie with an
AVAssetWriter and a pixel buffer adaptor, builds an AVMutableComposition from its ranges, exports it through an
AVMutableVideoComposition whose custom compositor is an Objective-C class, reads the export back with an AVAssetReader
(CMSampleBuffer / CVPixelBuffer C functions) and composes again with an AVAssetReaderVideoCompositionOutput; then runs
the simulated back camera through a session with video data, photo and movie file outputs and Objective-C delegates.
Needs ffmpeg."""
import shutil

import pytest
from isimtest import need_apps, selftest
from PIL import Image

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the simulated camera and the encoder need ffmpeg")


def test_avfoundation_objc(device_data, tmp_path):
    need_apps("AVFoundationObjCTest")
    img = Image.new("RGB", (640, 480), (128, 128, 128))
    img.paste((0, 200, 0), (140, 100, 500, 380))
    img.save(tmp_path / "camera.png")
    Image.new("RGB", (320, 240), (0, 0, 230)).save(tmp_path / "front.png")
    env = {"ISIM_CAMERA": str(tmp_path / "camera.png"), "ISIM_CAMERA_FRONT": str(tmp_path / "front.png"),
           "ISIM_CAMERA_PERMISSION": "allow", "SDL_AUDIO_DRIVER": "dummy"}
    selftest("AVFoundationObjCTest", data=device_data, env=env, timeout=240)


def test_capture_controls_objc(launch, tmp_path):
    """Issue #811 on an iPhone 16 Pro: the Camera Control's controls and the controls delegate driven by `cameracontrol`,
    capture events through AVKit's AVCaptureEventInteraction, the depth data output's delegate (CMTime by value) and a
    data output synchronizer, and system pressure through KVO, all from Objective-C."""
    need_apps("CaptureControlsObjCTest")
    img = Image.new("RGB", (640, 480), (128, 128, 128))
    img.save(tmp_path / "camera.png")
    depth = Image.new("L", (320, 240), 255)
    depth.paste(0, (160, 0, 320, 240))
    depth.save(tmp_path / "depth.png")
    env = {"ISIM_CAMERA": str(tmp_path / "camera.png"), "ISIM_CAMERA_DEPTH": str(tmp_path / "depth.png"), "ISIM_CAMERA_PERMISSION": "allow"}
    app = launch("CaptureControlsObjCTest", env=env, device="iphone16pro")
    p = "ControlsObjC: "
    app.wait_log(p + r"camera Back Dual Wide Camera depthFormats=\d+ pressure nominal factors=0")
    app.wait_log(p + r"interaction enabled=1")
    app.wait_log(p + r"depth output filtering=1 discards=1 delegate=1 connection=1")
    app.wait_log(p + r"controls supported=1 max=6")
    app.wait_log(p + r"picker titles 1x,2x,3x count=3 slider prominent=3 title=Intensity")
    app.wait_log(p + r"controls count=4 delegate=1")
    app.wait_log(p + r"running=1")
    app.wait_log(p + r"depth delegate \d+x\d+ timestamp=1 filtered=1 converted=1 calibration=1")
    app.wait_log(p + r"synchronizer outputs=2 delegate=1")
    app.wait_log(p + r"sync video=1 depth=\d+ sameTime=1 count=2 enumerated=2 dropped=0")
    app.send("cameracontrol lightpress")
    app.wait_log(p + r"controls active")
    app.wait_log(p + r"controls fullscreen")
    app.send("cameracontrol swipe 3")
    app.wait_log(p + r"zoom slider 0\.67")
    app.send("cameracontrol select 2")
    app.send("cameracontrol swipe 2")
    app.wait_log(p + r"intensity 2 on queue 1")
    app.send("cameracontrol select 3")
    app.send("cameracontrol swipe 1")
    app.wait_log(p + r"style Vivid")
    app.send("cameracontrol dismiss")
    app.wait_log(p + r"controls exit fullscreen")
    app.wait_log(p + r"controls inactive")
    app.send("cameracontrol press")
    app.wait_log(p + r"capture event primary began")
    app.wait_log(p + r"capture event primary ended")
    app.send("volume up")
    app.wait_log(p + r"capture event secondary ended")
    app.send("camerapressure serious temperature")
    app.wait_log(p + r"pressure serious factors=1 serious=1")
