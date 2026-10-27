"""Sound Analysis (issue #368) with an ONNX classifier on the host's ONNX Runtime: the test writes a tiny model with
YAMNet's interface (onnx_model.py: quiet audio scores "Silence", loud audio "Music") and a WAV (a second of near
silence, then a 440 Hz tone). SoundAnalysisTest.app checks the Objective-C interface (file and stream analyzers,
windows, time ranges, errors); HelloSoundAnalysis the Swift API. ONNX Runtime comes from ISIM_ONNXRUNTIME, the host's
libonnxruntime, or the onnxruntime Python package; without one the model tests are skipped and the classifier is
unavailable, with the reason."""
import ctypes.util
import math
import os
import struct
import subprocess
import sys
import wave
from pathlib import Path

import pytest

from isimtest import need_apps, selftest

sys.path.insert(0, str(Path(__file__).parent))
import onnx_model  # noqa: E402


def onnxruntime_library():
    if os.environ.get("ISIM_ONNXRUNTIME"):
        return os.environ["ISIM_ONNXRUNTIME"]
    if ctypes.util.find_library("onnxruntime"):
        return ""                                   # the host's libonnxruntime: isim finds it itself
    for python in (sys.executable, "python3"):           # the onnxruntime Python package's library (this env, or the host's)
        try:
            out = subprocess.run([python, "-c", "import onnxruntime, os; print(os.path.dirname(onnxruntime.__file__))"],
                                 capture_output=True, text=True, timeout=60)
        except OSError:
            continue
        if out.returncode == 0 and out.stdout.strip():
            libs = sorted((Path(out.stdout.strip()) / "capi").glob("libonnxruntime.so*"))
            if libs:
                return str(libs[0])
    return None


def write_wav(path, rate=44100):
    frames = []
    for i in range(rate * 3):
        t = i / rate
        v = 0.001 * math.sin(2 * math.pi * 50 * t) if t < 1 else 0.5 * math.sin(2 * math.pi * 440 * t)
        s = int(max(-1, min(1, v)) * 32767)
        frames.append(struct.pack("<hh", s, s))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(frames))


@pytest.fixture
def model_env(tmp_path):
    lib = onnxruntime_library()
    if lib is None:
        pytest.skip("no ONNX Runtime on this host")
    model, labels = onnx_model.write(tmp_path)
    env = {"ISIM_SOUND_MODEL": str(model), "ISIM_SOUND_LABELS": str(labels)}
    if lib:
        env["ISIM_ONNXRUNTIME"] = lib
    return env


def test_soundanalysis_objc(device_data, model_env, tmp_path):
    need_apps("SoundAnalysisTest")
    sound = tmp_path / "sound.wav"
    write_wav(sound)
    selftest("SoundAnalysisTest", data=device_data, env={**model_env, "SOUND_FILE": str(sound)})


def test_soundanalysis_objc_without_model(device_data):
    need_apps("SoundAnalysisTest")
    selftest("SoundAnalysisTest", data=device_data, env={"ISIM_SOUND_MODEL": "", "SOUND_EXPECT_MODEL": "0"})


def test_soundanalysis_swift(launch, model_env):
    app = launch("HelloSoundAnalysis", env=model_env)
    app.wait_log(r"HelloSoundAnalysis: done")
    log = app.log
    for line in [
        'known ["silence", "music", "speech"] window 0.975 overlap 0.5',
        "constraint range 0.975 ... 15.0",
        "stream windows 5 completed true tops silence,music,music,music,music",
        "file windows 3 completed true tops silence,music,music",
        "async reached end true windows 5",
        "cancelled reached end false",
        "short window invalidFormat",
        "not audio com.apple.SoundAnalysis 5 ",
    ]:
        assert f"HelloSoundAnalysis: {line}" in log, line
    assert "stream first 0.000+0.975 silence" in log
    app.wait_view(r"id=windows text= 0\.00 s  silence  0\.98")              # the first of the windows (the dump shows a label's first line)
    app.wait_still()
    app.screenshot("sound-windows")
    assert app.quit() == 0


def test_soundanalysis_swift_without_model(launch):
    app = launch("HelloSoundAnalysis", env={"ISIM_SOUND_MODEL": ""})
    app.wait_log(r"HelloSoundAnalysis: classifier unavailable: com.apple.SoundAnalysis 2 sound classification on isim needs an ONNX audio classifier")
    app.wait_log(r"HelloSoundAnalysis: done")
    assert app.quit() == 0
