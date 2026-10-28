"""PHASE from Objective-C (issue #386): PHASETest.app checks the engine, assets, objects and transforms, envelopes,
meta parameters, mixers, sound events, push streams, groups and duckers through Apple's selectors."""
from isimtest import need_apps, selftest


def test_phase_objc(device_data):
    need_apps("PHASETest")
    selftest("PHASETest", data=device_data, env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy"})
