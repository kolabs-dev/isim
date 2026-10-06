"""Measures the HelloCharts screenshot (1 px = 1 pt): bar heights, stacks, donut sectors, line/point/rule/area
positions, horizontal bar lengths, date bars and heat map cells. Prints PASS/FAIL lines; exit status 1 on failure."""
import sys
from pixels import Image, white, near

im = Image(sys.argv[1])
failed = False


def check(name, ok, detail=""):
    global failed
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else "   " + str(detail)))
    failed |= not ok


blue = lambda r, g, b: b > 200 and r < 60 and g > 80 and g < 160          # systemBlue (accent color)
pure_blue = lambda r, g, b: b > 200 and r < 40 and g < 40
red = lambda r, g, b: r > 230 and g < 40 and b < 40
green = lambda r, g, b: g > 130 and r < 40 and b < 40
orange = lambda r, g, b: r > 230 and 100 < g < 190 and b < 60
colored = lambda r, g, b: not white(r, g, b)

# 1. bar chart (20,60 360x150), y domain 0...40, values 10/20/40: heights 1:2:4 from a shared baseline
runs = [r for r in im.runs_x(186, 20, 380, blue) if r[1] - r[0] > 20]
heights, base = [], None
for (a, b) in runs:
    x = (a + b) // 2
    top = im.first_y(x, 186, 60, lambda *c: not blue(*c)) + 1
    bottom = im.first_y(x, 186, 230, lambda *c: not blue(*c))
    heights.append(bottom - top); base = bottom
check("BarMark: three bars with heights 10:20:40", len(heights) == 3 and heights[2] > 100 and near(heights[1] / heights[2], 0.5, 0.03)
      and near(heights[0] / heights[2], 0.25, 0.03), (runs, heights))
check("chartYScale(domain: 0...40): tallest bar spans the plot", len(heights) == 3 and near(heights[2], 125, 3), heights)
check("bars share a band layout (equal widths, even spacing)", len(runs) == 3 and near(runs[0][1] - runs[0][0], runs[2][1] - runs[2][0], 2)
      and near((runs[1][0] - runs[0][0]), (runs[2][0] - runs[1][0]), 2), runs)

# 2. stacked bars with foregroundStyle(by:) + chartForegroundStyleScale: Mon 10 red + 30 green, Tue 20 red + 10 green
def stack(x):
    reds = im.runs_y(x, 220, 370, red)
    greens = im.runs_y(x, 220, 370, green)
    return reds, greens
mon_r, mon_g = stack(57)
tue_r, tue_g = stack(132)
ok = len(mon_r) == 1 and len(mon_g) == 1 and len(tue_r) == 1 and len(tue_g) == 1
if ok:
    hr, hg = mon_r[0][1] - mon_r[0][0], mon_g[0][1] - mon_g[0][0]
    tr, tg = tue_r[0][1] - tue_r[0][0], tue_g[0][1] - tue_g[0][0]
    ok = near(hg / hr, 3, 0.25) and near(tr / tg, 2, 0.2) and mon_g[0][1] <= mon_r[0][0] + 1 and near(mon_r[0][1], tue_r[0][1], 1)
    ok = ok and near((hr + hg) / (tr + tg), 40 / 30, 0.08)
check("stacked BarMarks (series stack in order, custom style scale)", ok, (mon_r, mon_g, tue_r, tue_g))

# 3. donut (SectorMark angles 1:1:2, innerRadius .ratio(0.5)), first sector from 12 o'clock clockwise
col = im.runs_y(295, 220, 330, colored)
ok = len(col) == 2
if ok:
    top, bottom = col[0][0], col[1][1]
    cx, cy, r = 295, (top + bottom) / 2, (bottom - top) / 2
    d = 0.75 * r * 0.7071
    q1, q2, q3 = im.rgb(cx + d, cy - d), im.rgb(cx + d, cy + d), im.rgb(cx - 0.75 * r, cy)
    ok = blue(*q1) and (q2[1] > 150 and q2[0] < 120) and orange(*q3) and white(*im.rgb(cx, cy)) and near(col[0][1] - col[0][0], r / 2, 3)
