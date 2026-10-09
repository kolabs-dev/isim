"""Runtime loading self-test (DlopenTest.app): dlopen / dlsym / dladdr / dlopen_preflight of frameworks, a dylib and a
bundle embedded in the app but not linked, Swift code in a loaded framework, NSBundle's code loading, and a framework
whose dependency is missing failing to load without ending the app."""
from isimtest import need_apps, selftest


def test_selftest(device_data):
    need_apps("DlopenTest")
    r = selftest("DlopenTest", data=device_data, timeout=60)
    assert not r.lines(r"^FAIL"), r.lines(r"^FAIL")
