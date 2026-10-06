#!/usr/bin/env bash
# UI test: UIKit controls (HelloControls sample) — UISlider drag, UIStepper, UISegmentedControl, UIPageControl,
# UISwitch, UIActivityIndicatorView, and a UIButton pop-up UIMenu (inline section, checkmark, destructive item).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloControls; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.5; shot $shots/initial.png; drag 117 180 300 180 0.3; wait 0.3; tapid stepper; wait 0.2; tap 201 272; wait 0.5; tap 300 403; wait 0.2; tapid toggle; wait 0.2; tapid menu-button; wait 0.6; shot $shots/menu.png; dump; tapid menu-Date; wait 0.6; dump; quit" \
      timeout 40 out/bin/isim run out/apps/HelloControls.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "UISlider follows a thumb drag"         'grep -q "changed slider" <<<"$log" && grep -Eq "slider=(7[5-9]|8[0-9])" <<<"$log"'
check "UIStepper increments"                  'grep -q "stepper=3" <<<"$log"'
check "UISegmentedControl selects"            'grep -q "segment=1" <<<"$log"'
check "UIPageControl advances"                'grep -q "page=2" <<<"$log"'
check "UISwitch toggles"                      'grep -q "switch=false" <<<"$log"'
check "UIMenu shows title, items, checkmark"  'grep -q "id=menu-Name" <<<"$log" && grep -q "id=menu-Delete All" <<<"$log" && grep -q "id=isim-menu" <<<"$log"'
check "menu action runs"                      'grep -q "menu: Date" <<<"$log" && grep -q "text=Sort: Date" <<<"$log"'
check "exits cleanly"                         '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
