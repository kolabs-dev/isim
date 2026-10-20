"""Media selection and player item outputs (HelloVideo -outputs, issue #288): the audible and legible groups of an MP4
with two soundtracks and two subtitle tracks, the French soundtrack (880 Hz in the mixer output) and Spanish
subtitles selected, AVPlayerItemLegibleOutput's cues, the subtitles drawn over the video, AVPlayerItemVideoOutput's
frames (red, green, blue), AVPlayerItemMetadataOutput's timed ID3 groups from MPEG-TS, the access and error logs and
the rate change reasons. Needs ffmpeg/ffprobe on the host (the sample is not built without them)."""
import array
import re

import pytest
from isimtest import APPS


@pytest.fixture(autouse=True)
def media():
    if not (APPS / "HelloVideo.app/tracks.mp4").exists():
        pytest.skip("HelloVideo not built (needs ffmpeg)")


def tap_frequency(path, start, end):
    """the dominant frequency (zero crossings of the left channel) between two times of an ISIM_AUDIO_TAP capture, counted
    from its first sound (raw float32 stereo, 48 kHz)"""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    left = a[0::2]
    first = next((i for i, v in enumerate(left) if abs(v) > 0.01), 0)
    seg = left[first + int(start * 48000):first + int(end * 48000)]
    crossings = sum(1 for i in range(1, len(seg)) if (seg[i - 1] < 0) != (seg[i] < 0))
    return crossings / 2 / (len(seg) / 48000) if seg else 0


def test_outputs(launch, device_data):
    tap = device_data / "tap.f32"
    app = launch("HelloVideo", args=["-outputs"], env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy", "ISIM_AUDIO_TAP": str(tap)})
    app.wait_log(r"HelloVideo: legible 0\.5 \[Hola\]", timeout=30)
    shot = app.screenshot("subtitles")
    # the Spanish cue over the red picture: white text on a dark box near the bottom of the video (y 120...300)
    white = sum(1 for x in range(150, 252) for y in range(250, 296) if min(shot.getpixel((x, y))[:3]) > 220)
    assert white > 20, f"subtitles drawn in AVPlayerLayer ({white} white pixels)"
    app.wait_log(r"HelloVideo: outputs done", timeout=30)
    assert app.quit() == 0
    log = app.log

    def line(p):
        m = re.search(f"^.*{p}.*$", log, re.M)
        return m.group(0) if m else f"no {p!r} line"

    def has(p):
        return re.search(p, log, re.M)

    assert has(r"audible English/en,French/fr default en empty false"), f"the audible group: {line('audible')}"
    assert has(r"legible English/en,Spanish/es default none empty true characteristics 2"), f"the legible group: {line('legible Eng')}"
    assert has(r"selected audio fr subtitles es subtype true"), f"select(_:in:), currentMediaSelection, tx3g: {line('selected')}"
    assert has(r"outputs 2"), "AVPlayerItem.outputs"
    cues = re.findall(r"HelloVideo: legible (\d\.\d) \[([^\]]*)\]", log)
    texts = [c[1] for c in cues]
    assert texts[:4] == ["Hola", "", "Adiós", ""], f"Spanish cues start and end: {cues}"
    assert cues[0][0] == "0.5" and cues[2][0] == "1.8", f"cue times: {cues}"
    frames = line("frames")
    assert re.search(r"red.*green.*blue", frames), f"AVPlayerItemVideoOutput frames follow the video: {frames}"
    assert has(r"video output media data will change"), "requestNotificationOfMediaDataChange"
    assert has(r"metadata 0\.5 id3/TIT2=First cue"), f"timed ID3 at 0.5 s: {line('metadata')}"
    assert has(r"metadata 1\.5 id3/TXXX=two"), f"TXXX (description \\0 value) at 1.5 s: {line('metadata 1')}"
    assert has(r"access log entry"), "AVPlayerItemNewAccessLogEntry"
    m = re.search(r"access log events 1 type FILE watched ([\d.]+) uri true bytes true bitrate true startup true extended true", log)
    assert m and 2.5 <= float(m[1]) <= 3.5, f"access log: {line('access log events')}"
    assert has(r"error log domain AVFoundationErrorDomain code -11800 comment true"), f"error log of a missing file: {line('error log')}"
    assert has(r"rate reasons SetRateFailed,SetRateCalled,SetRateCalled"), f"rate -1 fails, play, pause at the end: {line('rate reasons')}"
    f = tap_frequency(tap, 0.3, 2.3)
    assert 840 <= f <= 920, f"the French soundtrack plays (880 Hz, not English 440 Hz): {f:.0f} Hz"
