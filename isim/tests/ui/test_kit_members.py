"""Small UIKit members (HelloKitMembers, issue #240): UIView.contentScaleFactor (the screen's scale, then set, with the
layer's contentsScale), UIButton.isHeld (a touch held on the button; the configuration update handler sees it, and it
ends with the touch), UINavigationItem.additionalOverflowItems (a deferred element in the bar's overflow menu, which
shows for it alone), UIWindowScene.isFullScreen and, on iOS 26 and later, UIView.Invalidating(.properties) running
updateProperties (os_matrix). Part 2 (issue #241): UIApplication.isDefault(_:) (iOS 18.2), NSItemProvider's
preferredPresentationStyle, UITextInput's supportsAdaptiveImageGlyph (iOS 18), UIPointerLockState.DidChangeMessage
(iOS 26) and a paste into a UISearchTextField that its paste delegate turns into a search token."""
import pytest


@pytest.mark.os_matrix
def test_kit_members(launch, ios):
    v = int(str(ios[0] or "18").split(".")[0])
    app = launch("HelloKitMembers")
    app.wait_log(r"^contentScaleFactor default=true$")
    app.wait_log(r"^contentScaleFactor set=1\.0 layer=1\.0$")
    app.wait_log(r"^configuration value title=Hold me copy=Copy button=Hold me equal=false same=true$")   # a struct (#487)
    app.wait_log(r"^isFullScreen=true$")
    if v >= 26:
        app.wait_log(r"^updateProperties count=1$")                    # the invalidating property changed
    else:
        assert "updateProperties" not in app.log

    app.wait_view(r"id=hold")
    x, y = app.find(id="hold").center
    app.drag(x, y, x + 1, y, 0.05, hold=1.2)                           # touch and hold
    app.wait_log(r"^held true$")
    app.wait_log(r"^held false$")                                      # released

    app.wait_log(r"^presentationStyle=attachment$")
    app.wait_log(r"^tokens=1 text=$")                                  # the pasted text became a token
    if v >= 18:
        app.wait_log(r"^supportsAdaptiveImageGlyph=true$")
    if v >= 26:                                                        # isDefault(_:) is iOS 18.2
        app.wait_log(r"^isDefault browser=false$")                     # Settings: no default browser chosen
        app.wait_log(r"^pointerLockMessage name=true$")

    app.wait_tap_id("nav-overflow")                                    # the additional items' overflow menu
    app.wait_tap_id("menu-Extra action")
    app.wait_log(r"^extra action$")
    assert app.quit() == 0, "exits cleanly"
