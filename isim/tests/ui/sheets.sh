#!/usr/bin/env bash
# UI test: SwiftUI presentations (HelloSheets sample). iPhone: an alert with a TextField and a SecureField, a popover
# adapted to a sheet, a popover kept by presentationCompactAdaptation(.popover), a detent sheet with
# presentationBackgroundInteraction(.enabled) (the page behind takes taps), interactiveDismissDisabled on a detent
# sheet (taps outside and drags do not close it). iPad: an anchored popover with its arrow, presentationSizing(.form),
# the inspector as a trailing column, a zoom fullScreenCover. Checked with the log, `dump` frames and pixels.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSheets; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tapid open-alert; wait 0.6; dump; tapid alert-field-0; type Ada; tapid alert-field-1; type pw; tapid alert-OK; wait 0.6; tapid open-popover; wait 0.8; dump; tap 200 30; wait 0.8; tapid open-compact; wait 0.8; dump; tap 200 820; wait 0.6; tapid open-interactive; wait 0.8; tapid bump; wait 0.3; tapid bump; wait 0.3; dump; swipeid sheet-grabber 0 300 0.3; wait 0.8; tapid open-locked; wait 0.8; tap 200 120; wait 0.6; swipeid sheet-grabber 0 380 0.3; wait 0.8; dump; tapid locked-close; wait 0.8; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSheets.app 2>&1); rc=$?
pad=$(ISIM_DEVICE=ipadpro11 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tapid open-popover; wait 0.8; dump; tap 600 1000; wait 0.6; tapid open-form; wait 0.8; dump; tap 30 1000; wait 0.8; tapid toggle-inspector; wait 0.6; dump; tapid open-zoom; wait 0.12; shot $shots/zoommid.png; wait 0.6; shot $shots/zoom.png; tapid zoom-close; wait 0.8; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSheets.app 2>&1); prc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "alert shows the TextField and SecureField"          'grep -q "id=alert-field-0" <<<"$log" && grep -q "id=alert-field-1" <<<"$log"'
check "typed alert text reaches the bindings before the action" 'grep -q "alert name: Ada secret: 2 chars" <<<"$log"'
check "popover adapts to a sheet on iPhone"                  'grep -q "popover adapted to a sheet on iPhone" <<<"$log" && grep -q "id=popover-text" <<<"$log"'
check "presentationCompactAdaptation(.popover) keeps the popover" 'grep -q "popover shown, arrow up" <<<"$log" && grep -q "id=compact-text" <<<"$log"'
check "background interaction: the page behind takes taps"   'grep -q "bump 2" <<<"$log"'
check "the locked sheet closes from its button (onDismiss)"  'grep -q "locked dismissed" <<<"$log"'
printf '%s\n' "$log" > "$shots/log.txt"; printf '%s\n' "$pad" > "$shots/pad.txt"
python3 tests/ui/sheets_check.py "$shots" || fail=1
check "iPad: the popover is anchored with an arrow"          'grep -q "popover shown, arrow down" <<<"$pad"'
check "exits cleanly"                                        '[ $rc = 0 ] && [ $prc = 0 ]'
[ $fail = 0 ] || { echo "--- iPhone log"; echo "$log" | grep -v "^ " | tail -20; echo "--- iPad log"; echo "$pad" | grep -v "^ " | tail -10; }
exit $fail
