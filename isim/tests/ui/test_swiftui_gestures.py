"""SwiftUI gestures (HelloSwiftUIGestures): MagnifyGesture + RotateGesture combined with simultaneously(with:) and
driven by scripted two-finger pinch / rotate2; a long press sequenced before a drag with @GestureState (the live
offset resets after the gesture, the kept position moves); a double tap exclusively before a SpatialTapGesture.
Port of tests/ui/swiftui-gestures.sh."""
import re


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


def test_gesture_priority(launch):
    """Nested gestures: a child's tap wins over its parent's .gesture; highPriorityGesture wins over the child's;
    simultaneousGesture fires with it; masks (.gesture: the subviews' off, .subviews: its own off, isEnabled: false)."""
    app = launch("HelloSwiftUIGestures", env={"PAGE": "priority"})
    app.wait_for(id="drag-child")
    dump = app.view_dump()

    def rect(ident):
        """the window frame of a view in the dump (its frame plus its ancestors' origins)"""
        lines = dump.splitlines()
        i = next(k for k, line in enumerate(lines) if f" id={ident}" in line)
        num = lambda line: [float(v) for v in re.search(r"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\)", line).groups()]
        x, y, w, h = num(lines[i])
        depth = len(lines[i]) - len(lines[i].lstrip())
        for line in reversed(lines[:i]):
            d = len(line) - len(line.lstrip())
            if d < depth:
                depth = d
                px, py, _, _ = num(line)
                x += px; y += py
        return x, y, w, h

    def parent_tap(row):
        """the parent's leading part (the child is 80 x 40 at its trailing side, the parent 300 x 70)"""
        x, y, w, h = rect(f"{row}-child")
        app.tap(x - 120, y + h / 2)

    app.tap_id("normal-child")
    app.wait_log(r"^normal child")
    parent_tap("normal")
    app.wait_log(r"^normal parent")
    app.tap_id("high-child")
    app.wait_log(r"^high parent")
    app.tap_id("simul-child")
    app.wait_log(r"^simul child")
    app.wait_log(r"^simul parent")
    app.tap_id("own-child")
    app.wait_log(r"^own parent")
    app.tap_id("subviews-child")
    app.wait_log(r"^subviews child")
    parent_tap("subviews")
    app.tap_id("off-child")
    app.wait_log(r"^off child")
    parent_tap("off")
    app.tap_id("drag-child")
    app.wait_log(r"^drag child")                                       # a drag around a tap: the tap still fires
    cx, cy, _, _ = rect("drag-child")
    app.drag(cx + 10, cy + 20, cx - 120, cy + 20, 0.3)
    app.wait_log(r"^drag parent")                                      # the drag recognizes once the tap fails
    app.sleep(0.6)                                                     # no late taps from the waiting gestures
    assert app.quit() == 0, "exits cleanly"
    assert app.count(r"^normal parent") == 1, "a child's gesture wins over its parent's: the parent's fires only outside it"
    assert app.count(r"^high child") == 0, "highPriorityGesture wins over the child's gesture"
    assert app.count(r"^own child") == 0, "including: .gesture turns the subviews' gestures off"
    assert app.count(r"^subviews parent") == 0, "including: .subviews turns the view's own gesture off"
    assert app.count(r"^off parent") == 0, "isEnabled: false"
    assert app.count(r"^drag child") == 1, "the drag does not tap the child"
