"""Objective-C constant literals (NSConstantArray & co., equality, serialization, Swift bridging):
ObjCLiteralsTest.app."""
import re

import pytest
from isimtest import need_apps, run_app


@pytest.mark.os_matrix
def test_objc_literals(device_data, ios):
    need_apps("ObjCLiteralsTest")
    os_version, device = ios
    r = run_app("ObjCLiteralsTest", data=device_data, os_version=os_version, timeout=60,
                env={"ISIM_DEVICE": device} if device else None)
    m = re.search(r"objc literals test: (\d+) passed, (\d+) failed", r.output)
    failures = "\n".join(r.lines(r"^FAIL|^  mismatch"))
    tail = "\n".join(r.output.splitlines()[-20:])
    assert m, f"ObjCLiteralsTest did not finish (exit {r.returncode})\n{tail}"
    assert r.returncode == 0 and m.group(2) == "0", f"{m.group(0)} (exit {r.returncode})\n{failures}\n{tail}"
