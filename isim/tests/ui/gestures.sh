#!/usr/bin/env bash
# UI test: gestures and hardware input (HelloGestures sample) — require(toFail:) single vs double tap, swipe
# directions, a custom UIGestureRecognizer subclass (began/changed/ended, fails when the finger wanders),
# UIScreenEdgePanGestureRecognizer, UIKeyCommand (Cmd+R, arrow), pressesBegan with UIKey, shake motion events.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloGestures; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/gestures; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tap 200 250; wait 0.7; tap 200 250; tap 200 250; wait 0.7; drag 330 250 80 250 0.15; wait 0.4; drag 80 250 330 250 0.15; wait 0.4; drag 200 450 210 455 0.3; wait 0.3; drag 200 450 330 460 0.3; wait 0.3; drag 200 600 260 600 0.3; wait 0.3; drag 2 600 250 600 0.4; wait 0.6; shot $shots/panel.png; dump; keydown cmd; keydown r; keyup r; keyup cmd; wait 0.2; keydown r; keyup r; keydown up; keyup up; keydown a; keyup a; wait 0.2; shake; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloGestures.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "single tap fires once double tap fails" '[ $(grep -c "^single tap" <<<"$log") = 1 ]'
check "double tap wins over single tap"        'grep -q "^double tap" <<<"$log"'
check "swipe left and right"                   'grep -q "^swipe left" <<<"$log" && grep -q "^swipe right" <<<"$log"'
check "custom recognizer: began..ended"        'grep -Eq "^still ended after [1-9][0-9]* moves" <<<"$log"'
check "custom recognizer fails on wander"      '[ $(grep -c "^still began" <<<"$log") = 2 ] && [ $(grep -c "^still ended" <<<"$log") = 1 ]'
check "edge pan only from the screen edge"     '[ $(grep -c "^edge pan began" <<<"$log") = 1 ] && grep -q "panel open" <<<"$log" && grep -Eq "UIView \(0 540; 260 x 200\) id=panel" <<<"$log"'
check "key command Cmd+R (not plain R)"        '[ $(grep -c "^command R" <<<"$log") = 1 ] && grep -q "^pressed r code 21" <<<"$log"'
check "key command arrow up"                   'grep -q "^arrow up" <<<"$log"'
check "pressesBegan with UIKey"                'grep -q "^pressed a code 4" <<<"$log"'
check "shake motion events"                    'grep -q "^shake began" <<<"$log" && grep -q "^shake ended" <<<"$log"'
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
