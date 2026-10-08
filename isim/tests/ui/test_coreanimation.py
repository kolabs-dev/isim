"""Core Animation, UIKit Dynamics and CoreHaptics (HelloCoreAnimation): CAShapeLayer strokeEnd paused half-way,
CAGradientLayer, CAReplicatorLayer, perspective CATransform3D (a layer and a view drawn as trapezoids), layer and view
masks, blurred shadow falloff, CAKeyframeAnimation positions at given times, CATransaction implicit animation +
completion + disableActions, CA animations on a view's layer with delegates, CASpringAnimation / CAAnimationGroup, an
item falling under gravity onto a collision boundary, and CoreHaptics (no hardware). Port of
tests/ui/coreanimation.sh."""
from isimtest import rgb

RED = lambda c: c[0] > 200 and c[1] < 60 and c[2] < 60                      # noqa: E731
WHITE = lambda c: c[0] > 235 and c[1] > 235 and c[2] > 235                  # noqa: E731
GREEN = lambda c: c[1] > 150 and c[0] < 60 and c[2] < 60                    # noqa: E731
ORANGE = lambda c: c[0] > 230 and 120 < c[1] < 200 and c[2] < 60           # noqa: E731
BLUE = lambda c: c[2] > 200 and c[0] < 60 and c[1] < 60                     # noqa: E731


def extent(img, x, y0, y1, pred):
    """Pixel rows in column x between y0 and y1 whose colour matches pred."""
    return sum(1 for y in range(y0, y1) if pred(rgb(img, x, y)))


def runs(img, y, x0, x1, pred):
    """Separate runs of matching pixels along row y between x0 and x1."""
    n, inside = 0, False
    for x in range(x0, x1):
        m = pred(rgb(img, x, y))
        n += m and not inside
        inside = m
    return n


def test_coreanimation(launch):
    app = launch("HelloCoreAnimation")
    main = app.wait_shot(lambda s: RED(rgb(s, 195, 100)) and runs(s, 200, 10, 395, GREEN) == 5, "layers drawn")
    app.tap_id("btn-Report")
    app.wait_log(r"keyframe keys=")
    app.tap_id("btn-Tx")
    app.wait_log(r"transaction complete")
    app.wait_log(r"disableActions radius=")
    app.tap_id("btn-Anim")
    app.wait_log(r"spin didStop")
    app.wait_log(r"group didStop")
    app.tap_id("btn-Drop")
    app.wait_log(r"dynamics rest", timeout=15)
    drop = app.screenshot()
    app.tap_id("btn-Haptic")
    app.wait_log(r"haptics players finished")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    assert all(RED(rgb(main, x, 100)) for x in (100, 195)) and all(WHITE(rgb(main, x, 100)) for x in (210, 370)), \
        "shape strokeEnd paused at 50%: stroked to the midpoint"
    assert "stroke presentation strokeEnd=0.50 model=1.00" in log, "presentation strokeEnd half-way, model untouched"
    l, m, r = rgb(main, 24, 150), rgb(main, 200, 150), rgb(main, 376, 150)
    assert l[0] > 220 and l[2] < 40 and r[2] > 220 and r[0] < 40 and 90 < m[0] < 170 and 90 < m[2] < 170, \
        "axial gradient red -> blue"
    assert runs(main, 200, 10, 395, GREEN) == 5 and GREEN(rgb(main, 270, 200)) and WHITE(rgb(main, 300, 200)), \
        "replicator draws 5 copies 60 pt apart"
    ol, orr = extent(main, 60, 200, 400, ORANGE), extent(main, 144, 200, 400, ORANGE)
    assert ol > 0 and orr > 0 and ol - orr > 25, f"perspective layer is a trapezoid (near edge taller: {ol} vs {orr})"
    bl, br = extent(main, 284, 200, 400, BLUE), extent(main, 344, 200, 400, BLUE)
    assert bl > 0 and br > 0 and br - bl > 15, f"view transform3D drawn in perspective ({bl} vs {br})"
    assert RED(rgb(main, 70, 430)) and WHITE(rgb(main, 24, 384)) and WHITE(rgb(main, 116, 476)), \
        "layer mask (circle) clips the red view"
    assert GREEN(rgb(main, 160, 430)) and WHITE(rgb(main, 220, 430)), "view mask shows only its left half"
    assert 40 < rgb(main, 320, 465)[0] < 200 and rgb(main, 320, 492)[0] > 225 and WHITE(rgb(main, 320, 425)), \
        "blurred shadow falls off below the card"
    assert all(s in log for s in ("keyframe t=0.25 x=120 y=520", "keyframe t=0.5 x=200 y=520",
                                  "keyframe t=1.25 x=200 y=560")), "keyframe values/keyTimes at t=0.25 0.5 1.25"
    assert "keyframe t=2.5 x=200 y=600" in log and 'keyframe keys=["path"] model x=40' in log, \
        "keyframe fillMode forwards holds the end value"
    assert "emitter particles>0 true" in log, "emitter spawns particles"
    assert "transform3D concat identity true affine true" in log, "CATransform3D concat/invert/isAffine"
    assert "implicit mid opacity between true" in log, "implicit animation in a CATransaction (mid value)"
    assert "transaction complete opacity=0.20 presentation=0.20" in log, \
        "CATransaction completion block after the animation"
    assert "disableActions radius=20 cornerRadius animated=false" in log, "setDisableActions: no implicit animation"
    assert "spin mid rotation between true model=0.00" in log, "CA animation on a view layer (rotation mid-way)"
    assert "spin didStart" in log and "spin didStop finished=true" in log, "animation delegate start/stop"
    assert "spring settlingDuration>0.3 true" in log and "spring didStop finished=true" in log and \
        "group didStop finished=true" in log, "CASpringAnimation and CAAnimationGroup finish"
    assert "dynamics falling y>600 true running=true" in log, "dynamics: the item falls"
    c = rgb(drop, 200, 770)
    assert "dynamics rest maxY=780 x=180" in log and c[0] > 220 and c[1] < 120, \
        "dynamics: rests on the collision boundary"
    assert "haptics supportsHaptics=false" in log and "haptics pattern duration=0.40" in log and \
        "CoreHaptics: pattern started: 2 event" in log and "haptics players finished" in log, \
        "CoreHaptics: no haptic hardware, pattern plays out"
