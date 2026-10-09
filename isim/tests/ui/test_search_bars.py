"""Search bar placements (HelloSearchBars, UINavigationItem.preferredSearchBarPlacement). iPhone under iOS 26:
.integrated puts the field in the navigation controller's toolbar at searchBarPlacementBarButtonItem (between Compose
and Add), activating it lifts the field above the keyboard, Cancel puts it back; .integratedButton is a toolbar search
button. iPad: a field in the navigation bar row, trailing (.integrated / .inline) or centred (.integratedCentered).
Before iOS 26, .inline is stacked on iPhone and in the bar row on iPad."""
import pytest
from isimtest import screen_frames


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_search_in_toolbar_iphone(launch, ios):
    if major(ios) < 26:
        app = launch("HelloSearchBars", args=["inline"])
        app.wait_log(r"^hsb placement preferred 1 effective 2$")       # inline is stacked on iPhone before iOS 26
        f = screen_frames(app.wait_view(r"id=search-field"))
        nav, bar = f["nav-bar"], f["search-bar"]
        assert bar[1] >= 100 and bar[1] + bar[3] <= nav[1] + nav[3] + 1, f"stacked below the title: {bar} {nav}"
        assert app.quit() == 0
        return

    app = launch("HelloSearchBars", args=["integrated"])
    app.wait_log(r"^hsb toolbar integration true external false$")
    app.wait_log(r"^hsb placement preferred 1 effective 1$")
    t = app.wait_view(r"id=search-field")
    app.wait_still()
    app.screenshot("toolbar")
    f = screen_frames(t)
    compose, field, add, nav = f["compose"], f["search-bar"], f["add"], f["nav-bar"]
    assert compose[0] + compose[2] < field[0] and field[0] + field[2] < add[0] and abs(field[1] - compose[1]) < 1, \
        f"the field takes the placement item's slot among the toolbar items: {compose} {field} {add}"
    assert field[1] > 700 and field[3] == 44, f"the field is in the bottom toolbar: {field}"
    assert nav[3] < 110, f"no stacked search band under the title: {nav}"

    app.tap_id("search-field")
    app.wait_log(r"isim: search controller active")
    app.wait_log(r"isim: keyboard shown")
    app.send("type ap")
    app.wait_log(r'^hsb search "ap" 3 results active true$')
    app.wait_still()
    app.screenshot("active")
    f = screen_frames(app.view_dump())
    bottom = f["search-bottom"]
    assert bottom[1] < 600, f"the active field rides above the keyboard: {bottom}"
    app.tap_id("search-cancel")
    app.wait_log(r"isim: search controller inactive")
    app.wait_still()
    f = screen_frames(app.view_dump())
    assert abs(f["search-bar"][1] - field[1]) < 1, f"back in the toolbar after Cancel: {f['search-bar']}"
    assert app.quit() == 0

    app = launch("HelloSearchBars", args=["button"])
    app.wait_log(r"^hsb placement preferred 3 effective 3$")
    f = screen_frames(app.wait_view(r"id=search-button"))
    assert f["search-button"][1] > 700 and "search-bar" not in f, f"integratedButton: a search button in the toolbar: {f.get('search-button')}"
    app.tap_id("search-button")
    app.wait_log(r"isim: search controller active")
    app.send("type ch")
    app.wait_log(r'^hsb search "ch" 2 results active true$')
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_search_in_bar_row_ipad(launch, ios):
    glass = major(ios) >= 26
    app = launch("HelloSearchBars", device="ipadpro11", os_version=ipad_os(ios), args=["integrated" if glass else "inline"])
    app.wait_log(r"^hsb placement preferred 1 effective 1$")
    f = screen_frames(app.wait_view(r"id=search-field"))
    nav, bar = f["nav-bar"], f["search-bar"]
    W = nav[2]
    assert abs(bar[0] + bar[2] - (W - 20)) < 1 and bar[1] + bar[3] <= nav[1] + nav[3], \
        f"the field at the trailing end of the bar row: {bar} {nav}"
    app.tap_id("search-field")
    app.wait_log(r"isim: search controller active")
    app.send("type pe")
    app.wait_log(r'^hsb search "pe" 3 results active true$')
    assert abs(screen_frames(app.view_dump())["search-bar"][1] - bar[1]) < 1, "the active field stays in the bar row"
    assert app.quit() == 0
    if not glass:
        return
    app = launch("HelloSearchBars", device="ipadpro11", os_version=ipad_os(ios), args=["centered"])
    app.wait_log(r"^hsb placement preferred 4 effective 4$")
    f = screen_frames(app.wait_view(r"id=search-field"))
    bar = f["search-bar"]
    assert abs(bar[0] + bar[2] / 2 - W / 2) < 2, f"integratedCentered: the field in the middle of the bar row: {bar}"
    assert app.quit() == 0
