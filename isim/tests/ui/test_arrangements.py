"""iOS 27.1 UIKit for foldable devices on isim's devices, none of which folds (HelloArrangements):
UIArrangementViewController split (stacked in compact width portrait, side by side on iPad; a primary asking for
240 pt / 30% with the higher layout priority; restricted to the vertical axis) and overlay (the primary layered over
the secondary), view states and placements, arrangementViewController; UIHingeInteraction (called with a nil hinge);
reserved regions (the Dynamic Island occludes on iPhone 17, nothing on the iPad Pro; no division); the vertical bar
(unspecified edge, preferredVerticalBarBehavior resolved through childForPreferredVerticalBarBehavior, axisBehavior,
verticalBarCompressionBehavior); layout regions (safe area, margins, a 44 pt bar strip along the leading edge).
Before 27.1 the APIs are unavailable."""
import pytest
from isimtest import screen_frames


@pytest.mark.os_matrix
def test_arrangements_unavailable(launch, ios):
    app = launch("HelloArrangements")                                  # every matrix version is before 27.1
    app.wait_log(r"^harr ios27\.1 no$")
    assert app.quit() == 0


def test_arrangements_iphone(launch):
    app = launch("HelloArrangements", device="iphone17", os_version="27.1")
    app.wait_log(r"^harr ios27\.1 yes$")
    app.wait_log(r"^harr hinge nil$")
    app.wait_log(r"^harr initial primary hidden false axis vertical z 0 frame 0 0 402 437$")
    app.wait_log(r"^harr initial secondary hidden false axis vertical z 0 frame 0 437 402 437$")
    app.wait_log(r"^harr placement true true$")
    app.wait_log(r"^harr occlusion 1 dynamic-island 138 11 125 37 active true$")
    app.wait_log(r"^harr division 0$")
    app.wait_log(r"^harr safe area region true margins true$")
    app.wait_log(r"isim: vertical bar behavior disabled \(from HelloArrangements\.PlayerViewController")
    app.wait_log(r"^harr arrangement parent true$")
    app.wait_log(r"^harr vertical bar edge unspecified traits 3$")
    app.wait_log(r"^harr axis behavior true compression true$")
    tree = app.wait_view(r"id=bar-guide")
    f = screen_frames(tree)
    assert "id=add-item" in tree or "add-item" in tree, "a horizontalOnly item shows: the device has horizontal bars"
    g, sec = f["bar-guide"], f["secondary-view"]
    assert g[2] == 44 and g[0] == sec[0] and g[1] >= sec[1], f"the bar region: a 44 pt strip on the leading edge of the safe area: {g} {sec}"
    app.wait_still()
    app.screenshot("split")

    app.tap_id("arrange-fixed")                                       # 30% of the height, kept by its priority
    app.wait_log(r"^harr fixed primary hidden false axis vertical z 0 frame 0 0 402 262$")
    app.wait_log(r"^harr fixed secondary hidden false axis vertical z 0 frame 0 262 402 612$")
    app.tap_id("arrange-overlay")
    app.wait_log(r"^harr overlay primary hidden false axis none z 1 frame 0 0 402 874$")
    app.wait_log(r"^harr overlay secondary hidden false axis none z 0 frame 0 0 402 874$")
    t = app.view_dump()
    assert t.index("id=secondary-view") < t.index("id=primary-view"), "overlay: the primary above the secondary"
    app.tap_id("arrange-split")
    app.wait_log(r"^harr split primary hidden false axis vertical")
    assert app.quit() == 0


def test_arrangements_ipad(launch):
    app = launch("HelloArrangements", device="ipadpro11", os_version="27.1")
    app.wait_log(r"^harr initial primary hidden false axis horizontal z 0 frame 0 0 417 1210$")
    app.wait_log(r"^harr initial secondary hidden false axis horizontal z 0 frame 417 0 417 1210$")
    app.wait_log(r"^harr occlusion 0 -$")                               # no Dynamic Island, no window controls
    app.wait_view(r"id=arrange-fixed")
    app.wait_still()
    app.tap_id("arrange-fixed")                                       # 240 pt wide
    app.wait_log(r"^harr fixed primary hidden false axis horizontal z 0 frame 0 0 240 1210$")
    app.tap_id("arrange-stacked")                                     # .split.axes(.vertical)
    app.wait_log(r"^harr stacked primary hidden false axis vertical z 0 frame 0 0 834 605$")
    app.send("rotate landscapeleft")
    app.wait_log(r"isim: arrangement split vertical primary 417 secondary 417")
    assert app.quit() == 0
