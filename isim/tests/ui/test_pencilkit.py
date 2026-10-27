"""PencilKit (HelloPencilKit, iPad; issue #360): the Swift value types (PKStroke, PKStrokePath, PKInk, PKDrawing and
the tools) at launch; a PKCanvasView that the Apple Pencil and a finger draw on, with the tool's ink; the PKToolPicker
docked at the bottom (its items select the canvas's tool, its color button recolors the ink, the ruler toggles); the
vector eraser removing a stroke; a drawing saved and reloaded through its data; and an eraser path in code splitting
strokes."""
import pytest
from isimtest import near, rgb


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_pencilkit(launch, ios):
    app = launch("HelloPencilKit", device="ipadpro11", os_version=ipad_os(ios))
    major = int(str(ios[0] or 18).split(".")[0])
    items = major >= 18                                                 # tool picker items (selectedToolItemIdentifier): iOS 18
    app.wait_log(r"swift: path of 5 points, 9 points every 25 pt, mid x 140")
    app.wait_log(r"swift: drawing of 2 strokes, bounds y 296, reads back true, first ink marker")
    app.wait_log(r"swift: pen width clamps to 25 \(range 25\), eraser 20")
    app.wait_log(r"swift: latest content version 5")
    app.wait_log(r"picker visible true, obscures \d+ pt")
    c = app.wait_for(id="canvas")
    y = c.y + 200
    app.send(f"pencil {c.x + 60} {y} {c.x + 500} {y} 0.4 2 0.9")    # the Pencil draws with the canvas's pen
    app.wait_log(r"began using pen width 6")
    app.wait_log(r"drawing changed: 1 strokes \[pen\]")
    app.wait_still()
    shot = app.screenshot("pencilkit-pen")
    assert near(rgb(shot, c.x + 280, y), (0, 122, 255), 60), rgb(shot, c.x + 280, y)    # system blue

    app.wait_tap_id("PKToolPicker.com.apple.ink.marker")              # the picker's marker, then its next color
    if items:
        app.wait_log(r"picker tool: com.apple.ink.marker")
    app.wait_tap_id("PKToolPicker.color")
    if items:
        app.wait_log(r"picker tool: com.apple.ink.marker", count=2)
    app.drag(c.x + 60, y + 150, c.x + 500, y + 150, 0.4)               # a finger draws too (any input)
    app.wait_log(r"began using marker width 15")
    app.wait_log(r"drawing changed: 2 strokes \[pen marker\]")

    app.wait_tap_id("PKToolPicker.com.apple.tool.ruler")
    app.wait_log(r"ruler active true")
    app.wait_tap_id("PKToolPicker.com.apple.tool.ruler")
    app.wait_log(r"ruler active false")

    app.wait_tap_id("save")                                           # the data representation round trip
    app.wait_log(r"saved \d+ bytes, reloaded 2 strokes")

    app.wait_tap_id("PKToolPicker.com.apple.tool.eraser.vector")      # the vector eraser removes the whole marker stroke
    if items:
        app.wait_log(r"picker tool: com.apple.tool.eraser.vector")
    app.drag(c.x + 280, y + 120, c.x + 280, y + 180, 0.3)
    app.wait_log(r"began using eraser vector")
    app.wait_log(r"drawing changed: 1 strokes \[pen\]", count=2)

    app.wait_tap_id("PKToolPicker.com.apple.ink.pen")                 # a vertical stroke across the middle, then a band erased in code
    m = c.y + c.h / 2
    app.drag(c.x + 700, m - 150, c.x + 700, m + 150, 0.4)
    app.wait_log(r"drawing changed: 2 strokes \[pen pen\]")
    if major < 26:                                                      # PKDrawing.erasePath: iOS 26
        app.wait_tap_id("erase-band")
        app.wait_log(r"erasing in code needs iOS 26")
        app.wait_tap_id("clear")
        app.wait_log(r"drawing changed: 0 strokes \[\]", count=2)
        assert app.quit() == 0
        return
    app.wait_tap_id("erase-band")
    app.wait_log(r"drawing changed: 3 strokes \[pen pen pen\]")
    app.wait_still()
    shot = app.screenshot("pencilkit-erased")
    assert near(rgb(shot, c.x + 700, m), (255, 255, 255), 30), rgb(shot, c.x + 700, m)          # the band is blank
    assert not near(rgb(shot, c.x + 700, m - 100), (255, 255, 255), 30)                          # the stroke above it stays

    app.wait_tap_id("clear")
    app.wait_log(r"drawing changed: 0 strokes \[\]", count=2)      # (the reload cleared it once)
    assert app.quit() == 0
