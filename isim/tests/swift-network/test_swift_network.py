"""Swift networking self-test: sockets, URLSession, cookies, cache, NWPathMonitor (in-process server), and
URLSessionWebSocketTask against ws_server.py: ws://, and wss:// with a throwaway certificate for localhost that only
this run trusts (SSL_CERT_FILE; skipped without the openssl command)."""
import shutil
import subprocess
from contextlib import ExitStack
from pathlib import Path

from isimtest import local_server, need_apps, selftest

HERE = Path(__file__).parent


def localhost_cert(d: Path):
    """a self-signed certificate for localhost (cert, key), or None without openssl"""
    if not shutil.which("openssl"):
        return None
    cert, key = d / "localhost.pem", d / "localhost.key"
    r = subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost",
                        "-addext", "subjectAltName=DNS:localhost", "-keyout", str(key), "-out", str(cert)],
                       capture_output=True)
    return (cert, key) if r.returncode == 0 else None


def test_swift_network(device_data, tmp_path):
    need_apps("SwiftNetworkTest")
    with ExitStack() as stack:
        env = {"ISIM_TEST_WS_PORT": str(stack.enter_context(local_server(HERE / "ws_server.py", tmp_path / "ws.log")))}
        tls = localhost_cert(tmp_path)
        if tls:
            env["ISIM_TEST_WSS_PORT"] = str(stack.enter_context(
                local_server(HERE / "ws_server.py", tmp_path / "wss.log", args=("0", *tls))))
            env["SSL_CERT_FILE"] = str(tls[0])                  # trust exactly this certificate (OpenSSL's default paths)
        selftest("SwiftNetworkTest", data=device_data, executable=True, timeout=90, env=env)
