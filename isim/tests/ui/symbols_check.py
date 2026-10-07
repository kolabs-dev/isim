"""Checks the HelloSymbols screenshot (shot scale 2): every grid cell draws a substitute that is not the placeholder,
.fill variants differ from (and carry more ink than) their outlines, distinct names draw distinct pictures, and
SymbolConfiguration weight / scale / tint show. usage: symbols_check.py shot.png app.log"""
import re, sys
from pixels import Image

im = Image(sys.argv[1])
log = open(sys.argv[2]).read().splitlines()
K = 2                                                     # pixels per point in the screenshot
failed = False


def check(name, ok, detail=""):
    global failed
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else "   " + str(detail)))
    failed |= not ok


def mask(x, y, size, pred=lambda r, g, b: r + g + b < 384):
    """the set of 'ink' pixels in a cell, relative to the cell's corner"""
    return frozenset((i, j) for j in range(size * K) for i in range(size * K) if pred(*im.rgb(x * K + i, y * K + j)))


cells = {}
for line in log:                                          # (stdout lines may share a line with stderr output)
    for m in re.finditer(r"cell (\d+) (\S+) (\d+) (\d+) (\d+)", line):
        cells[int(m[1])] = (m[2], mask(int(m[3]), int(m[4]), int(m[5])))
cells = [cells[i] for i in sorted(cells)]
check("grid laid out", len(cells) > 150, len(cells))
names = [n for n, _ in cells]
inks = dict(cells)

placeholder = cells[0][1]
check("reference placeholder draws", len(placeholder) > 40, len(placeholder))


def iou(a, b):
    return len(a & b) / max(1, len(a | b))


empty = [n for n, m in cells[1:] if len(m) < 30]
check("every symbol draws something", not empty, empty)
like_placeholder = [n for n, m in cells[1:] if iou(m, placeholder) > 0.6]
check("no symbol draws the placeholder (%d names)" % (len(cells) - 1), not like_placeholder, like_placeholder)

pairs = [(n, n + ".fill") for n in names if n + ".fill" in inks]
check("outline/fill pairs in the grid", len(pairs) >= 40, len(pairs))
same = [a for a, b in pairs if iou(inks[a], inks[b]) > 0.9]
check(".fill differs from the outline", not same, same)
thin = [a for a, b in pairs if len(inks[b]) < 1.1 * len(inks[a])]
check(".fill carries more ink than the outline", not thin, [(a, len(inks[a]), len(inks[a + '.fill'])) for a in thin])

seen, dupes = {}, []
for n, m in cells[1:]:
    if m in seen:
        dupes.append((seen[m], n))
    seen.setdefault(m, n)
check("distinct names draw distinct pictures", not dupes, dupes)

extras = {}
for line in log:
    p = line.split()
    if len(p) >= 7 and p[0] == "extra":
        extras[p[1]] = (int(p[2]), int(p[3]), int(p[4]), p[6])
check("weight/scale/tint row laid out", len(extras) == 6, extras.keys())
if len(extras) == 6:
    ink = {t: len(mask(x, y, s)) for t, (x, y, s, _) in extras.items()}
    check("weight: black strokes heavier than ultraLight", ink["black"] > 2 * ink["light"], ink)
    check("font weight carries into the symbol (bold > ultraLight)", ink["fontbold"] > 1.5 * ink["light"], ink)
    x, y, s, _ = extras["tinted"]
    red = len(mask(x, y, s, lambda r, g, b: r > 200 and g < 90 and b < 90))
    check("tint colors the template", red > 200, red)
    small = int(extras["small"][3].split("x")[0]); large = int(extras["large"][3].split("x")[0])
    check("scale: small < large", small < large and len(mask(*extras["small"][:3])) < len(mask(*extras["large"][:3])), (small, large))
sys.exit(1 if failed else 0)
