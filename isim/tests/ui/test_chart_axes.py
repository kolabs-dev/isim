"""Swift Charts axes and scales (HelloChartAxes, issue #246): a log scale (decade labels evenly spaced), a square root
scale, AxisValueLabel(format:) with a percent format and vertical labels (AxisValueLabelOrientation), labels
truncated by AxisValueLabelCollisionResolution.truncate, a position range with padding (.plotDimension(padding:)) and
an axis from AnyAxisContent. Label positions come from the view tree (frames summed up to each chart)."""
from isimtest import parse_views


def labels(tree):
    """{chart id: {label text: [(x, y, w, h), ...]}}, positions relative to the chart"""
    out, stack = {}, []                                  # (depth, abs x, abs y, chart id, chart x, chart y)
    for v in parse_views(tree):
        while stack and stack[-1][0] >= v.depth:
            stack.pop()
        px, py, chart, cx, cy = stack[-1][1:] if stack else (0, 0, None, 0, 0)
        ax, ay = px + v.x, py + v.y
        if v.id in ("log", "sqrt", "percent", "truncate", "padded"):
            chart, cx, cy = v.id, ax, ay
        stack.append((v.depth, ax, ay, chart, cx, cy))
        if chart and v.cls == "UILabel" and v.text:
            out.setdefault(chart, {}).setdefault(v.text, []).append((ax - cx, ay - cy, v.w, v.h))
    return out


def mid_y(r): return r[1] + r[3] / 2
def mid_x(r): return r[0] + r[2] / 2


def test_chart_axes(launch):
    app = launch("HelloChartAxes")
    app.wait_log(r"chart axes shown")
    tree = app.wait_view(r"text=100%")
    got = labels(tree)
    first = lambda chart: {t: rs[0] for t, rs in got[chart].items()}
    # the x axis' labels: the lowest of each text
    xaxis = lambda chart: {t: max(rs, key=lambda r: r[1]) for t, rs in got[chart].items()}

    # log: the decades evenly spaced, 1 at the bottom
    log = first("log")
    ys = [mid_y(log[t]) for t in ("1", "10", "100", "1000")]
    steps = [a - b for a, b in zip(ys, ys[1:])]
    assert all(s > 20 for s in steps) and max(steps) - min(steps) <= 2, f"log decades evenly spaced: {ys}"

    # square root: 25 halfway between 0 and 100
    sq = first("sqrt")
    y0, y25, y100 = (mid_y(sq[t]) for t in ("0", "25", "100"))
    assert abs((y0 - y25) - (y0 - y100) / 2) <= 2, f"sqrt: 25 at half of 100 ({y0}, {y25}, {y100})"

    # a percent format; vertical x labels make room below the plot
    pc = first("percent")
    assert {"0%", "50%", "100%"} <= set(pc), f"percent labels: {sorted(pc)}"
    assert mid_y(pc["0%"]) < 160 - 30, "vertical x labels: the plot ends higher than with one line of labels"

    # truncated: each label fits its band
    tr = first("truncate")
    for name in ("Extraordinarily long", "Remarkably long", "Unusually long", "Considerably long"):
        assert tr[name][2] <= 92, f"{name} truncated to its band: {tr[name]}"

    # padding: the domain's start is 40 pt into the plot; AnyAxisContent's marks only
    pd = xaxis("padded")
    assert abs(mid_x(pd["0"]) - 40) <= 3, f"x = 0 at 40 pt: {pd['0']}"
    assert "2" in pd and "4" in pd and "1" not in pd and "3" not in pd, f"marks at 0, 2, 4: {sorted(pd)}"
    assert app.quit() == 0, "exits cleanly"
