#!/usr/bin/env python3
"""Local TLS test server for HelloConnections (no Internet). A self-signed certificate for "localhost" is made
with the host's openssl in DIR. ALPN: isim-echo, http/1.1.

  python3 tls_echo.py DIR [PORT]     (prints "PORT <n>" when ready)

A client that starts with "GET " gets an HTTP/1.0 response "hello tls"; anything else is echoed as "echo:<data>".
"""
import os, socket, ssl, subprocess, sys, threading

d = sys.argv[1]; os.makedirs(d, exist_ok=True)
cert, key = os.path.join(d, "cert.pem"), os.path.join(d, "key.pem")
if not os.path.exists(cert):
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cert, "-days", "2",
                    "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, capture_output=True)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
ctx.set_alpn_protocols(["isim-echo", "http/1.1"])
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", int(sys.argv[2]) if len(sys.argv) > 2 else 0)); srv.listen(16)
print("PORT %d" % srv.getsockname()[1], flush=True)

def serve(raw):
    try:
        c = ctx.wrap_socket(raw, server_side=True)
    except Exception as e:
        sys.stderr.write("tls: handshake failed: %s\n" % e); raw.close(); return
    try:
        data = c.recv(65536)
        if data.startswith(b"GET "):
            while b"\r\n\r\n" not in data:
                more = c.recv(65536)
                if not more: break
                data += more
            body = b"hello tls"
            c.sendall(b"HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n%s" % (len(body), body))
        else:
            while data:
                c.sendall(b"echo:" + data)
                data = c.recv(65536)
    except Exception as e:
        sys.stderr.write("tls: %s\n" % e)
    finally:
        try: c.close()
        except Exception: pass

while True:
    conn, _ = srv.accept()
    threading.Thread(target=serve, args=(conn,), daemon=True).start()
