"""HelloSpriteKit2: SKLabelNode.attributedText, SKTransformNode, SKWarpGeometryGrid (+ warp actions),
SKMutableTexture / SKTexture(data:), SKVideoNode, SKAction.reversed(), GKObstacleGraph, GKMeshGraph,
GKMinmaxStrategist, GKMonteCarloStrategist, GKDecisionTree (manual, ID3), GKQuadtree / GKOctree / GKRTree, and a host
gamepad: the `gamepad` script command attaches an SDL virtual joystick, which reaches the app through the same SDL
gamepad path as a physical pad (GCController connect / buttons / sticks / triggers / disconnect). A second run with
ISIM_GAMEPADS=0 proves host pads can be turned off. Port of tests/ui/spritekit2.sh and spritekit2_check.py (the
screenshots keep the script's timeline: the scene animates)."""
import re
import time

from isimtest import APPS, near, rgb

LINES = {   # check: log lines (all must be present)
    "attributed label: text from the attributed string": ["attributed label text=RED BLUE"],
    "SKTransformNode: euler angles, quaternion / matrix round trip":
        ["transform: euler (0.00, 1.05, 0.00) frame width 100 quaternion round trip true angle 0.96 m00 0.67"],
    "SKWarpGeometryGrid positions": ["warp grid 1x1 vertices 4 dest2 (0.35, 1.00)"],
    "SKAction.warp(to:) reaches the target": ["warp action finished: centre (0.80, 0.80)"],
    "SKAction.animate(withWarps:times:restore:)": ["animate(withWarps:) restored: true"],
    "SKMutableTexture.modifyPixelData buffer": ["mutable texture 64x64 bytes 16384"],
    "reversed(): forward state": ["forward done: x=150 rot=1.57 scale=2.00 alpha=0.50 size=60x50"],
    "reversed(): rules": ["reverse rules: moveTo itself true, easeIn -> easeOut, fadeIn reversed duration 0.30, "
                          "animate reversed true, group duration 0.50", "hide reversed unhides: true",
                          "fadeOut reversed -> alpha 1.00"],
    "GKObstacleGraph: buffered corners, custom node class":
        ["obstacle graph: corners 4 (90,90) (210,90) (210,210) (90,210) custom class true nodes 6"],
    "GKObstacleGraph: path around the obstacle":
        ["obstacle path: 4 nodes (50,150) (90,90) (210,90) (250,150) length 264 clear true",
         "start sees end directly false, start links 2"],
    "GKObstacleGraph: lockConnection survives a new obstacle":
        ["obstacle lock: locked true a->b kept true b->a kept false obstacles 2",
         "obstacle path after second obstacle: 4 nodes clear true"],
    "SKNode.obstacles(fromNodeBounds:)": ["obstacles from node bounds: 1 vertices 4 first (80,90)"],
    "GKMeshGraph centers+midpoints": ["mesh graph centers+midpoints: path found clear true"],
    "GKMinmaxStrategist: win, block, self-play draw":
        ["minmax: win move 2 value 16777215 block move 5", "minmax self-play: draw after 9 moves",
         "minmax randomMove(best 1): 2"],
    "GKMonteCarloStrategist: win and block": ["montecarlo: win move 2 block move 5"],
    "GKDecisionTree by hand": ["decision tree: hungry -> eat, tired -> sleep, rested -> play", "in range true"],
    "GKDecisionTree learned (ID3, categorical and numeric)":
        ["id3: root outlook accuracy 14/14 sunny+high -> no overcast -> yes rain+strong -> no",
         "id3 numeric: 10 -> cold 26 -> warm"],
    "GKQuadtree add / query / remove": ["quadtree: in (0,0)-(30,30) 9 remove true after 8 at point true remove via node true",
                                        "quadtree: area element found true"],
    "GKOctree add / query / remove": ["octree: 125 points, in (0..40)^3 64, remove true then 63"],
    "host gamepad connects as a GCController":
        ["gamepad connected: isim Test Pad category=MFi extended=true player=0 current=true"],
    "gamepad buttons, stick, dpad, trigger, menu":
        ["pad A pressed", "pad A released", "pad left stick x=1.00 y=0.00", "pad dpad up pressed yAxis=1.00",
         "pad dpad up released yAxis=0.00", "pad right trigger 1.00 pressed=true", "pad menu pressed (via valueChangedHandler)"],
    "gamepad disconnect notification": ["gamepad disconnected: isim Test Pad remaining 0"],
}

BG = (20, 23, 36)
def red(c): return c[0] > 180 and c[1] < 90 and c[2] < 90
def blue(c): return c[2] > 180 and c[0] < 120
def green(c): return c[1] > 180 and c[0] < 90 and c[2] < 120
def orange(c): return c[0] > 220 and 120 < c[1] < 180 and c[2] < 60


