"""The iPad keyboard and status bar (HelloKeyboardTypes on iPad presets): the iPadOS layout (delete at the end of the
first row, return at the end of the second, shift on both sides of the third with , and . , the bottom row's .?123,
emoji, mic, space, .?123 and hide-keyboard keys, no globe / mic bar under the keys), typing with taps, shift and a
downward flick (the character above the key), the numbers plane, number pads on the numbers plane (no 3 x 4 pad), the
hide-keyboard key ending editing, the keys in the accessibility snapshot; landscape, and turning the device while the
keyboard is up; the 13" iPad Pro's extended layout (a number row, tab, caps lock, the shifted characters above the
keys); the status bar's date right of the time.
The keyboard and the status bar are system UI: os_matrix."""
import re

import pytest
from isimtest import count_px, rgb, screen_frames

SIZES = {"ipadmini": (744, 1133), "ipadpro11": (834, 1210), "ipadpro13": (1032, 1376)}
SIDE = 6                                                   # the keys' inset from the screen edges (UIKeyboard.m)


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the M4 iPad Pros need iOS 17.5


def keyboard(app, field, want="isim-kb-dismiss"):
    app.wait_tap_id(f"f-{field}")
    dump = app.wait_view(rf"^(?!.* hidden id=).* id={re.escape(want)}\b")
    return dump, screen_frames(dump)


def typed(app, name, value):
    app.wait_log(rf"^text {name}={re.escape(value)}$")


def center(f):
    return f[0] + f[2] / 2, f[1] + f[3] / 2


@pytest.mark.os_matrix
@pytest.mark.parametrize("device", ["ipadmini", "ipadpro11"])   # the 13" has the extended layout (below)
def test_ipad_keyboard_layout(launch, ios, device):
    W, H = SIZES[device]
    app = launch("HelloKeyboardTypes", device=device, os_version=ipad_os(ios), env={"ISIM_LANGUAGES": "en", "ISIM_REGION": "US"})
    dump, f = keyboard(app, "websearch")                   # letters, no keyboard-type keys
    k = lambda i: f[f"isim-kb-{i}"]
    row = lambda i: k(i)[1]
    # row 1: q .. p, delete to the right edge
    assert row("q") == row("p") == row("delete") and k("delete")[0] > k("p")[0], f"delete ends row 1: {k('p')} {k('delete')}"
    assert abs(k("delete")[0] + k("delete")[2] - (W - SIDE)) <= 1 and k("delete")[2] > k("p")[2] * 1.3, f"delete: {k('delete')}"
    # row 2: a .. l indented, a wide return to the right edge
    assert row("a") == row("l") == row("return") > row("q"), "return ends row 2"
    assert k("a")[0] > k("q")[0] + k("q")[2] / 3, f"row 2 indented: {k('q')} {k('a')}"
    assert abs(k("return")[0] + k("return")[2] - (W - SIDE)) <= 1 and k("return")[2] > k("l")[2] * 1.6, f"return: {k('return')}"
    # row 3: shift, z .. m , . , shift
    assert row("shift") == row("z") == row(",") == row(".") == row("shift-right") > row("a"), "third row"
    assert k("shift")[0] <= SIDE + 1 and k(",")[0] > k("m")[0] and k(".")[0] > k(",")[0] > k("m")[0], "shift, letters, , ."
    assert abs(k("shift-right")[0] + k("shift-right")[2] - (W - SIDE)) <= 1, f"right shift: {k('shift-right')}"
    # row 4: .?123, emoji, mic, space, .?123, hide keyboard (bottom right)
    bottom = [k(i) for i in ("123", "emoji", "dictation", "space", "123-right", "dismiss")]
    assert len({b[1] for b in bottom}) == 1 and bottom[0][1] > row("z"), f"bottom row: {bottom}"
    assert [b[0] for b in bottom] == sorted(b[0] for b in bottom), f"bottom row order: {bottom}"
    assert abs(k("dismiss")[0] + k("dismiss")[2] - (W - SIDE)) <= 1, f"hide keyboard at the bottom right: {k('dismiss')}"
    assert k("space")[2] > 3 * k("q")[2], f"wide space bar: {k('space')}"
    # no bar under the keys: the keys end just above the home indicator's 20 pt band
    end = k("dismiss")[1] + k("dismiss")[3]
    assert H - 20 - 14 <= end <= H - 20, f"keys end at {end} (screen {H})"
    # keys are about as tall as wide in portrait; the keyboard is taller than the iPhone's
    assert 0.75 < k("q")[3] / k("q")[2] < 1.3 and k("q")[3] >= 50, f"key size {k('q')}"
    img = app.screenshot("letters")
    assert all(v > 245 for v in rgb(img, *center(k("q")))), f"letter keys white: {rgb(img, *center(k('q')))}"
    assert rgb(img, W / 2 - 120, H - 10) == (209, 212, 217), f"keyboard background below the keys: {rgb(img, W / 2 - 120, H - 10)}"
    band = (30, end + 2, W / 2 - 120, H - end - 4)         # (clear of the display's rounded corner)           # left of the home indicator: no globe / mic icons
    assert count_px(img, band, lambda c: max(c) < 150) == 0, "nothing drawn under the keys"
    q = k("q")                                             # the flick character (1) small and grey above the q
    assert count_px(img, (q[0] + q[2] / 3, q[1] + 3, q[2] / 3, q[3] * 0.35), lambda c: 60 < max(c) < 200) > 3, "flick character drawn"
    assert app.quit() == 0, "exits cleanly"


