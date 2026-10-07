#!/usr/bin/env bash
# UI test: Auto Layout extras (HelloConstraints sample) — Visual Format Language (standard spacing, sizes,
# metrics, priorities, alignment options), keyboardLayoutGuide following the keyboard, registerForTraitChanges.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloConstraints; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/constraints; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; dump; tapid field; wait 0.8; dump; shot $shots/keyboard.png; tapid dark; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloConstraints.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "VFL standard spacing + fixed sizes"      'grep -q "UIView (20 120; 60 x 44) id=a" <<<"$log" && grep -q "UIView (88 120; 60 x 44) id=b" <<<"$log"'
check "VFL metric gap, priority, alignment"     'grep -q "UIView (178 120; 204 x 44) id=c" <<<"$log" && grep -q "^vfl constraints 13" <<<"$log"'
check "keyboard guide: bar above safe area"     'grep -q "UIView (0 796; 402 x 44) id=bar" <<<"$log"'
check "keyboard guide: bar rides the keyboard"  '[ $(grep -c "id=bar" <<<"$log") = 2 ] && ! [ "$(grep "id=bar" <<<"$log" | tail -1)" = "$(grep "id=bar" <<<"$log" | head -1)" ]'
check "registerForTraitChanges"                 'grep -q "^style changed 1 -> 2" <<<"$log"'
check "exits cleanly"                           '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
