"""Swift libraries self-test (Dispatch, Combine, JSON/Codable, Calendar, …)."""
import pytest
from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_swift_libraries(device_data, ios):
    need_apps("SwiftLibrariesTest")
    selftest("SwiftLibrariesTest", data=device_data, executable=True, timeout=60, os_version=ios[0])
