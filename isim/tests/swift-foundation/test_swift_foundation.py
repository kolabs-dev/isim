"""Swift <-> Foundation interop self-test."""
import pytest
from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_swift_foundation(device_data, ios):
    need_apps("SwiftFoundationTest")
    selftest("SwiftFoundationTest", data=device_data, executable=True, os_version=ios[0])
