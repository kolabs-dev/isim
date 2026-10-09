"""C++ exceptions self-test (CxxExceptionsTest.app: libc++abi's throw / catch / rethrow, exceptions thrown by libc++,
exception_ptr, nested exceptions, threads, mixing with Objective-C exceptions), and an uncaught C++ exception ending in
std::terminate's report and SIGABRT, as on iOS."""
from isimtest import need_apps, run_app, selftest


def test_selftest(device_data):
    need_apps("CxxExceptionsTest")
    r = selftest("CxxExceptionsTest", data=device_data, timeout=60)
    assert not r.lines(r"^FAIL"), r.lines(r"^FAIL")


def test_uncaught(device_data):
    need_apps("CxxExceptionsTest")
    r = run_app("CxxExceptionsTest", args=["uncaught"], data=device_data, timeout=30)
    assert r.returncode in (134, -6), f"exit code {r.returncode} (want SIGABRT: 134 / -6)\n{r.output[-2000:]}"
    assert "libc++abi: terminating due to uncaught exception of type AppError: app failed" in r.output, r.output[-2000:]
    assert "NOT REACHED" not in r.output
