#!/usr/bin/env python3
"""Another machine on the network for HelloConnections' multicast DNS scenario (no Internet, standard library only).

  python3 mdns_peer.py [PORT]     (prints "PORT <n>" when ready: its TCP echo service)

- advertises "Python Peer._isimpy._tcp.local" (TXT from=python) with a TCP echo service: answers multicast DNS
  queries for it (PTR, SRV, TXT, A 127.0.0.1) and announces it;
- browses for "_isimapp._tcp.local" with legacy unicast queries from its own port (RFC 6762 §6.7), connects to the
  first instance it resolves and logs its reply: "peer: found <name> port <n> reply=<text>" (stderr).
"""
import socket, struct, sys, threading, time

GROUP, PORT = "224.0.0.251", 5353
MY_TYPE, APP_TYPE, NAME = "_isimpy._tcp.local", "_isimapp._tcp.local", "Python Peer"
HOST = "python-peer.local"


def log(s):
    sys.stderr.write(s + "\n"); sys.stderr.flush()


def enc_name(n, instance=None):
    out = b""
    labels = ([instance] if instance else []) + n.split(".")
    for l in labels:
        b = l.encode(); out += bytes([len(b)]) + b
    return out + b"\0"


def rr(name, rtype, rdata, ttl=120, flush=True, instance=None):
    return enc_name(name, instance) + struct.pack(">HHIH", rtype, 1 | (0x8000 if flush else 0), ttl, len(rdata)) + rdata


def read_name(b, i):
    labels, end, jumps = [], None, 0
    while True:
        l = b[i]
        if l == 0:
            i += 1; break
        if l & 0xC0 == 0xC0:
            if end is None: end = i + 2
            i = ((l & 0x3F) << 8) | b[i + 1]; jumps += 1
            if jumps > 16: raise ValueError
            continue
        labels.append(b[i + 1:i + 1 + l].decode("utf-8", "replace")); i += 1 + l
    return labels, (end if end is not None else i)


def parse(b):
    _, flags, qd, an, ns, ar = struct.unpack(">HHHHHH", b[:12])
    i, qs, rrs = 12, [], []
    for _ in range(qd):
        n, i = read_name(b, i); t, c = struct.unpack(">HH", b[i:i + 4]); i += 4; qs.append((n, t))
    for _ in range(an + ns + ar):
        n, i = read_name(b, i); t, c, ttl, ln = struct.unpack(">HHIH", b[i:i + 10]); i += 10
        rd = b[i:i + ln]
        if t == 12: val = read_name(b, i)[0]
        elif t == 33: val = (struct.unpack(">H", rd[4:6])[0], read_name(b, i + 6)[0])
        else: val = rd
        i += ln; rrs.append((n, t, ttl, val))
    return flags & 0x8000 != 0, qs, rrs


srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", int(sys.argv[1]) if len(sys.argv) > 1 else 0)); srv.listen(8)
echo_port = srv.getsockname()[1]


def serve():
    while True:
        c, _ = srv.accept()
        data = c.recv(4096)
        log("peer: echo got %r" % data.decode(errors="replace"))
        c.sendall(b"python:" + data); c.close()


threading.Thread(target=serve, daemon=True).start()

txt = b"\x0bfrom=python"
answer = (struct.pack(">HHHHHH", 0, 0x8400, 0, 1, 0, 3) + rr(MY_TYPE, 12, enc_name(MY_TYPE, NAME), flush=False)
          + rr(MY_TYPE, 33, struct.pack(">HHH", 0, 0, echo_port) + enc_name(HOST), instance=NAME)
          + rr(MY_TYPE, 16, txt, instance=NAME) + rr(HOST, 1, socket.inet_aton("127.0.0.1")))

mc = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
mc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
mc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
mc.bind(("", PORT))
mc.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, socket.inet_aton(GROUP) + socket.inet_aton("0.0.0.0"))
mc.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
mc.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)


def responder():
    while True:
        b, src = mc.recvfrom(9000)
        try:
            is_resp, qs, _ = parse(b)
        except Exception:
            continue
        if not is_resp and any(".".join(n).lower() == MY_TYPE and t in (12, 255) for n, t in qs):
            log("peer: query for %s from %s:%d" % (MY_TYPE, *src))
            mc.sendto(answer, (GROUP, PORT))


threading.Thread(target=responder, daemon=True).start()
mc.sendto(answer, (GROUP, PORT))                                  # announce
print("PORT %d" % echo_port, flush=True)

# browse for the app's service with legacy unicast queries
q = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
q.bind(("", 0)); q.settimeout(0.5)
query = struct.pack(">HHHHHH", 0x1234, 0, 1, 0, 0, 0) + enc_name(APP_TYPE) + struct.pack(">HH", 12, 1)
done = False
while not done:
    q.sendto(query, (GROUP, PORT))
    end = time.time() + 0.5
    while time.time() < end and not done:
        try:
            b, src = q.recvfrom(9000)
            is_resp, _, rrs = parse(b)
        except (socket.timeout, ValueError, IndexError, struct.error):
            continue
        inst = next((v for n, t, ttl, v in rrs if t == 12 and ".".join(n).lower() == APP_TYPE), None)
        srv_rec = next((v for n, t, ttl, v in rrs if t == 33 and inst and n == inst), None)
        if not inst or not srv_rec:
            continue
        port, target = srv_rec
        addrs = [socket.inet_ntoa(v) for n, t, ttl, v in rrs if t == 1 and [x.lower() for x in n] == [x.lower() for x in target]]
        log("peer: answer for %s from %s:%d (id ok=%s)" % (inst[0], src[0], src[1], b[:2] == query[:2]))
        txts = [v for n, t, ttl, v in rrs if t == 16 and n == inst]
        try:
            c = socket.create_connection((addrs[0] if addrs else "127.0.0.1", port), timeout=3)
            c.sendall(b"hello from python"); reply = c.recv(4096).decode(errors="replace"); c.close()
        except OSError as e:
            reply = "error %s" % e
        log("peer: found %s port %d txt=%r addresses=%s reply=%s" % (inst[0], port, txts[0] if txts else b"", ",".join(addrs), reply))
        done = True
while True:
    time.sleep(3600)
