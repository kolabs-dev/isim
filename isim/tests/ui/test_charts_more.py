"""More Swift Charts (HelloChartsMore): point symbols (basic shapes, a custom ChartSymbolShape, symbol { view },
symbol(by:) + symbolSize(by:) through their scales), axis titles with positions, chartBackground / chartOverlay placed
with ChartProxy (and its value lookups), chartXSelection under a held finger, a scrolling chart (visible domain,
scroll position binding, value-aligned snapping), chartPlotStyle, iOS 18 vectorized plots (BarPlot / PointPlot with
key paths, function LinePlot / AreaPlot, SectorPlot) and, on iOS 26, Chart3D with a pose that follows a drag.
Pixels are measured on screenshots (1 px = 1 pt); the charts sit at fixed positions."""
import re

import pytest
from isimtest import rgb as _rgb, runs_x, white


def rgb(im, x, y):
    return _rgb(im, round(x), round(y))


def blue(c): return c[2] > 200 and c[0] < 40 and c[1] < 40
def red(c): return c[0] > 230 and c[1] < 40 and c[2] < 40
def green(c): return c[1] > 140 and c[0] < 40 and c[2] < 40
def orange(c): return c[0] > 230 and 100 < c[1] < 170 and c[2] < 60
def yellow(c): return c[0] > 240 and c[1] > 240 and c[2] < 40
def pale_yellow(c): return c[0] > 240 and c[1] > 240 and 120 < c[2] < 190
def lavender(c): return 190 < c[0] < 220 and 190 < c[1] < 220 and c[2] > 240


@pytest.fixture(scope="module")
def more(launch_module):
    app = launch_module("HelloChartsMore")
    app.wait_log(r"more charts shown")
    app.wait_log(r"proxy plot")
    tree = app.wait_view(r"text=Letters")
    shot = app.screenshot("more")
    return app, tree, shot


def test_symbols(more):
    _, _, im = more
    # x domain 0...6 over the 170-pt plot at x 20; y = 1 is at 87 (plot 51...160, domain 0...1.5)
    cx = lambda i: 20 + 170 * i / 6
    y1, y04 = 51 + 109 * (1 - 1 / 1.5), 51 + 109 * (1 - 0.4 / 1.5)
    assert blue(rgb(im, cx(1) + 5, y1 + 5)) and blue(rgb(im, cx(1) - 5, y1 - 5)), "square symbol (corners filled)"
    assert blue(rgb(im, cx(2), y1 + 2)) and white(rgb(im, cx(2) - 6, y1 - 6)), "triangle symbol"
    assert blue(rgb(im, cx(3), y1)) and white(rgb(im, cx(3) + 5, y1 + 5)), "diamond symbol (corners empty)"
    assert green(rgb(im, cx(4) - 5, y1)) and green(rgb(im, cx(4) + 5, y1)) and white(rgb(im, cx(4), y1 - 6)), \
        "custom ChartSymbolShape (a bow tie: left and right triangles)"
    assert red(rgb(im, cx(5), y1)) and red(rgb(im, cx(5) - 5, y1 - 5)), "symbol { view }: a 12-pt red square"
    small = [b - a for a, b in runs_x(im, y04, cx(2) - 20, cx(2) + 20, blue)]
    big = [b - a for a, b in runs_x(im, y04, cx(4) - 20, cx(4) + 20, blue)]
    assert len(small) == 1 and len(big) == 1 and small[0] <= 9 and big[0] >= 18, \
        f"symbolSize(by:) through chartSymbolSizeScale(range: 30...400): {small} {big}"


def test_axis_titles(more):
    _, tree, im = more
    assert "text=Letters" in tree and "text=Amount" in tree, "chartXAxisLabel / chartYAxisLabel"
    ink = lambda x0, x1, y0, y1: sum(not white(rgb(im, x, y)) for x in range(x0, x1) for y in range(y0, y1))
    # chart at (210, 50, 170, 110): "Letters" below the x labels at the trailing end, "Amount" vertical at the leading side
    assert ink(335, 380, 143, 158) > 20 and ink(215, 300, 143, 158) == 0, "x title: below the plot, trailing"
    assert ink(210, 224, 60, 115) > 20, "y title: vertical, leading"


