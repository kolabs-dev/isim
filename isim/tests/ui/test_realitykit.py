"""RealityKit without AR (HelloRealityKit, issue #331), drawn by isim's SceneKit renderer (Metal on the CPU): a SwiftUI
RealityView with a box spun by a custom System and Component, a PhysicallyBasedMaterial sphere moved by
move(to:duration:) (AnimationEvents.PlaybackCompleted), a mesh from a MeshDescriptor with an UnlitMaterial, a crystal
loaded from a Wavefront OBJ file by Entity.load(named:), a ball falling onto the floor (PhysicsBodyComponent,
CollisionComponent, CollisionEvents.Began), directional and point lights and a perspective camera; and a non-AR ARView
with entity(at:) and project(_:). Checked by the log and by pixels: SwiftUI's background behind the transparent
RealityView, the box drawn in the middle and turning, and the ARView's box on its background colour."""
from isimtest import near, rgb, screen_frames


def test_realitykit(launch):
    app = launch("HelloRealityKit")
    p = "realitykit "
    app.wait_log(p + r"arview anchors 1 mode nonAR true")
    app.wait_log(p + r"mesh bounds 0\.6")
    app.wait_log(p + r"loaded crystal children 1 model true")
    app.wait_log(p + r"content entities 9 box bounds 0\.50 found true")
    app.wait_log(p + r"system frames 5")
    m = app.wait_log(p + r"arview entity target project (\d+),(\d+)")
    app.wait_log(p + r"collision ball floor")
    app.wait_log(p + r"animation done sphere y 0\.6")
    f = screen_frames(app.wait_view(r"id=arview\b"))
    x, y, w, h = f["reality"]
    ax, ay, aw, ah = f["arview"]
    assert (int(m.group(1)), int(m.group(2))) == (int(aw / 2), int(ah / 2)), "the origin projects to the ARView's centre"
    sky = (140, 179, 230)                                          # SwiftUI's background, behind the RealityView

    def drawn(s):
        return near(rgb(s, x + 6, y + 6), sky, 8) and not near(rgb(s, x + w / 2, y + h * 0.5), sky, 40)

    first = app.wait_shot(drawn, "the RealityView's entities over SwiftUI's background")
    assert near(rgb(first, ax + 4, ay + 4), (31, 31, 41), 8), "the ARView's background colour"
    c = rgb(first, ax + aw / 2, ay + ah / 2)
    assert c[0] > 180 and c[2] < 80, f"the ARView's orange box at its centre: {c}"
    probe = [(x + w / 2 + dx, y + h * 0.5 + dy) for dx in (-15, -5, 5, 15) for dy in (-15, 0, 15)]
    before = [rgb(first, px, py) for px, py in probe]
    app.wait_shot(lambda s: [rgb(s, px, py) for px, py in probe] != before, "the box spun by its system")
    assert app.quit() == 0
