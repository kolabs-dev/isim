#!/usr/bin/env bash
# UI test: drive HelloCounter headlessly (taps in points), assert app behaviour from its logs
# and pixel colours from screenshots. Requires a built tree (isim/build.sh).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots; mkdir -p "$shots"; rm -f "$shots"/hc-*.png
log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.3; shot $shots/hc-launch.png; tap 196 444; wait 0.1; tap 196 444; wait 0.1; tap 196 444; wait 0.2; shot $shots/hc-3.png; tap 269 563; wait 0.2; shot $shots/hc-dark.png; tap 196 500; wait 0.2; quit" \
      timeout 30 out/bin/isim run out/apps/HelloCounter.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "app exits cleanly"               '[ $rc = 0 ]'
check "app delegate launched"           'grep -q "didFinishLaunchingWithOptions" <<<"$log"'
check "scene delegate became active"    'grep -q "sceneDidBecomeActive" <<<"$log"'
check "three taps reached the target"   '[ "$(grep -c "HelloCounter: count = " <<<"$log")" = 3 ] && grep -q "count = 3" <<<"$log"'
check "screenshots written"             '[ -s $shots/hc-launch.png ] && [ -s $shots/hc-3.png ] && [ -s $shots/hc-dark.png ]'
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }   # needs ImageMagick 7
check "light background is white"      '[ "$(px $shots/hc-launch.png 30 300)" = "255 255 255" ]'
check "Tap me button is system blue"    '[ "$(px $shots/hc-3.png 160 444)" = "0 122 255" ]'
check "dark mode background is black"   '[ "$(px $shots/hc-dark.png 30 300)" = "0 0 0" ]'
check "dark mode button is dark blue"   '[ "$(px $shots/hc-dark.png 160 444)" = "10 132 255" ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log"; }
exit $fail
