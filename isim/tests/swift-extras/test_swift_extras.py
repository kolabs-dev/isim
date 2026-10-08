"""Swift extras self-test (Combine operators, Dispatch sources/IO, Synchronization, Distributed)."""
from isimtest import need_apps, selftest


def test_swift_extras(device_data):
    need_apps("SwiftExtrasTest")
    selftest("SwiftExtrasTest", data=device_data, timeout=90)
