#!/usr/bin/env bash
# UI test: HelloSpriteKit2 — SKLabelNode.attributedText, SKTransformNode, SKWarpGeometryGrid (+ warp actions),
# SKMutableTexture / SKTexture(data:), SKVideoNode, SKAction.reversed(), GKObstacleGraph, GKMeshGraph,
# GKMinmaxStrategist, GKMonteCarloStrategist, GKDecisionTree (manual, ID3), GKQuadtree / GKOctree / GKRTree, and a
# host gamepad: the `gamepad` script command attaches an SDL virtual joystick, which reaches the app through the
# same SDL gamepad path as a physical pad (GCController connect / buttons / sticks / triggers / disconnect).
# A second run with ISIM_GAMEPADS=0 proves host pads can be turned off.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSpriteKit2; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/spritekit2; rm -rf "$ISIM_DATA"
pad="gamepad connect isim Test Pad; wait 0.3; gamepad button a 1; wait 0.2; shot $shots/pressed.png; gamepad button a 0; gamepad axis leftx 1; wait 0.2; gamepad axis leftx 0; gamepad button dpup 1; wait 0.1; gamepad button dpup 0; gamepad axis righttrigger 1; wait 0.1; gamepad button start 1; wait 0.1; gamepad disconnect"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.0; shot $shots/a.png; $pad; wait 2; shot $shots/b.png; quit" \
      timeout 120 out/bin/isim run out/apps/HelloSpriteKit2.app 2>&1); rc=$?
log0=$(ISIM_GAMEPADS=0 ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.5; gamepad connect isim Test Pad; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSpriteKit2.app 2>&1); rc0=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF -- "$1" <<<"$log"; }
check "attributed label: text from the attributed string"  'has "attributed label text=RED BLUE"'
check "SKTransformNode: euler angles, quaternion / matrix round trip" 'has "transform: euler (0.00, 1.05, 0.00) frame width 100 quaternion round trip true angle 0.96 m00 0.67"'
check "SKWarpGeometryGrid positions"                       'has "warp grid 1x1 vertices 4 dest2 (0.35, 1.00)"'
check "SKAction.warp(to:) reaches the target"              'has "warp action finished: centre (0.80, 0.80)"'
check "SKAction.animate(withWarps:times:restore:)"         'has "animate(withWarps:) restored: true"'
check "SKMutableTexture.modifyPixelData buffer"            'has "mutable texture 64x64 bytes 16384"'
check "reversed(): forward state"                          'has "forward done: x=150 rot=1.57 scale=2.00 alpha=0.50 size=60x50"'
check "reversed(): sequence/group/repeat/move/rotate/scale/fade/resize undone" '{ has "reversed done: position back=true rot=-0.00 scale=1.00 alpha=1.00 size=40x40" || has "reversed done: position back=true rot=0.00 scale=1.00 alpha=1.00 size=40x40"; }'
check "reversed(): rules (moveTo itself, easeIn->easeOut, fadeIn<->fadeOut, animate, group)" 'has "reverse rules: moveTo itself true, easeIn -> easeOut, fadeIn reversed duration 0.30, animate reversed true, group duration 0.50" && has "hide reversed unhides: true" && has "fadeOut reversed -> alpha 1.00"'
check "GKObstacleGraph: buffered corners, custom node class" 'has "obstacle graph: corners 4 (90,90) (210,90) (210,210) (90,210) custom class true nodes 6"'
check "GKObstacleGraph: path around the obstacle"           'has "obstacle path: 4 nodes (50,150) (90,90) (210,90) (250,150) length 264 clear true" && has "start sees end directly false, start links 2"'
check "GKObstacleGraph: lockConnection survives a new obstacle" 'has "obstacle lock: locked true a->b kept true b->a kept false obstacles 2" && has "obstacle path after second obstacle: 4 nodes clear true"'
check "SKNode.obstacles(fromNodeBounds:)"                   'has "obstacles from node bounds: 1 vertices 4 first (80,90)"'
check "GKMeshGraph: triangulation outside the obstacle, path" 'grep -Eq "mesh graph: triangles [0-9]+ inside obstacle 0 nodes [0-9]+ path [0-9]+ nodes clear true length ok true" <<<"$log" && has "mesh graph centers+midpoints: path found clear true"'
check "GKMinmaxStrategist: win, block, self-play draw"      'has "minmax: win move 2 value 16777215 block move 5" && has "minmax self-play: draw after 9 moves" && has "minmax randomMove(best 1): 2"'
check "GKMonteCarloStrategist: win and block"               'has "montecarlo: win move 2 block move 5"'
check "GKDecisionTree by hand (value, predicate, weight branches)" 'has "decision tree: hungry -> eat, tired -> sleep, rested -> play" && has "in range true"'
check "GKDecisionTree learned (ID3, categorical and numeric)" 'has "id3: root outlook accuracy 14/14 sunny+high -> no overcast -> yes rain+strong -> no" && has "id3 numeric: 10 -> cold 26 -> warm"'
check "GKQuadtree add / query / remove"                     'has "quadtree: in (0,0)-(30,30) 9 remove true after 8 at point true remove via node true" && has "quadtree: area element found true"'
check "GKOctree add / query / remove"                       'has "octree: 125 points, in (0..40)^3 64, remove true then 63"'
check "GKRTree (4 split strategies) matches brute force"    '[ "$(grep -c "queries match brute force true" <<<"$log")" = 4 ]'
check "host gamepad connects as a GCController"           'has "gamepad connected: isim Test Pad category=MFi extended=true player=0 current=true"'
check "gamepad buttons, stick, dpad, trigger, menu"        'has "pad A pressed" && has "pad A released" && has "pad left stick x=1.00 y=0.00" && has "pad dpad up pressed yAxis=1.00" && has "pad dpad up released yAxis=0.00" && has "pad right trigger 1.00 pressed=true" && has "pad menu pressed (via valueChangedHandler)"'
check "gamepad disconnect notification"                    'has "gamepad disconnected: isim Test Pad remaining 0"'
check "ISIM_GAMEPADS=0 disables host pads"                 'grep -q "host gamepads are disabled" <<<"$log0" && ! grep -q "gamepad connected" <<<"$log0" && [ $rc0 = 0 ]'
video=0; [ -f out/apps/HelloSpriteKit2.app/clip.mp4 ] && video=1
[ $video = 1 ] && check "SKVideoNode plays" 'has "video node playing 160x90"'
python3 tests/ui/spritekit2_check.py "$shots" $video || fail=1
check "exits cleanly"                                      '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | tail -60; }
exit $fail
