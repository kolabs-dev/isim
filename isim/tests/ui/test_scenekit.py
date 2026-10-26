"""SceneKit (HelloSceneKit, issue #330), drawn by isim's Metal on the CPU: SceneKit's shapes lit by ambient,
directional, omni and spot lights, a textured box spinning (SCNAction), a physically based sphere, a crystal from a
Wavefront OBJ file with its MTL materials, a ball falling onto the floor (physics and the contact delegate), a camera aimed
by a look-at constraint, a Core Animation animation on a node, hit tests, projection, SCNView.snapshot() and SCNRenderer,
and below them SwiftUI's SceneView and SpriteKit's SK3DNode showing a second scene. Checked by the log and by pixels: the
sky behind the scene, the box in the middle, the box turning, and the ring in SceneView and SK3DNode."""
from isimtest import near, rgb, screen_frames


def test_scenekit(launch):
    app = launch("HelloSceneKit")
    p = "scenekit "
    app.wait_log(p + r"obj nodes 1 materials Amethyst,Quartz")
    app.wait_log(p + r"action done")
    app.wait_log(p + r"contact ball floor")
    m = app.wait_log(p + r"project box (\d+),(\d+) in (\d+)x(\d+)")
    x, y, w, h = map(int, m.groups())
    assert abs(x - w / 2) <= 1 and abs(y - h / 2) <= 1, "the camera's look-at constraint centres the box"
    app.wait_log(p + r"hit box")
    app.wait_log(p + r"unproject 0\.00 0\.60 0\.00")
    app.wait_log(p + rf"snapshot {w * 3}x{h * 3}")                # the view's size at 3x
    app.wait_log(p + r"frustum box in")
    app.wait_log(p + r"renderer 64x48")
    app.wait_log(p + r"sk3d hit ring")
    app.wait_log(p + r"animation stop true")
    f = screen_frames(app.wait_view(r"id=sk3d\b"))
    sx, sy, sw, sh = f["scene"]
    sky = (140, 179, 230)                                         # the scene's background, UIColor(0.55, 0.7, 0.9)

    def drawn(s):
        return near(rgb(s, sx + 6, sy + 6), sky, 8) and not near(rgb(s, sx + sw / 2, sy + sh / 2), sky, 40)

    first = app.wait_shot(drawn, "the scene on its background")

    def orange(s, frame):
        x, y, w, h = frame
        return any(c[0] > 200 and 80 < c[1] < 190 and c[2] < 80
                   for c in (rgb(s, x + w * i / 12, y + h * j / 12) for i in range(1, 12) for j in range(1, 12)))

    assert orange(first, f["sceneview"]), "the ring in SwiftUI's SceneView"
    assert orange(first, f["sk3d"]), "the ring in SpriteKit's SK3DNode"
    probe = [(sx + sw / 2 + dx, sy + sh / 2 + dy) for dx in (-20, -10, 0, 10, 20) for dy in (-15, 0, 15)]
    before = [rgb(first, x, y) for x, y in probe]
    app.wait_shot(lambda s: [rgb(s, x, y) for x, y in probe] != before, "the box turning")
    assert app.quit() == 0
