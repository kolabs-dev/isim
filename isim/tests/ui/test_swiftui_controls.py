"""SwiftUI views and controls (HelloSwiftUIControls): SF Symbol rendering modes (monochrome, hierarchical, palette,
multicolor), symbolVariant, imageScale, symbol effects (variable colour, breathe, rotate, scale, disappear, wiggle,
bounce, replace); truncationMode, minimumScaleFactor, allowsTightening; MultiDatePicker; PasteButton; ShareLink with
Transferable items; RenameButton."""
import re
import time

import pytest
from isimtest import grep


def frame(dump, ident):
    m = re.search(rf"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\).* id={re.escape(ident)}\b", dump)
    return tuple(float(v) for v in m.groups()) if m else None


def window_rect(dump, ident):
    """The window frame of the view with this id: its own frame plus its ancestors' origins (untransformed)."""
    lines = dump.splitlines()
    i = next(k for k, line in enumerate(lines) if re.search(rf" id={re.escape(ident)}\b", line))
    depth = lambda line: len(line) - len(line.lstrip())
    rx = lambda line: tuple(float(v) for v in re.search(r"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\)", line).groups())
    x, y, w, h = rx(lines[i])
    d = depth(lines[i])
    for k in range(i - 1, -1, -1):
        if depth(lines[k]) < d:
            d = depth(lines[k])
            px, py, _, _ = rx(lines[k])
            if "_SUIScrollView" not in lines[k] and "ListScroll" not in lines[k]:
                x += px; y += py
    return x, y, w, h


def colours(img, rect, pad=0):
    """Pixels inside a rect (window points), as RGB tuples."""
    x, y, w, h = rect
    return [img.getpixel((int(px), int(py)))[:3] for px in range(int(x - pad), int(x + w + pad)) for py in range(int(y - pad), int(y + h + pad))]


def count(pixels, pred):
    return sum(1 for c in pixels if pred(c))


def ink(img, rect, pad=0):
    return count(colours(img, rect, pad), lambda c: sum(c) < 600)


@pytest.mark.os_matrix
def test_symbol_rendering(launch):
    app = launch("HelloSwiftUIControls")
    dump = app.wait_view(r"id=bell-large")
    app.wait_still()
    dump = app.view_dump()
    img = app.screenshot("symbols")
    assert app.quit() == 0, "exits cleanly"
    blue = lambda c: c[2] > 200 and c[0] < 80 and c[1] < 160
    pale_blue = lambda c: c[2] > 220 and 100 < c[0] < 200 and 150 < c[1] < 230
    red = lambda c: c[0] > 200 and c[1] < 90 and c[2] < 90
    green = lambda c: c[1] > 150 and c[0] < 110 and c[2] < 120
    mono, hier, pal, multi = (colours(img, window_rect(dump, i)) for i in ("mono", "hier", "palette", "multi"))
    assert count(mono, blue) > 200 and count(hier, pale_blue) > 3 * count(mono, pale_blue), \
        "monochrome: one colour; hierarchical: the enclosure lighter than the glyph"
    assert count(hier, blue) > 60, "hierarchical: the glyph in the full colour"
    assert count(pal, red) > 60 and count(pal, green) > 100, "palette: the primary (glyph) and secondary (enclosure) styles"
    assert count(multi, red) > 300, "multicolor: the heart's own red"
    plain, filled = (ink(img, window_rect(dump, i)) for i in ("star-plain", "star-fill"))
    circle, circle_fill = (ink(img, window_rect(dump, i)) for i in ("star-circle", "star-circle-fill"))
    assert filled > plain * 1.5, "symbolVariant(.fill)"
    assert circle > plain and circle_fill > circle * 1.5, "symbolVariant(.circle) / (.circle.fill)"
    small, medium, large = (frame(dump, f"bell-{s}")[3] for s in ("small", "medium", "large"))
    assert small < medium < large, f"imageScale: small < medium < large ({small} {medium} {large})"


