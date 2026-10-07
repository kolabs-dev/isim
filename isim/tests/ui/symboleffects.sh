#!/usr/bin/env bash
# UI test (HelloSymbolEffects, UIKit, per iOS version): SF Symbols effects on UIImageView — scale (held until removed,
# by pixels), disappear / appear (by pixels), bounce with a repeat count, pulse and its removal, variable colour,
# replace content transition (setSymbolImage); iOS 18 wiggle, rotate (continuous, removed), breathe (periodic);
# iOS 26 draw off / on. iOS 17 has no wiggle/rotate/breathe, iOS 18 no draw off/on.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSymbolEffects; mkdir -p "$shots"; rm -f "$shots"/*.png
data=$PWD/out/test-data/symboleffects; rm -rf "$data"; mkdir -p "$data"
run() { local os=$1 script=$2 dev=${ISIM_TEST_DEVICE:-iphone16pro}; [ "$os" = 17 ] && dev=iphone15; mkdir -p "$data/$os"   # iOS 17: a device that shipped with it
  ISIM_DATA=$data/$os ISIM_DEVICE=$dev ISIM_OS_VERSION=$os ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 90 out/bin/isim run out/apps/HelloSymbolEffects.app 2>&1; }
all="wait 1; shot $shots/start.png; tapid scaleUp; wait 0.6; shot $shots/scaled.png; tapid scaleOff; wait 0.6; tapid hide; wait 0.6; shot $shots/hidden.png;
 tapid show; wait 0.6; tapid bounce; wait 1.5; tapid pulse; wait 1; tapid variable; wait 1.5; tapid replace; wait 0.8; shot $shots/replaced.png;
 tapid wiggle; wait 1.2; tapid rotate; wait 1; tapid breathe; wait 2.5; tapid drawOff; wait 0.6; shot $shots/drawn-off.png; tapid drawOn; wait 0.6; quit"
log=$(run 26 "$all"); rc=$?
log17=$(run 17 "wait 1; tapid bounce; wait 1.5; tapid wiggle; wait 0.3; tapid rotate; wait 0.3; tapid breathe; wait 0.3; quit"); rc2=$?
log18=$(run 18 "wait 1; tapid wiggle; wait 1.2; tapid drawOff; wait 0.3; quit"); rc3=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
count() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" "$6" <<'EOF'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); x0, y0, x1, y1 = map(int, sys.argv[2:6])
pred = eval("lambda r, g, b: " + sys.argv[6].replace("&&", " and "))
print(sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(*im.rgb(x, y))))
EOF
}
red='r>200 && g<90 && b<90'; blue='b>200 && r<80'
heart0=$(count start 0 100 140 240 "$red"); heart1=$(count scaled 0 100 140 240 "$red")
star0=$(count start 150 120 250 220 "$blue"); star1=$(count hidden 140 100 260 240 "$blue")
check "scale.up holds the symbol larger until removed (pixels $heart0 -> $heart1)" \
  '[ "$heart0" -gt 300 ] && [ $((heart1 * 100)) -gt $((heart0 * 135)) ] && grep -q "scale removed true" <<<"$log" && grep -q "heart: transform identity true, alpha 1.00" <<<"$log"'
check "disappear hides the symbol, appear brings it back (pixels $star0 -> $star1)" \
  '[ "$star0" -gt 300 ] && [ "$star1" -lt 20 ] && grep -q "disappeared true" <<<"$log" && grep -q "appeared true" <<<"$log" && grep -q "star: transform identity true, alpha 1.00" <<<"$log"'
check "bounce animates, repeats twice and completes" \
  'grep -q "bouncing bell: transform identity false" <<<"$log" && grep -q "bounce finished true" <<<"$log" && grep -q "bell: transform identity true, alpha 1.00" <<<"$log"'
check "pulse runs until removed (completion not finished), the view gets its alpha back" \
  'grep -q "pulsing alpha below 1 true" <<<"$log" && grep -q "pulse ended false" <<<"$log" && grep -q "pulse removed true" <<<"$log" && grep -q "heart: transform identity true, alpha 1.00" <<<"$log"'
check "variable colour (non-repeating) completes" 'grep -q "variable color finished true" <<<"$log"'
check "setSymbolImage(_:contentTransition: .replace) swaps the image" \
  'grep -q "replaced true, transition true, image moon true" <<<"$log" && [ "$(count replaced 150 120 250 220 "$blue")" -gt 200 ]'
check "iOS 18 wiggle, rotate (continuous until removed), breathe (periodic)" \
  'grep -q "wiggling bell: transform identity false" <<<"$log" && grep -q "wiggle finished true" <<<"$log" && grep -q "rotating bell: transform identity false" <<<"$log" && grep -q "rotate ended false" <<<"$log" && grep -q "rotate removed true" <<<"$log" && grep -q "breathe finished true" <<<"$log"'
check "iOS 26 draw off / draw on" \
  'grep -q "drawn off true" <<<"$log" && [ "$(count drawn-off 140 100 260 240 "$blue")" -lt 20 ] && grep -q "drawn on true" <<<"$log"'
check "iOS 17: bounce works, no iOS 18 effects" \
  'grep -q "bounce finished true" <<<"$log17" && grep -q "wiggle unavailable" <<<"$log17" && grep -q "rotate unavailable" <<<"$log17" && grep -q "breathe unavailable" <<<"$log17"'
check "iOS 18: wiggle works, no draw off" 'grep -q "wiggle finished true" <<<"$log18" && grep -q "draw off unavailable" <<<"$log18"'
check "exits cleanly" '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "$log" | grep -E "HelloSymbolEffects:" | tail -30; echo "$log17$log18" | grep -E "HelloSymbolEffects:" | tail -10; }
exit $fail
