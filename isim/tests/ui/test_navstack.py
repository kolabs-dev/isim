"""SwiftUI navigation chrome (HelloNavStack): toolbar placements (leading, several trailing items, secondaryAction
"More" menu, principal, bottom bar + status, keyboard bar), toolbarTitleMenu, the push animation, the edge swipe back,
the iOS 18 zoom transition, toolbarRole(.editor), navigationBarBackButtonHidden, searchable with searchSuggestions
(searchCompletion) and searchScopes. Checked with view-tree frames, the app log and pixels. Port of
tests/ui/navstack.sh and its navstack_check.py."""
import re

import pytest
from isimtest import rgb, screen_frames


def px(img, x, y):
    return rgb(img, round(x), round(y))


def near(p, q, tol=14):
    return all(abs(a - b) <= tol for a, b in zip(p, q))


def orange(c):
    return c[0] > 230 and 120 < c[1] < 190 and c[2] < 90


BLUE, GREY = (217, 235, 255), (242, 242, 247)


@pytest.mark.os_matrix
def test_navstack(launch, ios):
    app = launch("HelloNavStack")
    d0 = app.wait_view(r"id=toolbar-more")
    root = app.screenshot("root")
    W, H = root.size
    for ident, line in (("tb-add", "tb: add"), ("tb-share", "tb: share"), ("tb-edit", "tb: edit")):
        app.tap_id(ident)
        app.wait_log(line)                                    # leading and two trailing toolbar items take taps
    app.tap_id("isim-nav-title-menu")
    app.wait_tap_id("menu-Rename")
    app.wait_log(r"title menu: rename")                       # toolbarTitleMenu: the title opens its menu
    app.wait_view(r"id=isim-menu", gone=True)
    app.tap_id("toolbar-more")
    app.wait_tap_id("menu-Archive")
    app.wait_log(r"tb: archive")                              # secondaryAction items in the More menu
    app.wait_view(r"id=isim-menu", gone=True)

    app.tap_id("push-detail")
    app.sleep(0.12)                                           # part-way through the push animation
    pushmid = app.screenshot("pushmid")
    app.wait_log(r"^path 1")

    def detail_done(s):
        bg = px(s, W * 0.8, 100)
        return bg[0] > 200 and bg[1] > 170 and bg[2] < 80
    detail = app.wait_shot(detail_done, "detail level pushed with its bar background")
    d1 = app.view_dump()

    app.drag(3, 400, 300, 400, 0.4)                           # edge swipe back
    app.wait_log(r"^path 0")
    back = app.wait_shot(lambda s: near(px(s, 30, 700), GREY), "after the edge swipe the root shows again")

    app.wait_tap_id("push-zoom")
    app.sleep(0.12)                                           # part-way through the zoom transition
    zoommid = app.screenshot("zoommid")
    zoom = app.wait_shot(lambda s: orange(px(s, 4, 800)), "zoom transition ends full screen")
    app.tap_id("isim-nav-back")
    app.wait_log(r"^path 0", count=2)

    app.wait_tap_id("push-bottom")
    app.wait_tap_id("bb-plus")
    app.wait_log(r"bottom: plus 1")                           # bottom bar item works
    app.tap_id("field")
    app.wait_view(r"id=kb-done")
    app.sleep(0.8)                                            # the keyboard slides up
    d2 = app.view_dump()
    app.tap_id("kb-done")
    app.wait_log(r"keyboard: done")                           # keyboard toolbar item works
    app.tap_id("isim-nav-back")
    app.wait_log(r"^path 0", count=3)

    app.wait_tap_id("push-editor")
    d3 = app.wait_view(lambda d: "id=editor-page" in d and "text=Stack" not in d,
                       what="toolbarRole(.editor): the back button shows no title")
    app.tap_id("isim-nav-back")
    app.wait_log(r"^path 0", count=4)
    app.wait_tap_id("push-custom")
    d4 = app.wait_view(lambda d: "id=custom-page" in d and "hidden id=isim-nav-back" in d,
                       what="navigationBarBackButtonHidden hides the back button")
    app.tap_id("custom-close")
    app.wait_log(r"^path 0", count=5)

    app.wait_tap_id("push-search")
    app.wait_tap_id("search-field")
    d5 = app.wait_view(lambda d: "id=suggest-Apple" in d and "id=result-Banana" not in d,
                       what="searchSuggestions replace the results while searching")
    app.tap_id("suggest-Cherry")
    app.wait_log(r"search text Cherry")                       # searchCompletion fills the search field
    d6 = app.wait_view(lambda d: "id=result-Cherry" in d and "id=suggest-Apple" not in d,
                       what="after the completion the results are filtered")
    app.tap_id("search-scopes")
    app.wait_log(r"^scope 1")                                 # searchScopes: the scope bar changes the scope
    assert app.quit() == 0, "exits cleanly"
    assert app.count(r"^path 0") >= 4, "edge swipe from the leading edge pops"

    f0 = screen_frames(d0)
    ids = ("tb-edit", "tb-add", "tb-share", "toolbar-more")
    assert all(i in f0 for i in ids), f"dump lists the toolbar items: {[i for i in ids if i not in f0]}"
    e, a, s, m = (f0[i] for i in ids)
    assert e[0] < 40, f"leading item at the leading edge {e}"
    assert a[0] + a[2] <= s[0] + 0.5 and s[0] + s[2] <= m[0] + 0.5 and m[0] + m[2] <= W - 15, \
        f"trailing items side by side, the last at the trailing edge {a} {s} {m}"
    assert all(40 < x[1] + x[3] / 2 < 130 for x in (e, a, s, m)), f"toolbar items in the navigation bar {e} {a}"

    p = screen_frames(d1).get("principal")
    assert p is not None and abs(p[0] + p[2] / 2 - W / 2) < 2, f"principal item centred in the bar {p}"
    bg = px(detail, W * 0.8, 100)
    light = sum(1 for i in range(int(p[2])) for j in range(int(p[3])) if min(px(detail, p[0] + i, p[1] + j)) > 215)
    assert bg[0] > 200 and bg[1] > 170 and bg[2] < 80 and light > 5, \
        f"toolbarBackground(color / .visible) and toolbarColorScheme(.dark) on the navigation bar {bg} {light}"
    r, l = px(pushmid, W - 30, 700), px(pushmid, 30, 700)
    assert near(r, BLUE) and not near(l, BLUE), f"push slides the new level in from the trailing edge {l} {r}"
    assert near(px(back, 30, 700), GREY), "after the edge swipe the root shows again"
    assert orange(px(zoommid, W / 2, 400)) and not orange(px(zoommid, 4, 800)), \
        f"zoom transition grows out of the source (part-way) {px(zoommid, W / 2, 400)} {px(zoommid, 4, 800)}"
    assert orange(px(zoom, 4, 800)), "zoom transition ends full screen"

    f2 = screen_frames(d2)
    kbw = re.search(r"__IsimKeyboardWindow \(-?[\d.]+ ([\d.]+);", d2)
    kb = f2.get("kb-done")
    assert kbw and kb, f"keyboard and its toolbar in the dump {bool(kbw)} {kb}"
    top = float(kbw.group(1))
    assert top - 44 <= kb[1] and kb[1] + kb[3] <= top + 0.5 and kb[0] + kb[2] > W - 40, \
        f"keyboard toolbar sits on the keyboard {kb} keyboard at {top}"
    bm, bs, bp = f2.get("bb-minus"), f2.get("bb-status"), f2.get("bb-plus")
    assert bm and bs and bp, f"bottom bar items in the dump {bm} {bs} {bp}"
    assert bm[0] < 40 and bp[0] + bp[2] > W - 40 and abs(bs[0] + bs[2] / 2 - W / 2) < 2 and \
        all(y[1] > H - 100 for y in (bm, bs, bp)), f"bottom bar: items at the edges, status in the middle {bm} {bs} {bp}"
    assert "id=editor-page" in d3 and "text=Stack" not in d3, "toolbarRole(.editor): the back button shows no title"
    assert "id=custom-page" in d4 and "hidden id=isim-nav-back" in d4, \
        "navigationBarBackButtonHidden hides the back button"
    assert "id=suggest-Apple" in d5 and "id=result-Banana" not in d5 and "id=search-scopes" in d5, \
        "searchSuggestions replace the results while searching, with the scope bar"
    assert "id=result-Cherry" in d6 and "id=result-Apple" not in d6 and "id=suggest-Apple" not in d6, \
        "after the completion the results are filtered"
