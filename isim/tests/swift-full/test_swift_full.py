"""Full Swift runtime self-test."""
import pytest
from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_swift_full(device_data, ios):
    need_apps("SwiftFullTest")
    selftest("SwiftFullTest", data=device_data, executable=True, os_version=ios[0])
