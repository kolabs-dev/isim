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
GET /attachment         a text file sent as an attachment (Content-Disposition: attachment; filename="report.txt")
GET /camera             a page that asks for the camera (getUserMedia) and shows the result in its title
GET /rules              a page with an "ad" image (/ads/pixel.png) and a .banner element; its title reports whether
                        content rule lists blocked the image and hid the banner
GET /ads/pixel.png      a 1x1 PNG
GET /article            a page with Open Graph tags (title, image /og.png, video) and an apple-touch-icon (/icon.png)
GET /plain              a page with a <title> and an icon link only (/icon.png)
GET /og.png, /icon.png  the article's image (600x314) and the icon (64x64), PNGs drawn here
GET /slowpage           a page sent after 5 s (for timeouts and cancelling)
"""
import hashlib, os, struct, sys, time, zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote

USER, PASSWORD = "ada", "lovelace"
NONCE = "dcd98b7102dd2f0e8b11d0f600bfb0c093"


def png(w, h, pixel):
    """a PNG of w x h RGB pixels, pixel(x, y) -> (r, g, b)"""
    rows = b"".join(b"\0" + bytes(c for x in range(w) for c in pixel(x, y)) for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


# the article image: a teal-to-blue gradient with a white disc; the icon: an orange square with a white bar
OG_PNG = png(600, 314, lambda x, y: (255, 255, 255) if (x - 300) ** 2 + (y - 157) ** 2 < 60 ** 2 else (0, 120 + x * 80 // 600, 200 + y * 55 // 314))
ICON_PNG = png(64, 64, lambda x, y: (255, 255, 255) if 14 < x < 50 and 28 < y < 36 else (255, 149, 0))


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
        elif path == "/attachment":
            self.reply(200, "quarterly report\n" * 64, headers=[("Content-Disposition", 'attachment; filename="report.txt"')])
        elif path == "/rules":
            self.reply(200, "<!doctype html><html><head><meta name=viewport content='width=device-width'><title>Rules</title></head>"
                            "<body style='font:20px sans-serif;margin:16px'><h1>Content rules</h1>"
                            "<div class=banner style='background:#ff9500;padding:12px'>Banner ad</div><p>Article text.</p><script>"
                            "var img=new Image();function report(s){var b=document.querySelector('.banner');"
                            "document.title='img '+s+' banner '+getComputedStyle(b).display}"
                            "img.onload=function(){report('loaded')};img.onerror=function(){report('blocked')};img.src='/ads/pixel.png?'+Date.now()"
                            "</script></body></html>", "text/html; charset=utf-8")
        elif path == "/article":
            self.reply(200, "<!doctype html><html><head><title>Fallback title</title>"
                            "<meta property='og:title' content='Building iOS apps on Linux &amp; more'>"
                            "<meta property=\"og:image\" content=\"/og.png\"><meta property='og:video' content='/video.mp4'>"
                            "<link rel='apple-touch-icon' href='/icon.png'><link rel=icon href='/favicon.ico'></head>"
                            "<body><h1>Article</h1></body></html>", "text/html; charset=utf-8")
        elif path == "/plain":
            self.reply(200, "<!doctype html><html><head><title>\n  A plain page\n</title><link rel='icon' href='icon.png'></head>"
                            "<body>plain</body></html>", "text/html; charset=utf-8")
        elif path == "/og.png":
            self.reply(200, OG_PNG, "image/png")
        elif path == "/icon.png":
            self.reply(200, ICON_PNG, "image/png")
        elif path == "/slowpage":
            time.sleep(5)
            try:
                self.reply(200, "<title>Slow</title>", "text/html")
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif path.startswith("/ads/"):
            import base64
            self.reply(200, base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="), "image/png")
        elif path == "/camera":
            self.reply(200, "<!doctype html><html><head><meta name=viewport content='width=device-width'><title>Camera</title></head>"
                            "<body style='font:20px sans-serif;margin:16px'><h1>Camera</h1><video id=v autoplay playsinline width=200></video><script>"
                            "navigator.mediaDevices.getUserMedia({video:true}).then(function(s){document.getElementById('v').srcObject=s;"
                            "document.title='camera '+s.getVideoTracks().length}).catch(function(e){document.title='camera '+e.name})"
                            "</script></body></html>", "text/html; charset=utf-8")
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
