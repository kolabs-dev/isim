"""Sample-buffer rendering (HelloSampleBuffers, issue #282): an H.264 movie read back compressed and fed to an
AVSampleBufferDisplayLayer (decoded by the host's libavcodec) shows red, green and blue in turn on an
AVSampleBufferRenderSynchronizer's clock; a 440 Hz LPCM tone plays through an AVSampleBufferAudioRenderer (checked
on the mixed output, ISIM_AUDIO_TAP); periodic and boundary time observers fire; pausing holds the frame; a second
layer shows uncompressed pixel buffers as they arrive; the first layer floats in Picture in Picture with a
sample-buffer content source and its playback delegate; VideoToolbox encodes three frames and decodes them back."""
import array
import re

from isimtest import near, rgb

RED, GREEN, BLUE = (255, 0, 0), (0, 255, 0), (0, 0, 255)


def tone_frequency(path):
    """the frequency of the first half second of sound in an ISIM_AUDIO_TAP capture (raw float32 stereo, 48 kHz), from
    its zero crossings, and its RMS"""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    left = [v for v in a[0::2]]
    loud = [i for i, v in enumerate(left) if abs(v) > 0.05]
    if len(loud) < 4800:
        return 0, 0
    seg = left[loud[0]:loud[0] + 24000]
    crossings = sum(1 for x, y in zip(seg, seg[1:]) if x < 0 <= y)
    rms = (sum(v * v for v in seg) / len(seg)) ** 0.5
    return crossings / (len(seg) / 48000), rms


def test_sample_buffers(launch, device_data):
    tap = device_data / "tap.f32"
    app = launch("HelloSampleBuffers", env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy", "ISIM_AUDIO_TAP": str(tap)})
    app.wait_log(r"HelloSampleBuffers: rate 1")
    w = app.screenshot().width - 40
    video = (20 + w / 2, 100 + w * 0.375)                       # the centre of the top layer
    frames = (20 + w / 4, 100 + w * 0.75 + 20 + w * 0.1875)    # the centre of the bottom one
    app.wait_shot(lambda s: near(rgb(s, *video), RED, 40), "the first second is red")
    app.wait_shot(lambda s: near(rgb(s, *video), GREEN, 40), "then green")
    app.wait_shot(lambda s: near(rgb(s, *video), BLUE, 40), "then blue")
    app.screenshot("playing")
    app.wait_log(r"HelloSampleBuffers: boundary at 1\.[5-9]")
    app.wait_log(r"HelloSampleBuffers: uncompressed enqueued 3 status rendering")
    seen = set()

    def all_colours(s):
        c = rgb(s, *frames)
        for name, ref in (("r", RED), ("g", GREEN), ("b", BLUE)):
            if near(c, ref, 40):
                seen.add(name)
        return len(seen) == 3
    app.wait_until(lambda: all_colours(app.screenshot()), what="the uncompressed layer shows each frame as it is enqueued")
    app.tap_id("pause")
    app.wait_log(r"HelloSampleBuffers: rate 0 at [\d.]+")
    held = rgb(app.screenshot(), *video)
    app.tap_id("pip")
    app.wait_log(r"HelloSampleBuffers: pip started active true")
    app.wait_view(r"id=pip-window")
    app.screenshot("pip")
    app.tap_id("pip-window")
    app.wait_tap_id("pip-play")
    app.wait_log(r"HelloSampleBuffers: pip setPlaying true")
    app.wait_tap_id("pip-skip-forward")
    app.wait_log(r"HelloSampleBuffers: pip skip 15")
    app.wait_tap_id("pip-close")
    app.wait_log(r"HelloSampleBuffers: pip stopped")
    assert app.quit() == 0
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"renderers 2 video timebase follows true"), "the synchronizer drives both renderers"
    assert has(r"compressed true image false"), "the movie's samples are compressed H.264"
    assert has(r"status rendering audio rendering"), "both renderers render"
    assert has(r"video all enqueued"), "requestMediaDataWhenReady fed the whole movie"
    assert has(r"periodic 0\.[4-6] shows red") and has(r"periodic 1\.[4-6] shows green"), \
        "periodic observer: copyDisplayedPixelBuffer follows the clock"
    assert near(held, BLUE, 40), "pausing the synchronizer holds the frame"
    assert has(r"pip possible true") and has(r"pip render size true"), "Picture in Picture of sample-buffer content"
    assert has(r"videotoolbox encoded 3 decoded red green blue"), "VideoToolbox: compression and decompression sessions (issue #284)"
    freq, rms = tone_frequency(tap)
    assert 420 < freq < 460 and rms > 0.1, f"the 440 Hz tone plays (measured {freq:.0f} Hz, RMS {rms:.2f})"