@pytest.mark.os_matrix
def test_ipad_keyboard_typing(launch, ios):
    app = launch("HelloKeyboardTypes", device="ipadpro11", os_version=ipad_os(ios), env={"ISIM_LANGUAGES": "en", "ISIM_REGION": "US"})
    dump, f = keyboard(app, "websearch")
    for key in ("shift", "h", "i"):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", "Hi")
    x, y = center(f["isim-kb-,"])                          # a downward swipe on , types the ! above it
    app.drag(x, y - 8, x, y + 24, 0.2)
    typed(app, "websearch", "Hi!")
    for key in ("space", "a", "delete", "b"):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", "Hi! b")
    assert app.has(r"^text websearch=Hi! a$") and not app.has(r"^text websearch=Hi! ab$"), "delete"
    prefix = "Hi! b"
    snap = app.snapshot()                                  # the keys in the accessibility snapshot, named like iOS
    names = {(e.type, e.id) for e in snap}
    for want in (("key", "q"), ("key", "delete"), ("key", "more"), ("key", "space"), ("button", "Return"),
                 ("button", "Hide keyboard"), ("button", "Dictate"), ("button", "Emoji")):
        assert want in names, f"{want} not in the snapshot"
    # the numbers plane: 1 .. 0 and delete, @ # $ ... and return, #+= on both sides, ABC
    app.tap_id("isim-kb-123")
    dump = app.wait_view(r"^(?!.* hidden id=).* id=isim-kb-abc-right\b")
    f = screen_frames(dump)
    assert f["isim-kb-1"][1] == f["isim-kb-0"][1] == f["isim-kb-delete"][1], "digits and delete on row 1"
    assert f["isim-kb-@"][1] == f["isim-kb-return"][1] > f["isim-kb-1"][1], "symbols and return on row 2"
    assert "id=isim-kb-q" not in dump, "letters gone"
    for key in ("4", "@"):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", prefix + "4@")
    app.tap_id("isim-kb-shift")                            # #+=
    app.wait_view(r"^(?!.* hidden id=).* id=isim-kb-\[")
    app.tap_id("isim-kb-[")
    typed(app, "websearch", prefix + "4@[")
    app.tap_id("isim-kb-abc-right")
    app.wait_view(r"^(?!.* hidden id=).* id=isim-kb-q\b")
    # a number pad: the full keyboard on the numbers plane, no 3 x 4 pad
    dump, f = keyboard(app, "number", "isim-kb-abc")
    assert "id=isim-kb-phone-symbols" not in dump and "id=isim-kb-return" in dump and "id=isim-kb-0" in dump, "numbers plane"
    assert f["isim-kb-1"][1] == f["isim-kb-0"][1] and f["isim-kb-0"][0] > f["isim-kb-1"][0], "digits in a row"
    for key in "42":
        app.tap_id(f"isim-kb-{key}")
    typed(app, "number", "42")
    # the hide-keyboard key ends editing: the keyboard goes away
    app.tap_id("isim-kb-dismiss")
    app.wait_log(r"isim: keyboard hidden")
    app.wait_for(type="keyboard", gone=True)
    assert app.quit() == 0, "exits cleanly"


