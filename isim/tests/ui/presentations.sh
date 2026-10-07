#!/usr/bin/env bash
# UI test: SwiftUI modal presentations (HelloPresentations sample) — sheet with environment object and
# dismiss, swipe-free close, alert with roles + message, confirmationDialog, fullScreenCover, sheet(item:).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloPresentations; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.5; tapid open-sheet; wait 0.8; shot $shots/sheet.png; dump; tapid sheet-inc; wait 0.3; tapid sheet-close; wait 0.8; tapid open-alert; wait 0.6; shot $shots/alert.png; dump; tapid alert-Delete; wait 0.6; tapid open-dialog; wait 0.6; shot $shots/dialog.png; taptext Small; wait 0.6; tapid open-cover; wait 0.8; shot $shots/cover.png; dump; tapid cover-close; wait 0.8; tapid open-item; wait 0.8; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloPresentations.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "sheet presents with large title"        'grep -q "showSheet true" <<<"$log" && grep -q "text=Sheet count 0" <<<"$log" && grep -q "(20 44; 362 x 52) text=Sheet" <<<"$log"'
check "sheet sees the environment object"      'grep -q "count 1" <<<"$log"'
check "dismiss() closes the sheet + onDismiss" 'grep -q "showSheet false" <<<"$log" && grep -q "sheet dismissed" <<<"$log"'
check "alert with title, message and roles"    'grep -q "text=Delete everything?" <<<"$log" && grep -q "text=This cannot be undone." <<<"$log" && grep -q "id=alert-Cancel" <<<"$log"'
check "alert action runs"                       'grep -q "alert: delete" <<<"$log"'
check "confirmationDialog action runs"         'grep -q "dialog: small" <<<"$log"'
check "fullScreenCover presents"               'grep -q "id=cover-close" <<<"$log"'
check "sheet(item:) shows the item"            'grep -q "text=Fruit: kiwi" <<<"$log"'
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
