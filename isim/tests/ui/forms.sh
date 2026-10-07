#!/usr/bin/env bash
# UI test: SwiftUI controls and tabs (HelloForms sample) — TabView tab bar + badge + page swipe, Toggle, Stepper,
# Slider (drag inside a List), Picker menu / segmented / inline / navigationLink, toolbar Menu with a Picker,
# and @AppStorage values surviving a relaunch.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloForms; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/forms; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloForms.app 2>&1; }
log=$(run "wait 0.8; shot $shots/form.png; taptext Vanilla; wait 0.6; shot $shots/picker-menu.png; tapid menu-Chocolate; wait 0.4; tap 340 266; wait 0.3; tapid notif; wait 0.3; tap 315 637; wait 0.4; taptext Miles; wait 0.4; drag 201 452 300 452 0.3; wait 0.3; dump; taptext Theme; wait 0.8; taptext Dark; wait 0.8; tapid more; wait 0.6; dump; tapid menu-Reset; wait 0.4; tapid tab-Pages; wait 0.6; drag 350 400 50 400 0.25; wait 0.8; shot $shots/pages.png; tapid tab-Inbox; wait 0.5; dump; quit"); rc=$?
log2=$(run "wait 0.8; dump; quit")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "Picker (menu) pops up and selects"      'grep -q "flavor chocolate" <<<"$log"'
check "Stepper increments a bound value"       'grep -q "count 3" <<<"$log"'
check "Toggle bound to @AppStorage"            'grep -q "notifications false" <<<"$log"'
check "Picker (segmented)"                     'grep -q "size large" <<<"$log"'
check "Picker (inline rows)"                   'grep -q "unit mi" <<<"$log"'
check "Slider drags inside a List"             'grep -Eq "text=Volume (8[0-9]|9[0-9])%" <<<"$log"'
check "Picker (navigationLink page)"           'grep -q "theme Dark" <<<"$log"'
check "toolbar Menu: button + picker section"  'grep -q "id=menu-Small" <<<"$log" && grep -q "menu: reset" <<<"$log" && grep -q "count 0" <<<"$log"'
check "TabView switches tabs, shows badge"     'grep -q "tab pages" <<<"$log" && grep -q "tab inbox" <<<"$log" && grep -q "text=Inbox is empty" <<<"$log"'
check "page TabView swipes"                    'grep -q "page 1" <<<"$log"'
check "@AppStorage persists across launches"   'grep -q "text=Chocolate" <<<"$log2" && grep -Eq "text=Volume (8[0-9]|9[0-9])%" <<<"$log2"'
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
