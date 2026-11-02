"""CryptoTokenKit persistent tokens (issue #743, HelloToken): a PIV card with an ECC P-256 key and its certificate goes in
a virtual reader; HelloToken's token driver extension (matched by the PIV AID) makes a token for it, the token watcher
reports it, and the keychain lists its identity and key (access group com.apple.token). Signing goes through the token
session to the card (GENERAL AUTHENTICATE), which wants its PIN: isim's PIN sheet asks, the PIN operation VERIFYs it,
and the signature verifies with the certificate's key. ECDH with a software key agrees both ways (also with the X9.63
KDF). The registration manager (iOS 26) registers the token. Removing the card removes the token and its keys."""
import json
import os
import re
import shutil
import subprocess

import pytest

from isimtest import ISIM

APP = "HelloToken"
PIV_AID = "A000000308000010000100"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def tlv(tag, value):
    n = len(value)
    length = bytes([n]) if n < 0x80 else bytes([0x81, n]) if n < 0x100 else bytes([0x82, n >> 8, n & 0xFF])
    return bytes.fromhex(tag) + length + value


def piv_card(tmp_path):
    """a PIV card with a P-256 key (reference 9A, PIN 123456) and a self-signed certificate for it, made with openssl"""
    if not shutil.which("openssl"):
        pytest.skip("openssl is not installed")
    key, cert = tmp_path / "key.pem", tmp_path / "cert.der"
    subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)], check=True)
    subprocess.run(["openssl", "req", "-new", "-x509", "-key", str(key), "-subj", "/CN=HelloToken PIV", "-days", "365",
                    "-outform", "DER", "-out", str(cert)], check=True)
    text = subprocess.run(["openssl", "ec", "-in", str(key), "-noout", "-text"], check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, text=True).stdout
    def block(name):
        m = re.search(name + r":\s*\n((?:\s+[0-9a-f:]+\n)+)", text)
        return bytes.fromhex(re.sub(r"[\s:]", "", m.group(1)))
    priv, pub = block("priv")[-32:].rjust(32, b"\0"), block("pub")
    assert len(pub) == 65 and pub[0] == 4
    obj = tlv("53", tlv("70", cert.read_bytes()) + tlv("71", b"\x00") + tlv("FE", b""))
    card = {"atr": "3BFD1300008131FE158073C021C057597562694B657940", "serial": "11223344", "pinTries": 3,
            "applets": [{"aid": PIV_AID, "fci": "611179074F05A0000003084F06000010000100", "pin": "123456", "pinReference": 0x80,
                         "objects": {"5FC105": obj.hex().upper()}, "keys": {"9A": (pub + priv).hex().upper()}}]}
    path = tmp_path / "card.json"
    path.write_text(json.dumps(card))
    return path


@pytest.mark.os_matrix
def test_token(launch, device_data, tmp_path, ios):
    version = int(str(ios[0] or "18").split(".")[0])
    isim(device_data, "smartcard", "insert", str(piv_card(tmp_path)))
    app = launch(APP, data=device_data)
    app.wait_log(r"^tk drivers \[\"dev\.isim\.samples\.HelloToken\.Driver\"\]$")
    app.wait_log(r"^tk token inserted dev\.isim\.samples\.HelloToken\.Driver:piv-[0-9A-F]+ driver=dev\.isim\.samples\.HelloToken\.Driver$")
    app.wait_log(r"^tk identities status=0 count=1 subject=HelloToken PIV group=com\.apple\.token$")
    app.wait_log(r"^tk key type=73 bits=256 sign=true derive=true exportable=false$")

    app.wait_tap_id("sign")                                         # the card wants its PIN: the PIN sheet
    app.wait_view(r"text=Enter PIN")
    app.tap_id("isim-smartcard-pin-0")
    app.type("123456")
    app.wait_still()
    app.screenshot("token-pin")
    app.tap_text("OK")
    app.wait_log(r"^tk sign bytes=(70|71|72) der=true verified=true$")

    app.wait_tap_id("sign")                                         # a wrong PIN: the card refuses it
    app.wait_view(r"text=Enter PIN")
    app.tap_id("isim-smartcard-pin-0")
    app.type("111111")
    app.tap_text("OK")
    app.wait_log(r"^tk sign failed error=-5$")

    app.wait_tap_id("agree")
    for _ in range(2):                                              # each operation is a new card session: its own PIN
        app.wait_view(r"text=Enter PIN")
        app.tap_id("isim-smartcard-pin-0")
        app.type("123456")
        app.tap_text("OK")
    app.wait_log(r"^tk agree bytes=32 equal=true kdf=32 kdfEqual=true error=0$")

    app.wait_tap_id("register")
    if version >= 26:
        app.wait_log(r"^tk registered true$")
        app.wait_log(r"^tk unregistered true$")
    else:
        app.wait_log(r"^tk registration needs iOS 26$")

    isim(device_data, "smartcard", "remove")
    app.wait_log(r"^tk token removed dev\.isim\.samples\.HelloToken\.Driver:piv-[0-9A-F]+$")
    app.wait_log(r"^tk after removal keys status=-25300$")
