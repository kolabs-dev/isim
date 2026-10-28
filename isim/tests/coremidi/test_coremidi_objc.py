"""CoreMIDI from C and Objective-C (issue #390): CoreMIDITest.app checks clients, ports, endpoints, properties, errors,
packet and event lists, the UMP constructors and conversions, decoding, thru connections, the setup, notifications and
the Objective-C classes through Apple's names."""
from isimtest import need_apps, selftest


def test_coremidi_objc(device_data):
    need_apps("CoreMIDITest")
    selftest("CoreMIDITest", data=device_data)
