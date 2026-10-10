"""Local StoreKit testing (HelloStore).

test_store, run 1: SubscriptionStoreView with a free-trial introductory offer, renewals on the accelerated clock (one
month = 4 s), an immediate upgrade, cancelling in the Manage Subscriptions sheet and the expiry that follows (the
win-back message goes to the app's Message.messages listener), StoreView/ProductView purchases, the subscription store
with the buttons control style, a multiline button label, policies and a win-back offer, an app-defined ProductViewStyle,
a refund through the refund sheet, offer-code redemption, the review prompt's 3-per-year limit, StoreKit 1
(SKProductsRequest, SKPaymentQueue purchase + restore), the PKCS #7 receipt (verified with OpenSSL against the device's
StoreKit testing certificate), SKOverlay and the product page (App Store listing from a lookup fixture). Run 2 (same
device data): the unfinished consumable is delivered again at launch, `isim storekit` (Transaction Manager) refunds
and expires while the app runs, promotional offers with a forged signature, a valid signature and a compact JWS,
win-back eligibility, offer codes for current subscribers (from the next renewal), single use, and for a one-time
product.

test_store_billing: billing issues with the grace period (entitlement kept, the Billing Problem message shown by isim),
billing retry, resolving them (Transaction Manager, the message's Update Payment Method), billing retry running out
(expired, billing error), the automatic win-back message, signed JWS values (verified with OpenSSL) and AppTransaction
device verification, and purchases surviving the app's deletion (AppStore.sync).

test_store_winback_ios17: no win-back offers or messages before iOS 18."""
import base64
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
from datetime import datetime

from PIL import Image

from isimtest import ISIM, visible

APP = "dev.isim.samples.HelloStore"
ENV = {"ISIM_STOREKIT_TIME_RATE": "month=4"}


def storekit(data, *args):
    return subprocess.run([str(ISIM), "storekit", APP, *args], env=dict(os.environ, ISIM_DATA=str(data)),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60).stdout


