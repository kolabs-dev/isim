"""iOS 27 UIKit bars and tabs (HelloBars27): navigationBarMinimization (on scroll down, back only at the scroll edge,
safe area adjusted), UIBarButtonItem.visibilityPriority (low-priority items move to the overflow menu first),
UITabBarController.prominentTabIdentifier (the search tab sits apart until another tab is named), performBatchUpdates,
UISearchTab.automaticallyActivatesSearch, and the sidebar's isAvailable / preferredPlacement / delegate (iPad)."""
import pytest
from isimtest import screen_frames


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_bars_and_tabs(launch, ios):
    v = major(ios)
    app = launch("HelloBars27")
    if v < 27:
        app.wait_log(r"^hb27 ios27 no$")
        t = app.wait_view(r"id=item-Edit")                          # (the first item is the trailingmost)
        assert "id=nav-overflow" not in t, f"iOS {v}: no overflow menu (iOS 27; items that do not fit are left out)"
        if v >= 26:                                                      # the search tab apart (iOS 26 look)
            f = screen_frames(t)
            assert f["tab-Search"][2] == f["tab-Search"][3] == 54, f"iOS {v}: the search tab on its own circle: {f['tab-Search']}"
        assert app.quit() == 0
        return

    app.wait_log(r"^hb27 minimization true$")
    app.wait_log(r"^hb27 priorities low<flag<standard<high true$")
    app.wait_log(r"^hb27 sidebar available false placement true$")      # iPhone: no sidebar
    t = app.wait_view(r"id=nav-overflow")
    app.wait_still()
    app.screenshot("bars")
    f = screen_frames(t)
    assert all(f"id=item-{n}" in t for n in ("Edit", "Share", "Pin")) and "id=item-Archive" not in t and "id=item-Flag" not in t, \
        "the low-priority items (Archive, Flag) moved to the overflow menu"
    assert f["nav-overflow"][0] > f["item-Pin"][0], f"the overflow button at the trailing edge: {f['nav-overflow']}"
    search = f["tab-Search"]
    assert search[2] == search[3] == 54 and search[0] > f["tab-Inbox"][0] + f["tab-Inbox"][2], f"the search tab apart: {search}"
    app.tap_id("nav-overflow")
    app.wait_tap_id("menu-Archive")
    app.wait_log(r"^hb27 item Archive$")

    app.wait_still()
    app.drag(200, 650, 200, 350, 0.5)                                    # scrolling down minimizes the bar
    app.wait_log(r"isim: navigation bar minimized")
    app.wait_still()
    app.screenshot("minimized")
    app.drag(200, 400, 200, 550, 0.4)                                    # a little back up: .atScrollEdge keeps it
    app.wait_still()
    assert "navigation bar restored" not in app.log, "restorationBehavior .atScrollEdge: not restored away from the top"
    for _ in range(2):
        app.drag(200, 300, 200, 800, 0.3)
        app.wait_still()
    app.wait_log(r"isim: navigation bar restored")

    app.tap_id("make-prominent")                                         # Inbox prominent: the search tab joins the bar
    app.wait_log(r"^hb27 prominent inbox$")
    app.wait_still()
    f = screen_frames(app.view_dump())
    assert f["tab-Inbox"][2] == f["tab-Inbox"][3] == 54 and f["tab-Search"][2] > 54, \
        f"prominentTabIdentifier: Inbox on the circle, Search in the capsule: {f['tab-Inbox']} {f['tab-Search']}"

    app.tap_id("batch")                                                  # two tab changes, one layout
    app.wait_log(r"^hb27 batch done$")
    app.wait_view(r"id=tab-Books")
    assert app.log.count("isim: tab bar batch update") == 1, "performBatchUpdates: one coalesced update"

    app.tap_id("tab-Search")                                             # automaticallyActivatesSearch
    app.wait_log(r"^hb27 search activated$")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_sidebar_delegate_ipad(launch, ios):
    if major(ios) < 27:
        pytest.skip("sidebar availability is iOS 27")
    app = launch("HelloBars27", device="ipadpro11", os_version=ipad_os(ios), args=["sidebar"])
    app.wait_log(r"^hb27 sidebar availability changed true$")
    app.wait_still()
    app.tap_id("toggle-sidebar")
    app.wait_log(r"^hb27 sidebar visibility will change hidden false$")
    app.wait_log(r"^hb27 sidebar visibility changed hidden true$")     # the completion runs after the change
    assert app.quit() == 0
