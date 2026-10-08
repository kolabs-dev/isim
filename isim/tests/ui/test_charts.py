"""Swift Charts (HelloCharts, `import Charts`): bar heights against the y domain, annotations, stacked series with a
custom style scale and legend, a donut of sector marks, line/point/rule/area positions, horizontal bars, custom
AxisMarks labels, a date axis and a rectangle heat map. Port of tests/ui/charts.sh and charts_check.py (pixels measured
on one screenshot, 1 px = 1 pt)."""
import re

import pytest
from isimtest import first_y, rgb as _rgb, runs_x, runs_y, white


def rgb(im, x, y):                                                  # nearest pixel, as charts_check.py measured
    return _rgb(im, round(x), round(y))


def close(a, b, tol):
    return abs(a - b) <= tol


def blue(c): return c[2] > 200 and c[0] < 60 and 80 < c[1] < 160          # systemBlue (accent color)
def pure_blue(c): return c[2] > 200 and c[0] < 40 and c[1] < 40
def red(c): return c[0] > 230 and c[1] < 40 and c[2] < 40
def green(c): return c[1] > 130 and c[0] < 40 and c[2] < 40
def orange(c): return c[0] > 230 and 100 < c[1] < 190 and c[2] < 60
def colored(c): return not white(c)


@pytest.fixture(scope="module")
def charts(launch_module):
    app = launch_module("HelloCharts")
    app.wait_log(r"charts shown")
    tree = app.wait_view(r"x 200\) id=ideal")
    shot = app.screenshot("charts")
    return tree, shot, app.quit()


def test_labels(charts):
    tree, _, rc = charts
    has = lambda pat: re.search(pat, tree, re.M) is not None
    assert all(has(rf"text={v}$") for v in (0, 10, 20, 30, 40)), "y axis value labels (0 ... 40)"
    assert all(has(rf"text={v}$") for v in ("A", "B", "C", "Mon", "Tue")), "category axis labels"
    assert all(f"text={v}" in tree for v in ("v10", "v20", "v40")), "annotations on bars"
    assert all(f"text={v}" in tree for v in ("Apples", "Pears", "Plums")), "legend for foregroundStyle(by:)"
    assert tree.count("text=Apples") == 2, "chartLegend(.hidden) hides a legend"
    assert all(f"text={v}" in tree for v in ("0%", "50%", "100%")), "custom AxisMarks values and labels"
    assert "text=q25" in tree and "text=q75" in tree, "several AxisMarks on one axis"
    assert "x 200) id=ideal" in tree, "a chart in a ScrollView is 200 pt tall"
    assert has(r"text=Jan [0-9]") and "text=5000" in tree, "date axis labels"
    assert rc == 0


def test_bars(charts):
    im = charts[1]
    # bar chart (20,60 360x150), y domain 0...40, values 10/20/40: heights 1:2:4 from a shared baseline
    runs = [r for r in runs_x(im, 186, 20, 380, blue) if r[1] - r[0] > 20]
    heights = []
    for a, b in runs:
        x = (a + b) // 2
        top = first_y(im, x, 186, 60, lambda c: not blue(c)) + 1
        bottom = first_y(im, x, 186, 230, lambda c: not blue(c))
        heights.append(bottom - top)
    assert len(heights) == 3 and heights[2] > 100 and close(heights[1] / heights[2], 0.5, 0.03) \
        and close(heights[0] / heights[2], 0.25, 0.03), f"BarMark: three bars with heights 10:20:40 {runs} {heights}"
    assert close(heights[2], 125, 3), f"chartYScale(domain: 0...40): tallest bar spans the plot {heights}"
    assert close(runs[0][1] - runs[0][0], runs[2][1] - runs[2][0], 2) \
        and close(runs[1][0] - runs[0][0], runs[2][0] - runs[1][0], 2), f"bars share a band layout {runs}"


def test_stacked_bars(charts):
    im = charts[1]
    # stacked bars with foregroundStyle(by:) + chartForegroundStyleScale: Mon 10 red + 30 green, Tue 20 red + 10 green
    mon_r, mon_g = runs_y(im, 57, 220, 370, red), runs_y(im, 57, 220, 370, green)
    tue_r, tue_g = runs_y(im, 132, 220, 370, red), runs_y(im, 132, 220, 370, green)
    detail = (mon_r, mon_g, tue_r, tue_g)
    assert len(mon_r) == len(mon_g) == len(tue_r) == len(tue_g) == 1, f"stacked BarMarks {detail}"
    hr, hg = mon_r[0][1] - mon_r[0][0], mon_g[0][1] - mon_g[0][0]
    tr, tg = tue_r[0][1] - tue_r[0][0], tue_g[0][1] - tue_g[0][0]
    assert close(hg / hr, 3, 0.25) and close(tr / tg, 2, 0.2) and mon_g[0][1] <= mon_r[0][0] + 1 \
        and close(mon_r[0][1], tue_r[0][1], 1) and close((hr + hg) / (tr + tg), 40 / 30, 0.08), \
        f"stacked BarMarks (series stack in order, custom style scale) {detail}"


