"""TabView and bars across iOS versions (HelloTabs). Port of tests/ui/tabs.sh and tabs_check.py.
- iOS 18 (the test device): TabSection tabs flattened into the tab bar, no bottom accessory.
- iOS 27 on iPhone 17: the bottom accessory above the floating tab bar, minimizing on scroll (accessory inline), tap to
  expand, merging glass in GlassEffectContainer and glassEffectUnion, backgroundExtensionEffect under the status bar,
  toolbar overflow by visibilityPriority with a pinned trailing item and ToolbarOverflowMenu, bottom bar minimization,
  the hard scroll edge.
- iOS 26 on iPad: .sidebarAdaptable: the sidebar with the sections; choosing a tab there."""
import re

from isimtest import count_px, rgb, screen_frames, visible


def test_ios18_tab_sections(launch):
    app = launch("HelloTabs")
    tree = app.wait_view(r"id=tab-Glass\b")
    assert all(f"id=tab-{t}" in tree for t in ("Home", "Bars", "Glass")), "iOS 18: TabSection tabs in the tab bar"
    assert "id=isim-tab-accessory" not in tree, "iOS 18: no bottom accessory"
    app.tap_id("tab-Glass")
    app.wait_log(r"^tab 2")
    assert app.quit() == 0


def test_ios27_bars(launch):
    app = launch("HelloTabs", os_version="27", device="iphone17")
    t0 = app.wait_view(r"id=isim-background-extension\b")
    home = app.screenshot("home")
    f0 = screen_frames(t0)
    acc, bar = f0.get("isim-tab-accessory"), f0.get("isim-tabbar")
    assert acc and bar and acc[1] + acc[3] <= bar[1] - 7 and "text=Now Playing" in t0, \
        f"bottom accessory above the floating tab bar: {acc} {bar}"
    p = rgb(home, home.width * 0.75, 57)                               # beside the Dynamic Island, above the safe area
    assert p[0] > 90 and p[2] > 90 and p[1] < 160, \
        f"backgroundExtensionEffect fills the status bar area with the mirrored hero: {p}"

    app.send("swipeid home-8 0 -200 0.4")
    t1 = app.wait_view(r"hidden id=tab-Bars\b")
    a1 = screen_frames(t1).get("isim-tab-accessory")
    assert a1 and a1[0] > 80 and "text=Inline" in t1, f"scrolling down minimizes the tab bar (accessory inline): {a1}"
    app.tap_id("tab-Home")
    app.wait_until(lambda: (lambda t: "id=tab-Bars" in t and "hidden id=tab-Bars" not in t)(app.view_dump()),
                   what="tapping the minimized tab expands the bar")

    app.tap_id("tab-Glass")

    def unions():
        u = re.findall(r"\((-?[\d.]+) (-?[\d.]+); ([\d.]+) x ([\d.]+)\) id=isim-glass-union", app.view_dump())
        return len(u) == 2 and u
    u = app.wait_until(unions, what="two glass unions")
    widths = sorted(float(x[2]) for x in u)
    assert abs(widths[0] - 110) < 1 and abs(widths[1] - 180) < 1, \
        f"GlassEffectContainer merges near shapes; glassEffectUnion merges a pair: {u}"

    app.tap_id("tab-Bars")
    t4 = app.wait_view(r"id=toolbar-overflow\b")
    f4 = screen_frames(t4)
    star, ov, pin = f4.get("tb-star"), f4.get("toolbar-overflow"), f4.get("tb-pinned")
    assert star and ov and pin and "id=tb-heart" not in t4 and "id=tb-bell" not in t4, \
        f"visibilityPriority: the low item overflows, the high one stays: {star} {ov} {pin}"
    assert star[0] < ov[0] < pin[0], f"pinned trailing item at the edge, the overflow button before it: {star} {ov} {pin}"
    bb = f4.get("bb-compose")
    assert bb, "bottom bar item"
    box = (round(bb[0]), round(bb[1]), int(bb[2]), int(bb[3]))
    blue = lambda img: count_px(img, box, lambda c: c[2] > 200 and c[0] < 90)
    assert blue(app.screenshot("bars")) > 5, "the bottom bar shows before scrolling"

    app.tap_id("toolbar-overflow")
    t5 = app.wait_view(r"id=menu-Extra\b")
    assert "id=menu-Heart" in t5, "overflow menu lists the hidden items and ToolbarOverflowMenu content"
    app.tap_id("menu-Extra")
    app.wait_log(r"bars: extra")                                      # overflow menu items run
    app.wait_view(visible("bar-8"))
    app.send("swipeid bar-8 0 -200 0.4")
    app.wait_until(lambda: blue(app.screenshot("barsmin")) == 0,
                   what="toolbarMinimizationBehavior: the bottom bar slides away on scroll down")
    t6 = app.wait_view(r"_SUINavBar .*alpha<1")                       # the navigation bar fades on scroll down
    hair = [l for l in t6.splitlines() if re.search(r"UIView \(0 [\d.]+; \d+ x 0\.5\)", l) and "Nav" not in l]
    assert any("hidden" not in h for h in hair), f"scrollEdgeEffectStyle(.hard): an opaque edge with a divider: {hair[:3]}"
    assert app.has(r"AsyncImage loaded"), "AsyncImage(request:) loads with the asyncImageURLSession session"
    assert app.quit() == 0


