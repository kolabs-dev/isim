"""Swift <-> C++ interoperability self-test."""
from isimtest import need_apps, selftest


def test_swift_cxx(device_data):
    need_apps("SwiftCxxTest")
    selftest("SwiftCxxTest", data=device_data, timeout=30)
