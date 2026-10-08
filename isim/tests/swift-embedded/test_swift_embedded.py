"""Embedded Swift self-test."""
from isimtest import need_apps, selftest


def test_swift_embedded(device_data):
    need_apps("SwiftEmbeddedTest")
    selftest("SwiftEmbeddedTest", data=device_data, executable=True)
