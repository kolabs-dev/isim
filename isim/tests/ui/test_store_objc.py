"""StoreKit 1 from Objective-C (HelloStoreObjC, issue #226), as Unity IAP and the Capacitor / Cordova purchase plugins
use it: SKProductsRequest (products with NSDecimalNumber prices, a subscription period and introductory offer, invalid
identifiers), buying through SKPaymentQueue with an Objective-C transaction observer (SKMutablePayment quantity,
the confirmation sheet, finishing, an unknown product failing with SKErrorDomain), restoring, refreshing the
receipt (NSBundle.appStoreReceiptURL), SKStoreReviewController, and signed promotional offers (#454)."""
import base64
import json
import os
import re
import subprocess
import time
import uuid

import pytest

from isimtest import ISIM


def buy(app, product):
    app.wait_tap_id(f"buy-{product}")
    app.wait_view(r"text=Buy\b")
    app.tap_text("Buy")


def test_store_objc(launch):
    app = launch("HelloStoreObjC")
    app.wait_log(r"^so invalid ")
    log = app.log
    assert "so canMakePayments 1 storefront USA" in log, re.findall(r"^so canMake.*$", log, re.M)
    assert "so product dev.isim.store.coins title=100 Coins price=0.99 formatted=$0.99 decimal=1 group=-" in log, \
        re.findall(r"^so product .*$", log, re.M)
    assert "so product dev.isim.store.full_game title=Full Game price=4.99 formatted=$4.99 decimal=1 group=-" in log
    assert re.search(r"^so product dev\.isim\.store\.plus\.monthly title=Plus Monthly price=2\.99 formatted=\$2\.99 decimal=1 "
                     r"period=1/2 intro=0x1 mode=2 group=\S+$", log, re.M), re.findall(r"^so product .*$", log, re.M)
    assert "so invalid dev.isim.store.nonexistent" in log
    assert "so request finished" in log

    buy(app, "dev.isim.store.coins")
    app.wait_log(r"^so transaction dev\.isim\.store\.coins purchased quantity=2 id=1 date=1$")
    app.wait_log(r"^so removed 1 pending=0$")
    assert "so add payment dev.isim.store.coins quantity=2 mutable=1" in app.log
    assert "so transaction dev.isim.store.coins purchasing quantity=2" in app.log
    buy(app, "dev.isim.store.full_game")
    app.wait_log(r"^so transaction dev\.isim\.store\.full_game purchased quantity=1 id=1 date=1$")

    app.wait_tap_id("buy-unknown")
    app.wait_log(r"^so transaction dev\.isim\.store\.nonexistent failed quantity=1 error=SKErrorDomain/5$")

    app.wait_tap_id("restore")
    app.wait_log(r"^so restore finished$")
    assert "so transaction dev.isim.store.full_game restored quantity=1 original=1" in app.log, "non-consumables come back"
    assert "so transaction dev.isim.store.coins restored" not in app.log, "consumables are not restored"

    app.wait_tap_id("refresh-receipt")
    app.wait_log(r"^so receipt refreshed bytes>0=1 pkcs7=1$")

    app.wait_tap_id("review")
    app.wait_view(r"id=isim-review-prompt\b")


@pytest.mark.os_matrix
def test_store_objc_promotional_offer(launch, device_data, tmp_path, ios):
    """A real signed StoreKit 1 offer through Objective-C, including the readonly payment getter."""
    def device(*args):
        return subprocess.run([str(ISIM), "storekit", "offer-key", *args],
                              env=dict(os.environ, ISIM_DATA=str(device_data)),
                              capture_output=True, text=True, check=True, timeout=60).stdout

    key = tmp_path / "offer.pem"
    key.write_text(device("--pem"))
    key_id = device("--id").strip()
    nonce, timestamp = str(uuid.uuid4()), str(int(time.time() * 1000))
    message = "\u2063".join(["dev.kolabs.isim.HelloStoreObjC", key_id, "dev.isim.store.plus.monthly",
                             "comeback", "", nonce, timestamp]).encode()
    signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)], input=message,
                               capture_output=True, check=True, timeout=60).stdout
    key.unlink()
    app = launch("HelloStoreObjC", env={"STOREOBJC_KEY_ID": key_id, "STOREOBJC_NONCE": nonce,
                 "STOREOBJC_TIMESTAMP": timestamp, "STOREOBJC_SIGNATURE": base64.b64encode(signature).decode(),
                 "ISIM_STOREKIT_TIME_RATE": "month=3600"})
    app.wait_tap_id("buy-dev.isim.store.plus.monthly")
    app.wait_view(r"text=Subscribe$")
    app.tap_text("Subscribe")
    app.wait_log(r"^so transaction dev\.isim\.store\.plus\.monthly purchased quantity=1 id=1 date=1$")
    # Offers require a previous subscriber. Expire through the Transaction Manager so the offer creates a new
    # transaction rather than showing the already-subscribed notice. Dismiss the iOS 18+ win-back message.
    subprocess.run([str(ISIM), "storekit", "dev.kolabs.isim.HelloStoreObjC", "expire", "21000001"],
                   env=dict(os.environ, ISIM_DATA=str(device_data)), capture_output=True, check=True, timeout=60)
    app.wait_log(r"ledger changed by the Transaction Manager")
    if int(ios[0] or os.environ.get("ISIM_OS_VERSION", "18")) >= 18:
        app.wait_tap_id("sk-winback-later")
    app.wait_tap_id("promo-bad")
    app.wait_log(r"^so transaction dev\.isim\.store\.plus\.monthly failed quantity=1 error=SKErrorDomain/12$")
    app.wait_tap_id("promo")
    app.wait_log(r"promotional offer comeback: signature verified")
    app.wait_view(r"text=Subscribe$")
    app.wait_shot_still().save(tmp_path / "objc-promotional-offer.png")
    app.tap_text("Subscribe")
    app.wait_log(r"^so transaction dev\.isim\.store\.plus\.monthly purchased quantity=1 id=1 date=1$", count=2)
    assert app.log.count("so discount class=1 identity=1 fields=1") == 2
    assert app.log.count("so discount cleared=1") == 2
    ledger = json.loads((device_data / "Library/isim/StoreKit/dev.kolabs.isim.HelloStoreObjC/ledger.json").read_text())
    assert any(t.get("offerID") == "comeback" and t.get("offerType") == 2 and t.get("price") == "0.99"
               and t.get("api") == "sk1" for t in ledger["transactions"])
    assert ledger["usedOfferNonces"] == [nonce]
