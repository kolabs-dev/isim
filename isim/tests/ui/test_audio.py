"""Audio APIs (HelloAudio): AVSpeechSynthesizer (espeak-ng), AudioToolbox system sounds and vibrate, AVAudioEngine
effects rendered offline, AVAudioFile writing (WAV, AAC), AVAudioRecorder + input-node tap fed by ISIM_AUDIO_INPUT,
MPNowPlayingInfoCenter and MPRemoteCommandCenter driven by `remote` script commands. The microphone input is a
generated 1 kHz tone (host ffmpeg); nothing is recorded from the real microphone. Port of tests/ui/audio.sh."""
import os
import re
import shutil
import subprocess

import pytest

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="HelloAudio needs ffmpeg on the host")


def test_audio(launch, device_data):
    tone = device_data / "mic-input.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "aevalsrc=0.8*sin(2*PI*1000*t):s=48000:d=3", str(tone)], check=True)
    app = launch("HelloAudio", env={"ISIM_AUDIO_INPUT": str(tone)})
    alert = app.wait_view(r"text=Allow")                          # the microphone privacy alert
    app.tap_text("Allow")
    app.wait_log(r"now playing Test Tone — isim @ 0\.0 s")
    for cmd in ("remote play", "remote skipforward 15", "remote seek 42", "remote next"):
        app.send(cmd)
    app.wait_log(r"remote command next -> status")
    app.wait_tap_id("speak")
    app.wait_log(r"speech didFinish")
    app.wait_view(r"id=spoken text=synthesizer")                   # the word callback updates the UI
    dump = app.view_dump()
    for line in (r"recording plays back", r"input tap ", r"file wav ", r"effects delay", r"custom system sound",
                 r"system sound 1104 completed"):
        app.wait_log(line)
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(s):
        return s in log

    def rx(p):
        return re.search(p, log, re.M)

    assert has("voices true fr=fr-FR"), "AVSpeechSynthesisVoice list + language lookup"
    if shutil.which("espeak-ng") or shutil.which("espeak"):
        assert rx(r"speech rendered .* s, audible true"), "AVSpeechSynthesizer.write renders speech"
    assert has("speech didStart speaking=true") and has("speech word Hello") and has("speech word synthesizer") and \
        has("speech didFinish"), "speak: didStart, word ranges, didFinish"
    if shutil.which("espeak-ng"):
        assert has("ssml text=Hello big & bright world markers=sentence,word:Hello,mark:middle,word:big,word:&,word:bright,word:world "
                   "rising=true inside=true"), "SSML utterance: markers from libespeak-ng (words in the plain text, the bookmark)"
    assert has("personal voice unsupported apple id en-US"), "Personal Voice unsupported; Apple voice identifiers map to eSpeak voices"
    assert has("system sound 1104 completed"), "AudioServicesPlaySystemSound + completion"
    assert has("vibrate (no haptics on this host)"), "kSystemSoundID_Vibrate is logged"
    assert has("custom system sound completed (status 0)"), "custom system sound from a WAV file"
    assert has("effects dry rms 0.35 end 0.94 tail 0.00"), "offline rendering (player node -> mixer)"
    assert has("effects eq lowpass true boost true"), "AVAudioUnitEQ low-pass and parametric boost"
    assert has("effects reverb tail true"), "AVAudioUnitReverb tail"
    assert rx(r"effects timepitch rate2 end 0\.4[0-9]"), "AVAudioUnitTimePitch rate 2 halves the length"
    assert has("effects delay tail true distortion true"), "AVAudioUnitDelay echo, AVAudioUnitDistortion"
    assert rx(r"file wav 0\.50 s; m4a 0\.5[0-2] s"), "AVAudioFile writes WAV and AAC (m4a; AAC padding varies by ffmpeg)"
    assert "text=“Audio” Would Like to Access the Microphone" in alert and \
        "text=Records a voice memo and taps the microphone." in alert and has("record permission true"), \
        "record permission: the microphone alert (NSMicrophoneUsageDescription), allowed"
    assert has("recorder metering true recording=true"), "AVAudioRecorder metering while recording"
    assert rx(r"recorded true 1\.0[0-9] s rms 0\.[2-6]") and has("recording plays back: duration 1.0"), \
        "AVAudioRecorder records ISIM_AUDIO_INPUT (m4a)"
    assert rx(r"input tap true frames, 48000 Hz 1 ch, peak 0\.[4-9]"), "input node tap receives the input"
    assert has("now playing Test Tone — isim @ 0.0 s") and has("now playing Test Tone — isim @ 42.0 s"), \
        "MPNowPlayingInfoCenter stores now-playing info"
    assert has("remote play") and has("remote skip 15") and has("remote seek 42"), \
        "MPRemoteCommandCenter play/skip/seek handlers"
    assert has("remote command next -> status 200"), "disabled remote command fails"
    assert "id=isim-volume-slider" in dump, "MPVolumeView shows a slider"


def test_audio_denied(launch, device_data):
    """Without microphone permission the input is silence (like iOS); the answer is remembered for the app."""
    tone = device_data / "mic-input.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "aevalsrc=0.8*sin(2*PI*1000*t):s=48000:d=3", str(tone)], check=True)
    app = launch("HelloAudio", env={"ISIM_AUDIO_INPUT": str(tone), "ISIM_MICROPHONE_PERMISSION": "deny"})
    app.wait_log(r"input tap ")
    app.wait_log(r"recorded ")
    assert app.quit() == 0, "exits cleanly"
    assert "record permission false" in app.log, "denied record permission"
    assert re.search(r"recorded true 1\.0[0-9] s rms 0\.00", app.log), "the recorder records silence"
    assert re.search(r"input tap true frames, 48000 Hz 1 ch, peak 0\.00", app.log), "the input node delivers silence"


def test_audio_host_microphone(launch, device_data, tmp_path):
    """ISIM_AUDIO_INPUT=mic records the host's capture device through `ffmpeg -f pulse`; a stand-in ffmpeg on PATH
    plays the capture device's part (a 1 kHz tone in real time), so no real microphone is opened."""
    real = shutil.which("ffmpeg")
    fake = tmp_path / "bin"
    fake.mkdir()
    (fake / "ffmpeg").write_text(f"""#!/bin/sh
case " $* " in *" -f pulse "*)
  exec {real} -nostdin -v error -f lavfi -i "aevalsrc=0.5*sin(2*PI*1000*t):s=48000,arealtime" -f f32le -ac 2 -ar 48000 - ;;
esac
exec {real} "$@"
""")
    (fake / "ffmpeg").chmod(0o755)
    path = f"{fake}:{os.environ.get('PATH', '')}"
    app = launch("HelloAudio", env={"ISIM_AUDIO_INPUT": "mic", "ISIM_MICROPHONE_PERMISSION": "allow", "PATH": path})
    app.wait_log(r"input tap ")
    app.wait_log(r"recorded ")
    assert app.quit() == 0, "exits cleanly"
    assert re.search(r"recorded true 1\.0[0-9] s rms 0\.(1[0-9]|2[0-6])", app.log), \
        "the recorder records the host capture device (a 0.5 mono sine, -3 dB in stereo: rms 0.25 once the stand-in runs, " \
        "which takes a few hundred ms to start): " + \
        "; ".join(x for x in app.log.splitlines() if "HelloAudio: rec" in x)
    assert re.search(r"input tap true frames, 48000 Hz 1 ch, peak 0\.3[3-7]", app.log), "the input node taps it"
