"""Video playback (HelloVideo): AVURLAsset async loading, AVAssetImageGenerator, AVPlayer with AVPlayerLayer (sublayer
and layerClass), KVO/Combine status, boundary/periodic observers, end notification, seek, rate 2, AVQueuePlayer,
AVPlayerLooper, AVPlayerViewController controls and SwiftUI VideoPlayer. The clip is red for 1 s, green for 1 s, blue
for 1 s, so screenshots show which frame is on screen (those are taken at playback times, so they keep their timing).
Needs ffmpeg/ffprobe on the host (the sample is not built without them). Port of tests/ui/video.sh."""
import time

import pytest
from isimtest import APPS, rgb, visible


def red(c): return c[0] > 230 and c[1] < 30 and c[2] < 30
def green(c): return c[1] > 230 and c[0] < 30 and c[2] < 30
def blue(c): return c[2] > 230 and c[0] < 30 and c[1] < 30


@pytest.fixture(autouse=True)
def clip():
    if not (APPS / "HelloVideo.app/clip.mp4").exists():
        pytest.skip("HelloVideo not built (needs ffmpeg)")


def at(t0, seconds):
    """sleep until `seconds` after t0 (playback time)"""
    time.sleep(max(0.0, t0 + seconds - time.monotonic()))


def test_playback(launch):
    app = launch("HelloVideo")
    app.wait_log(r"layer readyForDisplay true")                          # AVPlayerLayer.isReadyForDisplay KVO
    app.wait_log(r"item status readyToPlay duration=3\.00 size=320x180")  # AVPlayerItem.status KVO
    paused = app.wait_until(lambda: (lambda s: s if red(rgb(s, 201, 210)) else None)(app.screenshot("paused")),
                            what="first frame shown while paused (sublayer)")
    assert red(rgb(paused, 329, 647)), "first frame in the layerClass view"
    app.wait_tap_id("play")
    t0 = time.monotonic()
    at(t0, 0.5)
    assert red(rgb(app.screenshot("red"), 201, 210)), "frame at ~0.5 s is red"
    at(t0, 1.5)
    s = app.screenshot("green")
    assert green(rgb(s, 201, 210)) and green(rgb(s, 329, 647)), "frame at ~1.5 s is green"
    at(t0, 2.5)
    assert blue(rgb(app.screenshot("blue"), 201, 210)), "frame at ~2.5 s is blue"
    app.wait_log(r"did play to end t=3\.00")                             # AVPlayerItemDidPlayToEndTime at 3 s
    app.wait_view(r"id=time text=3\.0 s")                                # periodic time observer updates a label
    log = app.log
    assert "cmtime sum=0.75 compare=1 contains=true end=3.0 invalid=false" in log, "CMTime / CMTimeRange arithmetic"
    assert "asset duration=3.00 tracks=2 size=320x180 fps=25 audio=1" in log, "AVURLAsset.load(.duration, .tracks)"
    assert "thumbnail 320x180" in log, "AVAssetImageGenerator thumbnail"
    assert "missing asset fails" in log, "a missing file fails to load"
    assert "timeControlStatus playing" in log and "timeControlStatus paused" in log, "timeControlStatus publisher"
    assert app.has(r"boundary 1s at 1\.0[0-9]"), "boundary time observer at 1 s"
    assert app.quit() == 0


def test_seek_rate_queue_looper_avkit_swiftui(launch):
    app = launch("HelloVideo")
    app.wait_log(r"item status readyToPlay")
    app.wait_tap_id("seek")
    app.wait_log(r"seek finished true t=2\.00")
    app.wait_until(lambda: blue(rgb(app.screenshot("seek"), 201, 210)), what="seek(to: 2 s) shows the blue frame")
    app.tap_id("rate")
    app.wait_log(r"rate 2\.0")
    app.wait_log(r"did play to end t=3\.00 rate=2\.0")                   # rate 2 reaches the end early
    app.tap_id("queue")
    app.wait_log(r"queue item ended \(1\); now playing 1 item")
    app.wait_log(r"queue item ended \(2\); now playing 0 item")          # AVQueuePlayer advances through its items
    app.tap_id("loop")
    app.wait_log(r"looper loopCount=[2-4] status=ready")                 # AVPlayerLooper loops a time range
    app.tap_id("fullscreen")
    tree = app.wait_view(r"id=avkit-play\b")
    assert "id=avkit-scrubber" in tree and "id=avkit-close" in tree, "AVPlayerViewController controls"
    app.sleep(0.3)                                                       # presented
    app.tap_id("avkit-play")
    t0 = time.monotonic()
    at(t0, 1.2)
    tree = app.view_dump()
    assert "id=avkit-elapsed text=0:01" in tree and "id=avkit-remaining text=-0:02" in tree, "AVPlayerViewController time"
    assert green(rgb(app.screenshot("avkit"), 201, 380)), "AVPlayerViewController plays (green at ~1.2 s)"
    app.tap_id("avkit-close")
    app.wait_view(visible("avkit-close"), gone=True)
    app.sleep(0.3)
    app.wait_tap_id("swiftui")
    app.wait_log(r"SwiftUI VideoPlayer appeared")
    t0 = time.monotonic()
    app.wait_view(r"text=SwiftUI VideoPlayer")                           # VideoPlayer with its overlay
    at(t0, 1.4)
    assert green(rgb(app.screenshot("swiftui"), 201, 380)), "SwiftUI VideoPlayer plays (green at ~1.4 s)"
    assert app.quit() == 0
