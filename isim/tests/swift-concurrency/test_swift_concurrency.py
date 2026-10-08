"""Swift concurrency self-test (async/await, actors, MainActor)."""
import pytest
from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_swift_concurrency(device_data, ios):
    need_apps("SwiftConcurrencyTest")
    selftest("SwiftConcurrencyTest", data=device_data, executable=True, timeout=60, os_version=ios[0])
