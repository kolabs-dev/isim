"""Part 11 of #9 (HelloDragDrop -extras, iPad): Auto Layout extras and new traits; text drag and drop between text views
(the text drag and drop delegates); a table drop through a placeholder row; a spring-loaded button under a resting
drag; hover styles on the iPad pointer; a paste delegate; a UIKit trait bridged into SwiftUI's environment."""
import re


def test_drag_extras(launch):
    app = launch("HelloDragDrop", args=["-extras"], device="ipadpro11")
    app.wait_log(r"^dg ready$")
    log = app.log
    assert "dg offset gap 30" in log                                     # anchorWithOffset(to:) as a dimension
    assert "dg tracking near true away true listed 1" in log             # the keyboard guide is near the bottom
    assert "dg tracking removed false false" in log
    assert "dg archived true priorities 510 500" in log
    assert "dg traits capture 0 range true language ja changed 1 force true" in log
    assert "dg mutations true true" in log
    assert "dg text drag enabled true drop true" in log
    app.wait_log(r"^dg bridged bonjour$")                                 # UITraitBridgedEnvironmentKey

    # the selected word dragged from one text view into another
    m = re.search(r"dg beta at (\d+) (\d+)", log)
    x, y = int(m.group(1)), int(m.group(2))
    app.send(f"longdrag {x} {y} 240 400 0.8 0.6")
    app.wait_log(r"isim: text drag of \"beta\"")
    app.wait_log(r"^dg text drag request selected true items 1$")
    app.wait_log(r"^dg text drop same view false$")
    app.wait_log(r'isim: text drop inserted "beta"')
    app.wait_log(r"^dg target start beta$")
    app.wait_log(r"^dg text drag ended copy notes alpha beta gamma$")

    # a drop on the table: a placeholder row, then the committed insertion
    app.send("longdrag 120 142 630 300 0.8 0.6")
    app.wait_log(r"isim: drop placeholder at 0/2")
    app.wait_log(r"^dg placeholder committed true rows one,two,three$")

    # a drag resting on a spring-loaded button fires it
    app.send("longdrag 120 142 540 462 0.8 0.5 1.5")
    app.wait_log(r"isim: spring-loaded UIButton activated")
    app.wait_log(r"^dg spring button fired$")

    # hover styles: the pointer's highlight platter behind the view
    app.send("hover 120 540")
    app.wait_for(id="isim-pointer-effect")
    # the pointer's shape lies on the view (its own coordinates), not offset by the view's origin a second time
    white = lambda p: all(c > 240 for c in p[:3])
    app.wait_shot(lambda s: not white(s.getpixel((120, 540))) and white(s.getpixel((160, 1040))), "the hover shape on the view")
    app.send("hover")

    # the paste delegate transforms what is pasted
    app.wait_tap_id("pastebtn")
    app.wait_log(r"isim: pasted 1 item\(s\) through the paste delegate: \"SHOUT\"")
    app.wait_log(r"^dg pasted field SHOUT$")
