"""ReplayKit from Objective-C (issue #385): ReplayKitTest.app checks the recorder's properties and Apple's selectors,
a declined recording, stopping when nothing runs, the broadcast sheet and picker, and RPBroadcastConfiguration."""
from isimtest import need_apps, selftest


def test_replaykit_objc(device_data):
    need_apps("ReplayKitTest")
    selftest("ReplayKitTest", data=device_data, env={"ISIM_REPLAYKIT_PERMISSION": "deny"})
