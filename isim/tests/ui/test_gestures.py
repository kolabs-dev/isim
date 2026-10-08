"""Gestures and hardware input (HelloGestures): require(toFail:) single vs double tap, swipe directions, a custom
UIGestureRecognizer subclass (began/changed/ended, fails when the finger wanders), UIScreenEdgePanGestureRecognizer,
UIKeyCommand (Cmd+R, arrow), pressesBegan with UIKey, shake motion events. Port of tests/ui/gestures.sh."""


def test_gestures(launch):
    app = launch("HelloGestures")
    app.tap(200, 250)
    app.wait_log(r"^single tap")                                       # fires once the double tap fails
    app.tap(200, 250)
    app.tap(200, 250)
    app.wait_log(r"^double tap")                                       # double tap wins over single tap

    app.drag(330, 250, 80, 250, 0.15)
    app.wait_log(r"^swipe left")
    app.drag(80, 250, 330, 250, 0.15)
    app.wait_log(r"^swipe right")

    app.drag(200, 450, 210, 455, 0.3)
    app.wait_log(r"^still ended after [1-9][0-9]* moves")              # custom recognizer: began..ended
    app.drag(200, 450, 330, 460, 0.3)
    app.wait_log(r"^still began", count=2)
    app.drag(200, 600, 260, 600, 0.3)                                  # a pan away from the edge: no edge pan
    app.drag(2, 600, 250, 600, 0.4)
    app.wait_log(r"panel open")
    panel = app.wait_view(r"UIView \(0 540; 260 x 200\) id=panel")
    app.screenshot("panel")

    for k in ("keydown cmd", "keydown r", "keyup r", "keyup cmd"):
        app.send(k)
    app.wait_log(r"^command R")
    for k in ("keydown r", "keyup r", "keydown up", "keyup up", "keydown a", "keyup a"):
        app.send(k)
    app.wait_log(r"^pressed a code 4")                                 # pressesBegan with UIKey
    app.send("shake")
    app.wait_log(r"^shake ended")
    assert app.quit() == 0, "exits cleanly"

    assert app.count(r"^single tap") == 1, "single tap fires once double tap fails"
    assert app.count(r"^still began") == 2 and app.count(r"^still ended") == 1, "custom recognizer fails on wander"
    assert app.count(r"^edge pan began") == 1, "edge pan only from the screen edge"
    assert app.count(r"^command R") == 1 and "pressed r code 21" in app.log, "key command Cmd+R (not plain R)"
    assert app.count(r"^arrow up") == 1, "key command arrow up"
    assert app.count(r"^shake began") == 1, "shake motion events"
