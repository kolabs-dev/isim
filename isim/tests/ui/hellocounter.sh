#!/usr/bin/env bash
# UI test: drive HelloCounter headlessly (taps in points), assert app behaviour from its logs
# and pixel colours from screenshots. Requires a built tree (isim/build.sh).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
app=${1:-HelloCounter}                 # HelloCounter (Objective-C) or HelloCounterSwift
blue=${2:-"0 122 255"}; darkblue=${3:-"10 132 255"}
shots=out/test-shots/$app; mkdir -p "$shots"; rm -f "$shots"/hc-*.png
log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.3; shot $shots/hc-launch.png; tap 196 444; wait 0.1; tap 196 444; wait 0.1; tap 196 444; wait 0.2; shot $shots/hc-3.png; tap 269 563; wait 0.2; shot $shots/hc-dark.png; tap 196 500; wait 0.2; quit" \
      timeout 30 out/bin/isim run out/apps/$app.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "app exits cleanly"               '[ $rc = 0 ]'
check "app delegate launched"           'grep -q "didFinishLaunchingWithOptions" <<<"$log"'
check "scene delegate became active"    'grep -q "sceneDidBecomeActive" <<<"$log"'
check "three taps reached the target"   '[ "$(grep -c "$app: count = " <<<"$log")" = 3 ] && grep -q "count = 3" <<<"$log"'
check "screenshots written"             '[ -s $shots/hc-launch.png ] && [ -s $shots/hc-3.png ] && [ -s $shots/hc-dark.png ]'
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }   # needs ImageMagick 7
check "light background is white"      '[ "$(px $shots/hc-launch.png 30 300)" = "255 255 255" ]'
check "Tap me button has the tint color" '[ "$(px $shots/hc-3.png 160 444)" = "$blue" ]'
check "dark mode background is black"   '[ "$(px $shots/hc-dark.png 30 300)" = "0 0 0" ]'
check "dark mode tint is the dark variant" '[ "$(px $shots/hc-dark.png 160 444)" = "$darkblue" ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log"; }
exit $fail
