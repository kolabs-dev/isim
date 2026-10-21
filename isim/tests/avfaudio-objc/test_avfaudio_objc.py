"""AVFAudio from Objective-C (AVFAudioObjCTest.app, issue #553): #import <AVFAudio/AVFAudio.h> over the AVFoundation Swift
overlay. Formats (standard, common, a channel layout, settings), AVAudioTime's factories and extrapolation, PCM buffers;
a converter buffer to buffer and with a resampling input block, an AAC encode into a compressed buffer; a WAV file
written and read back; an engine in offline manual rendering (player node with a completion callback type, EQ, reverb, a
source node, a 3D environment node with the AVAudio3D… structs) and its rendering block; an AVAudioPlayer playing the
file to its delegate; and an AVAudioRecorder recording the microphone input (a generated tone) to its delegate."""
import shutil
import subprocess

import pytest

from isimtest import need_apps

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the audio files and the microphone input need ffmpeg on the host")


def test_avfaudio_objc(launch, device_data):
    need_apps("AVFAudioObjCTest")
    tone = device_data / "mic-input.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
                    "aevalsrc=0.8*sin(2*PI*1000*t):s=48000:d=3", str(tone)], check=True)
    app = launch("AVFAudioObjCTest", env={"ISIM_AUDIO_INPUT": str(tone), "ISIM_MICROPHONE_PERMISSION": "allow"})
    p = "AVFAudioObjC: "
    app.wait_log(p + r"format standard 1 common 1 interleaved 0; int16 common 3 bytes 2; quad channels 4; settings equal 1 rate 44100")
    app.wait_log(p + r"time sample 48000 valid 1 host 0 extrapolated 11\.0 s")
    app.wait_log(p + r"buffer capacity 4800 length 4800 stride 1 buffers 2 peak 0\.50 copy 4800")
    app.wait_log(p + r"convert 1 frames 480 int16 peak 1[56]\d\d\d prime 0")
    app.wait_log(p + r"resample status 0 frames 44\d\d\d")
    app.wait_log(p + r"aac status 1 packets [1-8] bytes yes descriptions yes bitrates yes")
    app.wait_log(p + r"file wrote 1 read 1 length 24000 frames 24000 position 24000 rate 48000 peak 0\.50 error none")
    app.wait_log(p + r"missing file refused error yes")
    app.wait_log(p + r"environment listener 0,0,0 yaw 90 forward 1\.0 model 3 output 1 position 2,0,-1 algorithm 2 mode 2")
    app.wait_log(p + r"engine manual 1 mode 0 started 1 running 1 status 0 frames 4800 time 14400 audible 1 source yes nodes [6-9]")
    app.wait_log(p + r"player node completion type 0")
    app.wait_log(p + r"block status 0 code 0; eq input eq player outputs 1 to eq; eq type 1")
    app.wait_log(p + r"engine stopped running 0 manual 0 autoShutdown 1; not manual error -80800")
    app.wait_log(p + r"player duration 0\.50 channels 1 metering 1 prepared 1 playing 1")
    app.wait_log(p + r"player finished 1")
    app.wait_log(p + r"recorder prepared 1 recording 1 metering 1")
    app.wait_log(p + r"recorder finished 1 seconds 0\.5 heard 1")
    assert app.quit() == 0
