"""SwiftUI gestures (HelloSwiftUIGestures): MagnifyGesture + RotateGesture combined with simultaneously(with:) and
driven by scripted two-finger pinch / rotate2; a long press sequenced before a drag with @GestureState (the live
offset resets after the gesture, the kept position moves); a double tap exclusively before a SpatialTapGesture.
Port of tests/ui/swiftui-gestures.sh."""


def test_swiftui_gestures(launch):
    app = launch("HelloSwiftUIGestures")
    app.wait_for(id="offset")
    app.send("pinch 201 314 1.6 0.5")
    app.wait_log(r"^magnify ended 1.6")                                # MagnifyGesture from a pinch
    app.send("rotate2 201 314 30 0.5")
    app.wait_log(r"^rotate ended 30")                                  # RotateGesture simultaneously
    app.screenshot("transformed")

    app.send("longdrag 201 518 261 548 0.6 0.4")
    app.wait_log(r"^moved by 60,30")                                   # sequenced long press + drag
    app.wait_view(r"id=offset text=offset 0 live, 60 kept")            # @GestureState resets, @State keeps

    app.tap(201, 677)
    app.wait_log(r"^single tap at 100,30")
    app.tap(201, 677)
    app.tap(201, 677)
    app.wait_log(r"^double tap")
    app.sleep(0.6)                                                     # no late single tap from the double tap
    assert app.quit() == 0, "exits cleanly"
    assert app.count(r"^single tap at 100,30") == 1, "SpatialTapGesture location"
    assert app.count(r"^double tap") == 1, "double tap exclusively before single tap"
