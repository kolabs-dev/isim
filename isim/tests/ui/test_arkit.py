"""ARKit (HelloAR): like Apple's Simulator, isim has no camera tracking. Every configuration's isSupported is false and
running one fails with ARError.unsupportedConfiguration, which reaches the session's delegate and the ARSCNView's /
ARSKView's delegates; no frames arrive. The app shows ARCoachingOverlayView over the (black) AR view. The value types
work: anchors (archived, copied), raycast queries (no results), reference images (validated), world maps (none).
SceneKit's scene graph (world positions, Euler angles, matrices, clone) and SCNView's render loop run underneath."""
import time

from isimtest import rgb

LINES = [
    "supported: world=false orientation=false face=false image=false body=false positional=false geo=false object scanning=false",
    "video formats 0 scene depth false mesh false faces 0",
    "geo availability false error 100",
    "session running: configuration true frame nil",
    "scene view session failed: com.apple.arkit.error 100 Unsupported configuration. unsupported true",
    "sprite view session failed: com.apple.arkit.error 100 Unsupported configuration. unsupported true",
    "scene graph: hand world 0.00 0.00 0.00 found true euler y 1.57",
    "matrices: translation 1.00 2.00 3.00 scale 2.00 inverse identity true",
    "clone: arm children 1 separate true",
    "removed: arm children 0 hand parent nil",
    "subclasses: label 1 tagged tag",            # selectors shared with superclass properties compile (#636)
    "anchor: marker z -1.00 archived true copy true",
    "raycast: results 0 tracked nil query from view nil",
    "reference image: poster physical 0.20x0.10 valid true group nil",
    "world map: nil error 302",
    "coaching will activate goal 1",
    "render loop: 10 updates, scene nodes 1",
]


def test_arkit(launch):
    app = launch("HelloAR")
    for line in LINES:
        app.wait_log(line.replace(".", r"\.").replace("(", r"\(").replace(")", r"\)"))
    log = app.log
    assert "frame?!" not in log, "no frames without tracking"
    assert log.count("scene view session failed") == 2, "the session's delegate and the view's delegate each get the error"
    assert "isim ARKit: ARWorldTrackingConfiguration is not supported on this device" in log
    tree = app.wait_view(r"text=AR is not available on this device")
    assert "id=coaching" in tree
    app.wait_still()
    img = app.screenshot("coaching")
    w, h = img.size
    assert all(c < 60 for c in rgb(img, 20, h - 40)), "the AR view shows black (no camera feed)"
    # the coaching overlay's instruction: white text in the middle of the screen
    white = sum(1 for x in range(40, w - 40, 2) for y in range(h // 2 - 40, h // 2 + 40, 2) if min(rgb(img, x, y)) > 200)
    assert white > 40, "the coaching overlay shows its instruction"
    assert app.quit() == 0
