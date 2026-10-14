"""Core Animation and Core Video from Objective-C and C (HelloQuartzCoreObjC, issue #222): #import
<QuartzCore/QuartzCore.h> (CALayer and its subclasses, CATransform3D, CATransaction, CABasicAnimation, CADisplayLink)
and the CoreVideo C API (CVPixelBufferCreate / WithBytes / WithPlanarBytes, locking, plane getters, attachments, the
pool), linked with -framework QuartzCore -framework CoreVideo."""
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
