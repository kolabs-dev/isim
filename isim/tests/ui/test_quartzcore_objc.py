"""Core Animation and Core Video from Objective-C and C (HelloQuartzCoreObjC, issue #222): #import
<QuartzCore/QuartzCore.h> (CALayer and its subclasses, CATransform3D, CATransaction, CABasicAnimation, CADisplayLink)
and the CoreVideo C API (CVPixelBufferCreate / WithBytes / WithPlanarBytes, locking, plane getters, attachments, the
pool), linked with -framework QuartzCore -framework CoreVideo; CATiledLayer, CAFrameRateRange, display link frame rates
and view anchor points (issue #275)."""
import re

from isimtest import near, rgb


def test_quartzcore_objc(launch):
    app = launch("HelloQuartzCoreObjC")
    app.wait_log(r"^qc reported$")
    fails = re.findall(r"^qc FAIL .*$", app.log, re.M)
    assert not fails, "\n".join(fails)
    m = re.search(r"^qc summary (\d+)/(\d+)$", app.log, re.M)
    assert m and m[1] == m[2] and int(m[2]) >= 40, m and m[0]
    img = app.screenshot("quartzcore-objc")
    w = img.size[0]
    # the display link drew the ring to the end: amber all round (the 200 pt layer at y 160, its circle inset 10)
    for x, y in ((w / 2, 170), (w / 2, 350), (w / 2 - 90, 260), (w / 2 + 90, 260)):   # the stroke's centre line
        assert near(rgb(img, x, y), (255, 191, 51), 40), (x, y, rgb(img, x, y))
    # the pixel buffer filled from C: red grows to the right, green downwards, blue to the left (2x nearest)
    left, right = rgb(img, w / 2 - 52, 432), rgb(img, w / 2 + 52, 432)   # inside the rounded corners
    assert left[2] > 200 and left[0] < 40 and right[0] > 200 and right[2] < 40, (left, right)
    assert rgb(img, w / 2 - 52, 536)[1] > 200, rgb(img, w / 2 - 52, 536)
    # issue #275: the CATiledLayer's four 64 pt tiles, each its own colour (the layer at x w/2-128, y 580)
    for (x, y), c in (((-96, 612), (51, 204, 77)), ((-32, 612), (51, 128, 255)), ((-96, 676), (255, 77, 77)),
                      ((-32, 676), (255, 217, 51))):
        assert near(rgb(img, w / 2 + x, y), c, 40), ("tile", x, y, rgb(img, w / 2 + x, y))
    # a 60x30 view turned a quarter about its top-left anchor: it hangs to the left of its center (w/2+100, 590)
    assert near(rgb(img, w / 2 + 85, 640), (255, 0, 153), 40), rgb(img, w / 2 + 85, 640)
    assert not near(rgb(img, w / 2 + 130, 600), (255, 0, 153), 60), "not drawn about the center"
    m = re.search(r"^qc display links fast (\d+) slow (\d+)$", app.log, re.M)
    assert m and 10 <= int(m[2]) <= 20, m and m[0]
    # a link whose target only the link holds: retained (iOS), it fires until invalidated, then the target is freed (#648)
    assert re.search(r"^qc target-only link ticks 3 released 1$", app.log, re.M), app.log[-2000:]
    m = re.search(r"^qc slow link interval ([\d.]+)$", app.log, re.M)
    assert m and abs(float(m[1]) - 1 / 30) < 0.002, m and m[0]
