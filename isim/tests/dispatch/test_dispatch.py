"""Dispatch C API self-test (DispatchTest.app): dispatch_data_t, dispatch_io_t, and the sources fed by host events
(write-source free space, pending connections, Mach receive / send, process fork / exec / exit)."""
import subprocess
import sys

from isimtest import need_apps, selftest

# waits for GO without forking, then forks a short-lived child, then execs: the app's process source sees
# fork, exec and (when the exec'd sleep ends) exit
HELPER = """
import os, sys, time
while not os.path.exists(sys.argv[1]):
    time.sleep(0.02)
if os.fork() == 0:
    time.sleep(0.5)
    os._exit(0)
time.sleep(0.2)
os.execv("/bin/sleep", ["sleep", "0.5"])
"""


def test_dispatch(device_data, tmp_path):
    need_apps("DispatchTest")
    go = tmp_path / "go"
    helper = subprocess.Popen([sys.executable, "-c", HELPER, str(go)])
    try:
        selftest("DispatchTest", data=device_data, timeout=60,
                 env={"DISPATCH_TEST_PID": str(helper.pid), "DISPATCH_TEST_GO": str(go)})
    finally:
        helper.kill()
        helper.wait()
