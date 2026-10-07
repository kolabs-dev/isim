#!/usr/bin/env bash
# UI test: Core Animation, UIKit Dynamics and CoreHaptics (HelloCoreAnimation sample) — CAShapeLayer strokeEnd
# animation paused half-way (pixels), CAGradientLayer pixels, CAReplicatorLayer copies, perspective CATransform3D
# (a layer and a view drawn as trapezoids: edge heights differ), layer mask and view mask pixels, blurred
# shadow falloff, CAKeyframeAnimation positions at given times (keyTimes, fillMode forwards), CATransaction
# implicit animation + completion block + disableActions, CA animations on a view's layer with delegates,
# CASpringAnimation / CAAnimationGroup, an item falling under gravity and resting on a collision boundary,
# and CoreHaptics (no hardware: supportsHaptics false, patterns timed to completion).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloCoreAnimation; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/coreanimation; rm -rf "$ISIM_DATA"
script="wait 1; shot $shots/main.png; tapid btn-Report; wait 0.3; tapid btn-Tx; wait 1.2; tapid btn-Anim; wait 0.2; shot $shots/spin.png; wait 1.5;
 tapid btn-Drop; wait 3; shot $shots/drop.png; tapid btn-Haptic; wait 1; quit"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 60 out/bin/isim run out/apps/HelloCoreAnimation.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
# vertical extent (pixel rows) of colour pred in column x between y0 and y1
extent() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" <<'EOF'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); x, y0, y1 = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
pred = eval("lambda r, g, b: " + sys.argv[5].replace("&&", " and "))
runs = im.runs_y(x, y0, y1, pred)
print(sum(e - s for s, e in runs))
EOF
}
runs() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" <<'EOF'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); y, x0, x1 = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
pred = eval("lambda r, g, b: " + sys.argv[5].replace("&&", " and "))
print(len(im.runs_x(y, x0, x1, pred)))
EOF
}
red='r>200 && g<60 && b<60'; white='r>235 && g>235 && b>235'
check "shape strokeEnd paused at 50%: stroked to the midpoint" 'is main 100 100 "$red" && is main 195 100 "$red" && is main 210 100 "$white" && is main 370 100 "$white"'
check "presentation strokeEnd half-way, model untouched"      'grep -q "stroke presentation strokeEnd=0.50 model=1.00" <<<"$log"'
check "axial gradient red -> blue"                            'is main 24 150 "r>220 && b<40" && is main 376 150 "b>220 && r<40" && is main 200 150 "r>90 && r<170 && b>90 && b<170"'
check "replicator draws 5 copies 60 pt apart"                 '[ "$(runs main 200 10 395 "g>150 && r<60 && b<60")" = 5 ] && is main 270 200 "g>150 && r<60" && is main 300 200 "$white"'
ol=$(extent main 60 200 400 "r>230 && g>120 && g<200 && b<60"); orr=$(extent main 144 200 400 "r>230 && g>120 && g<200 && b<60")
check "perspective layer is a trapezoid (near edge taller: $ol vs $orr)" '[ -n "$ol" ] && [ -n "$orr" ] && [ "$ol" -gt 0 ] && [ "$orr" -gt 0 ] && [ $((ol - orr)) -gt 25 ]'
bl=$(extent main 284 200 400 "b>200 && r<60 && g<60"); br=$(extent main 344 200 400 "b>200 && r<60 && g<60")
check "view transform3D drawn in perspective ($bl vs $br)"     '[ -n "$bl" ] && [ "$bl" -gt 0 ] && [ "$br" -gt 0 ] && [ $((br - bl)) -gt 15 ]'
check "layer mask (circle) clips the red view"                'is main 70 430 "$red" && is main 24 384 "$white" && is main 116 476 "$white"'
check "view mask shows only its left half"                    'is main 160 430 "g>150 && r<60 && b<60" && is main 220 430 "$white"'
check "blurred shadow falls off below the card"               'is main 320 465 "r<200 && r>40" && is main 320 492 "r>225" && is main 320 425 "$white"'
check "keyframe values/keyTimes at t=0.25 0.5 1.25"           'grep -q "keyframe t=0.25 x=120 y=520" <<<"$log" && grep -q "keyframe t=0.5 x=200 y=520" <<<"$log" && grep -q "keyframe t=1.25 x=200 y=560" <<<"$log"'
check "keyframe fillMode forwards holds the end value"        'grep -q "keyframe t=2.5 x=200 y=600" <<<"$log" && grep -q "keyframe keys=\[\"path\"\] model x=40" <<<"$log"'
check "emitter spawns particles"                              'grep -q "emitter particles>0 true" <<<"$log"'
check "CATransform3D concat/invert/isAffine"                  'grep -q "transform3D concat identity true affine true" <<<"$log"'
check "implicit animation in a CATransaction (mid value)"     'grep -q "implicit mid opacity between true" <<<"$log"'
check "CATransaction completion block after the animation"    'grep -q "transaction complete opacity=0.20 presentation=0.20" <<<"$log"'
check "setDisableActions: no implicit animation"              'grep -q "disableActions radius=20 cornerRadius animated=false" <<<"$log"'
check "CA animation on a view layer (rotation mid-way)"       'grep -q "spin mid rotation between true model=0.00" <<<"$log"'
check "animation delegate start/stop"                         'grep -q "spin didStart" <<<"$log" && grep -q "spin didStop finished=true" <<<"$log"'
check "CASpringAnimation and CAAnimationGroup finish"          'grep -q "spring settlingDuration>0.3 true" <<<"$log" && grep -q "spring didStop finished=true" <<<"$log" && grep -q "group didStop finished=true" <<<"$log"'
check "dynamics: the item falls"                              'grep -q "dynamics falling y>600 true running=true" <<<"$log"'
check "dynamics: rests on the collision boundary"             'grep -q "dynamics rest maxY=780 x=180" <<<"$log" && is drop 200 770 "r>220 && g<120"'
check "CoreHaptics: no haptic hardware, pattern plays out"    'grep -q "haptics supportsHaptics=false" <<<"$log" && grep -q "haptics pattern duration=0.40" <<<"$log" && grep -q "CoreHaptics: pattern started: 2 event" <<<"$log" && grep -q "haptics players finished" <<<"$log"'
check "exits cleanly"                                         '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; }
exit $fail
