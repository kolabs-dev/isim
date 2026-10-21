"""ARKit and SceneKit from Objective-C (ARSceneObjCTest.app, issue #560): #import <ARKit/ARKit.h> and <SceneKit/SceneKit.h>
over the Swift overlays. SceneKit: the scene graph (names, parents, world positions, conversions, enumeration, clones),
node transforms through SCNVector3 / SCNMatrix4 and simd, the SCNMatrix4 C functions and NSValue's additions, and
SCNView's render loop calling an Objective-C SCNSceneRendererDelegate. ARKit: unsupported configurations (as in the
Simulator) and their settings, an anchor and a raycast query with simd values, a session whose run fails with
ARErrorCodeUnsupportedConfiguration through its Objective-C delegate, an ARSCNView whose delegate gets its session's
failure, and the coaching overlay."""
from isimtest import need_apps


def test_arkit_scenekit_objc(launch):
    need_apps("ARSceneObjCTest")
    app = launch("ARSceneObjCTest")
    p = "ARSceneObjC: "
    app.wait_log(p + r"graph found child parent parent world 3,2,3 back 1,0,0 nodes 3 hidden 1 clone parent children 1")
    app.wait_log(p + r"transform m41 1 m42 2 m43 3 m11 0\.0 m13 -2\.0 simd 1,0,0 euler y 1\.57")
    app.wait_log(p + r"scene paused 1 named nil")
    app.wait_log(p + r"matrix m11 2 m41 1 identity 1 inverse m41 -0\.5 rotation m12 1 m21 -1 equal 1 boxed 1 simd 2 zero 1")
    app.wait_log(p + r"configuration supported world 0 face 0 image 0 planes 3 alignment 1 light 0 focus 0 semantics 0")
    app.wait_log(p + r"anchor marker x 0\.5 z -1\.0 copy 1 query dir z -1 target 2 alignment 0")
    app.wait_log(p + r"ar view delegate 1 session 1 frame nil coaching goal 1")
    app.wait_log(p + r"session failed domain com\.apple\.arkit\.error code 100 unsupported 1")
    app.wait_log(p + r"view session failed domain com\.apple\.arkit\.error code 100 unsupported 1")
    app.wait_log(p + r"view playing 1 delegate 1 antialiasing 1 project 4,5,6")
    app.wait_log(p + r"render loop 5 frames scene time 1")
    app.wait_log(p + r"did render")
    assert app.quit() == 0
