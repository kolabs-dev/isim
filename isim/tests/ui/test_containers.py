"""SwiftUI containers (HelloContainers): list styles (inset grouped, plain, grouped, inset, sidebar) with row / section
modifiers (listRowBackground, listRowInsets, listRowSeparator / Tint, headerProminence, Section(isExpanded:)),
listRowSpacing / listSectionSpacing / scrollContentBackground, List multiple selection in edit mode, lazy stacks and
grids with pinned section headers and footers, scroll indicators and bounce behaviour, named coordinate spaces."""
import re

import pytest
from isimtest import grep


def parent_frame(dump, ident):
    """(x, y, w, h) of the view right above the first view with this id (the row content around a label)."""
    line = grep(dump, rf"id={re.escape(ident)}\b", before=1).splitlines()[0]
    return tuple(float(v) for v in re.search(r"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\)", line).groups())


def subtree(dump, ident, up=2):
    """The dump lines of the view `up` levels above the view with this id, and everything inside it."""
    lines = dump.splitlines()
    i = next(k for k, line in enumerate(lines) if f"id={ident}" in line)
    depth = lambda line: len(line) - len(line.lstrip())
    for _ in range(up):
        d = depth(lines[i])
        i = next(k for k in range(i, -1, -1) if depth(lines[k]) < d)
    d, out = depth(lines[i]), [lines[i]]
    for line in lines[i + 1:]:
        if depth(line) <= d:
            break
        out.append(line)
    return "\n".join(out)


def scroll_offset(dump, ident):
    """The vertical (or horizontal) content offset of the scroll view with this id (or right inside it)."""
    m = re.search(rf"id={re.escape(ident)}( text=offset ([-0-9.]+)|\n\s+\S+ \([^)]*\) text=offset ([-0-9.]+))", dump)
    return float(m.group(2) or m.group(3))


def frame_of_window(dump):
    return views(dump, "UIWindow")[0]


def frame(dump, ident):
    """(x, y, w, h) of the first view with this id."""
    m = re.search(rf"\((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\).* id={re.escape(ident)}\b", dump)
    return tuple(float(v) for v in m.groups()) if m else None


def views(dump, cls):
    """(x, y, w, h) of the views of a class (in dump order)."""
    return [tuple(float(v) for v in m.groups()) for m in
            re.finditer(rf"\b{cls} \((-?[0-9.]+) (-?[0-9.]+); ([0-9.]+) x ([0-9.]+)\)", dump)]


def near(c, rgb, tol=24):
    return all(abs(a - b) <= tol for a, b in zip(c[:3], rgb))


WHITE, GROUPED_BG, SECONDARY_BG, YELLOW = (255, 255, 255), (242, 242, 247), (242, 242, 247), (255, 204, 0)


