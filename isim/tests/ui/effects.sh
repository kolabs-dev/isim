#!/usr/bin/env bash
# UI test: SwiftUI visual effects (HelloEffects sample) — colour filters, blend modes, blur, content shadows, alpha
# masks, clipped(), compositingGroup, contentShape hit testing, an animated grayscale, visualEffect and
# scrollTransition while scrolling; then sensoryFeedback (logged haptics), privacy redaction, a context menu with a
# preview, persistentSystemOverlays(.hidden) (the home indicator fades) and, on the device shell, defersSystemGestures
# (the first swipe up from the bottom stays in the app). Checked by pixels (effects_check.py, frames from `dump`)
# and the logs.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloEffects; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/start.png; dump; tapid t-shape-corner; wait 0.3; tapid t-shape; wait 0.3; tapid fade; wait 1; shot $shots/mid.png; swipeid row-2 0 -50 0.6; wait 1.6; shot $shots/scrolled.png; dump; tapid next; wait 0.5; shot $shots/more.png; tapid haptic; wait 0.3; tapid haptic; wait 0.3; tapid redact; wait 2.6; shot $shots/redacted.png; dump; holdid menu-source 0.8; wait 0.6; shot $shots/menu.png; dump; tapid menu-Copy; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloEffects.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "contentShape(Circle()): the corner does not take the tap, the centre does" 'grep -q "shape tapped 1" <<<"$log" && ! grep -q "shape tapped 2" <<<"$log"'
check "sensoryFeedback plays on trigger changes (logged haptics)" '[ "$(grep -c "haptic notification (success)" <<<"$log")" = 2 ] && [ "$(grep -c "haptic impact (heavy" <<<"$log")" = 1 ]'
check "contextMenu(menuItems:preview:) shows the preview with the menu" 'grep -q "id=isim-menu-preview" <<<"$log" && grep -q "id=menu-Copy" <<<"$log" && grep -q "menu: copy" <<<"$log"'
printf '%s\n' "$log" > "$shots/log.txt"
python3 tests/ui/effects_check.py "$shots" "$shots/log.txt" || fail=1
check "exits cleanly"                          '[ $rc = 0 ]'
# defersSystemGestures(on: .bottom) on the device shell: the first swipe up from the bottom edge goes to the app,
# a second one goes home
data=${ISIM_DATA:-$PWD/out/test-data/effects}/shell; rm -rf "$data"; mkdir -p "$data"
blog=$(ISIM_DATA=$data; export ISIM_DATA; out/bin/isim install out/apps/HelloEffects.app >/dev/null; ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 timeout 60 out/bin/isim boot --headless --script "wait 1; launch dev.isim.samples.HelloEffects; wait 1.2; tapid next; wait 0.6; drag 196 868 196 600; wait 0.8; dump; drag 196 868 196 600; wait 0.8; quit" 2>&1); brc=$?
check "defersSystemGestures: the first swipe from the bottom stays in the app" 'grep -q "id=menu-source" <<<"$blog"'
check "defersSystemGestures: a second swipe goes home"            '[ "$(grep -c "isim shell: home" <<<"$blog")" -ge 1 ]'
check "shell exits cleanly"                                        '[ $brc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; echo "--- shell log"; echo "$blog" | grep -v "^ " | tail -20; }
exit $fail
