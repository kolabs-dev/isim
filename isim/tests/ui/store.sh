#!/usr/bin/env bash
# UI test: local StoreKit testing (HelloStore sample). Run 1: SubscriptionStoreView with a free-trial
# introductory offer, renewals on the accelerated clock (one month = 4 s), an immediate upgrade, cancelling
# in the Manage Subscriptions sheet and the expiry that follows, StoreView/ProductView purchases, a refund
# through the refund sheet, offer-code redemption, the review prompt's 3-per-year limit, StoreKit 1
# (SKProductsRequest, SKPaymentQueue purchase + restore), the local receipt, SKOverlay and the product page.
# Run 2 (same device data): the unfinished consumable is delivered again at launch, `isim storekit`
# (Transaction Manager) refunds and expires while the app runs, a promotional offer, win-back eligibility.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloStore; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/store; rm -rf "$ISIM_DATA"
export ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_STOREKIT_TIME_RATE=month=4
app=dev.isim.samples.HelloStore
s1="wait 1.5; tapid open-subs; wait 1; tapid sk-plan-dev.isim.store.plus.monthly; wait 0.3; tapid sk-subscribe; wait 0.8; shot $shots/confirm.png; taptext Subscribe; wait 9.5"
s1="$s1; shot $shots/subscribed.png; tapid sk-plan-dev.isim.store.premium.monthly; wait 0.3; tapid sk-subscribe; wait 0.8; taptext Subscribe; wait 1.5; shot $shots/upgraded.png; tapid close-subs; wait 1"
s1="$s1; tapid manage; wait 1; tapid sk-manage-plan-dev.isim.store.plus.monthly; wait 0.5; shot $shots/manage.png; dump; wait 4.5; tapid sk-manage-cancel; wait 0.4; tapid sk-manage-confirm-cancel; wait 0.5; dump; tapid sk-manage-done; wait 6; tapid sk1; wait 1; taptext Buy; wait 1; tapid sk1-restore; wait 1"
s1="$s1; tapid open-products; wait 1; shot $shots/products.png; tapid sk-buy-dev.isim.store.full_game; wait 0.8; taptext Buy; wait 1; tapid sk-buy-dev.isim.store.coins; wait 0.8; taptext Buy; wait 1; dump; tapid close-products; wait 1"
s1="$s1; tapid refund; wait 1; shot $shots/refund.png; tapid sk-refund-reason-2; tapid sk-refund-submit; wait 1.5"
s1="$s1; tapid redeem; wait 1; tapid sk-redeem-field; type nope; tapid sk-redeem-submit; wait 0.5; dump; tapid sk-redeem-field; key backspace; key backspace; key backspace; key backspace; type WELCOME; tapid sk-redeem-submit; wait 0.8; shot $shots/redeemed.png; dump; tapid sk-redeem-ok; wait 1"
s1="$s1; tapid review; wait 0.6; shot $shots/review.png; tapid isim-review-not-now; wait 0.3; tapid review; wait 0.5; tapid isim-review-star-5; wait 0.3; tapid review; wait 0.5; tapid isim-review-not-now; wait 0.3; tapid review; wait 0.5"
s1="$s1; tapid receipt; wait 0.5; tapid overlay; wait 1; shot $shots/overlay.png; dump; tapid sk-overlay-close; wait 0.5; tapid product-page; wait 1; shot $shots/product-page.png; dump; tapid sk-product-page-done; wait 1; quit"
log1=$(ISIM_SCRIPT="$s1" timeout 120 out/bin/isim run out/apps/HelloStore.app 2>&1); rc1=$?
list1=$(out/bin/isim storekit $app list 2>&1)

# run 2: Transaction Manager changes while the app runs (after ~3 s)
coins=$(awk '$3 == "dev.isim.store.coins" && /unfinished/ { print $1; exit }' <<<"$list1")
( sleep 4; out/bin/isim storekit $app refund "${coins:-0}"; out/bin/isim storekit $app expire 21000001 ) > "$shots/manager.log" 2>&1 &
log2=$(ISIM_SCRIPT="wait 7; tapid promo; wait 0.8; shot $shots/promo.png; taptext Subscribe; wait 1; tapid winback; wait 1; quit" timeout 60 out/bin/isim run out/apps/HelloStore.app 2>&1); rc2=$?
wait
list2=$(out/bin/isim storekit $app list 2>&1)

