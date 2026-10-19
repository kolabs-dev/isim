"""Drag and drop (HelloDragDrop): `longdrag` lifts a UIDragInteraction source after a long press and drops on a
UIDropInteraction (enter, copy proposal, loadObjects(ofClass: String.self), drop location); a table row dragged onto
another row reorders through the data source's moveRowAt; text dragged onto the table is inserted by performDrop at the
destination row; SwiftUI .draggable / .dropDestination(for: String.self) and onDrop(of:delegate:). Port of
tests/ui/dragdrop.sh."""
from isimtest import screen_frames


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

    f = screen_frames(app.view_dump())
    src, dst = f["swiftui-source"], f["swiftui-target"]
    app.send(f"longdrag {src[0] + src[2] / 2} {src[1] + src[3] / 2} {dst[0] + dst[2] / 2} {dst[1] + dst[3] / 2} 0.7 2")
    lifted = app.wait_view(r"id=isim-drag-custom-preview")          # draggable(_:preview:): the custom preview lifts
    app.wait_log(r'^swiftui dropped \["SwiftUI tag"\]')              # SwiftUI draggable -> dropDestination
    assert "text=Moving tag" in lifted, "the preview's content"
    app.wait_view(r"id=row-Swift\b")

    app.send("longdrag 95 105 95 700 0.7 0.3")
    app.wait_log(r"isim: drag cancelled")
    app.wait_log(r"^drag ended with cancel")                         # drop on nothing cancels
    assert app.quit() == 0


def test_drop_delegate(launch):
    """onDrop(of:delegate:): the DropDelegate validates the drag, hears it enter, proposes a move and performs the drop
    (its DropInfo has the location and the item providers)."""
    app = launch("HelloDragDrop")
    f = screen_frames(app.wait_view(r"id=delegate-target\b"))
    sx, sy, sw, sh = f["swiftui-source"]
    tx, ty, tw, th = f["delegate-target"]
    app.send(f"longdrag {sx + sw / 2} {sy + sh / 2} {tx + tw / 2} {ty + th / 2} 0.7 2")
    app.wait_log(r"^delegate entered")
    app.wait_log(r"^delegate drop 1 at 181,30")
    app.wait_log(r"^delegate dropped SwiftUI tag")
