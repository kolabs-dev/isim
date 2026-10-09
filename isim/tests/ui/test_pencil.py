"""Apple Pencil, the iPad pointer and UIKit Dynamics rotation (HelloPencil, iPad): Pencil strokes are Pencil touches
(type, force, altitude, azimuth) while finger touches stay direct; double-tap and squeeze reach UIPencilInteraction
(the iOS 17.5 delegate, with the hover pose while hovering); a hovering Pencil has a zOffset; pointer styles draw their
shape (rounded rect, beam with arrow accessories, the I-beam over text); a box landing on a ledge with one corner
spins."""
import pytest


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_pencil(launch, ios):
    app = launch("HelloPencil", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"pencil preferred tap action 1, only drawing false")
    c = app.wait_for(id="canvas")
    y = c.y + c.h / 2
    app.send(f"pencil {c.x + 40} {y} {c.x + 300} {y + 60} 0.4 2.5 0.9")
    app.wait_log(r"canvas: pencil began force 2.50 of 4.17 altitude 0.90 azimuth 0.23")
    app.wait_log(r"canvas: stroke of \d+ points \(pen\)")
    app.drag(c.x + 40, y + 100, c.x + 200, y + 100, 0.3)                # a finger does not draw
    app.wait_log(r"canvas: finger ignored")
    app.wait_still()
    app.screenshot("pencil-stroke")

    app.send("pencil tap")                                              # double-tap: the preferred action (switch to eraser)
    app.wait_log(r"isim: Apple Pencil double-tap \(preferred action switchEraser\) to 1 interaction\(s\)")
    app.wait_log(r"pencil double-tap: Tool: eraser \(hovering false\)")
    app.send("pencil squeeze")
    app.wait_log(r"pencil squeeze phase 0")
    app.wait_log(r"pencil squeeze phase 2")
    app.send(f"pencil hover {c.x + 100} {y} 0.4")                       # a hovering Pencil
    app.wait_log(r"hover z 0.40")
    app.send("pencil tap")
    app.wait_log(r"pencil double-tap: Tool: pen \(hovering true\)")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_pointer_shapes_and_dynamics(launch, ios):
    app = launch("HelloPencil", device="ipadpro11", os_version=ipad_os(ios))
    s = app.wait_for(id="shaped")
    app.send(f"hover {s.x + 50} {s.y + 40}")                            # a rounded rect around the view (with lift)
    app.wait_log(r"isim: pointer shape rounded rect")
    b = app.wait_for(id="beam")
    app.send(f"hover {b.x + 60} {b.y + 30}")                            # a horizontal beam with arrows
    app.wait_log(r"isim: pointer shape beam")
    app.wait_still()
    app.screenshot("pointer-beam")
    f = app.wait_for(id="field")
    app.send(f"hover {f.x + 40} {f.y + f.h / 2}")                       # editable text: the I-beam
    app.wait_log(r"isim: pointer shape beam", count=2)
    app.send("hover off")

    app.wait_tap_id("drop")                                             # one corner lands on the ledge: the box spins
    app.wait_log(r"box turned -?\d\.\d\d rad")
    app.wait_still()
    app.screenshot("dynamics-spin")
    assert app.quit() == 0
