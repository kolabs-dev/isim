"""XPC between two processes of one device (issue #357): two copies of an app on one ISIM_DATA, one listening
(XPC_ROLE=server) and one talking to it (XPC_ROLE=client); each prints "<what> <role>: N/M passed".

- XPCTest.app (Objective-C): the C API (objects, connections, sessions, listeners, peer rejection, anonymous listeners
  and endpoints) and NSXPCConnection / NSXPCListener (reply blocks, synchronous proxies, one-way messages, errors).
- SwiftXPCTest: XPCListener and XPCSession with Codable and XPCDictionary messages, sync, async and handed-off replies,
  a rejecting listener and an anonymous listener through its endpoint."""
import os
import re
import subprocess
import threading

import pytest

from isimtest import APPS, ISIM, need_apps, run_app


def _passed(out, what, role):
    m = re.search(rf"{what} {role}: (\d+)/(\d+) passed", out)
    fails = "\n".join(l for l in out.splitlines() if l.startswith("FAIL"))
    assert m and m.group(1) == m.group(2), f"{role}:\n{fails}\n" + "\n".join(out.splitlines()[-40:])


@pytest.mark.parametrize("app,what,executable", [("XPCTest", "xpc", False), ("SwiftXPCTest", "swift xpc", True)])
def test_xpc_across_processes(device_data, app, what, executable):
    need_apps(app)
    target = APPS / f"{app}.app"
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_STANDALONE="1", XPC_ROLE="server")
    server = subprocess.Popen([str(ISIM), "run", str(target / app if executable else target)], env=env,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
    lines, ready = [], threading.Event()

    def read():
        for line in server.stdout:
            lines.append(line)
            if f"{what} server ready" in line:
                ready.set()
    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    try:
        assert ready.wait(60), "the server starts\n" + "".join(lines[-30:])
        client = run_app(app, data=device_data, env={"XPC_ROLE": "client"}, executable=executable, timeout=90)
        _passed(client.output, what, "client")
        assert client.returncode == 0, client.output[-2000:]
        server.wait(60)
    finally:
        if server.poll() is None:
            server.kill()
    reader.join(5)
    out = "".join(lines)
    _passed(out, what, "server")
    assert server.returncode == 0, out[-2000:]
