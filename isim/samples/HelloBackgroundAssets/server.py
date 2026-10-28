#!/usr/bin/env python3
"""Local asset server for HelloBackgroundAssets (BackgroundAssets). No Internet needed.

  python3 server.py [PORT]      (PORT 0: a free port; prints "PORT <n>" when ready; default 8460, the app's BAManifestURL)

GET /manifest.json      the app's asset manifest (its own format: the downloader extension reads it)
GET /files/<name>       an asset: <size> bytes of the name repeated (intro.bin, level2.bin, huge.bin, bonus.bin, extra.bin)
"""
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SIZES = {"intro.bin": 4096, "level2.bin": 8192, "huge.bin": 150000, "bonus.bin": 2048, "extra.bin": 1024}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        host = self.headers.get("Host") or f"127.0.0.1:{self.server.server_port}"
        if self.path == "/manifest.json":
            body = json.dumps({"base": f"http://{host}", "files": [
                {"id": "intro", "path": "/files/intro.bin", "size": SIZES["intro.bin"], "essential": True},
                {"id": "level2", "path": "/files/level2.bin", "size": SIZES["level2.bin"], "essential": False},
                {"id": "huge", "path": "/files/huge.bin", "size": SIZES["huge.bin"], "essential": True},
            ]}).encode()
            ctype = "application/json"
        elif self.path.startswith("/files/") and self.path[7:] in SIZES:
            name = self.path[7:]
            body = (name.encode() * (SIZES[name] // len(name) + 1))[:SIZES[name]]
            ctype = "application/octet-stream"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    s = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 8460), Handler)
    print(f"PORT {s.server_address[1]}", flush=True)
    s.serve_forever()
