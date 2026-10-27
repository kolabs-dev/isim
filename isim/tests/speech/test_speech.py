"""Speech, iOS 26/27 (issue #377): SpeechTest.app runs SpeechAnalyzer with SpeechTranscriber, DictationTranscriber and
SpeechDetector over files, input sequences and iOS 27's providers, custom language models and AssetInventory: once with
a stand-in whisper-cli (fake-whisper-cli, so the test needs no model) and once with no engine on the host."""
import os
import shutil
from pathlib import Path

from isimtest import need_apps, selftest

FAKE = Path(__file__).parent / "fake-whisper-cli"


def no_engine_path():
    """PATH without whisper.cpp or Vosk"""
    return os.pathsep.join(p for p in os.environ.get("PATH", "").split(os.pathsep)
                           if not any(shutil.which(t, path=p) for t in ("whisper-cli", "whisper-cpp", "vosk-transcriber")))


def test_speech_analyzer(device_data, tmp_path):
    need_apps("SpeechTest")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    shutil.copy(FAKE, bin_dir / "whisper-cli")
    (bin_dir / "whisper-cli").chmod(0o755)
    model = tmp_path / "ggml-test.bin"
    model.write_bytes(b"not a model: fake-whisper-cli ignores it")
    env = {"PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}", "ISIM_WHISPER_MODEL": str(model),
           "ISIM_SPEECH_PERMISSION": "allow"}
    r = selftest("SpeechTest", data=device_data, os_version="27", env=env)
    assert "engine: available" in r.output


def test_speech_analyzer_without_engine(device_data):
    need_apps("SpeechTest")
    env = {"PATH": no_engine_path(), "ISIM_WHISPER_MODEL": "", "ISIM_VOSK_MODEL": ""}
    r = selftest("SpeechTest", data=device_data, os_version="26", env=env)
    assert "engine: none" in r.output
