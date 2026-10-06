#!/usr/bin/env python3
"""Local test server for the HelloNetwork sample (no Internet needed).

  python3 server.py [PORT]      (PORT 0 or omitted: a free port; prints "PORT <n>" when ready)

GET  /todos       JSON array                     GET  /message   text
POST /login       {"user": ...} -> Set-Cookie    GET  /me        the cookie's user, else 401
GET  /status/<n>  that status code               GET  /ws        WebSocket echo ("echo: <text>")
"""
import base64, hashlib, json, struct, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TODOS = [{"id": 1, "title": "Write the network layer", "done": True},
         {"id": 2, "title": "Decode JSON", "done": True},
         {"id": 3, "title": "Ship it", "done": False}]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("server: " + (fmt % args) + "\n")

    def reply(self, status, body=b"", ctype="text/plain; charset=utf-8", headers=()):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in headers:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/todos":
            self.reply(200, json.dumps(TODOS).encode(), "application/json")
        elif path == "/message":
            self.reply(200, "Hello from a local server 👋".encode())
        elif path == "/me":
            cookies = dict(c.strip().split("=", 1) for c in self.headers.get("Cookie", "").split(";") if "=" in c)
            if "session" in cookies:
                self.reply(200, json.dumps({"user": cookies["session"]}).encode(), "application/json")
            else:
                self.reply(401, b'{"error":"not signed in"}', "application/json")
        elif path.startswith("/status/"):
            code = int(path.rsplit("/", 1)[1])
            self.reply(code, ("status %d" % code).encode())
        elif path == "/ws" and self.headers.get("Upgrade", "").lower() == "websocket":
            self.websocket()
        else:
            self.reply(404, b"not found")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if self.path == "/login":
            user = json.loads(body or b"{}").get("user", "guest")
            self.reply(200, json.dumps({"ok": True}).encode(), "application/json",
                       [("Set-Cookie", "session=%s; Path=/; Max-Age=3600; HttpOnly" % user)])
        else:
            self.reply(404, b"not found")

    # minimal RFC 6455 echo server (text frames, ping, close)
    def websocket(self):
        key = self.headers["Sec-WebSocket-Key"]
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.wfile.flush()
        while True:
            head = self.rfile.read(2)
            if len(head) < 2:
                break
            opcode, n = head[0] & 0x0F, head[1] & 0x7F
            if n == 126:
                n = struct.unpack("!H", self.rfile.read(2))[0]
            elif n == 127:
                n = struct.unpack("!Q", self.rfile.read(8))[0]
            mask = self.rfile.read(4) if head[1] & 0x80 else b"\0\0\0\0"
            data = bytes(b ^ mask[i % 4] for i, b in enumerate(self.rfile.read(n)))
            if opcode == 1:
                self.frame(1, ("echo: " + data.decode()).encode())
            elif opcode == 2:
                self.frame(2, data)
            elif opcode == 9:
                self.frame(10, data)
            elif opcode == 8:
                self.frame(8, data[:2] or struct.pack("!H", 1000))
                break
        self.close_connection = True

    def frame(self, opcode, payload):
        n = len(payload)
        head = bytes([0x80 | opcode]) + (bytes([n]) if n < 126 else bytes([126]) + struct.pack("!H", n) if n < 65536 else bytes([127]) + struct.pack("!Q", n))
        self.wfile.write(head + payload)
        self.wfile.flush()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 0), Handler)
    print("PORT", server.server_address[1], flush=True)
    server.serve_forever()
