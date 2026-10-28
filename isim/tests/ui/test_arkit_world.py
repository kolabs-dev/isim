"""World tracking on isim's simulated AR device (HelloAR -world, ISIM_AR_SCENE=room; issue #391): the session runs,
initializes and tracks; the room's planes become ARPlaneAnchors with their classes as the `ar` script command turns
the device; the captured image is the room in YCbCr 4:2:0 and ARSCNView draws it behind the plane overlays; a tap
raycasts onto the table and places a box; a tracked raycast follows the view's centre; the mapped room is saved as an
ARWorldMap, archived, and a new session relocalizes from it and brings the anchors back."""
from isimtest import rgb


def test_arkit_world(launch):
    app = launch("HelloAR", args=["-world"], env={"ISIM_AR_SCENE": "room"})

    def has(p):
        return app.wait_log(f"HelloARWorld: {p}")

    has(r"supported world true positional true face false formats 640x480@30 classification true")
    has(r"tracking limited\(initializing\)")
    has(r"tracking normal")
    # looking ahead: the table and the back wall, found at half their size first
    has(r"plane added table horizontal at 0\.00 -0\.65 -1\.50 extent 0\.60x0\.40 vertices 4")
    has(r"plane added wall vertical at 0\.00 -0\.10 -3\.50 extent 2\.00x1\.30")
    has(r"frame image 640x480 420f true points [1-9]\d* light 1000 camera 0\.00 0\.00 0\.00 width-axis-up true")
    has(r"mapping extending")
    m = has(r"table on screen at (\d+) (\d+)")
    x, y = int(m.group(1)), int(m.group(2))
    assert 150 < x < 250 and 600 < y < 800, "the table projects below the centre of the portrait view"

    # the camera feed: the back wall's light grey above the horizon, the floor's brown at the bottom
    shot = app.wait_shot(lambda s: min(rgb(s, s.size[0] // 2, s.size[1] // 3)) > 150, "the room behind the AR view")
    w, h = shot.size
    r, g, b = rgb(shot, w // 2, h - 60)
    assert r > g > b and r > 80, f"the floor is brown at the bottom: {(r, g, b)}"

    # a tap on the table: a raycast hits its geometry, a box is placed there
    app.tap(x, y)
    has(r"tap hit table at 0\.00 -0\.65 -1\.50 results 1")
    has(r"anchor added box")
    has(r"box node at 0\.00 -0\.65 -1\.50 in the scene true children 1")
    has(r"tracked raycast 1 at 0\.00 0\.00 -3\.50 estimated true")
    # the box: orange above the table's centre
    shot = app.wait_shot(lambda s: (lambda c: c[0] > 180 and c[1] < 170 and c[2] < 100)(rgb(s, x, y - 30)), "the orange box on the table")
    app.screenshot("box")

    # the device turns (the ar script command): down to the floor, to both walls, up to the ceiling
    app.send("ar pose 0 0 0 0 -45")
    app.wait_log(r"isim ARKit: camera at 0\.00 0\.00 0\.00 yaw 0 pitch -45")
    has(r"plane added floor horizontal at 0\.00 -1\.40 -1\.00")
    has(r"floor grew to 4\.00x5\.00")
    app.send("ar pose 0 0 0 70 0")
    has(r"plane added wall vertical at -2\.00 -0\.10 -1\.00")
    app.send("ar pose 0 0 0 -70 0")
    has(r"plane added wall vertical at 2\.00 -0\.10 -1\.00")
    app.send("ar pose 0 0 0 0 60")
    has(r"plane added ceiling horizontal at 0\.00 1\.20 -1\.00")
    has(r"mapping mapped")

    # the world map, archived, and a new session that relocalizes from it
    has(r"world map anchors 7 planes 6 box true extent 4\.00x2\.60x5\.00 points [1-9]\d* classes ceiling,floor,table,wall")
    has(r"tracking limited\(relocalizing\)")
    app.wait_log(r"HelloARWorld: tracking normal", count=3)
    has(r"anchor added box \(from the world map\)")
    log = app.log
    assert "failed" not in log.split("HelloARWorld: supported", 1)[1], "no session error"
    assert app.quit() == 0
