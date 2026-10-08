"""UIImagePickerController (HelloImagePicker): the camera source with the simulated camera (ISIM_CAMERA: a generated
picture) — photo with Retake / Use Photo and metadata, photo with the Move and Scale crop, video capture (PHOTO / VIDEO
switch, recording timer, Use Video), custom controls (showsCameraControls = false, an overlay calling takePicture on
the front camera) — and the photo library: a photo with the crop, the recorded video saved with
UISaveVideoAtPathToSavedPhotosAlbum and picked back. Needs ffmpeg."""
import shutil
import subprocess

import pytest
from isimtest import count_px

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the simulated camera needs ffmpeg")


@pytest.fixture
def camera_picture(tmp_path):
    pic = tmp_path / "camera.png"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "color=c=0xE63C28:s=640x480,drawbox=x=220:y=140:w=200:h=200:color=0x1E5ADC:t=fill", "-frames:v", "1", str(pic)],
                   check=True)
    return pic


def test_image_picker(launch, camera_picture):
    app = launch("HelloImagePicker", env={"ISIM_CAMERA": str(camera_picture), "ISIM_CAMERA_PERMISSION": "allow",
                                          "ISIM_PHOTOS_PERMISSION": "allow"})
    app.wait_log(r'picker sources library=true camera=true front=true flash=false media=\["public.image", "public.movie"\]')

    def closed():                                                      # the dismissed picker has left the view tree
        app.wait_view(r"id=(camera-preview|crop-scroll|photo-0|video-0)\b", gone=True)

    red = lambda c: c[0] > 200 and c[1] < 90 and c[2] < 70                  # the camera picture
    app.tap_id("camera-photo")                                         # photo, review, use
    app.wait_log(r"camera picker preview 640x480 \(back\)")
    app.wait_shot(lambda s: count_px(s, (0, 300, 402, 200), red) > 20000, "the live preview shows the camera picture")
    app.wait_tap_id("camera-shutter")
    app.wait_log(r"camera picker took a 640x480 photo")
    app.wait_tap_id("camera-use")
    app.wait_log(r'picked image 640x480 edited=none crop=none url=false meta=\["Orientation", "PixelHeight", "PixelWidth", "\{Exif\}", "\{TIFF\}"\] source=1')
    closed()

    app.wait_tap_id("camera-edit")                                     # photo, then Move and Scale
    app.wait_log(r"camera picker preview 640x480", count=2)
    app.wait_tap_id("camera-shutter")
    app.wait_tap_id("camera-use")
    app.wait_view(r"id=crop-choose")
    app.wait_tap_id("crop-choose")
    app.wait_log(r"picked image 640x480 edited=480x480 crop=480x480 url=false .* source=1")
    closed()

    app.wait_tap_id("library-edit")                                    # a library photo with the crop
    app.wait_tap_id("photo-0")
    app.wait_tap_id("crop-choose")
    app.wait_log(r"picked image (\d+)x(\d+) edited=(\d+)x\3 crop=\3x\3 url=true meta=\[\] source=0")
    closed()

    app.wait_tap_id("camera-video")                                    # video: switch, record, use
    app.wait_log(r"camera picker preview 640x480", count=3)
    app.wait_tap_id("camera-mode-video")
    app.wait_tap_id("camera-shutter")
    app.wait_log(r"camera picker started recording")
    app.wait_view(r"id=camera-timer text=00:00:01")
    app.tap_id("camera-shutter")
    app.wait_log(r"camera picker recorded [0-9.]+ s to capturedvideo-")
    app.wait_tap_id("camera-use")
    app.wait_log(r"picked movie MOV bytes>0=true source=1")
    closed()

    app.wait_tap_id("save-video")                                      # into the library and back out
    app.wait_log(r"video compatible true")
    app.wait_log(r"video saved error=none")
    app.wait_tap_id("library-video")
    app.wait_view(r"id=video-0")
    app.tap_id("video-0")
    app.wait_log(r"picked movie MOV bytes>0=true source=0")
    closed()

    app.wait_tap_id("camera-custom")                                   # no controls: the overlay's own shutter
    app.wait_log(r"camera picker preview 640x480 \(front\)")
    app.wait_tap_id("snap")
    app.wait_log(r"picked image 640x480 edited=none .* source=1", count=1)
    assert app.log.count("source=1") == 4, "four camera results"
    assert app.quit() == 0, "exits cleanly"


def test_image_picker_without_camera(launch, monkeypatch):
    """No ISIM_CAMERA: no camera source, like the Simulator."""
    monkeypatch.delenv("ISIM_CAMERA", raising=False)
    app = launch("HelloImagePicker")
    app.wait_log(r"picker sources library=true camera=false front=false flash=false media=\[\]")
    app.tap_id("camera-photo")
    app.wait_log(r"source 1 unavailable")
    assert app.quit() == 0, "exits cleanly"
