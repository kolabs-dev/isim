"""iOS 27.1 SwiftUI APIs for foldable devices on isim's devices, none of which folds (HelloSwiftUIFoldable):
onHingeChange is never called (no hinge), GeometryProxy.reservedRegions gives the Dynamic Island's occlusion in the
view's space (the same with .fixed in a left-to-right layout, mirrored with .mirrors(in: .leftToRight)) and no
division, \\.toolbarVerticalEdge is nil, \\.splitArrangementAxis is the split's axis inside an ArrangementView (nil
outside one) and \\.overlayArrangementZIndex orders an overlay (primary 1 on top, secondary 0); the vertical bar
modifiers and a CameraCaptureAccessory change nothing. Before 27.1 the APIs are unavailable."""
import pytest


@pytest.mark.os_matrix
def test_swiftui_foldable_unavailable(launch, ios):
    app = launch("HelloSwiftUIFoldable")                               # every matrix version is before 27.1
    app.wait_log(r"^fold ios27\.1 no$")
    assert app.quit() == 0


def test_swiftui_foldable(launch):
    app = launch("HelloSwiftUIFoldable", device="iphone17", os_version="27.1")
    app.wait_log(r"^fold ios27\.1 yes edge nil$")
    app.wait_log(r"^fold region dynamic-island occlusion 138 11 125 37 active true$")
    app.wait_log(r"^fold regions occlusion 1 fixed-same true ltr-mirrored-x 138 division 0$")
    app.wait_log(r"^fold outside axis none z 0$")
    app.wait_log(r"^fold primary axis vertical z 0$")                # compact width, portrait: stacked
    app.wait_log(r"^fold secondary axis vertical z 0$")
    app.wait_view(r"id=axis-primary text=primary vertical z0")
    app.wait_tap_id("toggle")
    app.wait_log(r"^fold overlay true$")
    tree = app.wait_view(r"id=axis-primary text=primary none z1")
    assert "id=axis-secondary text=secondary none z0" in tree, tree
    assert tree.index("id=axis-secondary") < tree.index("id=axis-primary"), "the primary (z 1) above the secondary"
    assert "hinge changed" not in app.log and "camera accessory available" not in app.log, \
        "no hinge change and no camera accessory on a device that does not fold"
    app.wait_view(r"id=hinge text=hinge changes 0")
    assert app.quit() == 0


def test_swiftui_foldable_landscape(launch):
    app = launch("HelloSwiftUIFoldable", device="iphone17", os_version="27.1")
    app.wait_log(r"^fold primary axis vertical z 0$")
    app.send("rotate landscapeleft")
    app.wait_view(r"id=axis-primary text=primary horizontal z0")      # landscape: side by side
    assert app.quit() == 0
