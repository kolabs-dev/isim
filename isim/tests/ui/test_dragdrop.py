"""Drag and drop (HelloDragDrop): `longdrag` lifts a UIDragInteraction source after a long press and drops on a
UIDropInteraction (enter, copy proposal, loadObjects(ofClass: String.self), drop location); a table row dragged onto
another row reorders through the data source's moveRowAt; text dragged onto the table is inserted by performDrop at the
destination row; SwiftUI .draggable / .dropDestination(for: String.self). Port of tests/ui/dragdrop.sh."""


def test_dragdrop(launch):
    app = launch("HelloDragDrop")
    app.wait_view(r"id=source\b")
    app.wait_view(r"id=swiftui-target\b")
    app.send("longdrag 95 105 296 130 0.7 0.5")
    app.wait_log(r"^drag begins from source")
    app.wait_log(r"drag began with 1 item")                          # long press lifts the drag item
    app.wait_log(r"^zone entered")
    app.wait_log(r"^dropped: Swift at 86,50")
    app.wait_log(r"^drag ended with copy")                           # drop interaction: enter + performDrop

    app.send("longdrag 200 222 200 310 0.7 0.5")
    app.wait_log(r"^row drag begins: A")
    app.wait_log(r"^order: B C A D")                                 # table rows reorder by dragging

    app.send("longdrag 95 105 200 354 0.7 0.5")
    app.wait_log(r"^inserted Swift at 3: B C A Swift D")             # drop onto the table inserts a row

    app.send("longdrag 201 481 201 568 0.7 0.5")
    app.wait_log(r'^swiftui dropped \["SwiftUI tag"\]')              # SwiftUI draggable -> dropDestination
    app.wait_view(r"id=row-Swift\b")

    app.send("longdrag 95 105 95 700 0.7 0.3")
    app.wait_log(r"isim: drag cancelled")
    app.wait_log(r"^drag ended with cancel")                         # drop on nothing cancels
    assert app.quit() == 0
