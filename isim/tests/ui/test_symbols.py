"""SF Symbol stand-ins (HelloSymbols): a grid of common symbol names and their .fill / .circle / .square / .slash
variants. By pixels (a screenshot at 2 px per point): none draws the placeholder, .fill differs from the outline, names
are distinct, and SymbolConfiguration weight / scale / tint (and a font's weight) show. Port of tests/ui/symbols.sh and
symbols_check.py."""
import re

import pytest

K = 2                                                     # pixels per point in the screenshot
pytestmark = pytest.mark.os_matrix


@pytest.fixture(scope="module")
def symbols(launch_module):
    app = launch_module("HelloSymbols", env={"ISIM_SHOT_SCALE": str(K)})
    app.wait_log(r"symbols laid out: ")                   # the app lays out the grid
    shot = app.screenshot("symbols")
    return app.log, shot.load(), app.quit()


def mask(px, x, y, size, pred=lambda r, g, b: r + g + b < 384):
    """the set of 'ink' pixels in a cell, relative to the cell's corner"""
    return frozenset((i, j) for j in range(size * K) for i in range(size * K) if pred(*px[x * K + i, y * K + j][:3]))


def iou(a, b):
    return len(a & b) / max(1, len(a | b))


@pytest.fixture(scope="module")
def cells(symbols):
    log, px, _ = symbols
    found = {}
    for m in re.finditer(r"cell (\d+) (\S+) (\d+) (\d+) (\d+)", log):    # stdout lines may share a line with stderr
        found[int(m[1])] = (m[2], mask(px, int(m[3]), int(m[4]), int(m[5])))
    return [found[i] for i in sorted(found)]


def test_log(symbols):
    log, _, rc = symbols
    missing = [l for l in log.splitlines() if "has no substitute" in l and "isim.no.such.symbol" not in l]
    assert not missing, f"no symbol name is reported missing: {missing}"
    assert rc == 0


def test_grid(cells):
    assert len(cells) > 150, f"grid laid out: {len(cells)}"
    placeholder = cells[0][1]
    assert len(placeholder) > 40, "reference placeholder draws"
    empty = [n for n, m in cells[1:] if len(m) < 30]
    assert not empty, f"every symbol draws something: {empty}"
    like = [n for n, m in cells[1:] if iou(m, placeholder) > 0.6]
    assert not like, f"no symbol draws the placeholder ({len(cells) - 1} names): {like}"
    seen, dupes = {}, []
    for n, m in cells[1:]:
        if m in seen:
            dupes.append((seen[m], n))
        seen.setdefault(m, n)
    assert not dupes, f"distinct names draw distinct pictures: {dupes}"


def test_fill_variants(cells):
    inks = dict(cells)
    pairs = [(n, n + ".fill") for n, _ in cells if n + ".fill" in inks]
    assert len(pairs) >= 40, f"outline/fill pairs in the grid: {len(pairs)}"
    same = [a for a, b in pairs if iou(inks[a], inks[b]) > 0.9]
    assert not same, f".fill differs from the outline: {same}"
    thin = [(a, len(inks[a]), len(inks[b])) for a, b in pairs if len(inks[b]) < 1.1 * len(inks[a])]
    assert not thin, f".fill carries more ink than the outline: {thin}"


def test_configuration(symbols):
    log, px, _ = symbols
    extras = {}
    for line in log.splitlines():
        p = line.split()
        if len(p) >= 7 and p[0] == "extra":
            extras[p[1]] = (int(p[2]), int(p[3]), int(p[4]), p[6])
    assert len(extras) == 6, f"weight/scale/tint row laid out: {list(extras)}"
    ink = {t: len(mask(px, x, y, s)) for t, (x, y, s, _) in extras.items()}
    assert ink["black"] > 2 * ink["light"], f"weight: black strokes heavier than ultraLight {ink}"
    assert ink["fontbold"] > 1.5 * ink["light"], f"font weight carries into the symbol (bold > ultraLight) {ink}"
    x, y, s, _ = extras["tinted"]
    red = len(mask(px, x, y, s, lambda r, g, b: r > 200 and g < 90 and b < 90))
    assert red > 200, f"tint colors the template: {red}"
    small, large = int(extras["small"][3].split("x")[0]), int(extras["large"][3].split("x")[0])
    assert small < large and len(mask(px, *extras["small"][:3])) < len(mask(px, *extras["large"][:3])), \
        f"scale: small < large {small} {large}"


def test_rendering_modes(symbols):
    """plus.circle.fill: the glyph (primary layer) on its circle (secondary layer) in each rendering mode"""
    log, px, _ = symbols
    boxes = {m[1]: tuple(map(int, m.groups()[1:])) for m in re.finditer(r"mode (\S+) (\d+) (\d+) (\d+)", log)}
    assert len(boxes) == 5, boxes

    def count(tag, pred):
        x, y, s = boxes[tag]
        return sum(1 for j in range(s * K) for i in range(s * K) if pred(*px[x * K + i, y * K + j][:3]))
    near = lambda c: (lambda r, g, b: abs(r - c[0]) + abs(g - c[1]) + abs(b - c[2]) < 60)
    blue, light_blue, red, green, white = (0, 122, 255), (127, 188, 255), (255, 59, 48), (52, 199, 89), (255, 255, 255)
    black = lambda r, g, b: r + g + b < 60
    assert count("monochrome", black) > 1500 and count("monochrome", near(blue)) == 0, "monochrome: one colour, the glyph cut out"
    assert count("hierarchical", near(blue)) > 150 and count("hierarchical", near(light_blue)) > 1000, \
        "hierarchical: the glyph in the colour, the circle lighter"
    assert count("palette", near(red)) > 150 and count("palette", near(blue)) > 1000, "palette: red glyph on a blue circle"
    assert count("multicolor", near(green)) > 1000 and count("multicolor", black) == 0, "multicolor: plus.circle.fill is green"
    assert count("multicolor-heart", near(red)) > 1000 and count("multicolor-heart", black) == 0, \
        "multicolor: heart.fill is red whatever the tint"
