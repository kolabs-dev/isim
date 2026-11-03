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
