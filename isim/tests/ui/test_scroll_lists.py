"""Scrolling and lists (HelloScrollAndLists, UIKit): a paging scroll view, the zoomed view's scaled frame, an
interactive collection view layout transition, reordering with the drop gap, navigation bar appearances (button /
done / back appearances, back indicator, per-item appearance) with a standalone bar and its delegate, and
NSItemProvider registrations (file, item, object, Transferable, preview image)."""
import re

import pytest
from isimtest import rgb


def any_pixel(img, el, pred):
    return any(pred(rgb(img, x, y)) for x in range(int(el.x), int(el.x + el.w), 2) for y in range(int(el.y + 8), int(el.y + el.h - 8), 2))


@pytest.mark.os_matrix
def test_paging_and_zoom(launch, ios):
    app = launch("HelloScrollAndLists")
    app.wait_tap_id("paging")
    pager = app.wait_for(id="pager")
    app.wait_still()
    y = pager.y + pager.h / 2
    app.drag(pager.x + pager.w - 40, y, pager.x + 60, y, 0.2)          # a swipe: one page, not wherever the finger stopped
    app.wait_log(r"^page 1$")
    app.drag(pager.x + pager.w - 40, y, pager.x + 60, y, 0.2)
    app.wait_log(r"^page 2$")
    z = app.wait_for(id="zoomer")
    app.wait_tap_id("zoom2")
    w, h = round(z.w * 2), round(z.h * 2)
    app.wait_log(rf"zoomed frame {w} x {h}, scale 2.0, content {w} x {h}")   # the zoomed view's frame is scaled
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_layout_transition(launch, ios):
    app = launch("HelloScrollAndLists")
    app.wait_tap_id("layouts")
    app.wait_view(r"id=item-1")
    app.wait_tap_id("start")
    app.wait_log(r"layout transition started \(UICollectionViewFlowLayout -> UICollectionViewFlowLayout\)")
    app.wait_tap_id("half")
    m = app.wait_log(r"half: item 1 at (\d+),(\d+) (\d+) x (\d+)")
    width = int(m.group(3))
    assert 120 < width < 340, f"half way between the 80-pt tile and the full-width row: {m.group(0)}"
    app.wait_still()
    app.screenshot("layout-half")
    app.wait_tap_id("finish")
    app.wait_log(r"transition completed true finished true")
    m = app.wait_log(r"after: item 1 at (\d+),(\d+) (\d+) x (\d+)")
    assert int(m.group(3)) > 340 and int(m.group(4)) == 44, m.group(0)
    app.wait_tap_id("start")                                            # back towards the grid, cancelled
    app.wait_tap_id("cancel")
    app.wait_log(r"transition completed false finished true")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_reorder_gap(launch, ios):
    app = launch("HelloScrollAndLists")
    app.wait_tap_id("reorder")
    t0, t2 = app.wait_for(id="tile-0"), app.wait_for(id="tile-2")
    app.wait_still()
    a, b = t0.center, t2.center
    app.send(f"longdrag {a[0]} {a[1]} {b[0]} {b[1]} 0.7 1.6")
    app.wait_log(r"drop gap at 0/1 \(\d+ cells moved\)")
    app.wait_log(r"drop gap at 0/2 \((\d+) cells moved\)")
    app.screenshot("reorder-gap")
    app.wait_log(r"order: Tile 1,Tile 2,Tile 0,Tile 3")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_bar_appearances(launch, ios):
    app = launch("HelloScrollAndLists")
    app.wait_view(r"id=paging")
    app.wait_still()
    shot = app.screenshot("bar-appearance")
    bar = app.find(id="nav-bar")
    c = rgb(shot, 6, bar.y + bar.h - 6)
    assert c[0] > 220 and 100 < c[1] < 180 and c[2] < 60, f"the standard appearance's orange: {c}"
    done, edit = app.find(id="bar-Done"), app.find(id="bar-Edit")
    assert any_pixel(shot, done, lambda p: p[0] > 220 and p[1] > 200 and p[2] < 90), "the done button appearance (yellow)"
    assert any_pixel(shot, edit, lambda p: min(p) > 235), "the button appearance (white)"

    app.wait_tap_id("bars")                                             # this item's own appearance (purple)
    app.wait_view(r"id=standalone")
    app.wait_still()
    shot = app.screenshot("item-appearance")
    c = rgb(shot, 6, bar.y + bar.h - 6)
    assert c[2] > 150 and c[1] < 120, f"the item's purple appearance: {c}"
    back = app.find(id="nav-back")
    if str(ios[0] or "").split(".")[0] not in ("26", "27"):            # (iOS 26: a glass circle, no back title)
        assert any_pixel(shot, back, lambda p: min(p) > 235), "the back button appearance (white title)"

    app.wait_tap_id("push-item")                                        # a standalone bar and its delegate
    app.wait_log(r"bar pushed Second")
    sb = app.find(id="standalone")
    app.tap(sb.x + 30, sb.y + sb.h / 2)
    app.wait_log(r"bar should pop Second")
    app.wait_log(r"bar popped Second")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_item_providers(launch, ios):
    app = launch("HelloScrollAndLists")
    app.wait_tap_id("providers")
    for line in (r"in place: hello.txt true", r"file data: file contents", r"item: https://isim.dev", r"object: lazy string",
                 r"transferable: a transferable note", r"preview: true size 120"):
        app.wait_log(line)
    assert app.quit() == 0
