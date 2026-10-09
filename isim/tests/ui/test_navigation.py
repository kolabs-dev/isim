"""UIKit containers (HelloNavigation): tab bar with badge, large title collapsing on scroll, push/pop, back button and
back swipe, toolbar items, hidesBottomBarWhenPushed, legacy toolbar images (setBackgroundImage / setShadowImage per
position and metrics, the delegate's position, UIAppearance), bar button menus, tab switching. Port of tests/ui/navigation.sh
with condition waits instead of fixed sleeps."""


import re

import pytest
from isimtest import screen_frames, rgb


def nav_bar_height(app):
    bars = [e for e in app.snapshot() if e.type == "navigationBar"]
    return round(bars[0].h) if bars else None


@pytest.mark.os_matrix
def test_navigation(launch, ios):
    if ios[0] == "17":
        pytest.skip("asserts the 402-pt screen, which no iOS 17.0 iPhone has")
    app = launch("HelloNavigation")
    app.wait_for(id="tab-Library")
    assert app.find(id="tab-Inbox"), "tab bar with items"
    assert app.find(id="bar-Sort"), "large title bar items"
    assert nav_bar_height(app) == 158, "large title"

    # Each drag ends with the finger held still, so it lifts with no velocity and the list moves by exactly the drag:
    # a fling's length depends on when the last touch moves are handled, and on a busy runner the first drag could
    # fling farther than the second, leaving the list short of the top (#100). 300 pt up collapses the title; 400 pt
    # down overshoots the top and springs back to rest exactly there.
    app.drag(200, 600, 200, 300, 0.4, hold=0.3)
    app.wait_until(lambda: nav_bar_height(app) == 106, what="large title collapses on scroll")
    app.drag(200, 300, 200, 700, 0.4, hold=0.3)
    app.wait_until(lambda: nav_bar_height(app) == 158, what="large title expands again")

    app.wait_for(id="book-3").tap()
    app.wait_log("detail 3 appears")
    app.wait_for(label="Details of book 3")
    # iOS 26 (#107): neighbouring toolbar items share one glass capsule; flexible spaces separate the groups
    tree = app.wait_view(r"id=bar-forward")
    f = screen_frames(tree)
    reply, fwd = f["bar-reply"], f["bar-forward"]
    capsules = [tuple(float(v) for v in m) for m in re.findall(r"__IsimBarGlass \(([\d.]+) ([\d.]+); ([\d.]+) x ([\d.]+)\)", tree)]
    if int(str(ios[0] or "18").split(".")[0]) >= 26:
        assert fwd[0] == reply[0] + reply[2], f"grouped items touch: {reply} {fwd}"
        assert any(abs(c[2] - (reply[2] + fwd[2])) < 0.5 and c[3] == 44 for c in capsules), f"one capsule under reply + forward: {capsules}"
        assert len(capsules) == 1, f"trash and Favorite keep their own glass: {capsules}"
    else:
        assert not capsules, "no glass before iOS 26"
    app.wait_for(id="bar-Favorite").tap()
    app.wait_log("favorite tapped")

    app.wait_for(id="read").tap()
    app.wait_log("reader appeared, tab bar hidden: true")
    app.wait_log(r"toolbars: clear 0\.0 shadow true, positions 1/2, top from appearance true, compact true/false")
    def yellow(c): return c[0] > 230 and c[1] > 180 and c[2] < 40
    def green(c): return c[1] > 160 and c[0] < 80 and c[2] < 120
    shot = app.wait_until(lambda: (lambda s: s if green(rgb(s, 300, 392)) else None)(app.screenshot("toolbars")),
                          what="toolbar images drawn")      # own image for the bottom position (no delegate: bottom)
    assert all(yellow(rgb(shot, 300, y)) for y in (300, 322, 343)), "empty background and shadow images: no bar, no hairline"
    assert all(green(rgb(shot, x, y)) for x, y in ((2, 392), (399, 392), (300, 372), (300, 413))), "a small image is tiled to the edges"
    assert (lambda c: c[0] > 230 and c[1] < 80 and c[2] < 80)(rgb(shot, 300, 462)), "the appearance's image for the top position"
    assert not (lambda c: c[2] > 200 and c[0] < 80)(rgb(shot, 300, 532)), "a compact-only image is not used in portrait"
    app.wait_for(id="nav-back").tap()
    app.wait_log("detail 3 appears", count=2)
    app.wait_for(id="nav-back").tap()
    app.wait_log("list appears", count=2)              # back button pops (twice)

    app.wait_for(id="book-5").tap()
    app.wait_log("detail 5 appears")
    app.wait_until(lambda: app.find(id="book-5") is None, what="push finished")   # before the edge swipe
    app.drag(3, 400, 330, 400, 0.4)
    app.wait_log("list appears", count=3)              # back swipe pops

    app.wait_for(id="bar-Sort").tap()
    app.wait_for(id="menu-Date").tap()
    app.wait_log("sort date")
    app.wait_for(id="tab-Inbox").tap()
    app.wait_log("inbox appeared")
    assert app.quit() == 0
