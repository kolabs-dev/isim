#!/usr/bin/env bash
# UI test: source-compatibility patterns from real apps (HelloSourceCompat): Text(Image) inline symbols (in a view,
# in Text + Text, in a Canvas), Divider().overlay(Color) resolving to the ShapeStyle overload, Color / Bundle in
# nonisolated statics, Scene.onChange(of: scenePhase), .gesture(cond ? DragGesture() : nil),
# UIImpactFeedbackGenerator.impactOccurred(intensity:).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
app=out/apps/HelloSourceCompat.app
[ -x "$app/HelloSourceCompat" ] || { echo "SKIP  HelloSourceCompat not built"; exit 0; }
data=$PWD/out/test-data/sourcecompat; rm -rf "$data"; mkdir -p "$data"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
red() { read -r r g b <<<"$(px "$@")"; [ "$r" -gt 180 ] && [ "$g" -lt 90 ] && [ "$b" -lt 90 ]; }
log=$(ISIM_DATA=$data ISIM_STANDALONE=1 timeout 90 out/bin/isim run "$app" --device ${ISIM_TEST_DEVICE:-iphone16pro} --headless --script \
  "wait 2; dump; shot $data/s.png; drag 120 528 280 528 0.3; wait 0.5; tapid disable; wait 0.5; drag 120 528 280 528 0.3; wait 0.5; tapid haptic; wait 0.5; quit" 2>&1)
check "Scene.onChange(of: scenePhase, initial: true)" 'grep -q "^compat scene phase active" <<<"$log"'
check "Color and Bundle in nonisolated statics"       'grep -q "^compat statics true bundle=dev.isim.samples.HelloSourceCompat" <<<"$log"'
check "Text(Image): symbol drawn in the text colour"   'red "$data/s.png" 402 512'
check "Text(Image) + Text: one rich label"            'grep -q "id=favorites text= Favorites" <<<"$log"'
check "Canvas draws Text(Image)"                      'red "$data/s.png" 402 830'
check "Divider().overlay(Color) uses the colour"      'read -r r g b <<<"$(px "$data/s.png" 402 701)"; [ "$b" -gt "$r" ]'
check "gesture(cond ? DragGesture() : nil): enabled"  'grep -q "^compat drag 1" <<<"$log"'
check "gesture(nil) after disabling installs nothing" 'grep -q "^compat drag disabled" <<<"$log" && ! grep -q "^compat drag 2" <<<"$log"'
check "impactOccurred(intensity:)"                    'grep -q "^compat haptic" <<<"$log"'
[ $fail = 0 ] || grep -E "FATAL|crashed|error" <<<"$log" | head
exit $fail