@pytest.mark.os_matrix
def test_ipad_status_bar_date(launch, ios):
    """iPadOS shows the date right of the time ("9:41 AM Mon Jun 10" with the 12-hour clock); iPhones only the time."""
    app = launch("HelloKeyboardTypes", device="ipadpro11", os_version=ipad_os(ios))
    ink = lambda c: max(c) < 120                           # the dark status bar text over the white app
    img = app.wait_shot(lambda s: count_px(s, (20, 4, 30, 16), ink) > 10, "the time drawn")
    assert count_px(img, (66, 4, 90, 16), ink) > 30, "the date drawn right of the time"
    assert count_px(img, (200, 2, 400, 20), ink) == 0, "nothing in the middle"
    assert app.quit() == 0, "exits cleanly"



@pytest.mark.os_matrix
def test_ipad_extended_keyboard(launch, ios):
    W, H = SIZES["ipadpro13"]
    app = launch("HelloKeyboardTypes", device="ipadpro13", os_version=ipad_os(ios), env={"ISIM_LANGUAGES": "en", "ISIM_REGION": "US"})
    dump, f = keyboard(app, "websearch")
    k = lambda i: f[f"isim-kb-{i}"]
    row = lambda i: k(i)[1]
    edge = lambda i: abs(k(i)[0] + k(i)[2] - (W - SIDE)) <= 1
    # five rows: ` 1 .. 0 - = delete / tab q .. p [ ] \ / caps lock a .. l ; ' return / shift z .. m , . / shift / bottom
    assert row("`") == row("1") == row("=") == row("delete") and edge("delete"), "the number row and delete"
    assert row("tab") == row("q") == row("[") == row("\\") > row("1") and k("tab")[0] <= SIDE + 1 and edge("\\"), "tab, q .. \\"
    assert row("capslock") == row("a") == row("'") == row("return") > row("q") and edge("return"), "caps lock, a .. ', return"
    assert row("shift") == row("z") == row("/") == row("shift-right") > row("a") and edge("shift-right"), "shift, z .. /, shift"
    bottom = [k(i) for i in ("emoji", "123", "dictation", "space", "123-right", "dismiss")]
    assert len({b[1] for b in bottom}) == 1 and bottom[0][1] > row("z"), f"bottom row: {bottom}"
    assert [b[0] for b in bottom] == sorted(b[0] for b in bottom) and bottom[0][0] <= SIDE + 1, f"emoji first: {bottom}"
    assert k("tab")[2] > k("q")[2] * 1.3 and k("capslock")[2] > k("q")[2] * 1.3, "wide tab and caps lock"
    assert all(k(i)[0] < k(j)[0] for i, j in (("`", "1"), ("0", "-"), ("-", "="), ("p", "["), ("l", ";"), ("m", ","), (".", "/"))), "order"
    end = k("dismiss")[1] + k("dismiss")[3]
    assert H - 20 - 14 <= end <= H - 20, f"keys end above the home indicator: {end}"
    img = app.screenshot("extended")
    one = k("1")                                           # the shifted character, small and grey above the 1
    assert count_px(img, (one[0] + one[2] / 3, one[1] + 3, one[2] / 3, one[3] * 0.35), lambda c: 60 < max(c) < 200) > 3, "! drawn"
    for key in ("1", "q", "tab", "["):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", "1q\t[")
    x, y = center(k("2"))                                  # a downward swipe types the character above: @
    app.drag(x, y - 8, x, y + 24, 0.2)
    typed(app, "websearch", "1q\t[@")
    app.tap_id("isim-kb-shift")                            # shift: a capital, or the character above
    app.tap_id("isim-kb-3")
    typed(app, "websearch", "1q\t[@#")
    app.tap_id("isim-kb-capslock")
    app.wait_log(r"isim: caps lock on")
    for key in ("a", "b"):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", "1q\t[@#AB")
    app.tap_id("isim-kb-capslock")
    app.wait_log(r"isim: caps lock off")
    app.tap_id("isim-kb-c")
    typed(app, "websearch", "1q\t[@#ABc")
    app.tap_id("isim-kb-123")                              # the numbers plane is the standard layout
    dump = app.wait_view(r"^(?!.* hidden id=).* id=isim-kb-abc-right\b")
    f = screen_frames(dump)
    assert "id=isim-kb-tab" not in dump and f["isim-kb-@"][1] == f["isim-kb-return"][1] > f["isim-kb-1"][1], "numbers plane"
    assert app.quit() == 0, "exits cleanly"


def laid_out(app, width):
    """The keyboard's frames once its delete key ends at the right edge of a screen `width` wide, else None."""
    f = screen_frames(app.view_dump())
    d = f.get("isim-kb-delete")
    return f if d and abs(d[0] + d[2] - (width - SIDE)) <= 1 else None


@pytest.mark.os_matrix
def test_ipad_keyboard_landscape(launch, ios):
    """Landscape (HelloKeyboardTypes supports every orientation on iPad): the keyboard spans the long side with the
    same layout, its keys wider than tall, and re-lays out when the device turns while it is up."""
    W, H = SIZES["ipadpro11"]
    app = launch("HelloKeyboardTypes", device="ipadpro11", os_version=ipad_os(ios), env={"ISIM_LANGUAGES": "en", "ISIM_REGION": "US"})
    dump, f = keyboard(app, "websearch")
    assert abs(f["isim-kb-delete"][0] + f["isim-kb-delete"][2] - (W - SIDE)) <= 1, "portrait first"
    app.send("rotate landscapeleft")                       # turned with the keyboard up
    f = app.wait_until(lambda: laid_out(app, H), what="the keyboard laid out across the landscape width")
    k = lambda i: f[f"isim-kb-{i}"]
    row = lambda i: k(i)[1]
    assert row("q") == row("p") == row("delete"), "delete ends row 1"
    assert row("a") == row("l") == row("return") > row("q") and abs(k("return")[0] + k("return")[2] - (H - SIDE)) <= 1, "return"
    assert row("shift") == row("z") == row(".") == row("shift-right") > row("a"), "third row"
    assert abs(k("shift-right")[0] + k("shift-right")[2] - (H - SIDE)) <= 1 and k("shift")[0] <= SIDE + 1, "both shifts"
    bottom = [k(i) for i in ("123", "emoji", "dictation", "space", "123-right", "dismiss")]
    assert len({b[1] for b in bottom}) == 1 and [b[0] for b in bottom] == sorted(b[0] for b in bottom), f"bottom row: {bottom}"
    assert k("q")[2] > k("q")[3] and k("q")[3] >= 50, f"landscape keys wider than tall: {k('q')}"
    end = k("dismiss")[1] + k("dismiss")[3]
    assert W - 20 - 14 <= end <= W - 20, f"keys end above the home indicator: {end} (screen height {W})"
    assert k("q")[1] > W / 2, f"the keyboard covers less than half the landscape screen: {k('q')}"
    img = app.wait_shot(lambda s: s.size == (H, W), "a landscape screenshot")
    assert all(v > 245 for v in rgb(img, *center(k("q")))), "letter keys white"
    for key in ("shift", "o", "k"):
        app.tap_id(f"isim-kb-{key}")
    typed(app, "websearch", "Ok")
    app.send("rotate portrait")                            # and back
    app.wait_until(lambda: laid_out(app, W), what="the portrait layout again")
    app.tap_id("isim-kb-dismiss")
    app.wait_for(type="keyboard", gone=True)
    assert app.quit() == 0, "exits cleanly"
