"""iOS 26 UIKit bars (HelloModernBars): UINavigationItem subtitles (subtitle + largeSubtitle under a large title, an
attributed inline subtitle, a subtitle view), UITabBarController.tabBarMinimizeBehavior (.onScrollDown: scrolling the
list minimizes the floating tab bar to the selected tab, tapping it expands), bottomAccessory (UITabAccessory above
the bar, inline beside the minimized one, with the tabAccessoryEnvironment trait), contentLayoutGuide, and
UIButton.Configuration.symbolContentTransition (replace). Earlier iOS versions: the APIs are unavailable."""
import pytest
from isimtest import screen_frames


@pytest.mark.os_matrix
def test_modern_bars(launch, ios):
    app = launch("HelloModernBars")
    if str(ios[0] or "").split(".")[0] not in ("26", "27"):            # the default device runs iOS 18
        app.wait_log(r"^hmb ios26 no$")
        tree = app.wait_view(r"id=tab-Player\b")
        assert "id=tab-accessory" not in tree, f"iOS {ios[0] or 18}: no bottom accessory"
        assert app.quit() == 0
        return

    app.wait_log(r"^hmb ios26 yes minimize true$")
    app.wait_log(r"^hmb accessory environment regular$")
    t0 = app.wait_view(r"text=Updated Just Now")
    app.wait_still()
    app.screenshot("expanded")
    f0 = screen_frames(t0)
    acc, bar = f0.get("tab-accessory"), f0.get("tab-bar")
    W = bar[2]
    assert acc and bar and acc[1] + acc[3] <= bar[1] - 7 and abs(acc[0] - 21) < 1 and abs(acc[2] - (W - 42)) < 1, \
        f"bottom accessory: a capsule above the floating tab bar: {acc} {bar}"
    assert "text=Now Playing" in t0 and "text=Track 1" in t0, "the accessory's content view"
    m = app.wait_log(r"^hmb content guide (\d+) (\d+) (\d+) (\d+)$")
    assert (int(m[1]), int(m[2]), int(m[3])) == (0, 0, int(W)) and abs(int(m[4]) - bar[1]) <= 1, \
        f"contentLayoutGuide: the content area above the tab bar: {m[0]} {bar}"

    nav = screen_frames(t0)
    large, sub = nav.get("nav-large-title"), nav.get("nav-large-subtitle")
    assert large and sub and sub[1] >= large[1] + 40, f"largeSubtitle under the large title: {large} {sub}"

    # scrolling the list down minimizes the tab bar; the accessory moves beside it (inline)
    app.drag(W / 2, 600, W / 2, 300, 0.5)
    app.wait_log(r"isim: tab bar minimized")
    app.wait_log(r"^hmb accessory environment inline$")
    t1 = app.wait_view(r"hidden id=tab-Player\b")
    app.wait_still()
    app.screenshot("minimized")
    f1 = screen_frames(t1)
    a1, inbox = f1.get("tab-accessory"), f1.get("tab-Inbox")
    assert a1 and a1[0] > 80 and abs(a1[1] - (bar[1] + 7)) < 1, f"accessory inline beside the minimized bar: {a1}"
    assert inbox and inbox[2] == inbox[3] == 54, f"minimized: the selected tab alone on a 62 pt circle: {inbox}"
    assert "hidden id=accessory-detail" in t1, "the content view follows tabAccessoryEnvironment (inline)"
    title, subtitle = f1.get("nav-title"), f1.get("nav-subtitle")
    assert title and subtitle and subtitle[1] > title[1] and "text=12 Unread" in t1, \
        f"collapsed large title: the inline title with its subtitle below: {title} {subtitle}"

    app.tap_id("tab-Inbox")                                             # the minimized tab expands the bar
    app.wait_log(r"isim: tab bar expanded")
    app.wait_log(r"^hmb accessory environment regular$", count=2)
    app.wait_until(lambda: (lambda t: "id=tab-Player" in t and "hidden id=tab-Player" not in t)(app.view_dump()),
                   what="tapping the minimized tab expands the bar")

    app.wait_still()
    rows = screen_frames(app.view_dump())                                # a row in the middle of the screen (not under the bars)
    row = min((k for k in rows if k.startswith("row-")), key=lambda k: abs(rows[k][1] - 400))
    app.tap_id(row)
    app.wait_log(rf"^hmb detail {int(row[4:]) + 1}$")
    t2 = app.wait_view(r"text=From Alice")
    f2 = screen_frames(t2)
    title, subtitle = f2.get("nav-title"), f2.get("nav-subtitle")
    assert title and subtitle and title[3] == 20 and subtitle[1] == title[1] + 20, \
        f"inline title over an attributed subtitle: {title} {subtitle}"
    app.wait_still()
    app.screenshot("detail")

    app.tap_id("tab-Player")
    t3 = app.wait_view(r"id=live-dot")
    assert "id=live-dot" in t3, "subtitleView in the navigation bar"
    app.wait_still()
    app.tap_id("play")
    app.wait_log(r"isim: symbol content transition play\.fill -> pause\.fill")
    app.wait_log(r"^hmb player playing transition true$")
    app.tap_id("play")
    app.wait_log(r"isim: symbol content transition pause\.fill -> play\.fill")
    assert app.quit() == 0
