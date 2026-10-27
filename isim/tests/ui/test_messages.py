"""iOS 26 typed notification messages (HelloMessages): UIKit's messages (app active, window key, keyboard frames, text
field changes and end-editing reason, table selection, Bold Text, the user's screenshot via `takescreenshot`), an
app's own MainActorMessage (Swift and old-style observers, removeObserver) and AsyncMessage (an async sequence);
Foundation's messages (UndoManager, UserDefaults, FileHandle, TimeZone) and ProgressManager (properties, reporters, the
bridge to Progress)."""
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
    for line in ("msg undo group closed discardable false", "msg undo will undo", "msg time zone changed from Europe/Lisbon"):
        assert line in log, f"Foundation message: {line}"
    app.wait_log(r"^msg defaults changed$")                             # UserDefaults.DidChangeMessage, async sequence
    app.wait_log(r"^msg file read hello file$")                         # FileHandle.ReadCompletionMessage
    assert "msg progress fraction 0.25 files 4 bytes 512 throughput [100] pages 2.5" in log, "properties and summaries"
    assert "msg progress child finished fraction 0.5 files 4 throughput [] completed 2" in log, "a finished child's summary"
    assert "msg progress reporter share fraction 0.625 child total 2" in log, "a share assigned to a reporter"
    assert "msg progress legacy child fraction 0.875 finished false" in log, "a share assigned to a Progress"
    assert "msg progress done fraction 1.0 finished true reporter true" in log
    assert "msg progress bridged parent 0.2" in log and "msg progress bridged parent finished share 0.4" in log, \
        "a subprogress of a Progress"
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
