"""HelloConnections: Network framework (TCP/UDP echo through NWListener + NWConnection, refused connection and DNS
failure states, TLS client with default and app trust + ALPN against a local TLS server, Bonjour advertising / browsing /
connecting through isim's local registry), MultipeerConnectivity (advertiser, browser, invitation, data both ways), and
URLSession: Basic and Digest challenges, credential storage, the plain 401, server-trust challenge (default rejects a
self-signed certificate, useCredential(trust:) accepts, cancel), task metrics + progress over a redirect, a download
cancelled with resume data and resumed with a Range request. Local servers only: samples/HelloWeb/server.py and
samples/HelloConnections/tls_echo.py. Port of tests/ui/connections.sh."""
import re
import sys

import pytest
from isimtest import ROOT, server

EXPECTED = {   # check: the line HelloConnections logs
    "NWListener + NWConnection TCP echo, currentPath": "tcp echo: echo:hello tcp error=none remote=ok",
    "UDP echo (listener datagram connection)": "udp echo: echo:datagram",
    "refused -> .waiting(ECONNREFUSED)": "refused: waiting ECONNREFUSED",
    "DNS failure -> .waiting(.dns)": "dns: waiting dns -65554",
    "TLS: self-signed certificate rejected by default": "tls default trust: failed OSStatus(-9807)",
    "TLS: verify block accepts, TLS 1.3, ALPN": "tls custom trust: echo:secret version=TLSv1.3 alpn=isim-echo",
    "Bonjour: advertise, NWBrowser with TXT, connect to service":
        "bonjour: found Echo Service._isimecho._tcplocal. txt v=1 reply=echo:via bonjour",
    "MultipeerConnectivity: find, invite": "multipeer: found Bob room=lobby; invitation from Alice context=hi",
    "URLSession Basic auth challenge, wrong password cancelled":
        "basic auth: 200 basic ok: welcome ada challenges=[basic realm=isim failures=0, basic realm=isim failures=0, "
        "basic realm=isim failures=1] wrong=cancelled",
    "URLCredentialStorage default credential (performDefaultHandling)":
        "credential storage: 200 basic ok: welcome ada challenges=1",
    "no credential: the 401 response is the result": "no credential: status 401",
    "Digest auth (MD5, qop=auth)": "digest auth: 200 digest ok: welcome ada challenges=[digest realm=isim-digest failures=0]",
    "server trust challenge: default / useCredential(trust:) / cancel":
        "server trust: default=-1202 trusted=hello tls cancel=-999 asked=serverTrust localhost",
    "download cancelled with resume data, resumed (Range)":
        "resume: partial=true resumedAt=true size=800000 intact=true error=none",
}


@pytest.fixture
def servers(tmp_path):
    with server(sys.executable, ROOT / "samples/HelloWeb/server.py", 0, log=tmp_path / "server.log") as web, \
         server(sys.executable, ROOT / "samples/HelloConnections/tls_echo.py", tmp_path / "tls",
                log=tmp_path / "tls.log") as tls:
        yield web, tls


def test_connections(launch, servers):
    web, tls = servers
    app = launch("HelloConnections", args=["-server", web.url, "-tls", str(tls.port)])
    app.wait_log(r"HelloConnections: done: all scenarios ran", timeout=60)
    log = app.log
    missing = [what for what, line in EXPECTED.items() if f"HelloConnections: {line}" not in log]
    assert not missing, f"missing: {missing}\n" + "\n".join(l for l in log.splitlines() if "HelloConnections:" in l)
    assert re.search(r"HelloConnections: multipeer: .*Alice connected to Bob.*Bob got ping from Alice.*Alice got pong from Bob",
                     log), "MultipeerConnectivity: connect, data both ways"
    assert re.search(r"HelloConnections: metrics: transactions=2 redirects=1 protocol=http/1\.1 remote=127\.0\.0\.1 "
                     r"fetch=true ordered=true progress=([0-9]+)/\1 fraction=1\.0", log), \
        "URLSessionTaskMetrics over a redirect + task progress"
    assert "GET /slowbytes/800000" in web.log, "the resumed download asked the server again"
    assert app.quit() == 0
