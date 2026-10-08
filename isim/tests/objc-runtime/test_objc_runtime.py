"""Objective-C runtime self-test (ObjCRuntimeTest.app: exceptions, forwarding, NSInvocation, NSProxy), and uncaught
exceptions from Objective-C and Swift callers terminating with iOS's report (SIGABRT). Port of
tests/objc-runtime/run.sh."""
import re

import pytest
from isimtest import APPS, need_apps, run_app, selftest

TERM = r"^\*\*\* Terminating app due to uncaught exception"


def test_selftest(device_data):
    need_apps("ObjCRuntimeTest")
    r = selftest("ObjCRuntimeTest", data=device_data, timeout=60)
    assert not r.lines(r"^FAIL"), r.lines(r"^FAIL")


UNCAUGHT = [
    ("ObjCUncaught", "raise", [rf"{TERM} 'NSInternalInconsistencyException', reason: 'state 3 is invalid'$",
                               r"^\*\*\* First throw call stack:$", r"ObjCUncaught`main",
                               r"^libc\+\+abi: terminating due to uncaught exception of type NSException$"]),
    ("ObjCUncaught", "handler", [r"^HANDLER NSInternalInconsistencyException state 3 is invalid$",
                                 rf"{TERM} 'NSInternalInconsistencyException'"]),
    ("ObjCUncaught", "unrecognized", [rf"{TERM} 'NSInvalidArgumentException', reason: '-\[NSObject notImplemented\]: "
                                      r"unrecognized selector sent to instance 0x[0-9a-f]+'$"]),
    ("ObjCUncaught", "object", [rf"{TERM} of class '__NSDate|NSDate'", r"terminating due to uncaught exception of type"]),
    ("ObjCUncaught", "finally", [r"^FINALLY ran$", rf"{TERM} 'FinallyException', reason: 'after finally'$"]),
    ("SwiftUncaught", "range", [rf"{TERM} 'NSRangeException', reason: '.*index 5 beyond bounds", r"SwiftUncaught`"]),
    ("SwiftUncaught", "raise", [rf"{TERM} 'NSInvalidArgumentException', reason: 'raised from Swift'$"]),
]


@pytest.mark.parametrize("app,mode,expected", UNCAUGHT, ids=[f"{a}-{m}" for a, m, _ in UNCAUGHT])
def test_uncaught(app, mode, expected, device_data):
    if not (APPS / f"{app}.app" / app).exists():
        pytest.skip(f"{app} is not built")
    r = run_app(app, args=[mode], data=device_data, timeout=30)
    assert r.returncode in (134, -6), f"exit code {r.returncode} (want SIGABRT: 134 / -6)\n{r.output[-2000:]}"
    missing = [rx for rx in expected if not re.search(rx, r.output, re.M)]
    assert not missing, f"missing: {missing}\n{r.output[-2000:]}"
    assert "NOT REACHED" not in r.output, "continued after the exception"
    if app == "SwiftUncaught":
        assert "SWIFT CAUGHT" not in r.output, "Swift do/catch must not catch NSException"