check("SectorMark donut: quarter, quarter, half; hole of half the radius", ok, (col, ))

# 4. line + points + rule (20,390 170x100), axes hidden: plot (20,391) 170x99, domains 0...3 x 0...40
ly = lambda v: 391 + 99 * (1 - v / 40)
lx = lambda v: 20 + 170 * v / 3
pt = im.rgb(lx(1), ly(30))
check("PointMark at (1, 30)", pt[0] > 230 and 100 < pt[1] < 160 and pt[2] < 60, pt)
reddish = lambda r, g, b: r > 230 and g < 140 and b < 140                  # a 1 pt line, antialiased over two rows
rule = lambda x: any(reddish(*im.rgb(x, round(ly(25)) + dy)) for dy in (-1, 0, 1))
check("RuleMark(y: 25) across the plot", rule(30) and rule(180) and white(*im.rgb(30, round(ly(25)) - 4)), (im.rgb(30, round(ly(25))),))
check("LineMark between (0,10) and (1,30)", any(blue(*im.rgb(lx(0.5), ly(20) + dy)) for dy in (-1, 0, 1)), im.rgb(lx(0.5), ly(20)))

# 5. area (210,390 170x100): filled under the line down to zero
ax = lambda v: 210 + 170 * v / 3
check("AreaMark fills below its line", pure_blue(*im.rgb(ax(1), ly(30) + 6)) and white(*im.rgb(ax(1), ly(30) - 6)) and pure_blue(*im.rgb(ax(1.5), 486)),
      (im.rgb(ax(1), ly(30) + 6), im.rgb(ax(1), ly(30) - 6)))

# 6. horizontal bars (20,510 170x100): Ann 30, Bob 15 over 0...30
ann = [r for r in im.runs_x(539, 20, 200, blue) if r[1] - r[0] > 10]
bob = [r for r in im.runs_x(582, 20, 200, blue) if r[1] - r[0] > 10]
check("horizontal BarMarks (y categories, x values)", len(ann) == 1 and len(bob) == 1 and ann[0][0] == bob[0][0]
      and near((bob[0][1] - bob[0][0]) / (ann[0][1] - ann[0][0]), 0.5, 0.03), (ann, bob))

# 7. date bars (20,630 360x100): five days, values 1000...5000
runs = [r for r in im.runs_x(706, 20, 380, blue) if r[1] - r[0] > 10]
hs = [im.first_y((a + b) // 2, 706, 630, lambda *c: not blue(*c)) for (a, b) in runs]
check("BarMark on a date axis (unit: .day)", len(runs) == 5 and all(hs[i] > hs[i + 1] for i in range(4)), (runs, hs))

# 8. RectangleMark heat map (20,750 100x60), axes hidden
check("RectangleMark cells", red(*im.rgb(45, 765)) and pure_blue(*im.rgb(95, 765)) and pure_blue(*im.rgb(45, 795)) and red(*im.rgb(95, 795)),
      (im.rgb(45, 765), im.rgb(95, 765)))

# 9. grouped bars (position(by:)) at (140,750 240x60), axes hidden, y 0...30: Mon apples 10 (red) beside pears 30 (green)
r = [x for x in im.runs_y(182, 745, 815, red)]
g = [x for x in im.runs_y(218, 745, 815, green)]
check("BarMark.position(by:) groups bars side by side", len(r) == 1 and len(g) == 1 and near(g[0][1] - g[0][0], 59, 2)
      and near((r[0][1] - r[0][0]) / (g[0][1] - g[0][0]), 1 / 3, 0.05) and near(r[0][1], g[0][1], 1)
      and not green(*im.rgb(182, 760)) and white(*im.rgb(182, 760)), (r, g))

sys.exit(1 if failed else 0)
