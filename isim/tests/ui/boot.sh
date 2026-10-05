#!/usr/bin/env bash
# UI test: the device shell (isim boot) on a scratch data dir — home screen, Settings
# (Display & Brightness > Dark), app launch, swipe up to go home, long-press > Remove App > Delete.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
export ISIM_DATA=$data
out/bin/isim install out/apps/HelloSwiftUI.app out/apps/HelloCounter.app >/dev/null
shots=out/test-shots/boot; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_SHOT_SCALE=1 timeout 60 out/bin/isim boot --headless --script "wait 1; shot $shots/home.png; tapid app-dev.isim.settings; wait 1; tapid settings-display; wait 0.6; tapid settings-dark; wait 0.6; home; wait 0.6; shot $shots/home-after.png; tapid app-dev.isim.samples.HelloSwiftUI; wait 1; tapid increment; wait 0.3; drag 196 845 196 600; wait 0.6; holdid app-dev.kolabs.isim.HelloCounter 0.8; wait 0.5; tapid menu-remove; wait 0.5; tapid alert-Delete; wait 0.6; quit" 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "home screen lists installed apps"     'grep -q "SpringBoard: 3 app(s): Settings, Hello SwiftUI, HelloCounter" <<<"$log"'
check "Settings launches from its icon"      'grep -q "launching Settings (dev.isim.settings)" <<<"$log"'
check "Dark appearance saved globally"        'grep -q "<string>Dark</string>" "$data/Library/Preferences/.GlobalPreferences.plist"'
check "apps launch as separate processes"     'grep -q "launched .*HelloSwiftUI.app (pid" <<<"$log" && grep -q "count 0 -> 1" <<<"$log"'
check "swipe up from the bottom goes home"    '[ "$(grep -c "isim shell: home" <<<"$log")" -ge 2 ]'
check "long press > Remove App > Delete"      'grep -q "deleting HelloCounter" <<<"$log" && [ ! -d "$data/Applications/HelloCounter.app" ]'
check "shell exits cleanly"                   '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
