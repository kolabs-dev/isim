#!/usr/bin/env bash
# UI test: SwiftUI drawing and animation (HelloDrawing sample) — custom Shape/Path rendering, even-odd fill,
# gradients (linear, radial, angular, elliptical, Color.gradient, foregroundStyle, background), dashed
# strokes, trim, strokeBorder, uneven corners, clipShape(custom), Canvas (transform, opacity, clip, text),
# projection effects, shape transforms; then animatable trim/custom shape/color/gradient checked half-way
# through a 2 s linear animation, TimelineView ticks, phaseAnimator and keyframeAnimator.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloDrawing; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/drawing; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/shapes.png; tapid next; wait 0.6; shot $shots/motion0.png; dump; tapid animate; wait 1.0; shot $shots/motion-mid.png; tapid bounce; wait 1.6; shot $shots/motion-end.png; dump; wait 1.2; quit" \
      timeout 60 out/bin/isim run out/apps/HelloDrawing.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
# pixel test: is FILE X Y 'arithmetic on r g b'   (ImageMagick 7)
is() {
    local f=$shots/$1.png
    read -r r g b < <(magick "$f" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null)
    [ -n "${b:-}" ] || return 1
    (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }
}
white='r>235 && g>235 && b>235'
check "custom Shape path(in:) filled"            'is shapes 70 160 "r>200 && g<100 && b<100" && is shapes 25 85 "$white"'
check "Path with even-odd fill leaves a hole"    'is shapes 150 90 "b>200 && r<60" && is shapes 190 130 "$white"'
check "Ellipse"                                  'is shapes 320 110 "g>150 && r<120 && b<120" && is shapes 263 83 "$white"'
check "LinearGradient view (leading->trailing)"  'is shapes 22 220 "r>230 && b<30" && is shapes 178 220 "b>230 && r<30" && is shapes 100 220 "r>90 && r<170 && b>90 && b<170"'
check "RadialGradient fill"                      'is shapes 240 240 "r>220 && g>220" && is shapes 276 240 "r<70 && g<70"'
check "AngularGradient (0 red, 120 green, 240 blue)" 'is shapes 370 240 "r>200 && g<60 && b<60" && is shapes 325 266 "g>150 && r<100 && b<100" && is shapes 325 214 "b>150 && r<100 && g<100"'
check "dashed stroke (StrokeStyle dash)"         'is shapes 25 300 "r<70 && g<70 && b<70" && is shapes 35 300 "$white"'
check "UnevenRoundedRectangle"                   'is shapes 203 303 "$white" && is shapes 277 303 "r>230 && g>110 && g<180 && b<60"'
check "trim(from:to:) stroke (bottom half only)" 'is shapes 340 370 "r>130 && b>180 && g<120" && is shapes 340 290 "$white"'
check "strokeBorder draws inside the frame"      'is shapes 60 384 "r>130 && b>180 && g<120" && is shapes 60 420 "$white"'
check "clipShape with a custom shape"            'is shapes 125 385 "$white" && is shapes 160 450 "g>140 && b>160 && r<120"'
check "Canvas fill + translateBy"                'is shapes 225 385 "r>240 && g<20 && b<20" && is shapes 315 395 "g>110 && g<150 && r<20 && b<20"'
check "Canvas opacity"                           'is shapes 240 460 "r>100 && r<150 && b>240"'
check "Canvas clip + linear gradient shading"    'is shapes 360 450 "r>230 && b<80" && is shapes 322 422 "$white"'
check "Color.gradient (lighter at the top)"      'is shapes 70 482 "b>200" && is shapes 70 518 "b>200" && [ $(magick $shots/shapes.png -format "%[fx:int(255*p{70,482}.r)]" info:) -gt $(magick $shots/shapes.png -format "%[fx:int(255*p{70,518}.r)]" info:) ]'
check "foregroundStyle(LinearGradient) on a shape" 'is shapes 142 500 "r>230 && g<40" && is shapes 238 500 "r>230 && g>220"'
check "EllipticalGradient"                       'is shapes 320 500 "g>200" && is shapes 262 482 "g<70"'
check "background(LinearGradient)"               'is shapes 22 602 "g>200 && b>200 && r<60" && is shapes 22 628 "r>200 && b>200 && g<60"'
check "rotation3DEffect (y axis, 60 degrees)"    'is shapes 30 560 "$white" && is shapes 70 560 "g>150 && r<120"'
check "transformEffect (translation)"            'is shapes 145 560 "$white" && is shapes 225 560 "b>200 && r<60"'
check "Shape.rotation (diamond past its frame)"  'is shapes 310 537 "r>200 && g<100" && is shapes 283 548 "$white"'
check "AnyShape(Capsule())"                      'is shapes 190 615 "b>150 && r<120 && g<120" && is shapes 141 601 "$white"'
check "Shape.offset"                             'is shapes 320 660 "r>120 && g>90 && b<120 && r<200" && is shapes 285 660 "$white"'
check "InsettableShape.inset(by:)"               'is shapes 145 655 "$white" && is shapes 170 680 "g>180 && b>150 && r<120"'
dark='r<60 && g<60 && b<60'
check "ImagePaint tiles an image (20 pt symbol)"  'grep -q "symbol size 20x20" <<<"$log" && is shapes 230 710 "$dark" && is shapes 250 710 "$dark" && is shapes 230 730 "$dark" && is shapes 221 701 "$white"'
check "Canvas draws an image"                     'is shapes 360 400 "$dark" && is shapes 360 385 "$white"'
check "custom GeometryEffect (shear)"             'is shapes 22 702 "r>130 && b>180 && g<120" && is shapes 22 738 "$white" && is shapes 42 738 "r>130 && b>180 && g<120"'
check "Core Graphics even-odd fill and line dash" 'is shapes 40 770 "$white" && is shapes 24 754 "r>230 && g<40" && is shapes 75 770 "$dark" && is shapes 85 770 "$white" && is shapes 95 770 "$dark"'
# share FILE WxH+X+Y 'fx predicate' 'awk condition on m': the fraction m of pixels in a region matching a predicate
share() { local m; m=$(magick $shots/$1.png -crop $2 -fx "$3" -format "%[fx:mean]" info: 2>/dev/null) || return 1; awk -v m="$m" "BEGIN { exit !($4) }"; }
check "Text with a gradient style uses its first color" 'share shapes 160x40+220+750 "r>0.8 && g<0.3 && b<0.3" "m > 0.04" && share shapes 160x40+220+750 "b>0.8 && r<0.3" "m == 0"'
check "Path API (description, bounds, contains, trim, CGPath, parse, arc)" 'grep -q "path description: 0 0 m 100 0 l 100 50 l h" <<<"$log" && grep -q "path bounds: (0.0, 0.0, 100.0, 50.0)" <<<"$log" && grep -q "path contains inside: true outside: false" <<<"$log" && grep -q "trimmed: 0 0 m 100 0 l 100 100 l" <<<"$log" && grep -q "from CGPath bounds: (0.0, 0.0, 20.0, 20.0)" <<<"$log" && grep -q "parsed: 0 0 m 10 0 l 10 10 l h" <<<"$log" && grep -q "arc end: 0,10" <<<"$log"'
check "KeyframeTimeline values, UnitCurve"       'grep -q "timeline duration 2.0 at 0.5: 5.0 at 1.5: true end: 0.0" <<<"$log" && grep -q "unit curve easeIn 0.5: true" <<<"$log"'
# animations: 2 s linear, screenshot ~1 s in
check "animated trim is half-way"                'is motion0 70 220 "$white" && is motion-mid 70 220 "r>130 && b>180 && g<120" && is motion-mid 70 121 "$white"'
check "custom Animatable shape interpolates"     'is motion-mid 200 140 "b>200 && r<60" && is motion-mid 356 140 "$white"'
check "shape color interpolates"                 'is motion0 170 215 "r>200 && b<60" && is motion-mid 170 215 "r>50 && r<210 && b>50 && b<210"'
check "gradient stops interpolate"               'is motion0 225 190 "b>200 && r<60" && is motion-mid 225 190 "r>60 && b<200"'
check "animations end at the new values"         'is motion-end 70 121 "r>130 && b>180 && g<120" && is motion-end 356 140 "b>200 && r<60" && is motion-end 170 215 "b>200 && r<60"'
check "AnimatableModifier interpolates"           'is motion0 40 520 "g>150 && r<120" && is motion-mid 40 520 "$white" && is motion-mid 140 520 "g>150 && r<120" && is motion-end 240 520 "g>150 && r<120" && is motion-end 140 520 "$white"'
check "TimelineView(.animation) updates per frame" 'grep -q "animation timeline 30 frames, live: true" <<<"$log"'
check "Canvas arc stroke"                       'is motion0 110 430 "r<60 && g<60 && b<60" && is motion0 98 402 "$white"'
ticks=$(grep -o "text=tick [0-9]*" <<<"$log" | sort -u | wc -l)
check "TimelineView(.periodic) re-renders"        '[ "$ticks" -ge 2 ]'
check "phaseAnimator cycles through phases"       '[ $(grep -c "^phase 0" <<<"$log") -ge 2 ] && grep -q "^phase 1" <<<"$log" && grep -q "^phase 2" <<<"$log"'
check "keyframeAnimator runs on trigger and ends" 'grep -q "bounce tapped" <<<"$log" && grep -q "^keyframe 30" <<<"$log" && grep -q "^keyframe 50" <<<"$log" && [ "$(grep "^keyframe" <<<"$log" | tail -1)" = "keyframe 0" ]'
check "exits cleanly"                             '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
