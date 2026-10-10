"""Swift networking self-test: sockets, URLSession, cookies, cache, NWPathMonitor (in-process server), and
URLSessionWebSocketTask against ws_server.py: ws://, and wss:// with a throwaway certificate for localhost that only
this run trusts (SSL_CERT_FILE; skipped without the openssl command). With that certificate, https_server.py serves
the server-trust (pinning) and client-certificate checks: a throwaway client CA and a PKCS#12 client identity."""
import base64
import shutil
import ssl
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


def client_identity(d: Path):
    """a client CA and a client identity it issued (CN isim-client) as PKCS#12 with the password "isim": (ca, p12)"""
    ca, cakey, key, csr, crt, p12 = (d / n for n in ("ca.pem", "ca.key", "client.key", "client.csr", "client.pem", "client.p12"))
    steps = [
        ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=isim test client CA",
         "-keyout", str(cakey), "-out", str(ca)],
        ["req", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=isim-client", "-keyout", str(key), "-out", str(csr)],
        ["x509", "-req", "-in", str(csr), "-CA", str(ca), "-CAkey", str(cakey), "-CAcreateserial", "-days", "1", "-out", str(crt)],
        ["pkcs12", "-export", "-inkey", str(key), "-in", str(crt), "-out", str(p12), "-passout", "pass:isim"],
    ]
    for args in steps:
        subprocess.run(["openssl", *args], capture_output=True, check=True)
    return ca, p12


def test_swift_network(device_data, tmp_path):
    need_apps("SwiftNetworkTest")
    with ExitStack() as stack:
        env = {"ISIM_TEST_WS_PORT": str(stack.enter_context(local_server(HERE / "ws_server.py", tmp_path / "ws.log")))}
        tls = localhost_cert(tmp_path)
        if tls:
            env["ISIM_TEST_WSS_PORT"] = str(stack.enter_context(
                local_server(HERE / "ws_server.py", tmp_path / "wss.log", args=("0", *tls))))
            env["SSL_CERT_FILE"] = str(tls[0])                  # trust exactly this certificate (OpenSSL's default paths)
            ca, p12 = client_identity(tmp_path)
            env["ISIM_TEST_HTTPS_PORT"] = str(stack.enter_context(
                local_server(HERE / "https_server.py", tmp_path / "https.log", args=("0", *tls))))
            env["ISIM_TEST_HTTPS_MTLS_PORT"] = str(stack.enter_context(
                local_server(HERE / "https_server.py", tmp_path / "mtls.log", args=("0", *tls, str(ca)))))
            env["ISIM_TEST_HTTPS_CERT"] = base64.b64encode(ssl.PEM_cert_to_DER_cert(tls[0].read_text())).decode()
            env["ISIM_TEST_CLIENT_P12"] = str(p12)
        selftest("SwiftNetworkTest", data=device_data, executable=True, timeout=90, env=env)
