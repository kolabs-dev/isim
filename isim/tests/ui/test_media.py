"""Media editing and low-level audio (HelloMedia): AVMutableComposition insert/remove/scale, AVAssetExportSession,
thumbnails of the export on screen (pixels), AVAssetReader frames/PCM, AVAssetWriter, AVAudioPlayer rate/pan/metering
through a silent SDL "dummy" audio device whose mixed output is captured with ISIM_AUDIO_TAP, AVAudioSession
interruption and route-change notifications from the `audio` script command, and AudioToolbox ExtAudioFile /
AudioFile / AudioConverter / AudioQueue. Port of tests/ui/media.sh (and its audio_tap.py checker)."""
import array
import math
import re

import pytest
from isimtest import APPS, rgb

RED = lambda c: c[0] > 200 and c[1] < 60 and c[2] < 60            # noqa: E731
GREEN = lambda c: c[1] > 200 and c[0] < 60 and c[2] < 60          # noqa: E731
BLUE = lambda c: c[2] > 200 and c[0] < 60 and c[1] < 60           # noqa: E731


def tap_balance(path):
    """RMS of the left and right channels of an ISIM_AUDIO_TAP capture (raw float32 little-endian stereo)."""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    left, right = a[0::2], a[1::2]

    def rms(x):
        return math.sqrt(sum(v * v for v in x) / len(x)) if len(x) else 0.0
    return rms(left), rms(right)


def test_media(launch, ios, device_data):
    app_dir = APPS / "HelloMedia.app"
    if not (app_dir / "tone.wav").exists():
        pytest.skip("HelloMedia not built (needs ffmpeg)")
    tap = device_data / "tap.f32"
    app = launch("HelloMedia", device=ios[1] or "iphone17",
                 env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy", "ISIM_AUDIO_TAP": str(tap),
                      "ISIM_AUDIO_INPUT": str(app_dir / "tone.wav")})
    app.wait_log(r"^.*meter avg")
    app.send("audio interrupt begin")
    app.wait_log(r"interruption began")
    app.send("audio route headphones")
    app.wait_log(r"route change reason=1")
    app.send("audio interrupt end resume")
    app.wait_log(r"interruption ended")
    app.sleep(0.5)                                                       # the resumed player runs (audio tap)
    app.send("audio route speaker")
    app.wait_log(r"route change reason=2")
    app.send("audio bogus")
    app.wait_log(r"unknown audio command")
    app.wait_log(r"editing done", timeout=30)
    for line in (r"queue input frames", r"queue output callbacks", r"converter out=", r"audiofile caf",
                 r"extaudiofile read", r"writer thumb", r"export without outputURL", r"m4a export",
                 r"scaled export"):
        app.wait_log(line, timeout=20)
    shot = app.wait_shot(lambda s: GREEN(rgb(s, 345, 152)), "writer thumbnail on screen")
    app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)

    def line(p):
        """the app's line matching p (for an assertion's message)"""
        m = re.search(f"^.*{p}.*$", log, re.M)
        return m.group(0) if m else f"no {p!r} line"

    assert has(r"composition duration=2.50 tracks=2 segments=3"), "composition insert (3 segments, 2.5 s, 2 tracks)"
    assert has(r"removeTimeRange duration=1.00"), "composition removeTimeRange"
    assert has(r"export status=completed progress=1.00"), "export session completes"
    assert has(r"exported duration=2.(4[6-9]|5[0-4]) video=1 audio=1"), "exported file: duration and tracks"
    assert has(r"thumbs 160x90 160x90 160x90") and RED(rgb(shot, 60, 152)) and RED(rgb(shot, 155, 152)) and \
        BLUE(rgb(shot, 250, 152)), "export thumbnails (red, inserted red, blue) on screen"
    assert has(r"scaled export duration=(1.9[6-9]|2.0[0-4])"), "scaleTimeRange + export(to:as:) (iOS 18)"
    assert has(r"m4a export status=3 video=0 audio=1 duration=(0.9|1.0)"), "AppleM4A preset: audio only"
    assert has(r"export without outputURL status=failed"), \
        f"export without outputURL fails: {line('export without outputURL')}"
    assert has(r"reader frames=6[0-5] status=completed colors=red,red,blue"), "AVAssetReader BGRA frames (red, red, blue)"
    assert has(r"audio reader samples=44100 peak=0.50"), "AVAssetReader 16-bit PCM"
    assert has(r"writer status=completed frames=30 duration=1.0[0-9] size=64x64 audio=1") and \
        GREEN(rgb(shot, 345, 152)), "AVAssetWriter (pixel buffer adaptor + AAC)"
    assert has(r"player channels=2 duration=1.00"), "AVAudioPlayer channels/duration"
    # measured against a rate-1 player's position (the mixer's clock), so it holds on a loaded machine
    assert has(r"player played=true rate=2.0 pan=-1.0 position rate=(1\.9[5-9]|2\.0[0-5])"), \
        f"AVAudioPlayer rate 2 (position runs twice as fast): {line('player played=')}"
    assert has(r"meter avg -9.[0-9] peak -6.[0-9]"), "AVAudioPlayer metering (-9 dB RMS, -6 dB peak sine)"
    assert has(r"route Speaker"), "AVAudioSession route (speaker)"
    assert has(r"interruption began, player playing=false"), "interruption began pauses the player"
    assert has(r"route change reason=1 output=Headphones previous=Speaker"), "route change: headphones (new device)"
    assert has(r"interruption ended shouldResume=true resumed=true playing=true"), \
        "interruption ended (shouldResume) resumes"
    assert has(r"route change reason=2 output=Speaker previous=Headphones"), \
        "route change: back to speaker (old device unavailable)"
    assert has(r"unknown audio command .bogus"), "unknown audio command is reported"
    left, right = tap_balance(tap)
    assert left > 0.05 and right < 0.01, f"pan -1: left channel only (mixer output tap): rms {left:.3f} {right:.3f}"
    assert has(r"extaudiofile 44100 Hz 2 ch 16-bit frames=44100"), "ExtAudioFile reads the WAV format"
    assert has(r"extaudiofile read 48000 frames at 48000 Hz mono, peak 0.50"), \
        "ExtAudioFile client format converts (48 kHz mono float)"
    assert has(r"audiofile caf packets=48000 16-bit 48000 Hz duration=1.00 firstBytes=8"), \
        "ExtAudioFile writes CAF; AudioFile reads it"
    assert has(r"converter to AAC status=fmt\?"), "AudioConverter: AAC not supported (fmt?)"
    assert has(r"converter out=22050 peak=0.50"), "AudioConverter: 44.1k stereo int16 -> 22.05k mono float"
    # the app waits until 0.5 s have played: one callback per 0.1 s buffer played (3 are queued ahead), and no faster
    # than real time
    q = re.search(r"queue output callbacks=(\d+) played=([\d.]+) s in ([\d.]+) s running=1", log)
    assert q and 0.5 <= float(q[2]) <= float(q[3]) + 0.05 and \
        float(q[2]) * 10 - 3 <= int(q[1]) <= float(q[2]) * 10 + 4, \
        f"AudioQueue output callbacks and time: {line('queue output callbacks')}"
    i = re.search(r"queue input frames=(\d+) peak=0.(4[5-9]|5[0-5])", log)        # whole 1600-frame buffers, 5 or more
    assert i and int(i[1]) >= 8000 and int(i[1]) % 1600 == 0, \
        f"AudioQueue input from the simulated microphone: {line('queue input frames')}"
    assert has(r"editing done"), "editing finished"
