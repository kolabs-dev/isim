"""HelloConnections: Network framework (TCP/UDP echo through NWListener + NWConnection, refused connection and DNS
failure states, TLS client with default and app trust + ALPN against a local TLS server, Bonjour advertising / browsing /
connecting through isim's local registry), MultipeerConnectivity (advertiser, browser, invitation, data both ways, a byte
stream, security identities: certificates exchanged, accepted and refused by the session delegate), and
URLSession: Basic and Digest challenges, credential storage, the plain 401, server-trust challenge (default rejects a
self-signed certificate, useCredential(trust:) accepts, cancel), task metrics + progress over a redirect, a download
cancelled with resume data and resumed with a Range request. Local servers only: samples/HelloWeb/server.py and
samples/HelloConnections/tls_echo.py. Port of tests/ui/connections.sh."""
import re
import shutil
import subprocess

import pytest
from isimtest import ROOT, local_server

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
    log = tmp_path / "server.log"
    with local_server(ROOT / "samples/HelloWeb/server.py", log) as web, \
         local_server(ROOT / "samples/HelloConnections/tls_echo.py", tmp_path / "tls.log", args=[tmp_path / "tls"]) as tls:
        yield web, tls, log


def peer_identity(d):
    """a self-signed identity (CN isim-peer) as PKCS#12 with the password "isim", or None without openssl"""
    if not shutil.which("openssl"):
        return None
    key, crt, p12 = d / "peer.key", d / "peer.pem", d / "peer.p12"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=isim-peer",
                    "-keyout", str(key), "-out", str(crt)], capture_output=True, check=True)
    subprocess.run(["openssl", "pkcs12", "-export", "-inkey", str(key), "-in", str(crt), "-out", str(p12), "-passout", "pass:isim"],
                   capture_output=True, check=True)
    return p12


def test_connections(launch, servers, tmp_path):
    web, tls, server_log = servers
    p12 = peer_identity(tmp_path)
    app = launch("HelloConnections", args=["-server", f"http://127.0.0.1:{web}", "-tls", str(tls)] + (["-p12", str(p12)] if p12 else []))
    app.wait_log(r"HelloConnections: done: all scenarios ran", timeout=60)
    log = app.log
    missing = [what for what, line in EXPECTED.items() if f"HelloConnections: {line}" not in log]
    assert not missing, f"missing: {missing}\n" + "\n".join(l for l in log.splitlines() if "HelloConnections:" in l)
    assert re.search(r"HelloConnections: multipeer: .*Alice connected to Bob.*Bob got ping from Alice.*Alice got pong from Bob"
                     r".*Bob stream chunks from Alice: streamed bytes$", log, re.M), "MultipeerConnectivity: connect, data both ways, a stream"
    if p12:
        assert "HelloConnections: multipeer identities: Carol connected to Dave; Carol got certificate isim-peer from Dave; " \
               "Dave got certificate isim-peer from Carol; Dave got certificate none from Eve; Eve got certificate isim-peer from Dave; " \
               "Eve not connected to Dave" in log, "MultipeerConnectivity: security identities, certificates accepted / refused"
    assert re.search(r"HelloConnections: metrics: transactions=2 redirects=1 protocol=http/1\.1 remote=127\.0\.0\.1 "
                     r"fetch=true ordered=true progress=([0-9]+)/\1 fraction=1\.0", log), \
        "URLSessionTaskMetrics over a redirect + task progress"
    assert "GET /slowbytes/800000" in server_log.read_text(), "the resumed download asked the server again"
    assert app.quit() == 0


def test_connections_mdns(launch, tmp_path):
    """Bonjour over multicast DNS (ISIM_MDNS=1): mdns_peer.py plays another machine on the network. The app's
    NWBrowser finds the peer's service (PTR/SRV/TXT/A answers to its queries) and connects to it; the peer finds the
    app's NWListener service with a legacy unicast query and connects to it."""
    log = tmp_path / "peer.log"
    with local_server(ROOT / "samples/HelloConnections/mdns_peer.py", log):
        app = launch("HelloConnections", args=["-mdns"], env={"ISIM_MDNS": "1"})
        app.wait_log(r"HelloConnections: done: mdns", timeout=30)
        assert "HelloConnections: mdns: found Python Peer._isimpy._tcplocal. from=python reply=python:hello from isim" in app.log
        app.wait_log(r"HelloConnections: mdns: app service got hello from python", timeout=20)
        peer = log.read_text()
        assert "peer: answer for isim App" in peer and "(id ok=True)" in peer, peer
        assert re.search(r"peer: found isim App port [0-9]+ txt=b'\\tfrom=isim' addresses=\S+ reply=isim:hello from python", peer), peer
        assert app.quit() == 0


@pytest.mark.os_matrix
def test_connections_mcui(launch):
    """MultipeerConnectivity's system UI (HelloConnections -mcui): MCBrowserViewController lists Bob, who advertises
    with MCAdvertiserAssistant; tapping him invites him (Connecting), the assistant's alert asks Bob, Accept connects
    both sessions (Connected) and Done reaches the browser's delegate."""
    app = launch("HelloConnections", args=["-mcui"])
    app.wait_tap_id("mc-browse")
    app.wait_view(r"text=Choose a Device")
    app.wait_tap_id("mc-peer-Bob")
    app.wait_log(r"HelloConnections: mcui: Alice connecting Bob")
    app.wait_log(r"HelloConnections: mcui: assistant will present invitation")
    app.wait_view("“Alice” wants to connect\\.")
    app.wait_view(r"text=Connecting")
    app.tap_text("Accept")
    app.wait_log(r"HelloConnections: mcui: assistant dismissed invitation")
    app.wait_log(r"HelloConnections: mcui: Alice connected Bob")
    app.wait_log(r"HelloConnections: mcui: Bob connected Alice")
    app.wait_view(r"text=Connected")
    app.wait_tap_id("mc-done")
    app.wait_log(r"HelloConnections: mcui: browser finished peers=Bob")
    assert app.quit() == 0