def test_symbol_effects(launch, ios):
    app = launch("HelloSwiftUIControls", env={"PAGE": "effects"})
    app.wait_view(r"id=fx-replace")
    dump = app.view_dump()
    rects = {i: window_rect(dump, i) for i in ("fx-variable", "fx-breathe", "fx-rotate", "fx-scale", "fx-disappear", "fx-wiggle", "fx-bounce", "fx-replace")}
    seen = {k: set() for k in ("fx-variable", "fx-breathe", "fx-rotate")}
    end = time.monotonic() + 8
    while time.monotonic() < end and not all(len(v) >= 3 for v in seen.values()):
        img = app.screenshot()
        for k in seen:
            seen[k].add(hash(tuple(colours(img, rects[k], pad=8)[::7])))
    before = app.screenshot("effects")
    scale0, gone0 = ink(before, rects["fx-scale"], pad=12), ink(before, rects["fx-disappear"])
    app.tap_id("activate")
    after = app.wait_shot(lambda im: ink(im, rects["fx-disappear"]) < 10 and ink(im, rects["fx-scale"], pad=12) > scale0 * 1.2,
                          what="scale up and disappear while active")
    scale1, gone1 = ink(after, rects["fx-scale"], pad=12), ink(after, rects["fx-disappear"])
    # bounce (3 times) and wiggle play when the value changes
    app.tap_id("bump")
    bounce0 = ink(before, rects["fx-bounce"], pad=12)
    moved = app.wait_shot(lambda im: ink(im, rects["fx-bounce"], pad=12) > bounce0 * 1.1, what="the bounce")
    # replace: the old symbol scales out while the new one scales in (a snapshot of the old one in the tree)
    app.tap_id("replace")
    # replace: frames between the old symbol and the new one (the old scales out while the new scales in)
    rr = rects["fx-replace"]
    sig = lambda im: tuple(colours(im, rr, pad=6)[::5])
    old_sig = sig(app.screenshot())
    app.tap_id("replace")
    frames, end = [], time.monotonic() + 6
    while time.monotonic() < end:
        frames.append(sig(app.screenshot()))
        if len(frames) >= 3 and frames[-1] == frames[-2] == frames[-3] and frames[-1] != old_sig:
            break
    between = [f for f in frames if f != old_sig and f != frames[-1]]
    assert app.quit() == 0, "exits cleanly"
    assert len(seen["fx-variable"]) >= 3, "variableColor runs (the symbol's colour changes over time)"
    if int(str(ios[0] or 18)) >= 18:
        assert len(seen["fx-breathe"]) >= 3 and len(seen["fx-rotate"]) >= 3, "breathe and rotate run (iOS 18)"
    assert scale1 > scale0 * 1.2, f"scale.up while active ({scale0} -> {scale1})"
    assert gone0 > 100 and gone1 < 10, f"disappear while active ({gone0} -> {gone1})"
    assert moved, "bounce plays when its value changes"
    assert frames[-1] != old_sig and between, "contentTransition(.symbolEffect(.replace)): the symbol changes through in-between frames"


def test_text_fitting(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "text"})
    app.wait_view(r"id=loose")
    app.wait_still()
    dump = app.view_dump()
    img = app.screenshot("text")
    assert app.quit() == 0, "exits cleanly"
    assert "text=…mps over the lazy dog" in grep(dump, r"id=head", after=1), "truncationMode(.head)"
    assert "text=The quick b…he lazy dog" in grep(dump, r"id=middle", after=1), "truncationMode(.middle)"
    # minimumScaleFactor: the text shrinks to fit 250 pt (its ink stays inside), tightening fits a slightly long line
    sx, sy, sw, sh = window_rect(dump, "scaled")
    right_ink = [x for x in range(int(sx), int(sx + sw + 60)) if any(sum(img.getpixel((x, y))[:3]) < 300 for y in range(int(sy), int(sy + sh)))]
    assert right_ink and right_ink[-1] <= sx + sw, f"minimumScaleFactor shrinks the line into its frame (ink to {right_ink[-1]}, frame to {sx + sw})"
    # allowsTightening: the slightly long line fits by tightening (all of it drawn); without, it is truncated
    tight, loose = window_rect(dump, "tight"), window_rect(dump, "loose")
    dark = lambda c: sum(c) < 250
    assert count(colours(img, tight), dark) > count(colours(img, loose), dark) * 1.1, "allowsTightening: the line fits by tightening"


