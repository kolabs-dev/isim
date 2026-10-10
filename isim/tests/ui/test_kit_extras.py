"""Smaller UIKit APIs from the documentation sweep (#9) in HelloKitExtras: stack view baseline spacing, flushUpdates,
UIUpdateLink's phases, the large content viewer's additions, letterform-aware sizing, item provider additions, private
click measurement (script `attributions`), full-page screenshots (script `fullpage`), renderer subclassing, motion
effects (script `tilt`), UIKit Dynamics fields and attachments, geometry values; on iPad tooltips (script `hover`),
band selection and pointer-only gesture recognizers (script `pointerdrag`)."""
import pytest
from isimtest import rgb


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_kit_extras(launch, ios, tmp_path):
    v = major(ios)
    app = launch("HelloKitExtras")
    app.wait_log(r"^hx dynamics field moved")
    log = app.log
    assert "hx custom spacing default true" in log and "hx custom spacing set 30" in log, "customSpacing(after:)"
    assert "hx motion effects 1 values 30" in log, "an interpolating effect gives its maximum at full tilt"
    assert "hx lcv exclusion UILongPressGestureRecognizer scales true insets 2" in log
    assert "hx letterform typographic true taller true" in log, "the oversize rule makes room for stacked marks"
    assert "hx label baseline true vibrancy true strategy true expansion false" in log
    assert "hx image view range true drawn true" in log
    assert "hx presentation size 30x20" in log, "an image gives its size to the item provider"
    assert "hx note can load true" in log
    app.wait_log(r"^hx note loaded augmented: hello$")                  # the augmenter reads plain text for Note
    assert "hx format scale 2 hdr false" in log
    assert "hx stamp context StampContext cg true" in log and "hx stamp completion" in log, "runDrawingActions in the subclass's context"
    assert "hx values insets true offset true zero true" in log
    assert "hx strings rect {{1, 2}, {3, 4}} back true offset {1, 2}" in log
    assert "hx coder point true insets true" in log
    assert "hx region contains true outside false inverse true" in log
    assert "hx dynamics field moved true slider stays true" in log, "a linear gravity field and a sliding attachment"
    assert "hx tooltip Delete item interaction true" in log
    assert "hx tap mask primary true pan scroll types 0 press types 7" in log and "hx button mask 2 true" in log
    assert "hx screenshot service true" in log
    if v >= 18:
        app.wait_log(r"^hx update info inside true$")
        assert ("hx phases afterUpdateScheduled,beforeEventDispatch,afterEventDispatch,beforeCADisplayLinkDispatch,"
                "afterCADisplayLinkDispatch,beforeCATransactionCommit,afterCATransactionCommit,afterUpdateComplete") in app.log, \
            "UIUpdateLink runs the phases in order (no low-latency phases)"
        assert "hx update info outside true" in app.log
    if v >= 26:
        assert "hx flush width 80" in app.log, "flushUpdates applies the pending layout before the block"
        assert "hx animator flush true" in app.log

    # private click measurement: opened without a tap it is dropped, after a tap on the attribution view recorded
    assert "isim: event attribution for shop.example.com dropped" in app.log
    app.tap_id("ad")
    app.wait_log(r"isim: event attribution recorded: source 7 purchaser \"Example Shop\" destination shop.example.com report ads.example.com")
    app.send("attributions")
    app.wait_log(r"isim: attributions 1$")

    # full-page screenshot: the delegate's PDF is written
    pdf = tmp_path / "page.pdf"
    app.send(f"fullpage {pdf}")
    app.wait_log(r"isim: full page .*page\.pdf \(\d+ bytes\) page 0 rect 0,0 300x400")
    assert pdf.read_bytes()[:5] == b"%PDF-", "a PDF"

    # motion effects: tilting moves the red square right (center.x +30 at full tilt)
    def red(s, x, y):
        c = rgb(s, x, y)
        return c[0] > 200 and c[1] < 100
    before = app.screenshot()
    assert red(before, 205, 120) and not red(before, 255, 120), "the square at rest"
    app.send("tilt 1 0")
    app.wait_log(r"isim: tilt 1\.00 0\.00")
    app.wait_shot(lambda s: red(s, 255, 120) and not red(s, 205, 120), "the square moved right")
    app.send("tilt 0 0")
    app.wait_shot(lambda s: red(s, 205, 120) and not red(s, 255, 120), "back at rest")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_kit_extras_ipad(launch, ios):
    app = launch("HelloKitExtras", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"^hx start ipad true$")
    app.wait_log(r"^hx dynamics field moved")
    # tooltips: a control's toolTip, a delegate's configuration (left half only), a truncated label
    app.send("hover 160 380")
    app.wait_log(r'isim: tooltip "Delete item"')
    app.send("hover 60 480")
    app.wait_log(r'isim: tooltip "Left half"')
    app.send("hover 240 480")                                           # right half: no tooltip there
    app.send("hover 250 370")
    app.wait_log(r'isim: tooltip "A label far too long to fit"')
    app.send("hover off")
    assert app.log.count('isim: tooltip "Left half"') == 1, "the left half's tooltip goes when the pointer leaves its rect"
    # band selection: pointer drags only, shift held when it starts, not over the right part (shouldBeginHandler)
    app.send("drag 40 440 140 520 0.5")                                  # a finger: no band
    app.send("keydown shift")
    app.send("pointerdrag 40 440 140 520 0 0.5")
    app.wait_log(r"^hx band ended 100x80 shift true$")
    app.send("keyup shift")
    assert "hx band began 0x0 shift true" in app.log and "hx band selecting" in app.log
    assert app.log.count("hx band began") == 1, "a finger drag starts no band"
    app.send("pointerdrag 230 440 260 520 0 0.5")                        # shouldBeginHandler says no
    app.wait_still()
    assert app.log.count("hx band began") == 1
    # a pan that only takes pointer touches; the event's button mask is primary for a pointer
    app.send("drag 40 600 200 600 0.5")
    app.send("pointerdrag 40 600 200 600 0 0.5")
    app.wait_log(r"^hx pointer pan began mask 1$")
    assert app.log.count("hx pointer pan began") == 1, "the finger drag did not reach the pointer-only pan"
    assert "hx should receive pointer event mask 1" in app.log
    assert app.quit() == 0
