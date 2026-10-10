"""Core Text (HelloCoreText): fonts and descriptors read from the font file (metrics, glyphs, advances, bounds,
outlines, CTFontDrawGlyphs; traits, style names and files, matching descriptors; font features), runs (string order,
fallback fonts in the attributes, bidi status, UTF-16 string indices, positions and advances, metrics and ink bounds,
a line redrawn glyph by glyph matching CTLineDraw, CTRunDraw of a range) and paragraph styles (every specifier read
back; alignment, writing direction, justification, indents, line heights and spacing, paragraph spacing and separators,
line break modes and truncation, tab stops, UIKit's NSParagraphStyle, suggested frame sizes). The app computes each
check and prints it; the test reads the lines and the screen."""
import re

from isimtest import count_px


def nums(line):
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", line)]


def test_coretext(launch):
    app = launch("HelloCoreText")
    app.wait_log("coretext checks done")
    shot = app.wait_shot(lambda s: count_px(s, (16, 870 / 2, 220, 35), lambda c: c[0] > 200 and c[1] < 100) > 50,
                         "the mixed line drawn")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def line(prefix):
        m = re.search(rf"^{re.escape(prefix)}.*$", log, re.M)
        assert m, f"no line {prefix!r}"
        return m.group(0)

    def has(s):
        return s in log

    # ---- fonts: metrics from the font file (DejaVu Sans: 2048 units per em, ascender 1901, descender 483)
    m = nums(line("font metrics"))
    upem, count, ascent, descent = m[0], m[1], m[2], m[3]
    assert upem == 2048 and count > 3000, "units per em and glyph count of DejaVu Sans"
    assert abs(ascent - 1901 / 2048 * 20) < 0.02 and abs(descent - 483 / 2048 * 20) < 0.02, "ascent / descent from hhea"
    assert re.search(r"glyphs for characters all true match run glyphs true advance0 12\.72 total 127\.25 line 127\.25", log), \
        "glyph ids are the shaper's; advances add up to the shaped line (DejaVu digits are 1303 units)"
    assert has("glyphs missing false true true"), "a character the font lacks gives glyph 0 and false"
    assert has("surrogate pair found true high true low 0"), "a surrogate pair: glyph at the high surrogate, 0 at the low one"
    r = nums(line("glyph H rect"))
    assert r[0:4] == r[4:8] and abs(r[3] - 1493 / 2048 * 20) < 0.02, "H: bounding rect = its outline's bounds, as tall as the glyph"
    d = nums(line("glyph outline vs drawn"))
    assert d[1] > 500 and d[0] < 0.02 * d[1], "CTFontCreatePathForGlyph filled = CTFontDrawGlyphs"
    assert has("space path empty true"), "a space has an empty outline"
    assert has("bold style Bold file DejaVuSans-Bold.ttf traits bold true"), "bold copy: the face's style and file"
    assert has("names family DejaVu Sans style Book full DejaVu Sans Bold"), "CTFontCopyName"
    assert has("mono trait true sans false"), "monospace trait read from the face"
    assert has("color glyphs trait true sans false"), "color glyphs trait read from the face"
    s = nums(line("italic slant angle"))
    assert s[0] < -5 and s[1] > 0.1 and s[2] == 0, "Adwaita Sans Italic's italic angle; slant trait; upright 0"
    assert has("condensed trait true width -0.4"), "condensed trait <-> width trait"
    assert has("width trait expanded true bold true"), "width and weight traits of a descriptor"
    assert has("style name bold true style Bold"), "the style name attribute picks the face"
    assert has("uifont as ctfont size 17.00 bold true ascent>0 true"), "a UIFont works as a CTFont"
    assert has("matching faces 2 first DejaVuSans has bold true"), "the family's faces, regular first"
    assert has('matching mandatory style ["DejaVuSans-Bold"]'), "mandatory style attribute"
    assert has("matching best DejaVuSans-Bold"), "the closest face for the bold trait"
    assert has("matching none true"), "no face matches a mandatory style the family lacks"

    # ---- features
    types = [int(t) for t in line("features types").split()[-1].split(",")]
    assert {1, 6, 14}.issubset(types), f"Adwaita Sans lists ligatures, number spacing, typographic extras: {types}"
    assert has("number spacing selectors tnum,pnum"), "number spacing selectors carry their OpenType tags"
    t = nums(line("tnum widths"))
    assert t[0] == t[1] and t[2] != t[3] and t[2:4] == t[4:6], "monospaced numbers (6/0) make 1 as wide as 0; 6/1 undoes it"
    assert has("exclusive feature replaced 1"), "a setting of an exclusive type replaces the earlier one"
    assert has("slashed zero differs true aat same true"), "OpenType tag and AAT 14/4 both give the slashed zero"
    assert has("ligature fi glyphs 1 off 2"), "common ligatures off (1/3)"
    assert has("small caps differ true"), "lower case small caps (37/1)"
    assert has("number case old-style differs true lining default true"), "number case: 21/0 old-style, 21/1 lining"

    # ---- runs
    assert has("runs 7: 0+6 DejaVu Sans | 6+5 DejaVu Sans | 11+1 DejaVu Sans | 12+2 Noto Color Emoji | 14+1 DejaVu Sans | "
               "15+4 DejaVu Sans rtl | 19+1 DejaVu Sans"), "runs in string order; the emoji run's font is the fallback"
    assert has("runs cover 20 of 20 in string order true"), "runs cover the string (UTF-16) once"
    assert has("emoji glyph at index 12 of 12 hebrew indices 18,17,16,15 x increasing true"), \
        "string indices are UTF-16; a right-to-left run's glyphs are in visual order with indices counting down"
    assert has("run glyphs match font true positions follow advances true base origins zero true ptrs true"), \
        "glyphs, positions and advances of a run"
    assert has("run sub range glyphs true"), "CTRunGetGlyphs of a sub range"
    b = line("run bounds")
    assert "ascent matches true descent matches true" in b and re.search(r"H ink 0\.00 14\.58", b), \
        "run metrics are its font's; ink of H from the baseline to the cap"
    assert has("run attributes color true font DejaVu Sans Bold"), "a run's attributes"
    assert has("run without font attribute has font true size 12.00"), "a run always names its font (12 pt default)"
    rd = nums(line("runs redrawn"))
    assert rd[1] > 500 and rd[0] < 0.02 * rd[1], "the line redrawn from its runs (CTFontDrawGlyphs) matches CTLineDraw"
    assert has("after a 3x draw width same true ascent 18.56 font ascent 18.56"), "drawing at 3x leaves metrics in user space"
    dr = nums(line("run draw range"))
    assert dr[0] >= 5 and dr[1] <= dr[2], "CTRunDraw of two glyphs inks only them"

    # ---- paragraph styles
    assert has("pstyle values true true true true 11.00,12.00,-13.00,14.00,1.50,40.00,15.00,16.00,17.00,18.00,2.00,19.00"), \
        "every specifier is read back"
    assert has("pstyle tabs 40.0/0,120.0/1"), "tab stops, sorted by location"
    assert has("pstyle defaults natural true tabs 12 first 28.0 copy 12.00"), "defaults: natural, 12 tabs 28 points apart; copy"
    assert has("pstyle line spacing sets minimum 6.00 maximum 6.00"), "the deprecated line spacing sets both limits"
    assert has("align left 0.00 right 300.00 center 150.00 natural 0.00 natural rtl 300.00"), "alignment in a 300 point box"
    assert has("writing direction rtl natural right 300.00 explicit left 0.00 run rtl false"), \
        "a right-to-left base direction: natural is right, left stays left, Latin stays left-to-right"
    j = nums(line("justified lines"))
    assert j[0] == 3 and j[1] == 300 and j[2] < 300 and j[3] == j[4], "justified lines fill the box, the last one does not"
    assert has("indents x 20.00 10.00 fit true lines 3"), "first line and head indents, tail indent from the right"
    assert has("tail indent positive fit true right aligned end 250.00"), "a positive tail indent is from the leading edge"
    assert has("hanging indent x 0.00 24.00"), "a hanging indent"
    st = nums(line("line step natural"))
    nat = st[0]
    assert abs(st[1] - 2 * nat) < 0.02, "line height multiple 2"
    assert st[2] == 40 and st[3] == 10, "minimum / maximum line height"
    assert abs(st[4] - (nat + 5)) < 0.02 and abs(st[5] - (nat + 8)) < 0.02 and abs(st[6] - (nat + 6)) < 0.02, \
        "line spacing adjustment, minimum line spacing, deprecated line spacing"
    p = line("paragraph spacing")
    assert re.search(r"lines 4 first top 22\.85 step 38\.62 ranges 0\+4,4\+4,8\+1,9\+4", p), \
        "spacing before (8) at the top, after (12) + before between paragraphs; an empty paragraph is a line"
    assert has("separators lines 3 ranges 0+3,3+2,5+1"), "\\r\\n and U+2029 end paragraphs and belong to their lines"
    assert re.search(r"break word 5 char 11 clip lines 1 width [0-9]{3}", log), "word / character wrapping, clipping"
    assert has("truncate tail lines 1 fits true head 1 true middle 1 true"), "truncation modes give one line that fits"
    assert has("truncated line fits true glyphs true"), "CTLineCreateTruncatedLine"
    tb = nums(line("tabs left"))
    assert tb[0] == 100 and tb[1] == 200 and tb[2] == 150 and tb[3] < 150 < tb[4] and tb[5:8] == [50, 100, 28], \
        "left, right, center and decimal tab stops; default tab interval; the default 28 point tabs"
    assert has("frame tabs 100.00"), "tab stops in a frame"
    assert has("nsparagraphstyle right end 300.00 step 32.62"), "UIKit's NSParagraphStyle (alignment, spacing)"
    sg = nums(line("suggest height"))
    assert abs(sg[1] - 2 * sg[0]) < 0.05 and "width<=300 true" in line("suggest height") and sg[3] == sg[4] and sg[5] == nat, \
        "suggested sizes follow the style; fit range; a height for one line"
    assert has("frame visible 0+35 lines 1"), "a frame one line high shows one line"

    # ---- the screen: alignment, and the mixed line redrawn from its runs looks the same
    red = count_px(shot, (16 + 361 / 2, 95, 361 / 2, 25), lambda c: c[0] > 200 and c[1] < 120)
    assert red > 40, "right-aligned red text on the right half"
    assert count_px(shot, (16, 95, 361 / 2 - 20, 25), lambda c: c[0] > 200 and c[1] < 120) == 0, "nothing red on the left"

    def ink(y):
        return [count_px(shot, (16 + 40 * k, y, 40, 34), lambda c: c[0] + c[1] + c[2] < 600) for k in range(6)]
    a, b = ink(422), ink(462)
    assert sum(a) > 200 and all(abs(x - y) <= max(6, 0.15 * x) for x, y in zip(a, b)), f"line vs runs: {a} {b}"