@pytest.mark.os_matrix
def test_multi_date_picker(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "dates"})
    app.wait_view(r"id=day-10")
    app.tap_id("day-10")
    app.wait_log(r"^days 10$")
    app.tap_id("day-12")
    app.wait_log(r"^days 10,12$")
    app.tap_id("day-10")
    app.wait_log(r"^days 12$")
    app.tap_id("day-28")                                                 # outside the range: disabled
    app.wait_still()
    dump = app.view_dump()
    app.screenshot("multidate")
    assert app.quit() == 0, "exits cleanly"
    assert "id=days text=days 12" in dump, "MultiDatePicker adds and removes days; days outside the range are disabled"
    assert "id=month-title text=May 2026" in dump, "starts at the range"


@pytest.mark.os_matrix
def test_paste_button(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "paste"})
    before = app.wait_view(r"id=paste")
    app.tap_id("copy")
    after = app.wait_view(r"^(?!.*alpha<1).*id=paste\b")
    app.tap_id("paste")
    app.wait_log(r"^pasted hello from the pasteboard")
    assert app.quit() == 0, "exits cleanly"
    assert "alpha<1" in grep(before, r"id=paste\b"), "disabled while the pasteboard has no text"
    assert "Allow Paste" not in app.log and "would like to paste" not in app.log, "a paste button pastes without the prompt"


@pytest.mark.os_matrix
def test_share_link(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "share"})
    app.wait_tap_id("share-note")
    note = app.wait_view(r"id=isim-share-sheet")
    app.wait_still()
    app.screenshot("share-note")
    app.tap_id("share-close")
    app.wait_view(r"id=isim-share-sheet", gone=True)
    app.wait_still()
    app.tap_id("share-url")
    url = app.wait_view(r"text=example.com")
    assert app.quit() == 0, "exits cleanly"
    assert "text=A note to share" in note, "a Transferable item is shared as its exported text"
    assert "text=2 items" in url, "a URL (its host as the preview title) with a message: two items"


def test_rename_button(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "rename"})
    app.wait_view(r"id=state text=not editing")
    app.tap_id("rename")
    app.wait_view(r"id=state text=editing")
    app.tap_id("rename-custom")
    app.wait_log(r"^custom rename")
    assert app.quit() == 0, "exits cleanly"


@pytest.mark.os_matrix
def test_slider_ticks(launch, ios):
    """iOS 26: a stepped slider shows its steps as ticks and snaps to them; custom ticks; neutralValue; enabledBounds."""
    if int(str(ios[0] or 18)) < 26:
        pytest.skip("Slider ticks are iOS 26")
    app = launch("HelloSwiftUIControls", env={"PAGE": "ticks"})
    dump = app.wait_view(r"id=values")
    app.wait_still()
    img = app.screenshot("ticks")
    sx, sy, sw, sh = window_rect(dump, "stepped")
    app.drag(sx + sw / 2, sy + sh / 2, sx + sw * 0.7, sy + sh / 2, 0.4)
    app.wait_log(r"^stepped 3\.00$")                                       # 0...4 step 1: snaps to 3
    bx, by, bw, bh = window_rect(dump, "bounded")
    app.drag(bx + bw / 2, by + bh / 2, bx + 2, by + bh / 2, 0.4)
    app.wait_log(r"^bounded 20$")                                          # clamped to the enabled bounds
    nx, ny, nw, nh = window_rect(dump, "neutral")
    app.drag(nx + nw / 2, ny + nh / 2, nx + nw * 0.25, ny + nh / 2, 0.4)
    app.wait_log(r"^neutral -0\.[0-9]+$")
    app.wait_still()
    after = app.screenshot("ticks-after")
    assert app.quit() == 0, "exits cleanly"
    # tick dots: brighter or darker specks on the stepped track (5 steps, the thumb hides the middle one)
    track_y = int(sy + sh / 2)
    row = [img.getpixel((x, track_y))[:3] for x in range(int(sx), int(sx + sw))]
    specks = sum(1 for i in range(1, len(row) - 1) if abs(sum(row[i]) - sum(row[i - 1])) > 60 and abs(sum(row[i]) - sum(row[i + 1])) < 60)
    assert specks >= 3, f"a stepped slider shows tick marks ({specks} edges)"
    # neutralValue: the fill runs from the middle to the thumb (to the left of the centre)
    blue_px = lambda im, x: (lambda c: c[2] > 200 and c[0] < 80)(im.getpixel((int(x), int(ny + nh / 2)))[:3])
    assert blue_px(after, nx + nw * 0.4) and not blue_px(after, nx + nw * 0.6), "the fill starts at the neutral value"


