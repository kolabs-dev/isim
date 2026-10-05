#!/usr/bin/env bash
# UI test: a UIKit app with a scrolling Auto Layout form and a text field; isim's system keyboard
# types into it, the globe switches to the app's embedded keyboard extension (loaded in-process).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloKeyboardApp; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.3; tapid field; wait 0.1; tapid isim-kb-h; tapid isim-kb-i; shot $shots/abc.png; tapid isim-kb-globe; wait 0.1; tapid key-1; tapid key-2; shot $shots/custom.png; holdid isim-kb-globe 0.6; tapid isim-kb-menu-builtin; tapid isim-kb-return; wait 0.1; drag 200 700 200 250; wait 1.5; quit" \
      timeout 40 out/bin/isim run out/apps/HelloKeyboardApp.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "scroll content sized by Auto Layout" 'h=$(grep -o "contentSize 393 x [0-9.]*" <<<"$log" | tail -1 | cut -d" " -f4); [ -n "$h" ] && awk "BEGIN{exit !($h > 1180 && $h < 1215)}"'
check "keyboard shows for the text field"   'grep -q "keyboard did show, height 295" <<<"$log"'
check "typing with auto-capitalization"     'grep -q "text = \"Hi\"" <<<"$log"'
check "globe loads the embedded keyboard"   'grep -q "loaded keyboard extension Hello Keyboard" <<<"$log" && grep -q "keyboard frame height 139" <<<"$log"'
check "custom keyboard types via proxy"     'grep -q "text = \"Hi12\"" <<<"$log"'
check "globe list switches back"            'grep -q "keyboard switched to English (US)" <<<"$log"'
check "return -> textFieldShouldReturn"     'grep -q "return pressed" <<<"$log" && grep -q "keyboard hidden" <<<"$log"'
check "pan scrolls with deceleration"       'y=$(grep -o "scrolled to [0-9.]*" <<<"$log" | tail -1 | cut -d" " -f3); [ -n "$y" ] && awk "BEGIN{exit !($y > 200)}"'
check "exits cleanly"                       '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | tail -40; }
exit $fail
