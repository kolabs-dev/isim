"""Wallet passes (HelloWallet): PKPass reads the app's .pkpass archives (fields, the English pass.strings, relevant
dates); a pass whose manifest does not match is refused. PKAddPassButton presents PKAddPassesViewController, which
draws the ticket from its pass.json and adds it to isim's Wallet in the device data, which `isim wallet` lists.
PKPassLibrary replaces it with a new version, adds the coupon after iOS's alert and removes the ticket, posting
PKPassLibraryDidChange each time. SwiftUI's AddPassToWalletButton is canceled once, then adds the boarding pass."""
import os
import subprocess

from isimtest import ISIM


def wallet(data, *args):
    return subprocess.run([str(ISIM), "wallet", *args], env=dict(os.environ, ISIM_DATA=str(data)),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60).stdout


def test_wallet(launch, device_data):
    app = launch("HelloWallet")
    app.wait_log(r"pass: pass\.dev\.isim\.samples\.wallet conf-2026-0042 org=isim Conf desc=Ticket for isim Conf 2026 seat=12A "
                 r"date=2026-11-12T09:00:00Z relevant=9h type=0 icon=29 web=passes\.example\.com token=token-conf-2026-0042")
    app.wait_log(r"pass: pass\.dev\.isim\.samples\.wallet coffee-5off org=isim Coffee desc=A coffee coupon seat=- date=- relevant=- type=0")
    app.wait_log(r"tampered: PKPassKitErrorDomain 3")
    app.wait_log(r"garbage: PKPassKitErrorDomain 1")
    app.wait_log(r"trip archive: sheet ready not loaded")
    app.wait_log(r"library: available true can add true passes 0")
    app.wait_view(r"text=0 passes in Wallet")
    app.wait_still()
    app.screenshot("buttons")

    # the add sheet: the ticket drawn from its pass.json, then added
    app.wait_tap_id("add-ticket")
    app.wait_log(r"isim PassKit: add passes sheet: pass\.dev\.isim\.samples\.wallet conf-2026-0042")
    app.wait_view(r"id=pk-pass-seat.*12A")
    app.wait_view(r"text=Keynote")
    app.wait_view(r"id=pk-pass-barcode")
    app.wait_still()
    app.screenshot("add-sheet")
    app.wait_tap_id("pk-pass-add")
    app.wait_log(r"isim PassKit: Wallet added pass pass\.dev\.isim\.samples\.wallet conf-2026-0042 \(isim Conf\)")
    app.wait_log(r"library changed: added=1 replaced=0 removed=0")
    app.wait_log(r"add sheet finished: in wallet=true")
    app.wait_view(r"text=1 passes in Wallet")
    listing = wallet(device_data, "list")
    assert "pass.dev.isim.samples.wallet conf-2026-0042  eventTicket  isim Conf: Ticket for isim Conf 2026" in listing, listing

    # a new version replaces it
    app.wait_tap_id("update")
    app.wait_log(r"library changed: added=0 replaced=1 removed=0")
    app.wait_log(r"replaced true seat=14C")

    # the library's own alert: Add All
    app.wait_tap_id("add-coupon")
    app.wait_view(r"text=Add “isim Coffee” Pass to Wallet\?")
    app.tap_text("Add All")
    app.wait_log(r"library add status: 0")
    app.wait_view(r"text=2 passes in Wallet")

    # SwiftUI: canceled, then added
    app.wait_tap_id("add-trip")
    app.wait_view(r"id=pk-pass-flight-is42")
    app.wait_tap_id("pk-pass-cancel")
    app.wait_log(r"swiftui add: false")
    app.wait_view(r"id=pk-pass-flight-is42", gone=True)
    app.wait_tap_id("add-trip")
    app.wait_tap_id("pk-pass-add")
    app.wait_log(r"swiftui add: true")
    app.wait_view(r"text=3 passes in Wallet")

    # removed
    app.wait_tap_id("remove")
    app.wait_log(r"library changed: added=0 replaced=0 removed=1")
    app.wait_log(r"removed: contains false passes 2")
    app.wait_tap_id("list")
    app.wait_log(r"listed 2 of type barcode 2 secure element 0")
    assert "conf-2026-0042" not in wallet(device_data, "list")
    assert app.quit() == 0


def test_wallet_cli(launch, device_data, tmp_path):
    """`isim wallet add FILE` adds a pass to the device as opening it from Mail would; remove takes it out."""
    import sys
    sys.path.insert(0, str(ISIM.parent.parent.parent / "samples" / "HelloWallet"))
    import gen_passes
    gen_passes.main(str(tmp_path))
    out = wallet(device_data, "add", str(tmp_path / "coupon.pkpass"))
    assert "added pass.dev.isim.samples.wallet coffee-5off" in out, out
    assert "refused" in wallet(device_data, "add", str(tmp_path / "tampered.pkpass"))
    app = launch("HelloWallet")
    app.wait_log(r"library: available true can add true passes 1")
    app.wait_view(r"text=1 passes in Wallet")
    assert "removed pass.dev.isim.samples.wallet coffee-5off" in wallet(device_data, "remove", "pass.dev.isim.samples.wallet", "coffee-5off")
    assert wallet(device_data, "list").strip() == "no passes"
    assert app.quit() == 0
