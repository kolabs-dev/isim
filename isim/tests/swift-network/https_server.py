#!/usr/bin/env python3
"""HTTPS test server for the SwiftNetworkTest self-test (server trust and client certificates).

  python3 https_server.py PORT CERT KEY [CLIENT_CA]   (PORT 0: a free port; prints "PORT <n>" when ready)

Every request gets 200 "client=<CN of the client certificate>", or "client=none". With CLIENT_CA the server requires
a client certificate issued by that CA (and names it in its certificate request).
"""
import socket
import ssl
import sys
import threading


def serve(conn):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            return
        data += chunk
    cert = conn.getpeercert()
    cn = next((v for rdn in (cert or {}).get("subject", ()) for k, v in rdn if k == "commonName"), "none")
    body = f"client={cn}".encode()
    conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length: " +
                 str(len(body)).encode() + b"\r\n\r\n" + body)


def main():
    port, cert, key = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cert, key)
    if len(sys.argv) > 4:
        ctx.verify_mode = ssl.CERT_REQUIRED
        ctx.load_verify_locations(sys.argv[4])
    srv = socket.create_server(("127.0.0.1", port))
    print("PORT", srv.getsockname()[1], flush=True)
    while True:
        conn, _ = srv.accept()

        def run(c=conn):
            try:
                c = ctx.wrap_socket(c, server_side=True)
                serve(c)
            except (OSError, ssl.SSLError) as e:
                print("connection:", e, file=sys.stderr, flush=True)
            finally:
                c.close()
        threading.Thread(target=run, daemon=True).start()


if __name__ == "__main__":
    main()
