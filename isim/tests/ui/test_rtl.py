"""Right-to-left layout (HelloRightToLeft): the app's direction from its Arabic localization, Xcode's right-to-left
pseudolanguage (-AppleTextDirection YES) or left to right in English; leading / trailing constraints with constants,
a stack view, directional margins, natural text alignment, an image that flips, a playback row that does not, the
navigation bar's back button and table cells, a segmented control (segment 0 on the leading side, taps too), a
horizontal flow layout (mirrored, starting at the leading end) and the back swipe from the leading edge. Positions are checked against the device's width (os_matrix: iPhone 15,
16 Pro, 17)."""
import re

import pytest
from isimtest import count_px


def frames(dump):
    out = {}
    for m in re.finditer(r"\(([-\d.]+) ([-\d.]+); ([-\d.]+) x ([-\d.]+)\)[^\n]*?id=([\w-]+)", dump):
        out.setdefault(m.group(5), tuple(map(float, m.group(1, 2, 3, 4))))
    return out


def red_weight(shot, f):
    """where the red arrow's pixels are: share in the left third minus share in the right third"""
    x, y, w, h = f
    red = lambda c: c[0] > 200 and c[1] < 90 and c[2] < 90
    left, right = count_px(shot, (x, y, w / 3, h), red), count_px(shot, (x + 2 * w / 3, y, w / 3, h), red)
    return left - right


@pytest.mark.os_matrix
@pytest.mark.parametrize("mode", ["arabic", "pseudo", "english"])
def test_rtl(launch, mode):
    env = {"ISIM_LANGUAGES": "ar" if mode == "arabic" else "en"}
    args = ["-AppleTextDirection", "YES"] if mode == "pseudo" else []
    app = launch("HelloRightToLeft", env=env, args=args)
    rtl = mode != "english"
    loc = "ar" if mode == "arabic" else "en"
    app.wait_log(rf"direction app={'rtl' if rtl else 'ltr'} view={'rtl' if rtl else 'ltr'} trait={'rtl' if rtl else 'ltr'} localization={loc}")
    app.wait_log(rf"margins left={10 if rtl else 30} right={30 if rtl else 10}")      # directional margins: leading 30
    dump = app.wait_view(r"id=player")
    f = frames(dump)
    W = max(w for (_, _, w, _) in f.values() if w > 300)
    first, second = f["first"], f["second"]
    if rtl:
        assert abs(first[0] + first[2] - (W - 30)) <= 1, f"leading = the right margin {first} in {W}"
        assert abs(second[0] + second[2] - (first[0] - 10)) <= 1, f"second.leading = first.trailing + 10 goes left {second}"
        assert f["s1"][0] > f["s2"][0] > f["s3"][0], "the stack view runs right to left"
        assert f["nav-back"][0] > W / 2, "the back button is on the right"
    else:
        assert abs(first[0] - 30) <= 1 and abs(second[0] - (first[0] + 70)) <= 1, f"left to right {first} {second}"
        assert f["s1"][0] < f["s2"][0] < f["s3"][0], "the stack view runs left to right"
        assert f["nav-back"][0] < W / 2, "the back button is on the left"
    assert f["rewind"][0] < f["play"][0], "the playback row stays left to right"
    app.wait_log(r"flips=true")
    off, mx = map(int, app.wait_log(r"shelf offset=(\d+) max=(\d+)").groups())
    assert mx > 0 and off == (mx if rtl else 0), f"the shelf starts at its leading end ({off} of {mx})"
    dump = app.wait_view(r"id=item1")
    f = frames(dump)
    item0, item1 = f["item0"], f["item1"]                              # in the shelf's content: minus the offset on screen
    if rtl:
        assert item1[0] < item0[0] and abs(item0[0] + item0[2] - off - W) <= 1, f"items run right to left {item0} {item1}"
    else:
        assert item1[0] > item0[0] and abs(item0[0]) <= 1, f"items run left to right {item0} {item1}"
    sx, sy, sw, sh = f["seg"]
    app.tap(sx + sw / 6, sy + sh / 2)                                  # the left-most segment
    app.wait_log(rf"segment {2 if rtl else 0}")
    shot = app.wait_shot_still()
    weight = red_weight(shot, f["arrow"])
    assert (weight > 0) == rtl, f"the arrow points {'left' if rtl else 'right'} (left - right pixels: {weight})"
    lx, ly, lw, lh = f["label"]                                        # natural alignment: the text on the leading side
    dark = lambda c: c[0] < 90 and c[1] < 90 and c[2] < 90
    left, right = count_px(shot, (lx, ly, lw / 2, lh), dark), count_px(shot, (lx + lw / 2, ly, lw / 2, lh), dark)
    assert (right > left) == rtl, f"the label's text is on the {'right' if rtl else 'left'} ({left} left, {right} right)"

    ax, ay, _, ah = f["arrow"]                                         # the back swipe, from the leading edge
    app.drag(W - 3, ay + ah / 2, W - 300, ay + ah / 2, 0.4) if rtl else app.drag(3, ay + ah / 2, 300, ay + ah / 2, 0.4)
    app.wait_log(r"list appears")                                      # the list: cells mirrored
    list_dump = app.wait_view(r"id=row0")
    inbox = re.search(r"\(([-\d.]+) [-\d.]+; ([-\d.]+) x [-\d.]+\)[^\n]*text=Inbox", list_dump)
    x, w = float(inbox.group(1)), float(inbox.group(2))
    assert (x > W / 3) == rtl, f"the row's title is on the {'right' if rtl else 'left'} ({x}, {w})"
    assert app.quit() == 0, "exits cleanly"
