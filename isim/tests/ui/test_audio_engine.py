"""AVAudioEngine's pull graph and AudioToolbox's Audio Units (HelloAudioEngine): varispeed and time/pitch (offline),
AVAudioEnvironmentNode positions, a resampled player and play(at:), an equalizer switched on while a looping buffer
plays (seen by a real-time tap on the main mixer), AVAudioSourceNode and an AVAudioSinkNode fed by the simulated
microphone, AUGraph (render callback -> MultiChannelMixer -> RemoteIO), RemoteIO's input bus, GenericOutput pulled
through an AUConverter, AudioUnitProcess on a delay, and an Audio Queue with time/pitch, pan and a processing tap. The graph plays through SDL's silent "dummy" device."""
import array
import math
import re
import shutil
import subprocess

import pytest

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the microphone input is generated with ffmpeg")


def tap_balance(path, last):
    """RMS of the left and right channels over the last `last` seconds of sound in an ISIM_AUDIO_TAP capture (raw
    float32 little-endian stereo at 48 kHz; trailing silence skipped)"""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    end = len(a)
    while end > 1 and abs(a[end - 2]) < 1e-4 and abs(a[end - 1]) < 1e-4:
        end -= 2
    seg = a[max(0, end - int(last * 48000) * 2):end]
    left, right = seg[0::2], seg[1::2]

    def rms(x):
        return math.sqrt(sum(v * v for v in x) / len(x)) if len(x) else 0.0
    return rms(left), rms(right)


def test_audio_engine(launch, device_data):
    tone = device_data / "mic.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "aevalsrc=0.6*sin(2*PI*1000*t):s=48000:d=10", str(tone)], check=True)
    tap_file = device_data / "tap.f32"
    app = launch("HelloAudioEngine", env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy", "ISIM_AUDIO_INPUT": str(tone), "ISIM_MICROPHONE_PERMISSION": "allow",
                                          "ISIM_AUDIO_TAP": str(tap_file)})
    app.wait_log(r"HelloAudioEngine: done", timeout=30)
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def line(p):
        m = re.search(f"^.*{p}.*$", log, re.M)
        return m.group(0) if m else f"no {p!r} line"

    def has(p):
        return re.search(p, log, re.M)

    assert has(r"varispeed end 0\.4[0-9] freq (8[6-9]\d|9[0-2]\d) after 0\.00"), \
        f"varispeed rate 2: half as long, an octave up: {line('varispeed')}"
    assert has(r"timepitch end 0\.9[0-9] freq (8[6-9]\d|9[0-2]\d)"), f"time pitch +1200 cents: same length, octave up: {line('timepitch')}"
    assert has(r"environment right true left true centre true far 0\.10 linear 1\.00"), \
        f"3D positions: pan by azimuth, inverse distance attenuation (linear: 10 m of 100 km is ~1): {line('environment')}"
    assert has(r"resampled player starts at [0-3] freq 4[34]\d"), f"24 kHz player resampled by the mixer: {line('resampled')}"
    assert has(r"play\(at:\) starts at 1200[0-9] playerTime 1[0-2]\d{3}"), f"play(at:) a sample time: {line('play.at')}"
    assert has(r"reverb audioUnit wetDryMix 25"), "AVAudioUnit.audioUnit is the Audio Unit"
    m = re.search(r"realtime tap true rms before ([\d.]+) after lowpass ([\d.]+) playerTime ([\d.]+)", log)
    assert m and float(m[1]) > 0.3 and float(m[2]) < float(m[1]) * 0.5 and 0.8 <= float(m[3]) <= 1.1, \
        f"real-time tap; the EQ change applies while the buffer plays; player time follows the clock: {line('realtime tap')}"
    assert has(r"source node rms 0\.1[6-9] sink frames true peak 0\.4[0-5]"), \
        f"AVAudioSourceNode (0.25 sine) and AVAudioSinkNode from the microphone (0.6 mono, -3 dB in stereo): {line('source node')}"
    assert has(r"generic output Apple: AUConverter freq 44\d rms 0\.3[45]"), \
        f"GenericOutput <- AUConverter (16-bit 44.1 kHz -> float 48 kHz): {line('generic output')}"
    assert has(r"delay unit echo at 4800 parameters 4"), f"AudioUnitProcess (delay 0.1 s), parameter list: {line('delay unit')}"
    assert has(r"augraph start 0 running true frames true peak 0\.4[0-9]"), \
        f"AUGraph: callback -> mixer (volume 0.5) -> RemoteIO, render notify: {line('augraph')}"
    assert has(r"remoteio input frames true peak 0\.4[0-5]"), f"RemoteIO input bus (16 kHz int16): {line('remoteio input')}"
    q = re.search(r"queue tap 0 format 44100 speed ([\d.]+) freq (\d+) pitched (\d+) rate 1\.0", log)
    assert q and 1.6 <= float(q[1]) <= 2.2 and 420 <= int(q[2]) <= 460 and 840 <= int(q[3]) <= 920, \
        f"AudioQueue play rate 2 (time pitch keeps 440 Hz), then pitch +1200 (880 Hz), seen by a processing tap: {line('queue tap')}"
    left, right = tap_balance(tap_file, last=0.4)
    assert left > 0.05 and right < 0.01, f"AudioQueue pan -1: left only at the end of the mixer output: {left:.3f} {right:.3f}"
