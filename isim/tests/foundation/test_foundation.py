"""Foundation self-test (FoundationTest.app): collections, strings, dates, archiving, KVO, errors, …, and the URL
loading system from Objective-C against http_server.py (ISIM_TEST_HTTP_PORT)."""
from pathlib import Path

import pytest
from isimtest import local_server, need_apps, selftest

HERE = Path(__file__).parent


@pytest.mark.os_matrix
def test_foundation(device_data, ios, tmp_path):
    need_apps("FoundationTest")
    with local_server(HERE / "http_server.py", tmp_path / "http.log") as port:
        selftest("FoundationTest", data=device_data, os_version=ios[0], env={"ISIM_TEST_HTTP_PORT": str(port)})
