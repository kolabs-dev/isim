"""Collection view layouts and lists (HelloCollectionLayouts, UIKit): outlines (section snapshots, outline disclosure
expand/collapse with the handlers), list swipe actions (trailing Delete, leading Pin), reordering (reorder accessory +
reorderingHandlers), a custom UIContentConfiguration updated for the selected state, async apply; compositional
section backgrounds (decoration items), a custom group, visibleItemsInvalidationHandler (a scaling carousel),
prefetching; a horizontally scrolling compositional layout; a custom flow layout's decoration views."""
import re

import pytest
from isimtest import rgb


def frame(dump, ident):
    m = re.search(rf"\((-?[\d.]+) (-?[\d.]+); ([\d.]+) x ([\d.]+)\).* id={re.escape(ident)}\b", dump)
    assert m, f"no {ident} in the view tree"
    return tuple(float(v) for v in m.groups())


@pytest.mark.os_matrix
def test_outline_list(launch, ios):
    app = launch("HelloCollectionLayouts")
    app.wait_tap_id("demo-outline")
    app.wait_log(r"outline: 5 visible of 7, level of Lemon 1")
    app.wait_log(r"async apply finished")
    app.wait_view(r"id=fruit-Lemon")
    tree = app.view_dump()
    assert "id=fruit-Strawberry" not in tree, "Berries is collapsed"
    assert frame(tree, "fruit-Lemon")[0] == frame(tree, "group-Citrus")[0], "rows share the list's column"

    app.wait_tap_id("group-Berries")                                    # selecting a group row does not expand it
    app.wait_view(r"id=group-Berries")
    berries = app.wait_for(id="group-Berries")
    app.tap(berries.x + berries.w - 16, berries.y + berries.h / 2)      # the outline disclosure
    app.wait_log(r"will expand group\(\"Berries\"\)")
    app.wait_view(r"id=fruit-Strawberry")
    citrus = app.wait_for(id="group-Citrus")
    app.tap(citrus.x + citrus.w - 16, citrus.y + citrus.h / 2)
    app.wait_log(r"will collapse group\(\"Citrus\"\)")
    app.wait_view(r"id=fruit-Lemon", gone=True)
    app.wait_still()
    app.screenshot("outline")

    straw = app.wait_for(id="fruit-Strawberry")                         # swipe actions
    app.drag(straw.x + straw.w - 40, straw.y + straw.h / 2, straw.x + straw.w - 160, straw.y + straw.h / 2, 0.4)   # a partial swipe reveals
    app.wait_view(r"id=swipe-Delete")
    app.wait_still()
    app.screenshot("swipe")
    app.wait_tap_id("swipe-Delete")
    app.wait_log(r"deleted Strawberry")
    app.wait_view(r"id=fruit-Strawberry", gone=True)
    blue = app.wait_for(id="fruit-Blueberry")
    app.drag(blue.x + 40, blue.y + blue.h / 2, blue.x + 150, blue.y + blue.h / 2, 0.4)
    app.wait_tap_id("swipe-Pin")
    app.wait_log(r"pinned Blueberry")

    app.wait_tap_id("group-Citrus")                                     # expand again, then reorder in editing mode
    citrus = app.wait_for(id="group-Citrus")
    app.tap(citrus.x + citrus.w - 16, citrus.y + citrus.h / 2)
    app.wait_view(r"id=fruit-Lime")
    app.wait_tap_id("edit")
    app.wait_log(r"editing true")
    app.wait_view(r"id=accessory-reorder")
    app.wait_still()
    lime, lemon = app.wait_for(id="fruit-Lime"), app.wait_for(id="fruit-Lemon")
    gx = lime.x + lime.w - 20
    app.drag(gx, lime.y + lime.h / 2, gx, lemon.y + lemon.h / 2 - 4, 0.6)
    app.wait_log(r"reordered: Lime,Lemon,Orange,Blueberry")

    badge = app.wait_for(id="badgecell-New")                            # a custom content configuration
    assert app.has(r"badge: New$") and app.has(r"badge: Sale$")
    app.wait_tap_id("edit")
    app.wait_log(r"editing false")
    badge.tap()
    app.wait_log(r"badge: New ✓")                                        # updated(for:) the selected state
    app.wait_log(r"update handler New selected true")                    # configurationUpdateHandler
    app.wait_view(r"id=badge-New ✓")
    shot = app.wait_shot(lambda s: rgb(s, badge.x + 40, badge.y + badge.h / 2)[2] > 200, what="the selected badge is blue")
    assert shot
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_compositional_extras(launch, ios):
    app = launch("HelloCollectionLayouts")
    app.wait_tap_id("demo-gallery")
    app.wait_view(r"id=tile-1-0")
    app.wait_log(r"prefetch 1-\d+")                                     # items below the screen, before they show
    tree = app.view_dump()
    assert "id=section-background" in tree, "the section background decoration view"
    bg = frame(tree, "section-background")
    t0, t1, t2 = frame(tree, "tile-1-0"), frame(tree, "tile-1-1"), frame(tree, "tile-1-2")
    assert t1[1] - t0[1] == 20 and t2[1] - t1[1] == 20, "the custom group's staggered frames"
    assert bg[0] < t0[0] and bg[1] < t0[1], "the background sits behind the section's items"
    first, third = frame(tree, "tile-0-0"), frame(tree, "tile-0-2")
    app.wait_still()
    app.screenshot("gallery")
    scales = lambda m: [float(x) for x in m.group(1).split(",")]
    before = scales(app.wait_log(r"carousel offset 0: scales ([\d.,]+)"))
    assert before[1] > before[2], f"visibleItemsInvalidationHandler scales items away from the center ({before})"
    app.drag(300, 160, 60, 160, 0.4)                                    # the carousel scrolls: scales follow
    app.wait_still()
    app.wait_log(r"carousel offset [1-9]\d*: scales")
    moved = re.findall(r"carousel offset [1-9]\d*: scales ([\d.,]+)", app.log)
    after = [float(x) for x in moved[-1].split(",")]
    assert after[2] > before[2], f"after scrolling, the item nearer the center grew ({before} -> {after})"
    app.drag(200, 700, 200, 250, 0.4)                                   # scrolling down prefetches further
    app.wait_log(r"prefetch 1-\d+", count=2)
    assert first and third

    app.send("tapid nav-back")
    app.wait_tap_id("demo-horizontal")
    app.wait_log(r"horizontal content (\d+)x(\d+)")
    w, h = map(int, re.search(r"horizontal content (\d+)x(\d+)", app.log).groups())
    assert w > 1000 and h <= 320, "a horizontal compositional layout scrolls sideways"
    tree = app.wait_view(r"id=h-0-1")
    a, b, c = frame(tree, "h-0-0"), frame(tree, "h-0-1"), frame(tree, "h-0-2")
    assert a[0] == b[0] and b[1] > a[1] and c[0] > a[0], "vertical groups laid out along x"
    assert frame(tree, "label-0")[0] < a[0], "the leading boundary supplementary"
    app.screenshot("horizontal")

    app.send("tapid nav-back")
    app.wait_tap_id("demo-shelf")
    tree = app.wait_view(r"id=shelf")
    assert tree.count("id=shelf") == 3, "a custom flow layout's decoration views (one per row)"
    app.screenshot("shelf")
    assert app.quit() == 0