@pytest.mark.os_matrix
@pytest.mark.parametrize("style", ["automatic", "plain", "grouped", "inset", "sidebar"])
def test_list_styles(launch, style):
    app = launch("HelloContainers", env={"LIST_STYLE": style})
    app.wait_view(r"id=big")
    app.wait_still()
    dump = app.view_dump()
    shot = app.screenshot(f"list-{style}")
    assert app.quit() == 0, "exits cleanly"

    apple, carrot = frame(dump, "apple"), parent_frame(dump, "carrot")
    cards = views(dump, "UIView")
    rows = views(dump, r"_TtC7SwiftUI11_SUIListRow")
    card = next(c for c in cards if c[3] >= 176 and c[1] > 0)          # the Fruits card: 4 rows of 44
    margin = {"automatic": 20, "plain": 0, "grouped": 0, "inset": 20, "sidebar": 10}[style]
    W = frame_of_window(dump)[2]
    assert card[0] == margin and card[2] == W - 2 * margin, f"{style}: rows inset {margin} pt from the edges"
    assert apple[0] == (12 if style == "sidebar" else 20), "row content inset"
    # listRowInsets: Carrot's content 50 pt from the row's leading edge, 20 pt above and below (a 61 pt row)
    assert carrot[0] == 50 and carrot[1] == 20, "listRowInsets"
    assert any(r[3] == 61 for r in rows), "listRowInsets: a taller row"
    # listRowBackground: Banana's row is yellow across the row
    by = int(card[1] + 44 + 22 + 106) if style != "plain" else None
    bx = int(margin + 300)
    yellow_rows = [y for y in range(100, 600, 2) if near(shot.getpixel((bx, y)), YELLOW)]
    assert len(yellow_rows) >= 18, f"{style}: listRowBackground ({len(yellow_rows)} px)"
    # backgrounds: plain / inset lists on the system background, the others on the grouped background
    bg = shot.getpixel((5, 800))
    if style in ("plain", "inset"):
        assert near(bg, WHITE, 6), f"{style}: list background {bg}"
    else:
        assert near(bg, GROUPED_BG, 6), f"{style}: grouped background {bg}"
    # separators (in the Fruits card): none in sidebars; Cherry's top one hidden (listRowSeparator); Date's tinted red
    card_lines = subtree(dump, "apple", up=2)
    seps = [v[1] for v in views(card_lines, "UIView") if v[3] < 1]
    if style == "sidebar":
        assert not seps, f"sidebar: no separators {seps}"
    else:
        expect = [43.6667, 131.667] + ([175.667] if style in ("plain", "inset") else [])
        assert [round(y, 1) for y in seps] == [round(y, 1) for y in expect], \
            f"{style}: separators between rows, none above Cherry (listRowSeparator(.hidden, edges: .top)): {seps}"
        reds = [y for y in range(100, 700) if (lambda c: c[0] > 200 and c[0] - c[1] > 25 and c[0] - c[2] > 25)(shot.getpixel((300, y)))]
        assert reds, f"{style}: listRowSeparatorTint(.red)"
    # headers: grouped styles uppercase, plain / inset bold on a band, sidebar large and bold
    if style in ("automatic", "grouped"):
        assert "text=FRUITS" in dump, f"{style}: uppercase header"
    else:
        assert "text=Fruits" in dump, f"{style}: header as written"
    assert re.search(r"UILabel \([0-9.]+ [0-9.]+; [0-9.]+ x 2[4-6]\) text=Prominent", dump), "headerProminence(.increased): title3"


@pytest.mark.os_matrix
def test_section_expansion(launch):
    app = launch("HelloContainers", env={"LIST_STYLE": "sidebar"})
    app.wait_view(r"id=extra-3")
    app.wait_still()
    app.screenshot("sidebar")
    app.tap_id("list-header-2")
    app.wait_log(r"^more hidden")
    collapsed = app.wait_view(r"id=extra-1", gone=True)
    app.tap_id("list-header-2")
    app.wait_log(r"^more shown")
    expanded = app.wait_view(r"id=extra-1")
    assert app.quit() == 0, "exits cleanly"
    assert "id=big" in collapsed and "id=extra-1" not in collapsed, "Section(isExpanded:) collapses"
    assert "id=extra-3" in expanded, "and expands again"


def test_spacing(launch):
    app = launch("HelloContainers", env={"PAGE": "spacing"})
    app.wait_view(r"id=three")
    app.wait_still()
    dump = app.view_dump()
    shot = app.screenshot("spacing")
    assert app.quit() == 0, "exits cleanly"
    cards = [c for c in views(dump, "UIView") if c[3] == 44]
    assert [c[1] for c in cards] == [18, 72, 166], f"listRowSpacing 10 and listSectionSpacing 50: {cards}"
    assert near(shot.getpixel((8, 600)), (0, 199, 190), 40), "scrollContentBackground(.hidden): the mint background shows"
    assert near(shot.getpixel((100, 62 + 18 + 60)), (255, 255, 255), 8), "rows keep their card"


@pytest.mark.os_matrix
def test_multiple_selection(launch):
    app = launch("HelloContainers", env={"PAGE": "selection"})
    app.wait_view(r"id=pick-Date")
    app.wait_view(r"text=Edit")
    app.tap_text("Edit")
    app.wait_view(r"id=row-select-1")
    app.tap_id("pick-Banana")
    app.wait_log(r"^selected 1$")
    app.tap_id("row-select-3")
    app.wait_log(r"^selected 1,3$")
    app.wait_still()
    dump = app.view_dump()
    app.screenshot("selection")
    app.tap_id("pick-Banana")
    app.wait_log(r"^selected 3$")
    assert app.quit() == 0, "exits cleanly"
    assert "id=selected text=selected 1,3" in dump, "List(selection: Set) selects several rows in edit mode"
    assert frame(dump, "pick-Banana")[0] == 58, "rows make room for the selection circles"