def test_proxy_overlay_background(more):
    app, _, im = more
    m = app.wait_log(r"proxy plot (\d+) (\d+) (\d+) (\d+) C at (\d+) 30 at (\d+) back (\S+) (-?\d+)")
    px, py, pw, ph, cx, cy, back, v = m.groups()
    px, py, pw, ph, cx, cy = map(int, (px, py, pw, ph, cx, cy))
    assert back == "C" and int(v) == 30, "value(atX:) / value(atY:) invert position(forX:) / position(forY:)"
    assert abs(cx - (pw / 6 * 2.5)) <= 2 and abs(cy - ph * 0.5) <= 2, "positions inside the plot frame (category band center, y 30 of 60)"
    assert orange(rgb(im, 20 + px + cx, 175 + py + cy)), "overlay dot at geometry[plotFrame] + position(for:)"
    assert pale_yellow(rgb(im, 20 + px + 6, 175 + py + 6)) and white(rgb(im, 20 + px + pw + 12, 175 + py + 6)), \
        "chartBackground fills plotFrame (not the axis labels' area)"


def test_selection(more):
    app, _, _ = more
    app.drag(218, 242, 220, 242, 0.3, hold=1.0)        # held over bar D
    app.wait_log(r"selected D")
    app.wait_log(r"selected nil")                      # lifted: the selection clears


def test_plot_style_and_vectorized(more):
    _, _, im = more
    assert yellow(rgb(im, 150, 525)) and blue(rgb(im, 21, 495)), "chartPlotStyle: background + border of the plot area"
    band = 170 / 6
    a, b = 210 + band * 0.5, 210 + band * 1.5
    assert red(rgb(im, a, 540)) and blue(rgb(im, b, 540)), "BarPlot foregroundStyle(by: key path) through the style scale"
    assert any(green(rgb(im, 210 + band * 5.5, y)) for y in range(444, 452)), "PointPlot on top of the tallest bar"


def test_functions_and_sectors(more):
    _, _, im = more
    x = 20 + 170 * 0.75                                # sin(pi/2) = 1: the top of the plot
    assert any(red(rgb(im, x, y)) for y in range(559, 568)), "LinePlot of sin(x) over chartXScale(-pi...pi)"
    assert lavender(rgb(im, 30, 610)) and not lavender(rgb(im, 30, 575)), "AreaPlot between yStart -0.5 and yEnd 0.5"
    assert red(rgb(im, 295 + 26, 610 - 15)) and blue(rgb(im, 295 - 30, 610)), "SectorPlot: A (1/3) from 12 o'clock, B the rest"


def test_scrolling(more):
    app, _, im = more
    assert not any(red(rgb(im, x, 405)) for x in range(150, 250)), "first 10 of 30 bars shown (chartXVisibleDomain)"
    app.drag(300, 380, 100, 380, 0.6)
    shot = app.screenshot("scrolled")                  # taken after the drag
    positions = re.findall(r"scroll x (\d+)", app.log)
    assert positions and positions[-1] == "5", f"chartScrollPosition: snapped to a multiple of 5 {positions}"
    assert red(rgb(shot, 200, 405)) and blue(rgb(shot, 56, 405)), "scrolled to 5: bars 10+ (red) in view"


def test_chart3d(launch):
    app = launch("HelloChartsMore", os_version="26")
    app.wait_log(r"3D shown")
    im = app.screenshot("3d")
    region = [(x, y) for x in range(40, 380, 4) for y in range(680, 820, 4)]
    hues = {(c[0] > 150, c[1] > 150, c[2] > 150) for c in (rgb(im, x, y) for x, y in region) if not white(c)}
    assert len(hues) >= 3, f"heightBased surface colors {hues}"
    assert any(red(rgb(im, x, y)) for x in range(185, 215) for y in range(690, 725)), "3D point (red, top center)"
    app.drag(200, 750, 260, 720, 0.5)
    app.wait_log(r"pose [1-9]\d* ")                     # dragging rotates the bound pose
    assert app.quit() == 0