@pytest.mark.os_matrix
def test_attributed_text_editor(launch, ios):
    """iOS 26: TextEditor(text: Binding<AttributedString>, selection:): runs drawn with their attributes, typed text
    takes the attributes before it, the selection binding sets and follows the selection."""
    if int(str(ios[0] or 18)) < 26:
        pytest.skip("TextEditor with AttributedString is iOS 26")
    app = launch("HelloSwiftUIControls", env={"PAGE": "rich"})
    dump = app.wait_view(r"id=editor")
    app.wait_still()
    img = app.screenshot("rich")
    ex, ey, ew, eh = window_rect(dump, "editor")
    red = lambda c: c[0] > 200 and c[1] < 90 and c[2] < 90
    assert count(colours(img, (ex, ey, ew, 30)), red) > 40, "the red bold run is drawn red"
    app.tap(ex + 6, ey + 12)                                               # before "Hello"
    app.wait_log(r"^caret 0$")
    app.tap(ex + ew - 20, ey + 12)                                         # after "world"
    app.wait_log(r"^caret 11$")
    app.type("wide")
    app.wait_log(r"^text Hello \|worldwide\[red\]$")
    app.tap_id("select")
    app.wait_log(r"^selected Hello$")
    app.tap_id("underline")
    app.wait_log(r"^text Hello\[u\]\| \|worldwide\[red\]$")
    assert app.quit() == 0, "exits cleanly"


def test_search_and_presentation_environment(launch):
    """\\.isSearching follows the search field of a .searchable list; \\.presentationMode and \\.isPresented in a sheet,
    and presentationMode.dismiss() closes it."""
    app = launch("HelloSwiftUIControls", env={"PAGE": "env"})
    app.wait_view(r"id=search-state text=not searching")
    app.wait_tap_id("search-field")
    app.wait_log(r"^isSearching true$")
    app.wait_view(r"id=search-state text=searching")
    app.type("an")
    app.wait_view(r"text=Banana")
    app.tap_id("search-cancel")
    app.wait_log(r"^isSearching false$")
    app.wait_tap_id("show-sheet")
    app.wait_view(r"id=sheet-state text=presented yes mode yes")
    app.tap_id("sheet-done")
    app.wait_log(r"^sheet gone$")
    app.wait_view(r"id=sheet-state", gone=True)
    assert app.quit() == 0, "exits cleanly"


def test_accessibility_order_and_actions(launch):
    """accessibilitySortPriority orders VoiceOver within a container; named accessibility actions (the first with
    `voiceover action`, others from the Actions rotor)."""
    app = launch("HelloSwiftUIControls", env={"PAGE": "ax"})
    app.send("voiceover on")
    app.wait_log(r'VoiceOver: "First"')                                      # the higher sort priority first
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Second"')
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Mail. Actions available."')
    app.send("voiceover action")
    app.wait_log(r"^archived$")                                              # accessibilityAction(named:)
    app.send("voiceover rotor").send("voiceover rotor")
    app.wait_log(r"VoiceOver rotor: Actions")
    app.send("voiceover down")
    app.wait_log(r'VoiceOver: "Flag"')
    app.send("voiceover activate")
    app.wait_log(r"^flagged$")                                               # accessibilityAction(named: Text)
    app.send("voiceover off")
    assert app.quit() == 0, "exits cleanly"
