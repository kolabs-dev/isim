"""CryptoTokenKit smart cards on isim's virtual readers (issue #403, HelloSmartCard): `isim smartcard insert --demo`
puts a PIV card in a PIN pad reader; the app sees the slot (KVO) and the token, parses the ATR, reads a CHUID longer
than one response (GET RESPONSE), is refused the PIN-protected certificate, verifies the PIN on isim's PIN sheet (a
wrong one first: the retry counter), reads the certificate, and sees the card leave when it is removed. Without the
smart card entitlement there is no slot manager."""
import json
import os
import subprocess

from isimtest import ISIM

APP = "HelloSmartCard"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_smartcard(launch, device_data):
    isim(device_data, "smartcard", "insert", "--demo")
    assert "isim Virtual Reader (PIN pad): card 3BFD1300008131FE158073C021C057597562694B657940 serial 0A1B2C3D token dev.isim.virtual.piv" \
        in isim(device_data, "smartcard", "list")
    card = json.load(open(device_data / "Library/isim/SmartCards/readers.json"))["readers"][0]["card"]
    chuid = bytes.fromhex(card["applets"][0]["objects"]["5FC102"])
    app = launch(APP, data=device_data)
    app.wait_log(r"^sc tlv outer=5381D25FC102 inner=\[\"5FC102\", \"30\"\] simple=800109 compact=420102 parsed=true bad=true$")
    app.wait_log(r"^sc slots \[\"isim Virtual Reader\"\]$")
    app.wait_log(r"^sc slot isim Virtual Reader state=4$")
    app.wait_log(r"^sc atr 3BFD1300008131FE158073C021C057597562694B657940 protocols=\[1\] historical=13 records=7:3,5:7 group2=1 t1=true$")
    app.wait_log(r"^sc token inserted dev\.isim\.virtual\.piv:0A1B2C3D driver=dev\.isim\.virtual\.piv$")

    app.wait_tap_id("read")
    app.wait_log(r"^sc select sw=9000 fci=19 protocol=2$")
    app.wait_log(rf"^sc chuid sw=9000 bytes={len(chuid)} tag=53 value={len(chuid) - 4}$")   # 4 bytes: 53 82 xx xx
    app.wait_log(r"^sc certificate before PIN sw=6982$")
    app.wait_log(r"^sc pin status sw=63C3$")

    app.wait_tap_id("verify")                                       # a wrong PIN on the PIN sheet
    app.wait_view(r"text=Enter PIN")
    app.tap_id("isim-smartcard-pin-0")
    app.type("111111")
    app.wait_still()
    app.screenshot("smartcard-pin")
    app.tap_text("OK")
    app.wait_log(r"^sc verify done=1 sw=63C2 error=none$")
    app.wait_log(r"^sc certificate after PIN sw=6982 bytes=0$")
    app.wait_tap_id("verify")
    app.wait_view(r"text=Enter PIN")
    app.tap_id("isim-smartcard-pin-0")
    app.type("123456")
    app.tap_text("OK")
    app.wait_log(r"^sc verify done=1 sw=9000 error=none$")
    app.wait_log(r"^sc certificate after PIN sw=9000 bytes=26[0-9]$")
    app.wait_tap_id("verify")                                       # cancelled
    app.wait_view(r"text=Enter PIN")
    app.tap_text("Cancel")
    app.wait_log(r"^sc verify done=0 sw=0000 error=-4$")

    app.wait_tap_id("change")                                       # change the PIN
    app.wait_view(r"text=Change PIN")
    for i, pin in enumerate(["123456", "654321", "654321"]):
        app.tap_id(f"isim-smartcard-pin-{i}")
        app.type(pin)
    app.tap_text("OK")
    app.wait_log(r"^sc change done=1 sw=9000$")

    isim(device_data, "smartcard", "remove")                        # the card leaves
    app.wait_log(r"^sc slot isim Virtual Reader state=1$")
    app.wait_log(r"^sc token removed dev\.isim\.virtual\.piv:0A1B2C3D$")
    app.wait_view(r"id=status text=No card")
    app.wait_tap_id("read")
    app.wait_log(r"^sc no card$")
    assert app.quit() == 0


def test_smartcard_entitlement(launch, device_data):
    """an app without com.apple.security.smartcard gets no slot manager (the app's own entitlements say so)"""
    isim(device_data, "smartcard", "insert", "--demo")
    app = launch("HelloSmartCardNoEntitlement", data=device_data)
    app.wait_log(r"^sc no slot manager$")
    assert app.quit() == 0
