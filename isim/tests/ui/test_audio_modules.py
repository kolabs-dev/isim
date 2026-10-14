"""The audio module names apps import (HelloAudioModules, issue #223): `import AVFAudio` (isim's AVFoundation),
`import AudioUnit` (a RemoteIO unit through AudioToolbox), `import CoreAudio` / `CoreAudioTypes` (the types, format IDs
and flags)."""
import re


def test_audio_modules(launch):
    app = launch("HelloAudioModules")
    app.wait_log(r"^am reported$")
    r = {m[0]: m[1] for m in re.findall(r"^am (\S+) (.*)$", app.log, re.M)}
    assert r["session"] == "category=AVAudioSessionCategoryPlayback", r["session"]
    assert r["format"] == "rate=44100 channels=2 lpcm=true float=true", r["format"]
    assert r["engine"] == "mixer=AVAudioMixerNode output=AVAudioOutputNode", r["engine"]
    assert r["remoteio"] == "set=0 get=0 rate=48000 channels=2", r["remoteio"]
    assert r["types"] == "buffers=1 bytes=512 asbd=40 aac=61616320", r["types"]
