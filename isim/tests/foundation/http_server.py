#!/usr/bin/env python3
"""HTTP server for FoundationTest's Objective-C URL loading checks.

  python3 http_server.py PORT   (PORT 0: a free port; prints "PORT <n>" when ready)

GET  /hello      200 "hello objc" (text/plain)
GET  /cookie     200, Set-Cookie: flavor=oatmeal; Path=/
GET  /redirect   302 to /hello
GET  /auth       401 (Basic realm "isim") unless Authorization is Basic user:secret
POST /echo       200 with the request body (application/octet-stream)
"""
import base64
import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, code, body=b"", headers=()):
        self.send_response(code)
        for k, v in headers:
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/hello":
            self.reply(200, b"hello objc", [("Content-Type", "text/plain")])
        elif self.path == "/cookie":
            self.reply(200, b"cookie", [("Content-Type", "text/plain"), ("Set-Cookie", "flavor=oatmeal; Path=/")])
        elif self.path == "/redirect":
            self.reply(302, b"", [("Location", "/hello")])
        elif self.path == "/auth":
            want = "Basic " + base64.b64encode(b"user:secret").decode()
            if self.headers.get("Authorization") == want:
                self.reply(200, b"welcome", [("Content-Type", "text/plain")])
            else:
                self.reply(401, b"", [("WWW-Authenticate", 'Basic realm="isim"')])
        else:
            self.reply(404)

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/echo":
            self.reply(200, body, [("Content-Type", "application/octet-stream")])
        else:
            self.reply(404)

    def log_message(self, fmt, *args):
        print(fmt % args, file=sys.stderr, flush=True)


def main():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 0), Handler)
    print("PORT", srv.server_address[1], flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
