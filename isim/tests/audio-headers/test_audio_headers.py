"""The audio framework headers from Objective-C and C (AudioHeadersTest.app, issue #223): <AVFAudio/AVFAudio.h>,
<AudioUnit/AudioUnit.h> (types and constants; the functions are issue #286) and <CoreAudio/CoreAudioTypes.h>."""
from isimtest import need_apps, selftest


def test_audio_headers(device_data):
    need_apps("AudioHeadersTest")
    selftest("AudioHeadersTest", data=device_data)
