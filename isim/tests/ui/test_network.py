"""Networking (HelloNetwork) against a local server (samples/HelloNetwork/server.py, no Internet): async/await +
JSONDecoder, completion handler on a background queue, POST + Set-Cookie + authenticated GET, HTTP 503, URLError for
an unreachable host, WebSocket echo, Combine dataTaskPublisher, NWPathMonitor, and ISIM_NETWORK=offline.
Port of tests/ui/network.sh."""
import re
import subprocess

import pytest
from isimtest import ROOT, local_server


def curl_has_ws():
    """The host libcurl speaks WebSocket (Ubuntu 24.04's does not: issue #5)."""
    out = subprocess.run(["curl", "--version"], capture_output=True, text=True).stdout
    return "Protocols:" in out and "ws" in out.split("Protocols:")[1].split("\n")[0].split()


def test_network(launch, device_data):
    log = device_data / "server.log"
    with local_server(ROOT / "samples/HelloNetwork/server.py", log) as port:
        server = ["-server", f"http://127.0.0.1:{port}"]
        app = launch("HelloNetwork", args=server)
        app.wait_log(r"^todos 3 ")
        app.wait_log(r"^message ")
        app.wait_view(lambda d: "text=Decode JSON" in d and "text=2 of 3 done" in d,
                      what="async/await data(from:) + JSONDecoder")
        app.wait_view(r"text=Hello from a local server", what="completion handler off the main thread")
        app.wait_view(r"text=online", what="NWPathMonitor reports the host connection")
        app.screenshot("loaded")
        app.wait_tap_id("reload")
        app.wait_log(r"^message ", count=2)
        app.wait_tap_id("signin")
        app.wait_log(r"^account ")
        app.wait_view(r"text=signed in as ada", what="POST JSON, Set-Cookie, cookie sent back")
        app.drag(200, 760, 200, 160, 0.3)
        app.wait_still()
        app.wait_tap_id("http503")
        app.wait_log(r"^error HTTP 503")
        app.wait_tap_id("unreachable")
        app.wait_log(r"^error cannot connect")
        app.wait_view(r"text=cannot connect \(-1004\)", what="unreachable host -> URLError.cannotConnectToHost")
        app.wait_tap_id("combinefetch")
        app.wait_log(r"^combine ")
        app.wait_view(r"text=3 todos via Combine", what="Combine dataTaskPublisher + tryMap + receive(on:)")
        app.screenshot("done")
        assert app.quit() == 0, "exits cleanly"
        out = app.log

        offline = launch("HelloNetwork", args=server, env={"ISIM_NETWORK": "offline"})
        offline.wait_log(r"^path unsatisfied")
        offline.wait_view(r"text=The Internet connection appears to be offline\.",
                          what="ISIM_NETWORK=offline: unsatisfied path, -1009")
        offline.quit()

    def has(p):
        return re.search(p, out, re.M)
    assert has(r"^todos 3 Write the network layer,Decode JSON,Ship it"), "async/await data(from:) + JSONDecoder"
    assert has(r"^message Hello from a local server 👋 main=false"), "completion handler off the main thread"
    assert has(r"^account signed in as ada"), "POST JSON, Set-Cookie, cookie sent back"
    assert has(r"^error HTTP 503 service unavailable"), "HTTP 503 is a response with a status code"
    assert has(r"^error cannot connect \(-1004\)"), "unreachable host -> URLError.cannotConnectToHost"
    assert has(r"^combine 3"), "Combine dataTaskPublisher + tryMap + receive(on:)"
    assert has(r"^path satisfied"), "NWPathMonitor reports the host connection"
    requests = log.read_text()
    assert "POST /login" in requests and "GET /me" in requests, "server saw the requests"


@pytest.mark.skipif(not curl_has_ws(), reason="the host libcurl has no WebSocket support (issue #5)")
def test_websocket(launch, device_data):
    with local_server(ROOT / "samples/HelloNetwork/server.py", device_data / "server.log") as port:
        app = launch("HelloNetwork", args=["-server", f"http://127.0.0.1:{port}"])
        app.wait_log(r"^todos 3 ")
        app.wait_view(r"id=echo")
        app.wait_still()
        app.drag(200, 760, 200, 160, 0.3)
        app.wait_still()
        app.wait_tap_id("echo")
        app.wait_log(r"^ws echo")
        app.wait_view(r"text=echo: hello isim", what="URLSessionWebSocketTask echo")
        assert app.quit() == 0, "exits cleanly"
        assert re.search(r"^ws echo: hello isim", app.log, re.M), "URLSessionWebSocketTask echo"
