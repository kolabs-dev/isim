"""App Transport Security (HelloTransportSecurity): the app's Info.plist NSAppTransportSecurity decides which
URLSession and WKWebView loads may use cleartext HTTP and which TLS settings HTTPS needs. Checks: IP addresses are
exempt, NSAllowsLocalNetworking (which makes NSAllowsArbitraryLoads ignored), exception domains with subdomains and a
more specific entry, a redirect to a blocked host, a ws:// WebSocket task, TLS 1.2 with forward secrecy by default,
NSExceptionMinimumTLSVersion and NSExceptionRequiresForwardSecrecy against servers limited to TLS 1.2 or to RSA key
exchange, and a WKWebView navigation failing provisionally. Blocked loads never reach the server. *.localhost names
resolve to the loopback address in libcurl itself."""
import http.server
import shutil
import socket
import ssl
import subprocess
import threading

import pytest

ATS_ERROR = r"error=-1022 \(The resource could not be loaded because the App Transport Security policy requires the use of a secure connection\.\)"


class Handler(http.server.BaseHTTPRequestHandler):
    hosts: list = []

    def do_GET(self):
        Handler.hosts.append(self.headers.get("Host", ""))
        if self.path.startswith("/redirect?to="):
            self.send_response(302)
            self.send_header("Location", self.path.split("=", 1)[1])
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        body = b"<html><head><title>ATS</title></head><body>hello</body></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


def tls_server(cert, key, ciphers=None):
    """an HTTPS server of TLS 1.2 at most (ciphers: OpenSSL's list for it); returns its port"""
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cert, key)
    ctx.maximum_version = ssl.TLSVersion.TLSv1_2
    if ciphers:
        ctx.set_ciphers(ciphers)
    srv = socket.create_server(("127.0.0.1", 0))

    def serve():
        while True:
            conn, _ = srv.accept()
            try:
                with ctx.wrap_socket(conn, server_side=True) as c:
                    data = b""
                    while b"\r\n\r\n" not in data:
                        chunk = c.recv(4096)
                        if not chunk:
                            break
                        data += chunk
                    c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
            except (ssl.SSLError, OSError):
                pass                                          # a handshake ATS's settings refused
    threading.Thread(target=serve, daemon=True).start()
    return srv.getsockname()[1]


def test_transport_security(launch, tmp_path):
    if not shutil.which("openssl"):
        pytest.skip("needs the openssl command for a throwaway certificate")
    cert, key = tmp_path / "cert.pem", tmp_path / "key.pem"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost",
                    "-addext", "subjectAltName=DNS:*.localhost", "-keyout", str(key), "-out", str(cert)],
                   capture_output=True, check=True)
    tls12 = tls_server(cert, key)
    rsa = tls_server(cert, key, "AES256-GCM-SHA384:AES128-GCM-SHA256")    # RSA key exchange: no forward secrecy
    Handler.hosts = []
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    port = httpd.server_address[1]
    try:
        app = launch("HelloTransportSecurity", args=["-http", str(port), "-tls12", str(tls12), "-rsa", str(rsa)],
                     env={"no_proxy": "*", "NO_PROXY": "*"})
        app.wait_log(r"HelloTransportSecurity: ip status=200")
        app.wait_log(r"HelloTransportSecurity: localhost status=200")
        app.wait_log(r"App Transport Security has blocked a cleartext HTTP \(http://\) resource load since it is insecure.*blocked\.localhost")
        app.wait_log(r"HelloTransportSecurity: blocked " + ATS_ERROR)
        app.wait_log(r"HelloTransportSecurity: exception status=200")
        app.wait_log(r"HelloTransportSecurity: subdomain status=200")
        app.wait_log(r"HelloTransportSecurity: specific " + ATS_ERROR)
        app.wait_log(r"HelloTransportSecurity: redirect " + ATS_ERROR)
        app.wait_log(r"HelloTransportSecurity: https status=200")
        app.wait_log(r"HelloTransportSecurity: tls13 error=-1200")
        app.wait_log(r"HelloTransportSecurity: nofs error=-1200")
        app.wait_log(r"HelloTransportSecurity: legacy status=200")
        app.wait_log(r"HelloTransportSecurity: websocket error=-1022")
        app.wait_view(r"id=results")
        app.wait_log(r"HelloTransportSecurity: web didFailProvisionalNavigation NSURLErrorDomain -1022 http://blocked\.localhost:\d+/")
        app.wait_log(r"HelloTransportSecurity: web didFinish http://localhost:\d+/")
        app.wait_log(r"HelloTransportSecurity: done")
        blocked = [h for h in Handler.hosts if h.startswith(("blocked.", "secure."))]
        assert not blocked, f"blocked loads reached the server: {blocked}"
        assert any(h.startswith("api.insecure.localhost") for h in Handler.hosts), Handler.hosts
        assert app.quit() == 0
    finally:
        httpd.shutdown()
