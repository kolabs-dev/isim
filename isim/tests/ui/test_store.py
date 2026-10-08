"""Local StoreKit testing (HelloStore). Run 1: SubscriptionStoreView with a free-trial introductory offer, renewals on
the accelerated clock (one month = 4 s), an immediate upgrade, cancelling in the Manage Subscriptions sheet and the
expiry that follows, StoreView/ProductView purchases, a refund through the refund sheet, offer-code redemption, the
review prompt's 3-per-year limit, StoreKit 1 (SKProductsRequest, SKPaymentQueue purchase + restore), the local receipt,
SKOverlay and the product page. Run 2 (same device data): the unfinished consumable is delivered again at launch,
`isim storekit` (Transaction Manager) refunds and expires while the app runs, a promotional offer, win-back
eligibility. Port of tests/ui/store.sh: condition waits instead of the script's fixed timeline (the renewals and the
expiry still take their accelerated-clock time)."""
import os
import re
import subprocess
from datetime import datetime

from isimtest import ISIM, visible

APP = "dev.isim.samples.HelloStore"
ENV = {"ISIM_STOREKIT_TIME_RATE": "month=4"}


def storekit(data, *args):
    return subprocess.run([str(ISIM), "storekit", APP, *args], env=dict(os.environ, ISIM_DATA=str(data)),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60).stdout


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


def test_store(launch, device_data):
    app = launch("HelloStore", env=ENV)
    app.wait_log(r"product: dev\.isim\.store\.plus\.monthly Auto-Renewable Subscription \$2\.99 group=21000001 level=2 "
                 r"period=1month intro=FreeTrial:1week promos=comeback winbacks=winback introEligible=true")
    app.wait_log(rf"appTransaction: bundle={APP} version=7 original=7 env=Xcode")   # AppTransaction (local)

    # subscribe with the free trial; renewals every 4 s
    app.wait_tap_id("open-subs")
    app.wait_tap_id("sk-plan-dev.isim.store.plus.monthly")
    app.wait_tap_id("sk-subscribe")
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")
    app.wait_log(r"subscribed to dev\.isim\.store\.plus\.monthly .* with introductory offer 1 week free")
    app.wait_log(r"entitlements: \[dev\.isim\.store\.plus\.monthly\]")
    app.wait_log(r"subscription dev\.isim\.store\.plus\.monthly renewed", count=2, timeout=20)
    app.wait_log(r"update: txn .* dev\.isim\.store\.plus\.monthly reason=renewal", count=2)   # in Transaction.updates
    # immediate upgrade
    app.wait_tap_id("sk-plan-dev.isim.store.premium.monthly")
    app.wait_tap_id("sk-subscribe")
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")
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
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly autoRenew=false")     # entitlement removed

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

    # the refund sheet revokes the purchase
    app.wait_tap_id("refund")
    app.wait_tap_id("sk-refund-reason-2")
    app.tap_id("sk-refund-submit")
    app.wait_log(r"refund request: success")
    app.wait_log(r"update: txn [0-9]* dev\.isim\.store\.full_game reason=purchase revoked")

    # offer codes
    app.wait_tap_id("redeem")
    app.wait_tap_id("sk-redeem-field")
    app.type("nope").tap_id("sk-redeem-submit")
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

    app.wait_tap_id("receipt")
    app.wait_log(r"receipt: [0-9]* bytes, local unsigned=true, full_game=true")         # local unsigned receipt
    app.wait_tap_id("overlay")
    app.wait_view(r"id=sk-overlay-title text=App 1234567890")
    app.tap_id("sk-overlay-close")
    app.wait_log(r"SKOverlay dismissed")
    app.wait_tap_id("product-page")
    app.wait_view(r"id=sk-product-page-title\b")
    app.tap_id("sk-product-page-done")
    app.wait_log(r"product page finished")                                              # SKOverlay + product page
    assert app.quit() == 0

    # the Transaction Manager lists the ledger
    list1 = storekit(device_data, "list")
    assert re.search(r"dev\.isim\.store\.full_game .*refunded", list1), list1
    coins = next((l.split()[0] for l in list1.splitlines()
                  if len(l.split()) > 2 and l.split()[2] == "dev.isim.store.coins" and "unfinished" in l), None)
    assert coins, f"an unfinished coins transaction: {list1}"

    # run 2: the unfinished consumable comes again; Transaction Manager changes while the app runs
    app = launch("HelloStore", env=ENV)
    app.wait_log(rf"update: txn {coins} dev\.isim\.store\.coins reason=purchase$")      # delivered at launch
    app.wait_log(r"coins 100")
    refund = storekit(device_data, "refund", coins)
    assert f"refunded transaction {coins}" in refund, refund
    storekit(device_data, "expire", "21000001")
    app.wait_log(rf"update: txn {coins} dev\.isim\.store\.coins reason=purchase revoked")   # the refund reaches the app
    app.wait_log(r"status: expired dev\.isim\.store\.plus\.monthly")                     # manager expire
    app.wait_tap_id("promo")
    app.wait_view(r"text=Subscribe\b")
    app.tap_text("Subscribe")
    app.wait_log(r"offer purchase: txn [0-9]* dev\.isim\.store\.plus\.monthly offer=2:comeback expires=4s")
    app.wait_tap_id("winback")
    app.wait_log(r"offer purchase failed: ineligibleForOffer")                          # win-back needs a lapsed sub
    assert app.quit() == 0
    list2 = storekit(device_data, "list")
    assert re.search(rf"^ *{coins} .*refunded", list2, re.M), f"ledger after run 2: {list2}"
