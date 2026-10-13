"""iOS 26 typed notification messages (HelloMessages): UIKit's messages (app active, window key, keyboard frames, text
field changes and end-editing reason, table selection, Bold Text, the user's screenshot via `takescreenshot`), an
app's own MainActorMessage (Swift and old-style observers, removeObserver) and AsyncMessage (an async sequence)."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_messages(launch, ios):
    app = launch("HelloMessages")
    if major(ios) < 26:
        app.wait_log(r"^msg ready \(no messages before iOS 26\)$")
        assert app.quit() == 0
        return
    app.wait_log(r"^msg ready$")
    log = app.log
    assert "msg cart 2" in log and "msg cart notification 2" in log, "a posted message reaches Swift and notification observers"
    assert "msg cart 3" not in log and "msg cart notification 3" not in log, "removeObserver stops both"
    assert "msg download a.zip" in log, "an async message read from messages(for:)"
    app.wait_log(r"^msg app active$")
    app.tap_id("field")
    app.wait_log(r"^msg keyboard will show height [1-9]\d+ duration true local true$")
    app.type("hi")
    app.wait_log(r"^msg text hi$")
    app.tap_id("row1")
    app.wait_log(r"^msg selection 1$")
    app.wait_log(r"^msg end editing reason true$")                     # the sample ends editing on a selection
    app.send("boldtext on")
    app.wait_log(r"^msg bold text true$")
    app.send("takescreenshot")
    app.wait_log(r"^msg screenshot$")
    assert app.quit() == 0
