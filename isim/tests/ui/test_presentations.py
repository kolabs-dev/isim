"""SwiftUI modal presentations (HelloPresentations): sheet with environment object and dismiss, alert with roles +
message, confirmationDialog, fullScreenCover, sheet(item:). Port of tests/ui/presentations.sh."""
import pytest


@pytest.mark.os_matrix
def test_presentations(launch, ios):
    if ios[0] == "17":
        pytest.skip("not run under iOS 17 (as in the shell suite)")
    app = launch("HelloPresentations")
    app.wait_tap_id("open-sheet")
    app.wait_log(r"showSheet true")
    sheet = app.wait_view(r"\(20 44; 362 x 52\) text=Sheet")              # sheet presents with a large title
    assert "text=Sheet count 0" in sheet, "sheet presents with large title"
    app.tap_id("sheet-inc")
    app.wait_log(r"count 1")                                           # the sheet sees the environment object
    app.tap_id("sheet-close")
    app.wait_log(r"showSheet false")                                   # dismiss() closes the sheet + onDismiss
    app.wait_log(r"sheet dismissed")

    app.wait_tap_id("open-alert")
    alert = app.wait_view(r"id=alert-Cancel")
    assert "text=Delete everything?" in alert and "text=This cannot be undone." in alert, \
        "alert with title, message and roles"
    app.tap_id("alert-Delete")
    app.wait_log(r"alert: delete")                                     # alert action runs

    app.wait_tap_id("open-dialog")
    app.wait_view(r"text=Small")
    app.tap_text("Small")
    app.wait_log(r"dialog: small")                                     # confirmationDialog action runs

    app.wait_tap_id("open-cover")
    app.wait_view(r"id=cover-close")                                   # fullScreenCover presents
    app.tap_id("cover-close")
    app.wait_view(r"id=cover-close", gone=True)
    app.wait_tap_id("open-item")
    app.wait_view(r"text=Fruit: kiwi")                                 # sheet(item:) shows the item
    assert app.quit() == 0, "exits cleanly"
