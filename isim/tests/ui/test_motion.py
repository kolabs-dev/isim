"""Transitions and gestures (HelloMotion, UIKit): UIView.transition(with:) flips turn in 3D with perspective (mid-flip
the card is a trapezoid), curl up lifts the old page off its top edge, curl down lowers the new one, cross dissolve
blends; modal flip horizontal and partial curl (the lifted page stays up, the presented view below it works, a tap on
the page dismisses); failure requirements from a recognizer subclass (pan waits for a double tap) and from the
delegate (pan waits for a swipe); layer shadow and border color animate."""
import re

import pytest
from isimtest import rgb


def red(c): return c[0] > 200 and c[1] < 90 and c[2] < 90
def blue(c): return c[2] > 200 and c[0] < 60 and c[1] < 160
def card(c): return red(c) or blue(c)


def extent(img, y):
    xs = [x for x in range(0, img.size[0]) if card(rgb(img, x, y))]
    return (xs[0], xs[-1]) if xs else None


def column_height(img, x, y0=90, y1=330):
    ys = [y for y in range(y0, y1) if card(rgb(img, x, y))]
    return len(ys)


@pytest.mark.os_matrix
def test_view_transitions(launch, ios):
    app = launch("HelloMotion")
    app.wait_view(r"id=card")
    app.wait_still()

    app.tap_id("flip")                                                  # a 3D flip: mid-way the card is a trapezoid
    def trapezoid(img):
        e = extent(img, 210)
        if not e or e[1] - e[0] > 250 or e[1] - e[0] < 40: return False
        return abs(column_height(img, e[0] + 4) - column_height(img, e[1] - 4)) > 8
    mid = app.shot_during(trapezoid, None, what="a perspective frame of the flip")
    app.wait_log(r"transition flip done: Back")
    assert blue(rgb(app.screenshot("flipped"), 200, 210))

    app.wait_tap_id("curlUp")                                           # the old (blue) page lifts: red shows below
    up = app.shot_during(lambda s: red(rgb(s, 200, 295)) and blue(rgb(s, 200, 125)), None, what="the old page part-way up")
    app.wait_log(r"transition curlUp done: Front")
    app.wait_tap_id("curlDown")                                         # the new (blue) page comes down over red
    down = app.shot_during(lambda s: blue(rgb(s, 200, 125)) and red(rgb(s, 200, 295)), None, what="the new page part-way down")
    app.wait_log(r"transition curlDown done: Back")
    app.wait_tap_id("dissolve")                                         # blue to red through a blend
    app.shot_during(lambda s: (lambda c: c[0] > 80 and c[2] > 80)(rgb(s, 200, 210)), None, what="a blended frame")
    app.wait_log(r"transition dissolve done: Front")
    app.wait_tap_id("flipTop")                                          # a flip about the horizontal axis
    app.shot_during(lambda s: 20 < column_height(s, 200) < 180, None, what="the card turning about its horizontal axis")
    app.wait_log(r"transition flipTop done: Back")
    assert mid and up and down
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_modal_styles_and_gestures(launch, ios):
    app = launch("HelloMotion")
    app.wait_view(r"id=card")
    app.wait_tap_id("modalFlip")                                        # flip horizontal: presents and dismisses in 3D
    app.wait_log(r"presented modalFlip")
    app.wait_tap_id("done")
    app.wait_log(r"dismissed", count=1)
    app.wait_view(r"id=settings", gone=True)

    app.wait_tap_id("modalCurl")                                        # partial curl: the page stays lifted
    m = app.wait_log(r"partial curl up \((\d+) pt of the page left\)")
    left = int(m.group(1))
    assert 100 < left < 500, left
    app.wait_log(r"presented modalCurl")
    app.wait_still()
    curl = app.screenshot("partial-curl")
    teal = lambda c: c[1] > 150 and c[2] > 150 and c[0] < 120
    assert teal(rgb(curl, 200, 820)), "the presented view shows below the lifted page"
    assert not teal(rgb(curl, 200, 40)), "the lifted page covers the top"
    app.wait_tap_id("done")                                             # the presented view below is usable
    app.wait_log(r"dismissed", count=2)
    app.wait_tap_id("modalCurl")
    app.wait_log(r"partial curl up", count=2)
    app.wait_still()
    app.tap(200, 60)                                                    # a tap on the lifted page dismisses
    app.wait_log(r"partial curl tapped: dismissing")
    app.wait_view(r"id=settings", gone=True)

    pad = app.wait_for(id="pad")                                        # failure requirements
    cx, cy = pad.x + pad.w / 2, pad.y + pad.h / 2
    app.tap(cx, cy).tap(cx, cy)
    app.wait_log(r"^double tap")
    app.drag(pad.x + 20, cy, pad.x + 300, cy, 0.15)                    # a fast swipe right: the swipe wins
    app.wait_log(r"^swipe right")
    app.drag(cx, pad.y + 20, cx, pad.y + 120, 0.8)                     # a slow vertical drag: the others fail, pan goes
    app.wait_log(r"^pan ended ([6-9]\d|100)$")                          # measured from where it began (after the others failed)
    assert app.count(r"^pan began") == 1, "the pan waited for the double tap and the swipe"

    app.wait_tap_id("lift")                                             # layer shadow + border color animations
    m = app.wait_log(r"lift mid: opacity ([\d.]+) radius ([\d.]+) offset ([\d.]+)")
    op, rad, off = map(float, m.groups())
    assert 0.1 < op < 0.75 and 2 < rad < 19 and 1 < off < 11, m.group(0)
    app.wait_log(r"lift done: opacity 0.8 radius 20")
    shot = app.screenshot("lifted")
    assert rgb(shot, 200, 735)[0] < 235, "the shadow is drawn below the box"
    assert app.quit() == 0
