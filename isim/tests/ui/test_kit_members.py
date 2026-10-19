"""Small UIKit members (HelloKitMembers, issue #240): UIView.contentScaleFactor (the screen's scale, then set, with the
layer's contentsScale), UIButton.isHeld (a touch held on the button; the configuration update handler sees it, and it
ends with the touch), UINavigationItem.additionalOverflowItems (a deferred element in the bar's overflow menu, which
shows for it alone), UIWindowScene.isFullScreen and, on iOS 26 and later, UIView.Invalidating(.properties) running
updateProperties (os_matrix)."""
import pytest


@pytest.mark.os_matrix
def test_kit_members(launch, ios):
    v = int(str(ios[0] or "18").split(".")[0])
    app = launch("HelloKitMembers")
    app.wait_log(r"^contentScaleFactor default=true$")
    app.wait_log(r"^contentScaleFactor set=1\.0 layer=1\.0$")
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

    app.wait_tap_id("nav-overflow")                                    # the additional items' overflow menu
    app.wait_tap_id("menu-Extra action")
    app.wait_log(r"^extra action$")
    assert app.quit() == 0, "exits cleanly"
