#!/usr/bin/env python3
"""WebSocket test server for the SwiftNetworkTest self-test (RFC 6455, no third-party packages).

  python3 ws_server.py PORT [CERT KEY]   (PORT 0: a free port; prints "PORT <n>" when ready; CERT/KEY: serve wss)

GET /ws          the scenarios below; the client's frames must be masked (else close 1002)
GET /refuse      403 instead of the upgrade

Text messages on /ws:
  "headers?"     -> "x-isim=<X-Isim header> proto=<Sec-WebSocket-Protocol> query=<the request's query>" (the server
                    accepts the first protocol)
  "fragment"     -> a ping, then "frag-1 frag-2 frag-3" in three fragments with a ping between them
  "pongs?"       -> "pongs: <n>" (pongs received for the server's pings, with the right payloads)
  "big"          -> a 70000-byte binary message (64-bit length)
  "close"        -> a close frame, code 4001 reason "bye"
  anything else  -> "echo: <text>"
Binary messages are echoed; pings are answered with pongs carrying the same payload.
"""
import base64
import hashlib
import socket
import ssl
import struct
import sys
import threading

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def read_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            raise EOFError
        buf += chunk
    return buf


def frame(opcode, payload=b"", fin=True):
    n = len(payload)
    head = bytes([(0x80 if fin else 0) | opcode])
    head += bytes([n]) if n < 126 else bytes([126]) + struct.pack("!H", n) if n < 65536 else bytes([127]) + struct.pack("!Q", n)
    return head + payload


def serve(conn):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            return
        data += chunk
    head = data.split(b"\r\n\r\n", 1)[0].decode("latin-1").split("\r\n")
    path, _, query = head[0].split()[1].partition("?")
    headers = {k.strip().lower(): v.strip() for k, v in (line.split(":", 1) for line in head[1:] if ":" in line)}
    if path != "/ws" or headers.get("upgrade", "").lower() != "websocket":
        conn.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        return
    accept = base64.b64encode(hashlib.sha1((headers["sec-websocket-key"] + GUID).encode()).digest()).decode()
    proto = headers.get("sec-websocket-protocol", "").split(",")[0].strip()
    conn.sendall(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                  f"Sec-WebSocket-Accept: {accept}\r\n" + (f"Sec-WebSocket-Protocol: {proto}\r\n" if proto else "") +
                  "\r\n").encode())
    pongs, pings_sent = 0, []
    while True:
        try:
            b0, b1 = read_exact(conn, 2)
        except EOFError:
            return
        opcode, n = b0 & 0x0F, b1 & 0x7F
        if n == 126:
            n = struct.unpack("!H", read_exact(conn, 2))[0]
        elif n == 127:
            n = struct.unpack("!Q", read_exact(conn, 8))[0]
        if not b1 & 0x80:                                     # clients must mask their frames
            conn.sendall(frame(8, struct.pack("!H", 1002) + b"unmasked"))
            return
        mask = read_exact(conn, 4)
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(read_exact(conn, n)))
        if opcode == 1:
            text = payload.decode()
            if text == "headers?":
                conn.sendall(frame(1, f"x-isim={headers.get('x-isim', '')} proto={proto} query={query}".encode()))
            elif text == "fragment":
                pings_sent += [b"p1", b"p2"]
                conn.sendall(frame(9, b"p1") + frame(1, b"frag-1 ", fin=False) + frame(9, b"p2") +
                             frame(0, b"frag-2 ", fin=False) + frame(0, b"frag-3"))
            elif text == "pongs?":
                conn.sendall(frame(1, f"pongs: {pongs}".encode()))
            elif text == "big":
                conn.sendall(frame(2, bytes(i % 251 for i in range(70000))))
            elif text == "close":
                conn.sendall(frame(8, struct.pack("!H", 4001) + b"bye"))
            else:
                conn.sendall(frame(1, b"echo: " + payload))
        elif opcode == 2:
            conn.sendall(frame(2, payload))
        elif opcode == 9:
            conn.sendall(frame(10, payload))
        elif opcode == 10:
            if pings_sent and payload == pings_sent[0]:
                pings_sent.pop(0)
                pongs += 1
        elif opcode == 8:
            conn.sendall(frame(8, payload[:2] or struct.pack("!H", 1000)))
            return


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    ctx = None
    if len(sys.argv) > 3:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(sys.argv[2], sys.argv[3])
    srv = socket.create_server(("127.0.0.1", port))
    print("PORT", srv.getsockname()[1], flush=True)
    while True:
        conn, _ = srv.accept()

        def run(c=conn):
            try:
                if ctx:
                    c = ctx.wrap_socket(c, server_side=True)
                serve(c)
            except (OSError, ssl.SSLError, EOFError) as e:
                print("connection:", e, file=sys.stderr, flush=True)
            finally:
                c.close()
        threading.Thread(target=run, daemon=True).start()


if __name__ == "__main__":
    main()