# seconds between consecutive renewals of Plus Monthly before the upgrade (accelerated clock: 4 s)
gaps=$(sed "/immediate upgrade/q" <<<"$log1" | grep "subscription dev.isim.store.plus.monthly renewed" | awk '{ split($2, t, ":"); s = t[1]*3600 + t[2]*60 + t[3]; if (n++) printf "%.1f ", s - p; p = s }')
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "products + subscription info from .storekit"   'grep -q "product: dev.isim.store.plus.monthly Auto-Renewable Subscription \$2.99 group=21000001 level=2 period=1month intro=FreeTrial:1week promos=comeback winbacks=winback introEligible=true" <<<"$log1"'
check "AppTransaction (local, from Info.plist)"       'grep -q "appTransaction: bundle=$app version=7 original=7 env=Xcode" <<<"$log1"'
check "subscribe with the free trial"                 'grep -q "subscribed to dev.isim.store.plus.monthly .* with introductory offer 1 week free" <<<"$log1" && grep -q "entitlements: \[dev.isim.store.plus.monthly\]" <<<"$log1"'
check "renewals arrive in Transaction.updates"        '[ $(grep -c "update: txn .* dev.isim.store.plus.monthly reason=renewal" <<<"$log1") -ge 2 ]'
check "renewals every 4 s (accelerated clock): $gaps" '[ -n "$gaps" ] && awk "BEGIN { n = split(\"$gaps\", g, \" \"); ok = n >= 1; for (i = 1; i <= n; i++) if (g[i] < 3.3 || g[i] > 4.9) ok = 0; exit !ok }"'
check "upgrade takes effect immediately"              'grep -q "dev.isim.store.plus.monthly -> dev.isim.store.premium.monthly (immediate upgrade)" <<<"$log1" && grep -q "status: subscribed dev.isim.store.premium.monthly autoRenew=true" <<<"$log1"'
check "manage sheet: downgrade at the next renewal"   'grep -q "id=sk-manage-status-21000001 text=Changes to Plus Monthly on" <<<"$log1" && grep -q "dev.isim.store.premium.monthly -> dev.isim.store.plus.monthly takes effect at the next renewal" <<<"$log1" && sed -n "/takes effect at the next renewal/,\$p" <<<"$log1" | grep -q "update: txn [0-9]* dev.isim.store.plus.monthly reason=renewal"'
check "manage sheet: cancel turns auto-renew off"     'grep -q "id=sk-manage-status-21000001 text=Expires" <<<"$log1" && grep -q "status: subscribed dev.isim.store.plus.monthly autoRenew=false" <<<"$log1"'
check "subscription expires, entitlement removed"     'grep -q "status: expired dev.isim.store.plus.monthly autoRenew=false" <<<"$log1" && grep -q "subscription dev.isim.store.plus.monthly expired (auto-renew off)" <<<"$log1"'
check "StoreView purchases + completion callback"     'grep -q "entitlements: \[dev.isim.store.full_game\]" <<<"$log1" && grep -q "completion: dev.isim.store.coins" <<<"$log1" && grep -q "id=sk-owned-dev.isim.store.full_game" <<<"$log1"'
check "refund sheet revokes the purchase"             'grep -q "refund request: success" <<<"$log1" && grep -q "update: txn [0-9]* dev.isim.store.full_game reason=purchase revoked" <<<"$log1"'
check "offer code: wrong code rejected"               'grep -q "id=sk-redeem-error text=This code isn’t valid." <<<"$log1"'
check "offer code redeemed via Transaction.updates"   'grep -q "update: txn [0-9]* dev.isim.store.plus.monthly reason=purchase offer=3:WELCOME" <<<"$log1" && grep -q "id=sk-redeem-done" <<<"$log1"'
check "review prompt: at most 3 times a year"         '[ $(grep -c "showing the development-style rating prompt" <<<"$log1") = 3 ] && grep -q "requestReview() ignored" <<<"$log1"'
check "SK1 products request (invalid ids too)"        'grep -q "sk1 product: dev.isim.store.plus.monthly Plus Monthly 2.99 period=1/2 intro=2" <<<"$log1" && grep -q "sk1 invalid: \[\"dev.isim.store.nope\"\]" <<<"$log1"'
check "SK1 payment queue purchase + restore"          'grep -q "sk1: dev.isim.store.coins state=1 id=" <<<"$log1" && grep -q "sk1: dev.isim.store.plus.monthly state=3 .* original=" <<<"$log1" && grep -q "sk1: restore finished" <<<"$log1"'
check "local unsigned receipt"                        'grep -q "receipt: [0-9]* bytes, local unsigned=true, full_game=true" <<<"$log1"'
check "SKOverlay + product page"                      'grep -q "id=sk-overlay-title text=App 1234567890" <<<"$log1" && grep -q "SKOverlay dismissed" <<<"$log1" && grep -q "id=sk-product-page-title" <<<"$log1" && grep -q "product page finished" <<<"$log1"'
check "Transaction Manager lists the ledger"          'grep -q "dev.isim.store.full_game .*refunded" <<<"$list1" && [ -n "$coins" ]'
check "unfinished consumable delivered at launch"     'grep -q "update: txn $coins dev.isim.store.coins reason=purchase$" <<<"$log2" && grep -q "coins 100" <<<"$log2"'
check "manager refund reaches the running app"        'grep -q "update: txn $coins dev.isim.store.coins reason=purchase revoked" <<<"$log2" && grep -q "refunded transaction $coins" "$shots/manager.log"'
check "manager expire ends the subscription"          'grep -q "status: expired dev.isim.store.plus.monthly" <<<"$log2"'
check "promotional offer (signature not verified)"    'grep -q "offer purchase: txn [0-9]* dev.isim.store.plus.monthly offer=2:comeback expires=4s" <<<"$log2"'
check "win-back offer needs a lapsed subscription"    'grep -q "offer purchase failed: ineligibleForOffer" <<<"$log2"'
check "ledger after run 2"                            'grep -q "^ *$coins .*refunded" <<<"$list2"'
check "exits cleanly"                                 '[ $rc1 = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- run 1"; grep -v "^ " <<<"$log1" | tail -40; echo "--- run 2"; grep -v "^ " <<<"$log2" | tail -30; echo "--- manager"; cat "$shots/manager.log"; echo "$list2" | tail -8; }
exit $fail