def storekit_device(data, *args):
    """isim storekit certificate|offer-key (the device's, not an app's)"""
    r = subprocess.run([str(ISIM), "storekit", *args], env=dict(os.environ, ISIM_DATA=str(data)),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    return r.stdout


def offer_env(data):
    """the device's subscription offers key, for the sample's stand-in offer server"""
    return {"HELLOSTORE_OFFER_KEY": storekit_device(data, "offer-key", "--pem"),
            "HELLOSTORE_OFFER_KEY_ID": storekit_device(data, "offer-key", "--id").strip()}


def lookup_fixture(tmp):
    """App Store lookup results for app 1234567890 (with an icon) and none for 999 (ISIM_APPSTORE_LOOKUP_URL)"""
    Image.new("RGB", (100, 100), (30, 120, 220)).save(tmp / "icon.png")
    (tmp / "lookup-1234567890.json").write_text(json.dumps({"resultCount": 1, "results": [{
        "trackId": 1234567890, "trackName": "Fixture App", "sellerName": "Fixture Developer", "formattedPrice": "Free",
        "primaryGenreName": "Games", "version": "2.1", "trackContentRating": "4+", "averageUserRating": 4.5,
        "userRatingCount": 1234, "description": "An app from the lookup fixture.",
        "artworkUrl100": (tmp / "icon.png").as_uri()}]}))
    (tmp / "lookup-999.json").write_text(json.dumps({"resultCount": 0, "results": []}))
    return {"ISIM_APPSTORE_LOOKUP_URL": (tmp / "lookup-{id}.json").as_uri().replace("%7B", "{").replace("%7D", "}")}


def openssl(*args, data=None):
    r = subprocess.run(["openssl", *map(str, args)], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    assert r.returncode == 0, r.stderr.decode()
    return r.stdout


def b64url(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def der_int(b):
    b = b.lstrip(b"\0") or b"\0"
    if b[0] & 0x80:
        b = b"\0" + b
    return bytes([2, len(b)]) + b


def verify_jws(token, cert_pem, tmp):
    """checks an ES256 JWS like a server does with Xcode's StoreKit Test certificate: its x5c certificate is the
    device's, and the signature verifies with that certificate's key; returns the payload"""
    header, payload, sig = token.split(".")
    h = json.loads(b64url(header))
    assert h["alg"] == "ES256", h
    x5c = base64.b64decode(h["x5c"][0])
    assert x5c == openssl("x509", "-in", cert_pem, "-outform", "DER"), "x5c holds the device's StoreKit testing certificate"
    raw = b64url(sig)
    der = der_int(raw[:32]) + der_int(raw[32:])
    (tmp / "sig.der").write_bytes(bytes([0x30, len(der)]) + der)
    (tmp / "input").write_bytes(f"{header}.{payload}".encode())
    (tmp / "pub.pem").write_bytes(openssl("x509", "-in", cert_pem, "-pubkey", "-noout"))
    out = openssl("dgst", "-sha256", "-verify", tmp / "pub.pem", "-signature", tmp / "sig.der", tmp / "input")
    assert b"Verified OK" in out, out
    return json.loads(b64url(payload))


def der_items(b):
    """the TLVs of a DER SET/SEQUENCE body: [(tag, body)]"""
    out, i = [], 0
    while i < len(b):
        tag, n = b[i], b[i + 1]
        i += 2
        if n & 0x80:
            k = n & 0x7f
            n = int.from_bytes(b[i:i + k], "big")
            i += k
        out.append((tag, b[i:i + n]))
        i += n
    return out


def receipt_fields(payload):
    """receipt attributes {type: [value bytes]} of a receipt payload (SET OF SEQUENCE {type, version, value})"""
    (tag, body), = der_items(payload)
    assert tag == 0x31
    fields = {}
    for _, attr in der_items(body):
        (_, t), _, (_, v) = der_items(attr)
        fields.setdefault(int.from_bytes(t, "big"), []).append(v)
    return fields


def renewal_gaps(log):
    """seconds between consecutive renewals of Plus Monthly before the upgrade (NSLog timestamps)"""
    before = log.split("immediate upgrade")[0]
    times = [datetime.strptime(m.group(1), "%H:%M:%S.%f")
             for m in re.finditer(r"^\S+ (\d+:\d+:[\d.]+) .*subscription dev\.isim\.store\.plus\.monthly renewed", before, re.M)]
    return [round((b - a).total_seconds(), 1) for a, b in zip(times, times[1:])]


def buy(app, button):
    app.wait_tap_id(button)
    app.wait_view(r"text=Buy\b")
    app.tap_text("Buy")


def subscribe(app, button):
    app.wait_tap_id(button)
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")


def redeem(app, code):
    app.wait_tap_id("redeem")
    app.wait_tap_id("sk-redeem-field")
    app.type(code).tap_id("sk-redeem-submit")


def test_store(launch, device_data, tmp_path):
    env = {**ENV, **offer_env(device_data), **lookup_fixture(tmp_path), "HELLOSTORE_MESSAGES": "defer"}
    app = launch("HelloStore", env=env)
    app.wait_log(r"product: dev\.isim\.store\.plus\.monthly Auto-Renewable Subscription \$2\.99 group=21000001 level=2 "
                 r"period=1month intro=FreeTrial:1week promos=comeback winbacks=winback introEligible=true")
    app.wait_log(rf"appTransaction: bundle={APP} version=7 original=7 env=Xcode")   # AppTransaction (local)

    # subscribe with the free trial; renewals every 4 s
    app.wait_tap_id("open-subs")
    app.wait_tap_id("sk-plan-dev.isim.store.plus.monthly")
    subscribe(app, "sk-subscribe")
    app.wait_log(r"subscribed to dev\.isim\.store\.plus\.monthly .* with introductory offer 1 week free")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]")
    app.wait_log(r"subscription dev\.isim\.store\.plus\.monthly renewed", count=2, timeout=20)
    app.wait_log(r"update: txn .* dev\.isim\.store\.plus\.monthly reason=renewal", count=2)   # in Transaction.updates
    # immediate upgrade
    app.wait_tap_id("sk-plan-dev.isim.store.premium.monthly")
    subscribe(app, "sk-subscribe")
    app.wait_log(r"dev\.isim\.store\.plus\.monthly -> dev\.isim\.store\.premium\.monthly \(immediate upgrade\)")
    app.wait_log(r"status: subscribed dev\.isim\.store\.premium\.monthly autoRenew=true")
    gaps = renewal_gaps(app.log)
    assert gaps and all(3.3 <= g <= 4.9 for g in gaps), f"renewals every 4 s (accelerated clock): {gaps}"
    app.wait_tap_id("close-subs")

    # Manage Subscriptions: a downgrade at the next renewal, then cancel; the subscription expires
    app.wait_tap_id("manage")
    app.wait_tap_id("sk-manage-plan-dev.isim.store.plus.monthly")
    app.wait_view(r"id=sk-manage-status-21000001 text=Changes to Plus Monthly on")
    app.wait_log(r"dev\.isim\.store\.premium\.monthly -> dev\.isim\.store\.plus\.monthly takes effect at the next renewal")
    app.wait_until(lambda: re.search(r"update: txn [0-9]* dev\.isim\.store\.plus\.monthly reason=renewal",
                                     app.log.split("takes effect at the next renewal", 1)[1]),
                   timeout=10, what="the downgrade takes effect at the next renewal")
    app.tap_id("sk-manage-cancel")
    app.wait_tap_id("sk-manage-confirm-cancel")
    app.wait_view(r"id=sk-manage-status-21000001 text=Expires")
    app.wait_log(r"status: subscribed dev\.isim\.store\.plus\.monthly autoRenew=false")   # cancel: auto-renew off
    app.tap_id("sk-manage-done")
    app.wait_log(r"subscription dev\.isim\.store\.plus\.monthly expired \(auto-renew off\)", timeout=15)
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly autoRenew=false reason=1")   # entitlement removed
    # a lapsed subscriber: the win-back message goes to the app's listener, which defers it (no sheet)
    app.wait_log(r"message winBackOffer \(dev\.isim\.store\.plus\.monthly\) sent to Message\.messages")
    app.wait_log(r"^message: winBackOffer$")

    # StoreKit 1
    buy(app, "sk1")
    app.wait_log(r"sk1: dev\.isim\.store\.coins state=1 id=")
    app.wait_tap_id("sk1-restore")
    app.wait_log(r"sk1: restore finished")
    app.wait_log(r"sk1: dev\.isim\.store\.plus\.monthly state=3 .* original=")           # payment queue purchase + restore
    assert app.has(r"sk1 product: dev\.isim\.store\.plus\.monthly Plus Monthly 2\.99 period=1/2 intro=2") and \
        app.has(r'sk1 invalid: \["dev\.isim\.store\.nope"\]'), "SK1 products request (invalid ids too)"

    # StoreView / ProductView purchases
    app.wait_tap_id("open-products")
    buy(app, "sk-buy-dev.isim.store.full_game")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.full_game\]")
    buy(app, "sk-buy-dev.isim.store.coins")
    app.wait_log(r"completion: dev\.isim\.store\.coins")
    app.wait_view(r"id=sk-owned-dev\.isim\.store\.full_game\b")
    app.tap_id("close-products")

    # the subscription store with buttons, a multiline label and policies; the lapsed subscriber's win-back offer;
    # an app-defined ProductViewStyle
    app.wait_tap_id("open-plans")
    app.wait_view(r"id=sk-subscribe-dev\.isim\.store\.premium\.monthly\b")            # one button per plan
    app.wait_view(r"text=2 months for \$0\.49/month, then \$2\.99/month$")           # multiline label: win-back offer
    app.wait_view(r"id=badge-owned\b")
    app.wait_tap_id("sk-policy-terms")
    app.wait_log(r"policy termsOfService: opening https://isim\.dev/terms")
    app.wait_tap_id("sk-policy-privacy")
    app.wait_view(r"id=privacy-text\b")                                              # the app's privacy view
    app.wait_tap_id("sk-policy-done")
    app.wait_view(visible("privacy-text"), gone=True)
    app.wait_tap_id("close-plans")

    # the refund sheet revokes the purchase
    app.wait_tap_id("refund")
    app.wait_tap_id("sk-refund-reason-2")
    app.tap_id("sk-refund-submit")
    app.wait_log(r"refund request: success")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.full_game reason=purchase revoked")

    # offer codes
    redeem(app, "nope")
    app.wait_view(r"id=sk-redeem-error text=This code isn’t valid\.")    # a wrong code is rejected
    app.tap_id("sk-redeem-field")
    for _ in range(4):
        app.send("key backspace")
    app.type("WELCOME").tap_id("sk-redeem-submit")
    app.wait_view(r"id=sk-redeem-done\b")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.plus\.monthly reason=purchase offer=3:WELCOME")
    app.tap_id("sk-redeem-ok")

    # the review prompt: at most 3 times a year
    app.wait_tap_id("review")
    app.wait_tap_id("isim-review-not-now")
    app.wait_view(visible("isim-review-not-now"), gone=True)
    app.tap_id("review")
    app.wait_tap_id("isim-review-star-5")
    app.wait_view(visible("isim-review-star-5"), gone=True)
    app.tap_id("review")
    app.wait_tap_id("isim-review-not-now")
    app.wait_view(visible("isim-review-not-now"), gone=True)
    app.tap_id("review")
    app.wait_log(r"requestReview\(\) ignored")
    assert app.count(r"showing the development-style rating prompt") == 3, "review prompt: at most 3 times a year"

    # the receipt: PKCS #7 signed with the device's StoreKit testing certificate, Apple's ASN.1 fields
    app.drag(200, 760, 200, 260)                                                        # the StoreKit 1 rows
    app.wait_view(visible("receipt"))
    app.wait_tap_id("receipt")
    path = app.wait_log(r"receipt: [0-9]* bytes, pkcs7=true, path=(.*)$").group(1)
    cert = tmp_path / "StoreKitTestCertificate.pem"
    storekit_device(device_data, "certificate", cert)
    payload = openssl("cms", "-verify", "-inform", "DER", "-in", path, "-CAfile", cert, "-binary")
    f = receipt_fields(payload)
    bundle_der = f[2][0]
    assert bundle_der[2:].decode() == APP and f[3][0][2:].decode() == "7" and f[19][0][2:].decode() == "7", f
    vendor = plistlib.load(open(device_data / "Library/isim/vendor-identifiers.plist", "rb"))["dev.isim.samples"]
    expected = hashlib.sha1(bytes.fromhex(vendor.replace("-", "")) + f[4][0] + bundle_der).digest()
    assert f[5][0] == expected, "the receipt hash: SHA-1 of identifierForVendor, the opaque value and the bundle ID"
    products = {receipt_fields(v)[1702][0][2:].decode() for v in f[17]}           # in-app purchase receipts
    assert {"dev.isim.store.full_game", "dev.isim.store.plus.monthly"} <= products, products

    app.wait_tap_id("overlay")
    app.wait_view(r"id=sk-overlay-title text=Fixture App")                               # the App Store listing
    app.tap_id("sk-overlay-close")
    app.wait_log(r"SKOverlay dismissed")
    app.wait_tap_id("product-page")
    app.wait_view(r"id=sk-product-page-title text=Fixture App")
    app.wait_view(r"id=sk-product-page-seller text=Fixture Developer")
    app.wait_view(r"id=sk-product-page-rating text=4\.5")
    app.wait_log(r"product page 1234567890 loaded: true")
    app.wait_tap_id("sk-product-page-get")
    app.wait_view(r"text=Apps from the App Store can’t be installed on isim\.")
    app.tap_text("OK")
    app.wait_tap_id("sk-product-page-done")
    app.wait_log(r"product page finished")
    app.wait_tap_id("product-page-unknown")                                             # an unknown app fails
    app.wait_log(r"product page 999 loaded: false")
    app.wait_view(r"id=sk-product-page-note text=This app is not available in the App Store\.")
    app.wait_tap_id("sk-product-page-done")
    app.wait_log(r"product page finished", count=2)
    assert app.quit() == 0

    # the Transaction Manager lists the ledger
    list1 = storekit(device_data, "list")
    assert re.search(r"dev\.isim\.store\.full_game .*refunded", list1), list1
    coins = next((l.split()[0] for l in list1.splitlines()
                  if len(l.split()) > 2 and l.split()[2] == "dev.isim.store.coins" and "unfinished" in l), None)
    assert coins, f"an unfinished coins transaction: {list1}"

    # run 2: the unfinished consumable comes again; Transaction Manager changes while the app runs
    app = launch("HelloStore", env=env)
    app.wait_log(rf"update: txn {coins} dev\.isim\.store\.coins reason=purchase$")      # delivered at launch
    app.wait_log(r"coins 100")
    refund = storekit(device_data, "refund", coins)
    assert f"refunded transaction {coins}" in refund, refund
    storekit(device_data, "expire", "21000001")
    app.wait_log(rf"update: txn {coins} dev\.isim\.store\.coins reason=purchase revoked")   # the refund reaches the app
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly")                     # manager expire

    # promotional offers: the signature is checked against the device's subscription offers key
    app.wait_tap_id("promo-bad")
    app.wait_log(r"offer purchase failed: invalidOfferSignature")
    app.wait_tap_id("promo")
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")
    app.wait_log(r"promotional offer comeback: signature verified")
    app.wait_log(r"offer purchase: txn [0-9]* dev\.isim\.store\.plus\.monthly offer=2:comeback expires=4s")
    storekit(device_data, "expire", "21000001")
    app.wait_log(r"status update: expired dev\.isim\.store\.plus\.monthly", count=2)
    app.wait_tap_id("promo-jws")                                                         # the compact JWS form
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")
    app.wait_log(r"offer purchase: txn [0-9]* dev\.isim\.store\.plus\.monthly offer=2:comeback expires=4s", count=2)
    app.wait_tap_id("winback")
    app.wait_log(r"offer purchase failed: ineligibleForOffer")                          # win-back needs a lapsed sub

    # offer codes: a code for current subscribers starts at the next renewal; each offer once; one-time products
    redeem(app, "LOYAL")
    app.wait_view(r"id=sk-redeem-done\b")
    app.wait_log(r"offer code LOYAL redeemed: dev\.isim\.store\.plus\.monthly \(1 month free\) from the next renewal")
    app.tap_id("sk-redeem-ok")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.plus\.monthly reason=renewal offer=3:LOYAL", timeout=15)
    redeem(app, "WELCOME")
    app.wait_view(r"id=sk-redeem-error text=You’ve already redeemed this offer\.")
    app.tap_id("sk-redeem-cancel")
    app.wait_view(visible("sk-redeem-cancel"), gone=True)
    redeem(app, "FREEGAME")                                                             # iOS 18: a non-consumable
    app.wait_view(r"id=sk-redeem-done\b")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.full_game reason=purchase offer=3:FREEGAME")
    app.tap_id("sk-redeem-ok")
    assert app.quit() == 0
    list2 = storekit(device_data, "list")
    assert re.search(rf"^ *{coins} .*refunded", list2, re.M), f"ledger after run 2: {list2}"


def test_store_billing(launch, device_data, tmp_path):
    # one month = 8 s: grace period (16 days) ~4.3 s, billing retry (60 days) 16 s
    env = {"ISIM_STOREKIT_TIME_RATE": "month=8", "ISIM_STOREKIT_BILLING_GRACE_PERIOD": "1"}
    app = launch("HelloStore", env=env)
    app.wait_log(r"appTransaction deviceVerification ok=true")                          # SHA-384(nonce + device ID)
    app_jws = app.wait_log(r"appTransaction jws: (\S+)").group(1)
    app.wait_tap_id("open-subs")
    app.wait_tap_id("sk-plan-dev.isim.store.plus.monthly")
    subscribe(app, "sk-subscribe")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]")
    app.wait_tap_id("close-subs")

    # a billing issue: the renewal fails; the grace period keeps the subscription and isim shows the message
    storekit(device_data, "billing-issue", "21000001", "on")
    app.wait_log(r"could not renew \(billing issue\): grace period until", timeout=20)
    app.wait_log(r"status: inGracePeriod dev\.isim\.store\.plus\.monthly autoRenew=true grace=true billingRetry=true reason=2")
    app.wait_log(r"message billingIssue \(dev\.isim\.store\.plus\.monthly\) displayed")
    app.wait_view(r"id=sk-message-title text=Billing Problem")
    assert "entitlements: []" not in app.log.split("entitlements: [dev.isim.store.plus.monthly]", 1)[1], \
        "the grace period keeps the entitlement"
    app.wait_tap_id("sk-billing-later")
    # billing retry: no entitlement; the Transaction Manager resolves the issue and the subscription renews
    app.wait_log(r"status: inBillingRetryPeriod dev\.isim\.store\.plus\.monthly autoRenew=true billingRetry=true reason=2", timeout=15)
    app.wait_log(r"^entitlements: \[\]", count=2)
    assert "billing retry until" in storekit(device_data, "list")
    storekit(device_data, "resolve", "21000001")
    app.wait_log(r"billing issue resolved: subscription dev\.isim\.store\.plus\.monthly renewed")
    app.wait_log(r"status: subscribed dev\.isim\.store\.plus\.monthly autoRenew=true", count=2)

    # again: Update Payment Method in the message resolves it
    storekit(device_data, "billing-issue", "21000001", "on")
    app.wait_log(r"message billingIssue \(dev\.isim\.store\.plus\.monthly\) displayed", count=2, timeout=20)
    app.wait_tap_id("sk-billing-update")
    app.wait_log(r"billing issue resolved: subscription dev\.isim\.store\.plus\.monthly renewed", count=2)

    # once more, unresolved: billing retry runs out, the subscription expires (billing error)
    storekit(device_data, "billing-issue", "21000001", "on")
    app.wait_log(r"message billingIssue \(dev\.isim\.store\.plus\.monthly\) displayed", count=3, timeout=20)
    app.wait_tap_id("sk-billing-later")
    app.wait_log(r"expired \(billing issue: billing retry ended\)", timeout=40)
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly autoRenew=true reason=2")
    # a lapsed subscriber: isim shows the win-back offer (iOS 18); buying it reaches Transaction.updates
    app.wait_log(r"message winBackOffer \(dev\.isim\.store\.plus\.monthly\) displayed")
    app.wait_view(r"id=sk-winback-terms text=2 months for \$0\.49/month, then \$2\.99/month")
    subscribe(app, "sk-winback-subscribe")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.plus\.monthly reason=purchase offer=4:winback")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]", count=2)

    # signed values verify with the exported certificate
    cert = tmp_path / "cert.pem"
    storekit_device(device_data, "certificate", cert)
    a = verify_jws(app_jws, cert, tmp_path)
    assert a["bundleId"] == APP and a["receiptType"] == "Xcode" and a["originalApplicationVersion"] == "7", a
    app.wait_tap_id("jws")
    t = verify_jws(app.wait_log(r"transaction jws: (\S+)").group(1), cert, tmp_path)
    assert t["productId"] == "dev.isim.store.plus.monthly" and t["environment"] == "Xcode" and t["offerType"] == 4 \
        and t["offerIdentifier"] == "winback" and t["price"] == 490, t
    assert app.quit() == 0

    # the purchase history belongs to the device's account: deleting the app keeps it; sync restores
    shutil.rmtree(device_data / "Containers" / APP)
    app = launch("HelloStore", env=env)
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]")
    app.wait_tap_id("sync")
    app.wait_log(r"AppStore\.sync\(\) restored [0-9]+ transactions from the account")
    app.wait_log(r"sync: done entitlements=\[dev\.isim\.store\.plus\.monthly\]")
    assert app.quit() == 0


def test_store_winback_ios17(launch, device_data):
    """win-back offers came with iOS 18: under iOS 17 a lapsed subscriber gets no win-back message or offer"""
    app = launch("HelloStore", env=ENV, os_version="17", device="iphone15")
    app.wait_tap_id("open-subs")
    app.wait_tap_id("sk-plan-dev.isim.store.plus.monthly")
    subscribe(app, "sk-subscribe")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]")
    storekit(device_data, "expire", "21000001")
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly")
    app.wait_log(r"entitlements: \[\]")
    app.wait_view(r"text=Subscribe$")      # no win-back offer (on iOS 18: Resubscribe, the offer's terms)
    app.wait_view(r"id=sk-terms text=\$2\.99/month\. Auto-renews until canceled\.")
    assert not app.has(r"message winBackOffer"), "no win-back message before iOS 18"
    assert app.quit() == 0
