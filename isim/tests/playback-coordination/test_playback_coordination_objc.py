"""Coordinated playback from Objective-C (issue #392): PlaybackCoordinationTest.app checks AVPlayer's playbackCoordinator
with an item-naming delegate, two players kept in step by an AVPlaybackCoordinationMedium, suspensions and their reasons,
participant limits, the notifications, and an AVDelegatingPlaybackCoordinator's play, pause and seek commands."""
from isimtest import need_apps, selftest


def test_playback_coordination_objc(device_data):
    need_apps("PlaybackCoordinationTest")
    selftest("PlaybackCoordinationTest", data=device_data)
