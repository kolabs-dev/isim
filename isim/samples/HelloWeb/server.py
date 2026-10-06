#!/usr/bin/env python3
"""Local test server for the web & communication samples (HelloWeb, HelloSafari, HelloLinks). No Internet needed.

  python3 server.py [PORT]      (PORT 0 or omitted: a free port; prints "PORT <n>" when ready)

GET /page3              HTML page that sets a cookie (Set-Cookie: visited=yes)
GET /redirect           302 -> /page3
GET /basic              HTTP Basic auth (user "ada", password "lovelace"), realm "isim"
GET /digest             HTTP Digest auth (MD5, qop=auth), same user/password, realm "isim-digest"
GET /bytes/<n>          n bytes (application/octet-stream, Content-Length, honours Range: bytes=a-)
GET /slowbytes/<n>      n bytes sent in 16 KB chunks 50 ms apart (for progress / cancel-with-resume-data)
GET /oauth/authorize    a sign-in page; its button goes to /oauth/approve?redirect_uri=...&state=...
GET /oauth/approve      302 to redirect_uri?code=abc123&state=...
GET /hello.txt          text
"""
import hashlib, os, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote

USER, PASSWORD = "ada", "lovelace"
NONCE = "dcd98b7102dd2f0e8b11d0f600bfb0c093"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("server: " + (fmt % args) + "\n")

    def reply(self, status, body=b"", ctype="text/plain; charset=utf-8", headers=()):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in headers:
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        u = urlparse(self.path)
        path, q = u.path, parse_qs(u.query)
        if path == "/page3":
            self.reply(200, "<!doctype html><html><head><meta name=viewport content='width=device-width'><title>Server Page</title></head>"
                            "<body style='font:20px sans-serif;margin:16px'><h1>Served over HTTP</h1><p id=c>cookie: <span id=cv></span></p>"
                            "<script>document.getElementById('cv').textContent=document.cookie</script></body></html>",
                       "text/html; charset=utf-8", [("Set-Cookie", "visited=yes; Path=/")])
        elif path == "/redirect":
            self.reply(302, "", headers=[("Location", "/page3")])
        elif path == "/hello.txt":
            self.reply(200, "hello from the local server\n")
        elif path == "/basic":
            import base64
            auth = self.headers.get("Authorization", "")
            ok = auth.startswith("Basic ") and base64.b64decode(auth[6:]).decode() == "%s:%s" % (USER, PASSWORD)
            if ok:
                self.reply(200, "basic ok: welcome %s" % USER)
            else:
                self.reply(401, "auth required", headers=[("WWW-Authenticate", 'Basic realm="isim"')])
        elif path == "/digest":
            auth = self.headers.get("Authorization", "")
            if auth.startswith("Digest ") and self.digest_ok(auth[7:]):
                self.reply(200, "digest ok: welcome %s" % USER)
            else:
                self.reply(401, "auth required", headers=[("WWW-Authenticate",
                           'Digest realm="isim-digest", qop="auth", nonce="%s", opaque="5ccc069c403ebaf9f0171e9517f40e41", algorithm=MD5' % NONCE)])
        elif path.startswith("/bytes/") or path.startswith("/slowbytes/"):
            n = int(path.rsplit("/", 1)[1])
            start = 0
            rng = self.headers.get("Range", "")
            if rng.startswith("bytes=") and rng[6:].split("-")[0].isdigit():
                start = int(rng[6:].split("-")[0])
            data = bytes((i * 7) & 255 for i in range(start, n))
            status = 206 if start else 200
            self.send_response(status)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("ETag", '"bytes-%d"' % n)
            self.send_header("Accept-Ranges", "bytes")
            if start:
                self.send_header("Content-Range", "bytes %d-%d/%d" % (start, n - 1, n))
            self.end_headers()
            if path.startswith("/slowbytes/"):
                for i in range(0, len(data), 16384):
                    try:
                        self.wfile.write(data[i:i + 16384]); self.wfile.flush()
                    except (BrokenPipeError, ConnectionResetError):
                        return
                    time.sleep(0.05)
            else:
                self.wfile.write(data)
        elif path == "/oauth/authorize":
            redirect, state = q.get("redirect_uri", [""])[0], q.get("state", [""])[0]
            approve = "/oauth/approve?redirect_uri=%s&state=%s" % (quote(redirect, safe=""), quote(state, safe=""))
            self.reply(200, "<!doctype html><html><head><meta name=viewport content='width=device-width'><title>Sign In</title></head>"
                            "<body style='font:18px sans-serif;margin:0;padding:24px;background:#f2f2f7'>"
                            "<h2 style='margin:0 0 12px'>Example Account</h2><p>Allow <b>HelloSafari</b> to access your profile?</p>"
                            "<a id=approve href='%s' style='position:absolute;left:24px;top:160px;width:300px;height:50px;line-height:50px;"
                            "text-align:center;background:#007aff;color:white;border-radius:12px;text-decoration:none'>Allow</a>"
                            "</body></html>" % approve, "text/html; charset=utf-8")
        elif path == "/oauth/approve":
            redirect, state = q.get("redirect_uri", [""])[0], q.get("state", [""])[0]
            self.reply(302, "", headers=[("Location", "%s?code=abc123&state=%s" % (redirect, quote(state, safe="")))])
        else:
            self.reply(404, "not found")

    def digest_ok(self, header):
        parts = {}
        for item in header.split(","):
            if "=" in item:
                k, v = item.strip().split("=", 1)
                parts[k] = v.strip('"')
        if parts.get("username") != USER or parts.get("nonce") != NONCE:
            return False
        ha1 = hashlib.md5(("%s:%s:%s" % (USER, parts.get("realm"), PASSWORD)).encode()).hexdigest()
        ha2 = hashlib.md5(("%s:%s" % (self.command, parts.get("uri"))).encode()).hexdigest()
        if parts.get("qop"):
            expect = hashlib.md5(("%s:%s:%s:%s:%s:%s" % (ha1, NONCE, parts.get("nc"), parts.get("cnonce"), parts.get("qop"), ha2)).encode()).hexdigest()
        else:
            expect = hashlib.md5(("%s:%s:%s" % (ha1, NONCE, ha2)).encode()).hexdigest()
        return parts.get("response") == expect


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("PORT %d" % srv.server_address[1], flush=True)
    srv.serve_forever()
