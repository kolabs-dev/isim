"""Swift Charts mark styling (HelloCharts -styling, issue #247): lineStyle(by:) through chartLineStyleScale (a dashed
and a solid series), zIndex, offset, shadow, clipShape, mask(content:) and blur on marks (pixels at known values:
axes hidden, domains 0...10), annotations fitted inside the chart or overflowing (AnnotationOverflowResolution),
ChartProxy's line and foreground style lookups and angle(at:), and NumberBins / DateBins."""
from isimtest import rgb, screen_frames, white


def red(c): return c[0] > 200 and c[1] < 80 and c[2] < 80
def blue(c): return c[2] > 200 and c[0] < 80 and c[1] < 80
def green(c): return c[1] > 150 and c[0] < 80 and c[2] < 80


def near(shot, pred, x, y, d=2):
    """pred holds within d points of (x, y) vertically (a stroke's row, give or take its anti-aliasing)"""
    return any(pred(rgb(shot, x, y + k)) for k in range(-d, d + 1))


def test_chart_styling(launch):
    app = launch("HelloCharts", args=["-styling"])
    app.wait_log(r"^bins numbers=\[0, 2, 4, 6, 8, 10, 12\] count=6 index7.9=3 first=0-2$")
    app.wait_log(r"^bins size=\[0, 5, 10, 15, 20\] ints=1$")
    app.wait_log(r"^bins days=3 hours=5 index=1$")
    app.wait_log(r'^proxy line plan=\[8.0, 6.0\] actual=\[\] domain=\["Plan", "Actual"\] styles=\["Plan", "Actual"\] angle=90$')
    tree = app.wait_view(r"id=fitted")
    frames = screen_frames(tree)
    shot = app.wait_shot_still()

    def at(chart, vx, vy):
        """the screen point of a value: the plot is the chart (axes hidden)"""
        x, y, w, h = frames[chart]
        return round(x + vx / 10 * w), round(y - 1 + (1 - vy / 10) * h)

    # lineStyle(by:): the dashed series has gaps, the solid one none
    x0, y7 = at("lines", 0.5, 7)
    x1, _ = at("lines", 9.5, 7)
    reds = [near(shot, red, x, y7, 1) for x in range(int(x0), int(x1))]
    runs = sum(1 for a, b in zip(reds, reds[1:]) if b and not a)
    assert runs >= 10, f"Plan is dashed: {runs} dashes"
    _, y3 = at("lines", 0, 3)
    assert all(near(shot, blue, x, y3) for x in range(int(x0), int(x1), 3)), "Actual is solid"

    # zIndex: the blue rectangle declared first is drawn above the red one
    assert blue(rgb(shot, *at("effects", 2.5, 5))) and red(rgb(shot, *at("effects", 0.5, 5))), "zIndex(1) above"
    # offset(x: 20): the rule at x = 6 is drawn 20 pt to the right
    rx, ry = at("effects", 6, 5)
    assert green(rgb(shot, rx + 20, ry)) and not green(rgb(shot, rx, ry)), "the rule is offset by 20 pt"
    # shadow(color: red, x: 8): red beside the black rectangle's right edge
    sx, sy = at("effects", 9, 5)
    assert red(rgb(shot, sx + 4, sy)), "the shadow is offset to the right"

    # clipShape(Circle()): the rectangle shows inside the circle over the plot only
    cx, cy = at("clip", 3.8, 5)
    assert green(rgb(shot, cx, cy)), "inside the circle"
    assert not green(rgb(shot, *at("clip", 0.5, 5))), "outside the circle"
    # mask: the area shows only where the mask's rectangle is (x 5...7)
    assert blue(rgb(shot, *at("clip", 6, 9))) and not blue(rgb(shot, *at("clip", 7.6, 9))), "the area through its mask"
    # blur: the red rectangle's edges are soft
    bx, by = at("clip", 8, 5)
    soft = rgb(shot, bx, by)
    assert not red(soft) and not white(soft), f"blurred edge: {soft}"

    # annotations at the right edge: fitted inside the chart, or past it
    ax, _, aw, _ = frames["annotations"]
    fx, _, fw, _ = frames["fitted"]
    ox, _, ow, _ = frames["overflowing"]
    assert fx + fw <= ax + aw + 1, f"fitted inside the chart: {fx + fw} <= {ax + aw}"
    assert ox + ow > ax + aw + 20, "overflowing past the chart"
    assert app.quit() == 0, "exits cleanly"
