"""Foundation self-test (FoundationTest.app): collections, strings, dates, archiving, KVO, errors, …"""
import pytest
from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_foundation(device_data, ios):
    need_apps("FoundationTest")
    selftest("FoundationTest", data=device_data, os_version=ios[0])
