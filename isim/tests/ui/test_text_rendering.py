"""HelloText -rendering: a TextRenderer draws text from its Text.Layout (lines, runs with a custom attribute, one slice
per character, a line limit) inside its display padding; TextSelection bindings of a TextField and a TextEditor set
and follow the selection; a rich TextEditor's AttributedTextFormattingDefinition constrains colours and underlines,
for the text it is given and for typed text (iOS 26)."""
from isimtest import rgb, screen_frames


def colours(img, box, step=2):
    x, y, w, h = box
    return [rgb(img, x + i, y + j) for i in range(0, int(w), step) for j in range(0, int(h), step)]


def test_text_renderer_and_selection(launch):
    app = launch("HelloText", os_version="26", args=["-rendering"])
    # "Wavy " + "text" (highlighted) + " here": three runs, 12 characters drawn, the highlight on characters 5–8
    app.wait_log(r"tr wave lines 1 runs \[3\] characters 12 highlighted \[5,6,7,8\]")
    app.wait_log(r"tr lines 2 truncated true baselines \d+,\d+")
    tree = app.wait_view(r"id=wave")
    app.wait_still()
    img = app.screenshot("renderer")
    f = screen_frames(tree)
    wave, lines = f["wave"], f["lines"]
    yellow = lambda c: c[0] > 220 and c[1] > 180 and c[2] < 80
    dark = lambda c: max(c) < 90
    w = colours(img, wave)
    assert sum(map(yellow, w)) > 30, "the highlighted run's box is drawn behind it"
    assert sum(map(dark, w)) > 30, "the glyphs are drawn"
    # the shifted characters reach into the display padding below the text
    x, y, ww, h = wave
    assert sum(map(dark, colours(img, (x, y + h - 10, ww, 10)))) > 3, "characters drawn lower, in the display padding"
    red = lambda c: c[0] > 200 and c[1] < 80 and c[2] < 80
    blue = lambda c: c[2] > 200 and c[0] < 80 and c[1] < 80
    l = colours(img, lines, step=1)
    assert any(map(red, l)) and any(map(blue, l)), "each line's rule is drawn in its own colour"

    # (first: the keyboard then covers the lower editors)
    # the formatting definition: green becomes blue (not an allowed colour), the underline goes; typed text takes the attributes before it
    app.wait_log(r"tr rich green =blue \| red=red$")
    tree = app.wait_view(r"id=rich")
    rx, ry, rw, rh = screen_frames(tree)["rich"]
    app.tap(rx + rw - 10, ry + 12)
    app.type("x")
    app.wait_log(r"tr rich green =blue \| redx=red$")

    # TextField selection: set from the binding, then typing replaces it
    app.tap_id("field")
    app.tap_id("select-world")
    app.wait_log(r"tr field selection 6\.\.<11 'World' insertion false")
    app.type("X")
    app.wait_log(r"tr field text 'Hello X'")
    app.wait_log(r"tr field selection 7\.\.<7 '' insertion true")
    # TextEditor selection: an insertion point at the start, then typing there
    app.tap_id("notes")
    app.tap_id("notes-start")
    app.type("A")
    app.wait_log(r"tr notes text 'Anotes'")

    assert app.quit() == 0, "exits cleanly"