def test_donut(charts):
    im = charts[1]
    # SectorMark angles 1:1:2, innerRadius .ratio(0.5), first sector from 12 o'clock clockwise
    col = runs_y(im, 295, 220, 330, colored)
    assert len(col) == 2, f"SectorMark donut {col}"
    top, bottom = col[0][0], col[1][1]
    cx, cy, r = 295, (top + bottom) / 2, (bottom - top) / 2
    d = 0.75 * r * 0.7071
    q1, q2, q3 = rgb(im, cx + d, cy - d), rgb(im, cx + d, cy + d), rgb(im, cx - 0.75 * r, cy)
    assert blue(q1) and (q2[1] > 150 and q2[0] < 120) and orange(q3) and white(rgb(im, cx, cy)) \
        and close(col[0][1] - col[0][0], r / 2, 3), f"SectorMark donut: quarter, quarter, half; hole of half the radius {col}"


def test_line_point_rule_area(charts):
    im = charts[1]
    # line + points + rule (20,390 170x100), axes hidden: plot (20,391) 170x99, domains 0...3 x 0...40
    ly = lambda v: 391 + 99 * (1 - v / 40)
    lx = lambda v: 20 + 170 * v / 3
    pt = rgb(im, lx(1), ly(30))
    assert pt[0] > 230 and 100 < pt[1] < 160 and pt[2] < 60, f"PointMark at (1, 30) {pt}"
    reddish = lambda c: c[0] > 230 and c[1] < 140 and c[2] < 140                 # a 1 pt line, antialiased
    rule = lambda x: any(reddish(rgb(im, x, round(ly(25)) + dy)) for dy in (-1, 0, 1))
    assert rule(30) and rule(180) and white(rgb(im, 30, round(ly(25)) - 4)), "RuleMark(y: 25) across the plot"
    assert any(blue(rgb(im, lx(0.5), ly(20) + dy)) for dy in (-1, 0, 1)), "LineMark between (0,10) and (1,30)"
    # area (210,390 170x100): filled under the line down to zero
    ax = lambda v: 210 + 170 * v / 3
    assert pure_blue(rgb(im, ax(1), ly(30) + 6)) and white(rgb(im, ax(1), ly(30) - 6)) \
        and pure_blue(rgb(im, ax(1.5), 486)), "AreaMark fills below its line"


def test_horizontal_date_heatmap_grouped(charts):
    im = charts[1]
    # horizontal bars (20,510 170x100): Ann 30, Bob 15 over 0...30
    ann = [r for r in runs_x(im, 539, 20, 200, blue) if r[1] - r[0] > 10]
    bob = [r for r in runs_x(im, 582, 20, 200, blue) if r[1] - r[0] > 10]
    assert len(ann) == 1 and len(bob) == 1 and ann[0][0] == bob[0][0] \
        and close((bob[0][1] - bob[0][0]) / (ann[0][1] - ann[0][0]), 0.5, 0.03), \
        f"horizontal BarMarks (y categories, x values) {ann} {bob}"
    # date bars (20,630 360x100): five days, values 1000...5000
    runs = [r for r in runs_x(im, 706, 20, 380, blue) if r[1] - r[0] > 10]
    hs = [first_y(im, (a + b) // 2, 706, 630, lambda c: not blue(c)) for (a, b) in runs]
    assert len(runs) == 5 and all(hs[i] > hs[i + 1] for i in range(4)), f"BarMark on a date axis {runs} {hs}"
    # RectangleMark heat map (20,750 100x60), axes hidden
    assert red(rgb(im, 45, 765)) and pure_blue(rgb(im, 95, 765)) and pure_blue(rgb(im, 45, 795)) \
        and red(rgb(im, 95, 795)), "RectangleMark cells"
    # grouped bars (position(by:)) at (140,750 240x60), y 0...30: Mon apples 10 (red) beside pears 30 (green)
    r, g = runs_y(im, 182, 745, 815, red), runs_y(im, 218, 745, 815, green)
    assert len(r) == 1 and len(g) == 1 and close(g[0][1] - g[0][0], 59, 2) \
        and close((r[0][1] - r[0][0]) / (g[0][1] - g[0][0]), 1 / 3, 0.05) and close(r[0][1], g[0][1], 1) \
        and not green(rgb(im, 182, 760)) and white(rgb(im, 182, 760)), f"BarMark.position(by:) groups bars {r} {g}"
