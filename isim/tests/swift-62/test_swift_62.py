"""Swift 6.2 self-test (Span, MutableSpan, RawSpan, InlineArray, TaskExecutor, Observations) under each iOS version:
the APIs newer than the selected version are skipped, like on a device."""
import pytest
from isimtest import need_apps, selftest

EXPECTED = {"17": "Span", "18": "Span TaskExecutor", "26": "Span TaskExecutor InlineArray Observations",
            "27": "Span TaskExecutor InlineArray Observations"}


@pytest.mark.os_matrix
def test_swift_62(device_data, ios):
    need_apps("Swift62Test")
    r = selftest("Swift62Test", data=device_data, executable=True, timeout=60, os_version=ios[0])
    major = str(ios[0] or "18").split(".")[0]                 # isim's default is iOS 18
    assert f"available: {EXPECTED[major]}\n" in r.output
