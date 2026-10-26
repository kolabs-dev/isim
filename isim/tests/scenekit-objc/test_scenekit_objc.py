"""SceneKit's renderer from Objective-C (SceneKitObjCTest.app, issue #330): #import <SceneKit/SceneKit.h> over the Swift
overlay. Geometry from the class factories (a box's six elements, its bounding box) and from sources and an element,
materials (lighting model names, double-sided), lights and a camera with a look-at constraint, actions with SCNVector3
arguments and completion handlers, physics with gravity, velocity and an Objective-C contact delegate, hitTest:options:
with SCNHitTestResult's coordinates, a node's segment hit test, and SCNRenderer drawing into an image."""
from isimtest import near, need_apps, rgb, screen_frames


def test_scenekit_objc(launch):
    need_apps("SceneKitObjCTest")
    app = launch("SceneKitObjCTest")
    p = "SceneKitObjC: "
    app.wait_log(p + r"box elements 6 sources 3 bounds 1 -0\.5\.\.0\.5 model SCNLightingModelLambert double 1")
    app.wait_log(p + r"triangle semantic kGeometrySourceSemanticVertex vectors 3 float 1 primitives 1")
    app.wait_log(p + r"light omni camera fov 50 near 1")
    app.wait_log(p + r"physics gravity -12 velocity 1 dynamic 1")
    app.wait_log(p + r"actions spin,move has 1")
    app.wait_log(p + r"hit box face 0 world z 0\.5 normal z 1")
    app.wait_log(p + r"segment hits 1")
    app.wait_log(p + r"renderer 40x30 device 1")
    app.wait_log(p + r"action done z -4\.0")
    app.wait_log(p + r"contact ball floor normal 1")
    x, y, w, h = screen_frames(app.wait_view(r"id=scene\b"))["scene"]
    shot = app.wait_shot(lambda s: rgb(s, x + w / 2, y + h * 0.55)[0] > 200 and rgb(s, x + w / 2, y + h * 0.55)[1] < 60,
                         "the red box in the middle of the view")
    assert near(rgb(shot, x + 4, y + 4), (51, 51, 77), 8), "the scene's background colour"
    assert app.quit() == 0
