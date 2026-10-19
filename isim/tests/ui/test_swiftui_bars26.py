"""iOS 26 SwiftUI additions (HelloSwiftUI -bars…, under iOS 26): safeAreaBar (out of the home indicator's area, the
scroll-edge fade behind it), ConcentricRectangle (concentric with a container shape), sliderThumbVisibility(.hidden)
(UIKit's thumbless slider: a drag anywhere moves it), labelIconToTitleSpacing, searchToolbarBehavior(.minimize),
DefaultToolbarItem(kind: .search) and tabViewSearchActivation(.searchTabSelection)."""
from isimtest import screen_frames

BLUE = (0, 122, 255)


def bars(launch, page):
    return launch("HelloSwiftUI", args=[page], os_version="26", device="iphone17")


def test_safe_area_bar(launch):
    app = bars(launch, "-bars")
    tree = app.wait_view(r"id=total-bar")
    assert "id=safe-area-bar-fade" in tree
    app.wait_until(lambda: (lambda f: f["total-bar"][1] + f["total-bar"][3] <= 874 - 34 + 0.5)(screen_frames(app.view_dump())),
                   what="the bar above the home indicator")
    f = screen_frames(app.view_dump())
    assert f["safe-area-bar-fade"][2] == 402, "the bar (and its fade) spans the screen"
    assert f["safe-area-bar-fade"][1] + f["safe-area-bar-fade"][3] >= 873.5, "the fade reaches the screen edge"


def test_shapes_slider_label(launch):
    app = bars(launch, "-bars-shapes")
    tree = app.wait_view(r"id=level")
    f = screen_frames(tree)
    x, y, _, _ = f["concentric"]
    bx, by = x + 10, y + 10               # the blue ConcentricRectangle, 10 pt inside a 30 pt container: 20 pt corners
    img = app.wait_shot_still()
    px = lambda dx, dy: img.getpixel((int(bx + dx), int(by + dy)))[:3]
    assert px(4, 4) != BLUE and px(100, 4) == BLUE and px(16, 16) == BLUE, (px(4, 4), px(100, 4), px(16, 16))
    # labelIconToTitleSpacing(24): the title 24 pt after the 20 pt icon (8 pt by default)
    asst = tree.split("id=wide-label", 1)[1]
    assert "UILabel (44 0;" in asst.split("id=label", 1)[0]
    # sliderThumbVisibility(.hidden): no thumb to grab, a drag anywhere on the track moves the value
    sx, sy, sw, sh = f["level"]
    app.drag(sx + sw * 0.8, sy + sh / 2, sx + sw * 0.95, sy + sh / 2, 0.3)
    app.wait_log(r"^level 0\.[5-9]")


def test_search_minimize(launch):
    app = bars(launch, "-bars-search")
    tree = app.wait_view(r"id=search-minimized")
    assert 'id=search-field text="" placeholder' in tree and "hidden id=search-field" in tree, "minimized: the field hides"
    assert "id=toolbar-search" in tree                                       # DefaultToolbarItem(kind: .search)
    app.tap_id("search-minimized")
    app.wait_view(r'id=search-field text="" \(editing\)')
    app.type("Ch")
    app.wait_log(r"^query Ch$")
    app.tap_id("search-cancel")
    app.wait_view(r"id=search-minimized")
    app.wait_tap_id("toolbar-search")
    app.wait_view(r'id=search-field text="" \(editing\)')


def test_tab_search_activation(launch):
    app = bars(launch, "-bars-tabs")
    app.wait_tap_id("tab-Search")
    app.wait_view(r"id=tab-search-field .*\(editing\)")                      # focused on selection
