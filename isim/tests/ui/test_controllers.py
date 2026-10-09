"""View controllers (HelloControllers, UIKit): a triple-column UISplitViewController on iPad (tile, overlay and
displace display modes, the sidebar button, a tap on the dimmed secondary, the edge swipe), collapsing and expanding
when an iPhone Pro Max turns, a search controller with suggestions and a results controller (the bar slides up) and
a standalone one, and the share sheet's Save Image and Print.

DisplayMode raw values: 1 secondaryOnly, 2 oneBesideSecondary, 3 oneOverSecondary, 4 twoBesideSecondary,
5 twoOverSecondary, 6 twoDisplaceSecondary."""
import pytest
from isimtest import screen_frames


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_split_display_modes(launch, ios):
    app = launch("HelloControllers", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"split collapsed false mode 4")                       # tile: primary + supplementary beside the secondary
    f = screen_frames(app.wait_view(r"id=detail\b"))
    assert f["library"][0] == 0 and f["messages"][0] > 300 and f["detail"][0] > 600, f

    app.wait_tap_id("overlay")                                          # overlay: the columns hide ...
    app.wait_log(r"behavior overlay: mode 1")
    app.wait_still()
    app.wait_tap_id("isim-split-toggle")                                # ... the sidebar button shows them over the secondary
    app.wait_log(r"will change to mode 5")
    app.wait_log(r"isim: split view display mode twoOverSecondary")
    app.wait_still()
    f = screen_frames(app.view_dump())
    assert f["detail"][0] == 0 and f["library"][0] == 0, f
    app.screenshot("split-overlay")
    app.wait_for(id="isim-split-dimming"); app.tap(790, 900)                               # a tap on the secondary hides them
    app.wait_log(r"isim: split view display mode secondaryOnly")

    app.wait_still()
    app.drag(2, 500, 320, 500, 0.3)                                     # the edge swipe shows them again
    app.wait_log(r"isim: split view edge swipe")
    app.wait_log(r"isim: split view display mode twoOverSecondary", count=2)
    app.wait_for(id="isim-split-dimming"); app.tap(790, 900)
    app.wait_log(r"isim: split view display mode secondaryOnly", count=2)

    app.wait_tap_id("displace")                                         # displace: the secondary is pushed aside, dimmed
    app.wait_log(r"behavior displace: mode 1")                          # (still hidden: the user's choice stays)
    app.wait_tap_id("isim-split-toggle")
    app.wait_log(r"isim: split view display mode twoDisplaceSecondary")
    app.wait_still()
    f = screen_frames(app.view_dump())
    assert f["detail"][0] > 600 and f["detail"][2] > 700, f"the secondary keeps its width, pushed right: {f['detail']}"
    app.screenshot("split-displace")
    app.wait_for(id="isim-split-dimming"); app.tap(790, 900)
    app.wait_log(r"isim: split view display mode secondaryOnly", count=3)
    app.wait_tap_id("tile")
    app.wait_log(r"behavior tile: mode 1")                              # (the user hid the columns: it stays so)
    app.wait_tap_id("isim-split-toggle")
    app.wait_log(r"isim: split view display mode twoBesideSecondary")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_split_collapse_expand(launch, ios):
    old = ios[0] and str(ios[0]).split(".")[0] == "17"
    app = launch("HelloControllers", device="iphone15promax" if old else "iphone16promax")   # (a Pro Max of that iOS)
    app.wait_log(r"split collapsed true")
    app.wait_tap_id("folder-Archive")
    app.wait_tap_id("message-2")
    app.wait_view(r"id=detail-title text=Message 2")
    app.send("rotate landscapeleft")                                    # regular width: the columns come back
    app.wait_log(r"isim: split view expanded")
    app.wait_log(r"did expand")
    f = screen_frames(app.wait_view(r"id=detail-title text=Message 2"))
    assert f["detail"][0] > 300, f"the pushed message is the secondary column: {f}"
    app.screenshot("split-expanded")
    app.send("rotate portrait")                                         # compact again: one stack, from the primary
    app.wait_log(r"did collapse", count=3)                              # (the delegate's top column)
    app.wait_view(r"id=folder-Archive")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_search_and_share(launch, ios):
    app = launch("HelloControllers")
    app.wait_log(r"split collapsed true")
    app.wait_tap_id("folder-Inbox")
    app.wait_tap_id("message-1")
    bar = app.wait_for(id="search-bar")
    app.tap(bar.x + 100, bar.y + bar.h / 2)                             # the bar slides up as the navigation bar goes
    moving = app.shot_during(lambda s: True, None, what="a frame of the bar moving")
    app.wait_log(r"search presented")
    app.wait_still()
    top = app.find(id="search-bar")
    assert top.y < bar.y, f"the active bar is at the top: {top} (was {bar})"
    app.type("ap")
    app.wait_view(r"id=isim-search-suggestion-1")
    app.wait_view(r"text=apricot — fruit")
    app.screenshot("search-suggestions")
    app.wait_tap_id("isim-search-suggestion-0")
    app.wait_log(r"suggestion selected: apple")
    app.wait_view(r"id=results-label text=picked: apple")
    app.tap_text("Cancel")
    app.wait_log(r"search dismissed")
    app.wait_view(r"id=results-label", gone=True)

    sb = app.wait_for(id="standalone-bar")                              # a standalone search controller stays in place
    app.tap(sb.x + 100, sb.y + sb.h / 2)
    app.type("kiwi")
    app.wait_log(r'search standalone "kiwi"')
    app.wait_view(r"id=standalone-label text=standalone: kiwi")
    assert abs(app.find(id="standalone-bar").y - sb.y) < 2
    app.tap_text("Cancel")
    app.wait_view(r"id=standalone-label", gone=True)

    app.wait_tap_id("share")                                            # share sheet: Save Image and Print
    app.wait_view(r"id=share-Save Image")
    app.wait_view(r"id=share-Print")
    app.wait_still()
    app.screenshot("share-sheet")
    app.find(id="share-Save Image").tap()
    app.wait_log(r"share sheet saved 1 image\(s\) to the photo library")
    app.wait_log(r"share finished: com.apple.UIKit.activity.SaveToCameraRoll true")
    app.wait_view(r"id=isim-share-sheet", gone=True)
    app.wait_view(r"Would Like to Add to your Photos")                  # the photo library asks first (add-only access)
    app.tap_text("Allow")
    app.wait_view(r"id=isim-alert", gone=True)
    app.wait_still()
    app.wait_tap_id("share")
    app.wait_view(r"id=share-Print")
    app.wait_still()
    app.find(id="share-Print").tap()
    app.wait_log(r"share sheet prints 1 item\(s\)")
    app.wait_log(r"share finished: com.apple.UIKit.activity.Print true")
    app.wait_log(r"print options for “Controllers”")
    assert moving is not None
    assert app.quit() == 0
