"""StoreKit 1 from Objective-C (HelloStoreObjC, issue #226), as Unity IAP and the Capacitor / Cordova purchase plugins
use it: SKProductsRequest (products with NSDecimalNumber prices, a subscription period and introductory offer, invalid
identifiers), buying through SKPaymentQueue with an Objective-C transaction observer (SKMutablePayment quantity,
the confirmation sheet, finishing, an unknown product failing with SKErrorDomain), restoring, refreshing the
receipt (NSBundle.appStoreReceiptURL) and SKStoreReviewController."""
import re


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
