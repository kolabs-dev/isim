"""SwiftUI layout (HelloLayout): Grid (column alignment, spans), LazyHGrid, ViewThatFits, a custom Layout (flow) and
AnyLayout switching, alignment guides (built-in and custom AlignmentID through nested stacks), position, preferences
(reduce + onPreferenceChange, anchors in overlayPreferenceValue), onGeometryChange, @ScaledMetric, safeAreaInset,
containerRelativeFrame, paging / view-aligned scrolling, scrollPosition, scrollDisabled, contentMargins.
Frames are the view tree's (relative to the superview). Port of tests/ui/layout.sh."""
import re

from isimtest import grep


def frame(dump, ident):
    """(x, y, w, h) of the first view with this id."""
    m = re.search(rf"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\).* id={re.escape(ident)}\b", dump)
    return tuple(float(v) for v in m.groups()) if m else None


def right(dump, ident):
    f = frame(dump, ident)
    return f[0] + f[2]


def line_near(dump, pattern, offset):
    """The line `offset` lines after (or before, if negative) the first line matching `pattern`."""
    lines = dump.splitlines()
    i = next(i for i, line in enumerate(lines) if re.search(pattern, line))
    return lines[i + offset]


def x_of(line):
    return float(re.search(r"\((-?[0-9.]+) ", line).group(1))


def test_grid(launch):
    app = launch("HelloLayout")
    grid = app.wait_view(r"id=tag-wraps")
    app.wait_still()
    grid = app.view_dump()
    app.screenshot("grid")
    app.tap_id("switch")
    switched = app.wait_view(r"\(0 29; [0-9.]+ x 21\) id=any-2", what="AnyLayout switches to a VStack")
    assert app.quit() == 0, "exits cleanly"

    assert right(grid, "qty-apples") == right(grid, "qty-kiwi") and \
        frame(grid, "qty-apples")[0] != frame(grid, "qty-kiwi")[0], "Grid: trailing column alignment"
    assert right(grid, "span") == right(grid, "qty-apples"), "Grid: gridCellColumns spans both columns"
    # rows 30 pt with GridItem's default 8 pt gap, centred in the 70 pt grid; columns `spacing` (10) apart
    assert frame(grid, "h1") == (0, 43.5, 40, 21) and frame(grid, "h2") == (50, 5.5, 40, 21), \
        "LazyHGrid fills rows, then columns"
    assert "text=Short" in grep(grid, r"id=fits-narrow", after=2) and \
        "text=Wide label" in grep(grid, r"id=fits-wide", after=1), "ViewThatFits picks what fits"
    assert frame(grid, "tag-protocol")[:2] == (0, 35) and frame(grid, "tag-wraps")[:2] == (0, 70), \
        "custom Layout (flow) wraps"
    assert re.search(r"\([1-9][0-9.]* 0; [0-9.]+ x 21\) id=any-2", grid) and \
        re.search(r"\(0 29; [0-9.]+ x 21\) id=any-2", switched), "AnyLayout switches HStack -> VStack"


def test_align(launch):
    app = launch("HelloLayout")
    app.wait_tap_id("tab-Align")
    app.wait_view(r"id=widest text=widest 149")
    app.wait_still()
    align = app.view_dump()
    app.screenshot("align")
    app.tap_id("geo")
    app.wait_log(r"^geometry width 161")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    assert frame(align, "guide-b")[0] == 24, "alignmentGuide offsets a view"
    row1, row2 = x_of(line_near(align, r"text=User:", -1)), x_of(line_near(align, r"text=Password:", -1))
    a1, a2 = frame(align, "acct-1")[0], frame(align, "acct-2")[0]
    assert row1 + a1 == row2 + a2 and row1 != row2, "custom AlignmentID lines up nested views"
    assert "(40 20; 20 x 20)" in grep(align, r"id=dot", after=1), \
        "position(x:y:) centres the view there"
    assert re.search(r"^max width 149", log, re.M) and "id=widest text=widest 149" in align, \
        "PreferenceKey reduce + onPreferenceChange"
    second = re.search(r"; ([0-9.]+) x 21\).*text=Second", align).group(1)
    under = grep(align, r"id=underline", after=1)
    assert re.search(rf"\([1-9][0-9.]* 21; {re.escape(second)} x 3\)", under), \
        "anchorPreference + overlayPreferenceValue"
    assert re.search(r"^geometry width 55", log, re.M) and re.search(r"^geometry width 161", log, re.M), \
        "onGeometryChange reports size changes"
    assert "id=avatar-xxxl text=scaled 46" in align and "id=avatar-default text=avatar 40" in align, \
        "@ScaledMetric follows dynamicTypeSize"
    assert frame(align, "inset-bar")[1] == 54, "safeAreaInset puts content below"


def test_scroll(launch):
    app = launch("HelloLayout")
    app.wait_tap_id("tab-Scroll")
    app.wait_view(r"id=pager")
    app.wait_still()
    app.screenshot("scroll")
    app.send("swipeid pager 0 -100 0.6")
    app.wait_view(r"text=offset 150, content 402 x 600")
    app.wait_still()
    app.send("swipeid aligned 0 -95 0.6")
    app.wait_log(r"^position 3")
    app.wait_still()
    app.send("swipeid locked 0 -40 0.4")
    app.wait_still()
    scroll = app.view_dump()
    app.tap_id("go8")
    after = app.wait_view(r"id=position text=position 8")
    app.wait_still()
    after = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    both = scroll + "\n" + after

    assert "(0 0; 402 x 150) text=offset 150, content 402 x 600" in scroll, \
        "containerRelativeFrame: page = scroll height"
    assert "text=offset 150, content 402 x 600" in scroll, "scrollTargetBehavior(.paging)"
    assert "text=offset 180, content 402 x 710" in scroll, "viewAligned snaps to a row + scrollPosition"
    assert "text=offset 480, content 402 x 710" in after and "id=position text=position 8" in after, \
        "scrollPosition binding scrolls"
    assert "(0 0; 402 x 60) text=offset 0, content 402 x 282" in both, "scrollDisabled"
    assert "(30 0;" in line_near(scroll, r"id=m0", -1), "contentMargins"
