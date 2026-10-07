#!/usr/bin/env bash
# UI test: rotation (HelloRotation sample) — turning the device (script `rotate`), Info.plist supported orientations,
# viewWillTransition(to:with:) + coordinator, size classes, side safe areas and the landscape screen shape (through
# the shell), requestGeometryUpdate, setNeedsUpdateOfSupportedInterfaceOrientations; an app without
# UISupportedInterfaceOrientations stays portrait.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloRotation; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/rotation; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; rotate left; wait 0.8; shot $shots/landscape.png; dump; tapid lock; wait 0.8; shot $shots/locked.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloRotation.app 2>&1); rc=$?
log2=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tapid force; wait 0.8; shot $shots/forced.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloRotation.app 2>&1); rc2=$?
log3=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; rotate left; wait 0.8; shot $shots/portrait-only.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloTable.app 2>&1); rc3=$?
size() { magick identify -format "%wx%h" "$1" 2>/dev/null; }
px() { magick "$1" -format "%[fx:int(255*u.p{$2,$3}.r)] %[fx:int(255*u.p{$2,$3}.g)] %[fx:int(255*u.p{$2,$3}.b)]" info: 2>/dev/null; }
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "device orientation notification"     'grep -q "^device orientation 3" <<<"$log"'
check "viewWillTransition to landscape"      'grep -q "^will transition to 874x402" <<<"$log"'
check "compact height size class"            'grep -q "^traits h=1 v=1" <<<"$log"'
check "landscape safe areas + scene"         'grep -q "^transitioned: view 874x402, safe left 62 bottom 21, scene 3" <<<"$log"'
check "safe-area layout follows"             'grep -Eq "UIView \(62 351; 750 x 30\) id=bar" <<<"$log"'
check "landscape screen (through the shell)" '[ "$(size $shots/landscape.png)" = 874x402 ] && [ "$(px $shots/landscape.png 28 200)" = "0 0 0" ]'
check "locking to portrait turns back"       'grep -q "^will transition to 402x874" <<<"$log" && [ "$(size $shots/locked.png)" = 402x874 ]'
check "requestGeometryUpdate forces landscape" 'grep -q "^will transition to 874x402" <<<"$log2" && [ "$(size $shots/forced.png)" = 874x402 ]'
check "app without the plist key stays portrait" '[ "$(size $shots/portrait-only.png)" = 402x874 ] && ! grep -q "interface orientation 3" <<<"$log3"'
check "exits cleanly"                        '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