def test_pinned_lazy_vstack(launch):
    app = launch("HelloContainers", env={"PAGE": "pinned"})
    app.wait_view(r"id=footer-2")
    app.wait_still()
    top = app.view_dump()
    app.send("swipeid pinned-scroll 0 -300 0.8")
    app.wait_still()
    dump = app.view_dump()
    app.screenshot("pinned")
    assert app.quit() == 0, "exits cleanly"
    offset = scroll_offset(dump, "pinned-scroll")
    h0, h1, f1, f0 = frame(dump, "header-0"), frame(dump, "header-1"), frame(dump, "footer-1"), frame(dump, "footer-0")
    assert frame(top, "header-0")[1] == 0 and frame(top, "header-1")[1] == 406, "headers at their places before scrolling"
    # section 0: header 0..30, rows 30..382, footer 382..406; section 1 starts at 406
    assert 406 < offset < 406 + 352, f"scrolled into section 1 ({offset})"
    assert h1[1] == offset, "the header of the section under the top edge sticks to it"
    assert h0[1] == 376, "the previous header is pushed away by the next section"
    assert f0[1] == 382 and f1[1] == 788, "footers stay where they are when their place is visible"
    # the last visible footer: section 2's footer sits at the bottom edge while section 2 is under it
    f2 = frame(dump, "footer-2")
    vis_bottom = offset + float(re.search(r"\(0 [0-9.]+; 402 x ([0-9.]+)\) id=pinned-scroll", dump).group(1))
    assert f2[1] == min(1194, vis_bottom - 24), f"footer pinned to the bottom edge ({f2}, bottom {vis_bottom})"
    assert grep(dump, r"id=header-1").strip(), "header drawn"


def test_pinned_grid_and_hstack(launch):
    app = launch("HelloContainers", env={"PAGE": "grid"})
    app.wait_view(r"id=cell-1-11")
    app.wait_still()
    grid0 = app.view_dump()
    app.send("swipeid grid-scroll 0 -250 0.8")
    app.wait_still()
    grid = app.view_dump()
    app.screenshot("grid")
    assert app.quit() == 0, "exits cleanly"
    # LazyVGrid: header spanning the columns, then 3 columns (flexible, flexible, fixed 60 aligned leading), 12 pt rows
    h = frame(grid0, "grid-header-0")
    assert h[0] == 0 and h[2] == 402 - 32, "section header spans the grid"
    c0, c1, c2, c3 = (frame(grid0, f"cell-0-{i}") for i in range(4))
    assert c0[1] == c1[1] == c2[1] and c3[1] == c0[1] + 40 + 12, "rows of three, 12 pt apart"
    assert abs((c3[0] + c3[2] / 2) - (c0[0] + c0[2] / 2)) <= 0.5 and c0[0] + c0[2] / 2 == 147 / 2, \
        "flexible columns share the width; cells centred in them"
    assert c2[0] == 402 - 32 - 60, "the fixed column, leading-aligned at the trailing edge"
    offset = scroll_offset(grid, "grid-scroll")
    assert frame(grid, "grid-header-0")[1] == offset, "LazyVGrid(pinnedViews: .sectionHeaders) pins the header"

    app = launch("HelloContainers", env={"PAGE": "hstack"})
    app.wait_view(r"id=h-2-4")
    app.wait_still()
    app.send("swipeid hstack-scroll -500 0 0.8")
    app.wait_still()
    hs = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    # section 1 spans x 440..880 (header 40 + 5 items of 80); a horizontal swipe of 500 pins its header
    h1, h0 = frame(hs, "hheader-1"), frame(hs, "hheader-0")
    assert h0[0] == 400 - 40 or h0[0] < h1[0], "LazyHStack: the earlier header is pushed away"
    assert h1[0] > 440, f"LazyHStack(pinnedViews:) pins the header at the leading edge ({h1})"


def test_scroll_indicators_and_bounce(launch):
    app = launch("HelloContainers", env={"PAGE": "scroll"})
    app.wait_view(r"id=bounce-always")
    app.wait_still()
    dump = app.view_dump()
    app.send("swipeid bounce-based 0 80 0.6")
    app.send("swipeid bounce-always 0 80 0.6")
    app.wait_log(r"^always bounced")
    app.wait_still()
    assert app.quit() == 0, "exits cleanly"
    assert re.search(r"id=indicators-hidden\n\s+_TtC7SwiftUI14_SUIScrollView .*, indicators hidden$", dump, re.M), \
        "scrollIndicators(.hidden)"
    assert re.search(r"id=indicators-shown\n\s+_TtC7SwiftUI14_SUIScrollView .*inset bottom 0$", dump, re.M), \
        "indicators shown by default"
    assert "based on size bounced" not in app.log, "scrollBounceBehavior(.basedOnSize): short content does not bounce"
