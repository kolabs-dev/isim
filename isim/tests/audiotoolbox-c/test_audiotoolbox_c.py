"""AudioToolbox's C interface (AudioToolboxCTest.app, issue #286): <AudioToolbox/AudioToolbox.h> from Objective-C and
plain C over isim's Swift AudioToolbox: Audio Components and Units (an offline render, parameters, properties,
listeners, RemoteIO), AUGraph, Audio File and Extended Audio File Services, Audio Converter, Audio Queues (proc and
dispatch-queue block callbacks) and System Sound Services."""
from isimtest import need_apps, selftest


def test_audiotoolbox_c(device_data):
    need_apps("AudioToolboxCTest")
    r = selftest("AudioToolboxCTest", data=device_data)
    assert "vibrate" in r.output     # kSystemSoundID_Vibrate's alert reached the haptic stand-in
