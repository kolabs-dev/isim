"""CryptoTokenKit on the host's PC/SC readers (issue #745): with ISIM_PCSC=1 the readers of a running pcscd are slots
next to the virtual ones, and their cards take APDUs through pcsclite (SCardTransmit). The reader is vsmartcard's
virtual PC/SC reader (vpcd, a pcscd driver); the card in it is a small PIV-like card this test emulates over vpcd's
socket protocol. HelloSmartCard watches the slot, reads the ATR, selects the applet, reads a CHUID longer than one
response (GET RESPONSE) and sees the card leave. Skipped where pcscd or vpcd is not installed (CI's stock image), or
where a pcscd is already running (the test needs its own, with the virtual reader)."""
import ctypes
import os
import shutil
import socket
import struct
import subprocess
import threading
import time

import pytest

APP = "HelloSmartCard"
VPCD = "/usr/lib/pcsc/drivers/serial/libifdvpcd.so"
READER = "isim Test PCD 00 00"
ATR = bytes.fromhex("3BFD1300008131FE158073C021C057597562694B657940")
PIV = bytes.fromhex("A000000308000010000100")
FCI = bytes.fromhex("61114F0600001000010079074F05A000000308")
CHUID = bytes([0x53, 0x82, 0x01, 0x2C]) + bytes(range(256)) + bytes(44)       # 300 bytes of value: GET RESPONSE


class Card:
    """a card behind vpcd: answers vpcd's power / ATR requests and a few PIV commands"""
    def __init__(self, port):
        self.port, self.sock, self.apdus, self.rest = port, None, [], b""
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def answer(self, apdu):
        self.apdus.append(apdu.hex().upper())
        ins = apdu[1]
        if ins == 0xA4 and apdu[2] == 0x04:
            return FCI + b"\x90\x00" if apdu[5:5 + apdu[4]] == PIV else b"\x6A\x82"
        if ins == 0xCB and apdu[5:10] == bytes.fromhex("5C035FC102"):
            return self.chunk(CHUID)
        if ins == 0xCB:
            return b"\x69\x82"                                          # the certificate: the PIN first
        if ins == 0xC0:
            return self.chunk(self.rest) if self.rest else b"\x69\x85"
        if ins == 0x20:
            return b"\x63\xC3"
        return b"\x6D\x00"

    def chunk(self, d):
        self.rest = d[256:]
        return d[:256] + (bytes([0x61, min(len(self.rest), 255) & 0xFF]) if self.rest else b"\x90\x00")

    def run(self):
        while not self.stop.is_set():                                   # vpcd listens once pcscd has loaded it
            try:
                self.sock = socket.create_connection(("127.0.0.1", self.port), timeout=1)
                break
            except OSError:
                self.stop.wait(0.2)
        if not self.sock:
            return
        self.sock.settimeout(None)
        f = self.sock.makefile("rb")
        try:
            while True:
                head = f.read(2)
                if len(head) < 2:
                    return
                msg = f.read(struct.unpack(">H", head)[0])
                if len(msg) == 1:                                       # 0 off, 1 on, 2 reset, 4 the ATR
                    if msg[0] == 4:
                        self.sock.sendall(struct.pack(">H", len(ATR)) + ATR)
                    continue
                r = self.answer(msg)
                self.sock.sendall(struct.pack(">H", len(r)) + r)
        except OSError:
            return

    def remove(self):
        self.stop.set()
        if self.sock:
            self.sock.shutdown(socket.SHUT_RDWR)
            self.sock.close()


def pcsc_readers():
    lib = ctypes.CDLL("libpcsclite.so.1")
    ctx = ctypes.c_long()
    if lib.SCardEstablishContext(2, None, None, ctypes.byref(ctx)):
        return None
    try:
        n = ctypes.c_ulong(0)
        if lib.SCardListReaders(ctx, None, None, ctypes.byref(n)):
            return []
        b = ctypes.create_string_buffer(n.value)
        lib.SCardListReaders(ctx, None, b, ctypes.byref(n))
        return [x.decode() for x in b.raw.split(b"\0") if x]
    finally:
        lib.SCardReleaseContext(ctx)


@pytest.fixture
def pcscd(tmp_path):
    if not shutil.which("pcscd") or not os.path.exists(VPCD):
        pytest.skip("pcscd or vsmartcard's vpcd is not installed (apt install pcscd vsmartcard-vpcd)")
    try:
        ctypes.CDLL("libpcsclite.so.1")
    except OSError:
        pytest.skip("libpcsclite.so.1 is not installed")
    if pcsc_readers() is not None:
        pytest.skip("a pcscd is already running: the test needs its own, with the virtual reader")
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    conf = tmp_path / "reader.conf.d"
    conf.mkdir()
    (conf / "vpcd").write_text(f'FRIENDLYNAME "isim Test PCD"\nDEVICENAME /dev/null:0x{port:X}\nLIBPATH {VPCD}\nCHANNELID 0x{port:X}\n')
    log = open(tmp_path / "pcscd.log", "w")
    p = subprocess.Popen(["pcscd", "-f", "-c", str(conf), "--disable-polkit"], stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 20                               # a condition, polled: pcscd has loaded the reader
        while p.poll() is None and READER not in (pcsc_readers() or []) and time.monotonic() < deadline:
            time.sleep(0.1)
        if p.poll() is not None or READER not in (pcsc_readers() or []):
            pytest.skip(f"pcscd did not start with the virtual reader: {(tmp_path / 'pcscd.log').read_text()[-400:]}")
        yield port
    finally:
        p.terminate()
        p.wait(10)
        log.close()


def test_smartcard_pcsc(launch, device_data, pcscd):
    off = launch(APP, data=device_data, env={"SMARTCARD_READER": READER})     # without ISIM_PCSC=1: no host readers
    off.wait_log(r"^sc slots \[\]$")
    off.quit()

    card = Card(pcscd)
    app = launch(APP, data=device_data, env={"ISIM_PCSC": "1", "SMARTCARD_READER": READER})
    app.wait_log(r'^sc slots \["isim Test PCD 00 00", "isim Test PCD 00 01"\]$')
    app.wait_log(rf"^sc slot {READER} state=4$")
    app.wait_log(rf"^sc atr {ATR.hex().upper()} protocols=\[1\] historical=13 records=7:3,5:7 group2=1 t1=true$")

    app.wait_tap_id("read")
    app.wait_log(rf"^sc select sw=9000 fci={len(FCI)} protocol=2$")              # T=1, the protocol pcscd chose
    app.wait_log(rf"^sc chuid sw=9000 bytes={len(CHUID)} tag=53 value=300$")     # two responses: 61xx, GET RESPONSE
    app.wait_log(r"^sc certificate before PIN sw=6982$")
    app.wait_log(r"^sc pin status sw=63C3$")
    assert any(a.startswith("00C00000") for a in card.apdus), card.apdus

    card.remove()                                                                # the card leaves the reader
    app.wait_log(rf"^sc slot {READER} state=1$")
