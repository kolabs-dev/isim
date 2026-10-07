#!/usr/bin/env bash
# UI test: SwiftUI keyboard and focus APIs (HelloKeys sample) — keyboardShortcut (Cmd+S, cancelAction), onKeyPress
# (arrows, characters), inspector, defaultFocus, @FocusedValue/.focusedSceneValue, UIViewRepresentable.sizeThatFits.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloKeys; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/keys; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; dump; keydown cmd; keydown s; keyup s; keyup cmd; wait 0.2; keydown s; keyup s; keydown escape; keyup escape; keydown up; keyup up; keydown up; keyup up; keydown b; keyup b; wait 0.3; dump; tapid open-inspector; wait 0.8; shot $shots/inspector.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloKeys.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "Cmd+S shortcut (plain S is not)"       '[ $(grep -c "^saved" <<<"$log") = 1 ]'
check "cancelAction on Escape"                'grep -q "^cancelled" <<<"$log"'
check "onKeyPress arrow"                      'grep -q "^up 2" <<<"$log" && grep -q "text=ups 2 letters" <<<"$log"'
check "onKeyPress characters"                 'grep -q "^letter b" <<<"$log"'
check "defaultFocus focuses the field"        'grep -q "^focus name" <<<"$log" && grep -q "(editing)" <<<"$log"'
check "focusedSceneValue -> @FocusedValue"    'grep -q "text=focused: item 2" <<<"$log"'
check "representable sizeThatFits"            'grep -Eq "UILabel \([0-9.]+ [0-9.]+; 123 x 45\) id=badge" <<<"$log"'
check "inspector shows as a sheet"            'grep -q "id=inspector text=Inspector" <<<"$log"'
check "exits cleanly"                         '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
