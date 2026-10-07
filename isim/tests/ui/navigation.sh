#!/usr/bin/env bash
# UI test: UIKit containers (HelloNavigation sample) — UITabBarController with badge, UINavigationController with a
# large title that collapses on scroll, push/pop, back button, back swipe, bar button items (system, menu),
# toolbar items, hidesBottomBarWhenPushed, appearance callbacks.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloNavigation; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/navigation; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.8; shot $shots/list.png; dump; drag 200 600 200 300 0.4; wait 0.8; shot $shots/collapsed.png; dump; drag 200 300 200 700 0.4; wait 0.8; tapid book-3; wait 0.8; shot $shots/detail.png; dump; tapid bar-Favorite; wait 0.3; tapid read; wait 0.8; dump; tapid nav-back; wait 0.8; tapid nav-back; wait 0.8; tapid book-5; wait 0.8; drag 3 400 330 400 0.4; wait 0.8; dump; tapid bar-Sort; wait 0.6; tapid menu-Date; wait 0.4; tapid tab-Inbox; wait 0.8; shot $shots/inbox.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloNavigation.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "tab bar with items and badge"        'grep -q "id=tab-Library" <<<"$log" && grep -q "id=tab-Inbox" <<<"$log"'
check "large title, bar items"              'grep -q "id=bar-Sort" <<<"$log" && grep -Eq "UINavigationBar \(0 0; 402 x 158\)" <<<"$log"'
check "large title collapses on scroll"     'grep -Eq "UINavigationBar \(0 0; 402 x 106\)" <<<"$log"'
check "push shows the detail + toolbar"     'grep -q "detail 3 appears" <<<"$log" && grep -q "text=Details of book 3" <<<"$log" && grep -q "id=bar-Favorite" <<<"$log"'
check "toolbar item action"                 'grep -q "favorite tapped" <<<"$log"'
check "hidesBottomBarWhenPushed"            'grep -q "reader appeared, tab bar hidden: true" <<<"$log"'
check "back button pops (twice)"            '[ $(grep -c "list appears" <<<"$log") -ge 2 ]'
check "back swipe pops"                     '[ $(grep -c "list appears" <<<"$log") -ge 3 ]'
check "bar button menu"                     'grep -q "sort date" <<<"$log"'
check "tab switch + appearance callbacks"   'grep -q "inbox appeared" <<<"$log"'
check "exits cleanly"                       '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
