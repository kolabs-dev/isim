"""ReplayKit (HelloReplayKit; issue #385): RPScreenRecorder records the app's windows to an H.264 movie
(stopRecording(withOutput:): its duration and a red frame) with the camera preview, captures video and microphone
sample buffers, buffers clips and exports the last second; the broadcast sheet reports no services; a recording's
RPPreviewViewController saves it to Photos. The consent alert is answered by ISIM_REPLAYKIT_PERMISSION, or tapped;
declining fails with RPRecordingErrorCode.userDeclined."""
from PIL import Image


def test_replaykit(launch, tmp_path):
    Image.new("RGB", (320, 240), (0, 0, 230)).save(tmp_path / "front.png")
    app = launch("HelloReplayKit", env={"ISIM_REPLAYKIT_PERMISSION": "allow", "ISIM_PHOTOS_PERMISSION": "allow",
                                        "ISIM_CAMERA_FRONT": str(tmp_path / "front.png"), "SDL_AUDIO_DRIVER": "dummy"})
    app.wait_log(r"HelloReplayKit: available=true recording=false")
    app.wait_log(r"recording started isRecording=true camera=true")
    m = app.wait_log(r"output duration=(\d+\.\d) size=(\d+)x(\d+) colour=(\S+)", timeout=30)
    assert 1.0 <= float(m.group(1)) <= 2.5, m.group(0)
    assert int(m.group(2)) % 2 == 0 and int(m.group(3)) > int(m.group(2)), "even, portrait (points)"
    assert m.group(4) == "red", m.group(0)
    app.wait_log(r"stop when not recording code=-5829")
    app.wait_log(r"capture video=true mic=true size=\d+x\d+", timeout=30)
    m = app.wait_log(r"clip duration=(\d+\.\d)", timeout=30)
    assert 0.5 <= float(m.group(1)) <= 1.6, m.group(0)
    app.wait_log(r"broadcast sheet shown")
    app.wait_view(r"id=RPBroadcastActivityViewController")
    app.wait_tap_id("RPBroadcast.cancel")
    app.wait_log(r"broadcast finished controller=false code=-5801")
    app.wait_log(r"preview presented", timeout=30)
    app.wait_tap_id("RPPreview.save")
    app.wait_log(r"preview activities com.apple.UIKit.activity.SaveToCameraRoll")
    app.wait_log(r"HelloReplayKit: done")
    assert app.quit() == 0


def test_replaykit_consent_alert(launch):
    """no scripted answer: iOS's consent alert, tapped"""
    app = launch("HelloReplayKit", args=["-deny-test"])
    app.wait_view(r"text=Allow screen recording in “Replay”\?")
    app.tap_text("Don’t Allow")
    app.wait_log(r"start error domain=com.apple.ReplayKit.RPRecordingErrorDomain code=-5801")
    app.wait_log(r"HelloReplayKit: done")


def test_replaykit_declined(launch):
    app = launch("HelloReplayKit", args=["-deny-test"], env={"ISIM_REPLAYKIT_PERMISSION": "deny"})
    app.wait_log(r"start error domain=com.apple.ReplayKit.RPRecordingErrorDomain code=-5801")
    app.wait_log(r"HelloReplayKit: done")
