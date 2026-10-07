#!/usr/bin/env bash
# UI test: two fingers (HelloMultiTouch sample) — scripted pinch / rotate2 / twofinger drive UIPinchGestureRecognizer,
# UIRotationGestureRecognizer and a 2-touch UIPanGestureRecognizer recognized together (card transform in pixels);
# a multipleTouchEnabled view sees both UITouches in UIEvent.allTouches; UIScrollView pinch zooming and double-tap
# zoomToRect (zoomScale, contentSize, zoomed pixels); hover drives UIHoverGestureRecognizer; on iPad a pointer
# interaction gets its region request and the highlight effect.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloMultiTouch; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/multitouch; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/start.png; pinch 201 250 2 0.5; wait 0.3; shot $shots/pinch.png; rotate2 201 250 45 0.5; wait 0.3; twofinger 201 250 80 0 0.5; wait 0.3; pinch 201 450 1.5 0.3; wait 0.3; pinch 201 620 2.5 0.6; wait 0.5; shot $shots/zoom.png; tap 150 600; tap 150 600; wait 0.8; tap 150 600; tap 150 600; wait 0.8; hover 100 770; hover 120 775; hover 100 300; wait 0.2; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloMultiTouch.app 2>&1); rc=$?
pad=$(ISIM_DEVICE=ipad ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; hover 300 300; wait 0.2; hover 600 770; wait 0.3; shot $shots/pointer.png; dump; hover 300 300; wait 0.3; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloMultiTouch.app 2>&1); rc2=$?
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
orange() { read -r r g b <<<"$(px "$1" "$2" "$3")"; [ "$r" -gt 230 ] && [ "$g" -gt 120 ] && [ "$g" -lt 175 ] && [ "$b" -lt 40 ]; }
num() { grep -oE "$1" <<<"$log" | head -1 | grep -oE '[0-9.]+' | head -${2:-1} | tail -1; }
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "pinch recognizer sees two touches"      'grep -q "^pinch began with 2 touches" <<<"$log"'
check "pinch scale 2.0 (fingers 100 -> 200 pt)" 's=$(num "pinch ended scale [0-9.]+"); awk "BEGIN{exit !($s > 1.9 && $s < 2.1)}"'
check "card scaled in pixels"                  '! orange $shots/start.png 50 250 && orange $shots/pinch.png 50 250'
check "rotation 45 degrees"                    'd=$(num "rotation ended -?[0-9]+ degrees"); [ "$d" -ge 44 ] && [ "$d" -le 46 ]'
check "two-finger pan (minimumNumberOfTouches 2)" 'x=$(num "two-finger pan ended at [0-9]+"); [ "$x" -ge 60 ] && [ "$x" -le 81 ]'
check "pinch/rotate don't fire on a pan"       '[ $(grep -c "^pinch ended" <<<"$log") = 1 ] && [ $(grep -c "^rotation ended" <<<"$log") = 1 ]'
check "multipleTouchEnabled view gets 2nd touch" 'grep -q "^touchpad began 1 touch, 2 down" <<<"$log" && grep -q "^touchpad ended 1 touch, 2 in event" <<<"$log"'
check "scroll view pinch zoom 2.5x"            'grep -q "^zoom began" <<<"$log" && grep -q "^zoom ended scale 2.50, content 905 x 550" <<<"$log"'
# checker squares: 20 pt wide before zooming, 50 pt at 2.5x (median width of the teal runs along a row)
squares() { python3 -c "import sys; sys.path.insert(0, 'tests/ui'); from pixels import Image
im = Image('$1'); rs = sorted(e - s for s, e in im.runs_x(640, 22, 380, lambda r, g, b: b > 150 and r < 120 and g > 140))
print(rs[len(rs) // 2] if rs else 0)"; }
check "zoomed content in pixels (20 -> 50 pt squares)" 'a=$(squares $shots/start.png); b=$(squares $shots/zoom.png); [ "$a" -ge 19 ] && [ "$a" -le 21 ] && [ "$b" -ge 48 ] && [ "$b" -le 52 ]'
check "double tap: setZoomScale(1) then zoomToRect 4x" 'grep -q "^zoom ended scale 1.00, content 362 x 220" <<<"$log" && grep -q "^zoom ended scale 4.00, content 1448 x 880" <<<"$log"'
check "hover began / moved / ended"            'grep -q "^hover began" <<<"$log" && grep -q "^hover at 100,35" <<<"$log" && grep -q "^hover ended" <<<"$log"'
check "no pointer effects on iPhone"           '! grep -q "pointer region requested" <<<"$log"'
check "iPad pointer: region + enter"           'grep -q "^pointer region requested" <<<"$pad" && grep -q "^pointer entered button" <<<"$pad"'
check "iPad pointer: highlight platter, then gone" '[ $(grep -c "id=isim-pointer-effect" <<<"$pad") = 1 ]'
check "exits cleanly"                          '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