def bg(c, tol=40):
    return near(c, BG, tol)


def count(im, x0, x1, y0, y1, pred):
    px = im.load()
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(px[x, y][:3]))


def test_spritekit2(launch):
    app = launch("HelloSpriteKit2")
    t0 = time.monotonic()
    time.sleep(max(0.0, t0 + 1.0 - time.monotonic()))
    a = app.screenshot("a")
    app.send("gamepad connect isim Test Pad")
    app.wait_log(r"gamepad connected: ")
    app.send("gamepad button a 1")
    app.wait_log(r"pad A pressed")
    app.sleep(0.2)
    pressed = app.screenshot("pressed")
    app.send("gamepad button a 0").send("gamepad axis leftx 1")
    app.wait_log(r"pad left stick x=1\.00")
    app.send("gamepad axis leftx 0").send("gamepad button dpup 1")
    app.wait_log(r"pad dpad up pressed")
    app.send("gamepad button dpup 0").send("gamepad axis righttrigger 1")
    app.wait_log(r"pad right trigger 1\.00")
    app.send("gamepad button start 1")
    app.wait_log(r"pad menu pressed")
    app.send("gamepad disconnect")
    app.wait_log(r"gamepad disconnected: ")
    app.sleep(2)                                                          # the scene runs on (video, actions)
    b = app.screenshot("b")
    log = app.log
    missing = [(what, l) for what, lines in LINES.items() for l in lines if l not in log]
    assert not missing, f"missing: {missing}"
    assert re.search(r"mesh graph: triangles [0-9]+ inside obstacle 0 nodes [0-9]+ path [0-9]+ nodes clear true length ok true",
                     log), "GKMeshGraph: triangulation outside the obstacle, path"
    assert "reversed done: position back=true rot=-0.00 scale=1.00 alpha=1.00 size=40x40" in log or \
        "reversed done: position back=true rot=0.00 scale=1.00 alpha=1.00 size=40x40" in log, \
        "reversed(): sequence/group/repeat/move/rotate/scale/fade/resize undone"
    assert log.count("queries match brute force true") == 4, "GKRTree (4 split strategies) matches brute force"
    video = (APPS / "HelloSpriteKit2.app/clip.mp4").exists()
    if video:
        assert "video node playing 160x90" in log, "SKVideoNode plays"
    assert app.quit() == 0

    # pixels (one screenshot each)
    assert count(a, 90, 185, 90, 132, red) > 150 and count(a, 90, 185, 90, 132, blue) == 0, \
        "attributed label: red run on the left"
    assert count(a, 185, 320, 90, 132, blue) > 100 and count(a, 185, 320, 90, 132, red) == 0, \
        "attributed label: blue (kerned) run on the right"
    assert green(rgb(a, 100, 250)) and green(rgb(a, 100, 205)) and green(rgb(a, 120, 250)) and bg(rgb(a, 132, 250)) \
        and bg(rgb(a, 68, 250)), "SKTransformNode: y rotation halves the width"
    assert orange(rgb(a, 300, 250)) and orange(rgb(a, 245, 303)) and orange(rgb(a, 355, 303)) and orange(rgb(a, 300, 196)) \
        and bg(rgb(a, 246, 196)) and bg(rgb(a, 354, 196)), "warp geometry: trapezoid (top corners cut, bottom full)"
    assert blue(rgb(a, 100, 392)) and red(rgb(a, 100, 448)), "SKMutableTexture: first rows at the bottom (red), rest blue"
    assert near(rgb(a, 300, 545), (89, 89, 89), 20) and green(rgb(pressed, 300, 545)) \
        and near(rgb(b, 300, 545), (89, 89, 89), 20), "gamepad indicator gray, green while A is held"
    c = rgb(b, 60, 560)
    assert c[0] > 200 and c[1] > 180 and c[2] < 90 and bg(rgb(b, 180, 590)), "reversed actions: sprite back at its start"
    if video:
        assert red(rgb(a, 300, 420)) and red(rgb(pressed, 300, 420)) and green(rgb(b, 300, 420)) \
            and bg(rgb(a, 300, 470)), "SKVideoNode: first second red, last frame green"


def test_gamepads_off(launch):
    app = launch("HelloSpriteKit2", env={"ISIM_GAMEPADS": "0"})
    app.send("gamepad connect isim Test Pad")
    app.wait_log(r"host gamepads are disabled")
    app.sleep(0.5)                                                        # no connection may follow
    assert "gamepad connected" not in app.log, "ISIM_GAMEPADS=0 disables host pads"
    assert app.quit() == 0
