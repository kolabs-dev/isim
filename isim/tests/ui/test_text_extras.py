"""Text field, text view, responder, text input and keyboard members (HelloTextExtras): overlay views and layout
rects, attributed placeholders and default attributes, text highlights, money and physical value detection, edit
actions on attributes, attributed text in a range, text placeholders, the lexicon, grammar checking, remote control
events, F-key commands, math expression completion, input view controllers with reloadInputViews, and the iPad
shortcuts bar."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_text_extras(launch, ios):
    v = major(ios)
    app = launch("HelloTextExtras")
    app.wait_log(r"^tx ready$")
    app.wait_log(r"^tx lexicon omw=On my way!$")
    log = app.log
    assert "tx search text rect x 28 left view 28 right view 310 shown true" in log, "the text sits after the left view"
    assert "tx padded text rect x 24 placeholder 24" in log, "a subclass's textRect(forBounds:)"
    assert "tx fancy font 18.0 placeholder Orange placeholder attributed 0" in log
    assert f"tx aligned {'true' if v >= 26 else 'false'} bold true" in log
    assert "tx placeholder rects 1" in log and "tx hardware expected true" in log
    if v >= 18:
        assert "tx attributed in range Remember" in log
        assert "tx inserted true red true" in log
        app.wait_log(r"^tx highlight drawn for milk$")
    if v >= 26:
        assert "tx can align true" in log and "tx selected ranges 1" in log
        app.wait_log(r"^tx grammar 3 fixes I,an,the$")

    # remote control events and an F-key command
    app.send("remote play")
    app.wait_log(r"^tx remote control 100 type true$")
    app.send("keydown f1; keyup f1")
    app.wait_log(r"^tx f1 help localized true$")

    # math completion (iOS 18): 12*3= offers 36
    app.wait_tap_id("math")
    app.wait_log(r"^tx math input mode en-US$")
    if v >= 18:
        app.send("type 12*3=")
        app.wait_log(r"math completion 36")
        app.wait_tap_id("isim-kb-suggestion-0")
        app.wait_log(r'math result "36" inserted')

    # an input view controller's view is the keyboard; reloadInputViews brings the keyboard back
    app.wait_tap_id("picker")
    app.wait_tap_id("pick")
    app.wait_log(r"^tx picked$")
    app.wait_for(id="isim-kb-suggestion-0")


def test_shortcuts_bar_ipad(launch, ios):
    app = launch("HelloTextExtras", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"^tx ready$")
    app.wait_tap_id("math")
    app.wait_tap_id("isim-kb-assistant-bold")
    app.wait_log(r"^tx assistant bold$")