def test_ipad_sidebar(launch):
    app = launch("HelloTabs", os_version="26", device="ipadpro11")
    app.wait_tap_id("isim-tab-sidebar-toggle")
    tree = app.wait_view(r"id=sidebar-Glass\b")
    assert "id=isim-tab-sidebar" in tree and "text=Main" in tree and "text=More" in tree, \
        "iPad sidebarAdaptable: the sidebar lists the sections and tabs"
    app.wait_tap_id("sidebar-Glass")
    app.wait_log(r"^tab 2")                                          # choosing a tab in the sidebar
    assert app.quit() == 0


def test_ios26_search_tab(launch):
    """iOS 26: selecting the search tab turns the floating tab bar into a circle with the tab to go back to and the search
    tab's .searchable field; typing filters, the field rides above the keyboard; the circle goes back."""
    app = launch("HelloTabs", os_version="26", device="iphone17")
    app.wait_tap_id("tab-Search")
    t = app.wait_view(r"id=tab-search-field")
    f = screen_frames(t)
    home, field = f["tab-Home"], f["tab-search-field"]
    assert "id=search-tab" in t and home[0] < field[0], "the back circle (Home) leading, the search field after it"
    assert "UISearchBar" not in t and "id=search-field" not in t, "the field is in the tab bar, not under the title"
    bar0 = f["isim-tabbar"]
    app.tap_id("tab-search-field")
    app.type("ap")
    app.wait_log(r"^query ap$")
    t2 = app.wait_view(lambda d: "id=fruit-Apple" in d and "id=fruit-Apricot" in d and "id=fruit-Banana" not in d, what="filtered")
    app.screenshot("search-tab")
    # the field rides above the keyboard: where the bar was, the keyboard now shows (no white glass)
    bx, by, bw, bh = field
    app.wait_shot(lambda im: max(im.getpixel((int(bx + bw / 2), int(by + bh / 2)))[:3]) < 235, what="the bar above the keyboard")
    app.tap_id("tab-Home")
    app.wait_log(r"^tab 0$")
    assert app.quit() == 0, "exits cleanly"


def test_ios27_prominent_tab(launch):
    """TabRole.prominent (iOS 27): apart at the trailing end on a tinted glass circle, its icon white."""
    app = launch("HelloTabs", os_version="27", device="iphone17", env={"PROMINENT": "1"})
    t = app.wait_view(r"id=tab-New\b")
    shot = app.screenshot("prominent-tab")
    x, y, w, h = screen_frames(t)["tab-New"]
    c = shot.getpixel((int(x + 6), int(y + h / 2)))[:3]
    assert c[2] > 180 and c[0] < 120, f"the circle is tinted (blue) {c}"
    app.tap_id("tab-New")
    app.wait_view(r"id=new-tab")
    assert app.quit() == 0, "exits cleanly"
