"""Xcode's iOS Game template (SpriteKit + GameplayKit) on scene files made by Xcode (HelloGameTemplate, issue #225):
GKScene(fileNamed:) on an Xcode-made GameScene.sks (the root node as the app's GameScene class, its size, anchor,
background, the label's text / font / colour / alignment, sceneDidLoad, entities and graphs), a GKScene built in code
(GKSKNodeComponent, addGraph / removeGraph), and SKAction(named:) on an Xcode-made Actions.sks."""
import re

from isimtest import rgb


def test_game_template(launch):
    app = launch("HelloGameTemplate")
    app.wait_log(r"^gt ready$")
    log = app.log
    assert "gt sceneDidLoad label=Hello, World! alpha=1.0" in log, "sceneDidLoad runs after the children are decoded"
    assert ("gt root class=GameScene size=750x1334 anchor=(0.5, 0.5) background=0.149,0.149,0.149,1.0 children=1") in log, \
        re.findall(r"^gt root .*$", log, re.M)
    assert ("gt label text=Hello, World! font=HelveticaNeue-UltraLight size=144 color=255,255,255,255 vertical=1 "
            "horizontal=0 position=(0.0, 0.0)") in log, re.findall(r"^gt label .*$", log, re.M)
    assert "gt gkscene entities=0 graphs=0 rootIsScene=true" in log
    assert "gt code entities=1 graphs=[\"grid\"] nodeEntity=true component=true" in log
    assert "gt code after-remove entities=0 graphs=0 copyRoot=true" in log
    # Actions.sks: "Pulse" is a group of two 0.3 s sequences (scale, fade)
    assert re.search(r"^gt pulse duration=0\.6\d* missing=true scaled=1\.2$", log, re.M), re.findall(r"^gt pulse .*$", log, re.M)

    # the label fades in over 2 s: white text on the template's dark grey, centred
    shot = app.wait_shot(lambda s: max(rgb(s, x, s.size[1] / 2)[0] for x in range(0, s.size[0], 2)) > 200,
                         "the faded-in Hello, World! label")
    w, h = shot.size
    assert rgb(shot, 5, 5)[0] < 60, "the scene's background"

    # a touch runs the Pulse action on the label (scale 0.6 relative, then back to 1)
    app.tap(w / 2, h / 2)
    app.wait_log(r"^gt touch label scale=1\.0$")
    app.tap(w / 2, h / 2 + 100)
    m = app.wait_log(r"^gt touch label scale=(\S+)$", count=2)
    assert 0.55 <= float(m[1]) <= 1.0, m[0]
    # the spinny shapes: copies of the template's SKShapeNode (NSCopying) keep its actions, spinning and fading out
    shot = app.screenshot("touched")
    assert any(rgb(shot, x, h / 2 + 100)[1] > 150 and rgb(shot, x, h / 2 + 100)[0] < 120 for x in range(int(w / 2) - 60, int(w / 2) + 60)), \
        "a green spinny shape where the screen was touched"
