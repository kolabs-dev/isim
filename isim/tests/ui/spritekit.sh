#!/usr/bin/env bash
# UI test: SpriteKit + GameplayKit + GameController (HelloSpriteKit sample) — a menu scene decoded from an .sks
# archive, a doorway transition, physics (gravity, ramp, contacts with sensors and boxes), particles from an .sks
# emitter and from code, a texture atlas, sounds, a camera HUD, a crop node, GKStateMachine, GKGridGraph pathfinding,
# seeded random sources, the hardware keyboard (GCKeyboard via keydown/keyup) and a GCVirtualController button.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSpriteKit; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/spritekit; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.5; shot $shots/menu.png; tap 201 477; wait 0.3; shot $shots/doorway.png; wait 1.3; shot $shots/game.png; keydown right; wait 0.2; keyup right; tap 310 794; wait 6; shot $shots/win.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSpriteKit.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
near() { python3 -c 'import sys; a=list(map(int,sys.argv[1].split())); b=list(map(int,sys.argv[2].split())); sys.exit(0 if all(abs(x-y)<=6 for x,y in zip(a,b)) else 1)' "$1" "$2"; }
check "scene decoded from Menu.sks (sceneDidLoad sees children)" 'grep -q "menu loaded from sks: title=Hello SpriteKit logo=true" <<<"$log"'
check "SpriteView: resizeFill size before didMove"  'grep -q "menu size 402x874" <<<"$log"'
check "doorway transition presents the game scene"  'grep -q "menu: play tapped -> doorway transition" <<<"$log" && grep -q "game size 402x874" <<<"$log"'
check "GKStateMachine ready -> playing -> won"      'grep -q "state ready" <<<"$log" && grep -q "state playing (from ReadyState)" <<<"$log" && grep -q "state won" <<<"$log"'
check "texture atlas (.atlas folder, @2x frames)"  'grep -q "atlas Hero: 4 textures hero_1.png,hero_2.png,hero_3.png,hero_4.png" <<<"$log" && grep -q "hero texture size 32x32" <<<"$log"'
check "GKGridGraph path around a wall"              'grep -q "path 16 nodes: (0,0) (1,0)" <<<"$log" && grep -q "hero reached the end of the path" <<<"$log"'
check "gravity moves the ball"                      'grep -Eq "ball after 1s: y=([0-9]+) \(start 581\) moving=true" <<<"$log" && [ "$(grep -Eo "ball after 1s: y=[0-9]+" <<<"$log" | grep -Eo "[0-9]+$")" -lt 560 ]'
check "contacts: sensor coins (passed through)"     'grep -q "contact ball-coin" <<<"$log" && grep -q "coin collected (3)" <<<"$log"'
check "contacts: ball hits the box"                 'grep -q "contact ball-box" <<<"$log"'
check "contacts: goal sensor"                       'grep -q "contact ball-goal" <<<"$log"'
lab=$(grep -Eo "lab: pendulum [0-9]+ \(60\) swung=[a-z]+ rope [0-9]+ \(<=32\) spring [0-9]+ speck [0-9]+" <<<"$log")
num() { grep -Eo "$1 [0-9]+" <<<"$lab" | grep -Eo "[0-9]+$"; }
check "pin joint keeps the pendulum length"         '[ -n "$lab" ] && [ "$(num pendulum)" -ge 57 ] && [ "$(num pendulum)" -le 63 ] && grep -q "swung=yes" <<<"$lab"'
check "limit joint (rope) holds"                    '[ -n "$lab" ] && [ "$(num rope)" -le 34 ]'
check "spring joint stretches under gravity"        '[ -n "$lab" ] && [ "$(num spring)" -gt 30 ] && [ "$(num spring)" -lt 80 ]'
check "radial gravity field pulls a body"           '[ -n "$lab" ] && [ "$(num speck)" -lt 40 ]'
check "emitter decoded from Spark.sks"             'grep -q "spark emitter from sks: birthRate=400 toEmit=80 texture=true colorSequence=3" <<<"$log"'
check "sounds found and decoded"                    '! grep -Eq "no sound file|cannot play" <<<"$log"'
check "GameplayKit random sources"                  'grep -q "mt19937 first 3499211612" <<<"$log" && grep -q "shuffled d6 covers 1...6: true" <<<"$log" && grep -q "arc4 reproducible: true" <<<"$log" && grep -q "shuffle keeps elements: true" <<<"$log"'
check "GCKeyboard: host key presses and releases"   'grep -q "keyboard connected" <<<"$log" && grep -q "key right down" <<<"$log" && grep -q "key right up" <<<"$log"'
check "GCVirtualController connects and its A button works" 'grep -q "controller connected: Virtual Controller extended=true" <<<"$log" && grep -q "virtual A pressed" <<<"$log" && grep -q "virtual A released" <<<"$log"'
check "push transition to the win scene"            'grep -q "presenting win scene (push)" <<<"$log" && grep -q "win scene shown, coins 3" <<<"$log"'
check "screenshots written"                         '[ -s $shots/menu.png ] && [ -s $shots/doorway.png ] && [ -s $shots/game.png ] && [ -s $shots/win.png ]'
check "menu: shape node fill color"                 'near "$(px $shots/menu.png 130 477)" "51 153 255"'
check "menu: scene background"                      'near "$(px $shots/menu.png 380 820)" "20 25 51"'
check "win: scene background"                       'near "$(px $shots/win.png 30 300)" "12 63 38"'
check "exits cleanly"                               '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; }
exit $fail
