"""Auto Layout extras (HelloConstraints): Visual Format Language (standard spacing, sizes, metrics, priorities,
alignment options), keyboardLayoutGuide following the keyboard, registerForTraitChanges, readableContentGuide (the
margins in portrait, 672 pt centred in landscape), a constraint animation, keyboardDismissMode .onDrag.
Port of tests/ui/constraints.sh."""
import re

from isimtest import count_px


def test_constraints(launch):
    app = launch("HelloConstraints")
    app.wait_log(r"^vfl constraints 13")
    before = app.wait_view(r"id=bar")
    assert "UIView (20 120; 60 x 44) id=a" in before and "UIView (88 120; 60 x 44) id=b" in before, \
        "VFL standard spacing + fixed sizes"
    assert "UIView (178 120; 204 x 44) id=c" in before, "VFL metric gap, priority, alignment"
    assert "UIView (0 796; 402 x 44) id=bar" in before, "keyboard guide: bar above the safe area"
    bar = re.search(r".*id=bar.*", before).group(0)

    app.tap_id("field")
    app.wait_until(lambda: re.search(r".*id=bar.*", app.view_dump()).group(0) != bar,
                   what="keyboard guide: bar rides the keyboard")

    app.tap_id("dark")
    app.wait_log(r"^style changed 1 -> 2")                             # registerForTraitChanges

    def frame(dump, ident):
        m = re.search(rf"\(([-\d.]+) ([-\d.]+); ([-\d.]+) x ([-\d.]+)\)[^\n]*id={ident}\b", dump)
        return tuple(map(float, m.groups())) if m else None
    dump = app.view_dump()
    margin, readable = frame(dump, "grower")[0], frame(dump, "readable")     # grower: on the layout margins guide
    assert readable[0] == margin and readable[2] == 402 - 2 * margin, f"readableContentGuide = the margins in portrait {readable}"

    g = frame(dump, "grower")                                          # 10 high; grows to 90 over 1.5 s

    def drawn_height(shot):                                            # the grower's teal rows (frames report the end value)
        return count_px(shot, (g[0] + g[2] / 2, g[1], 1, 100), lambda c: c[0] < 30 and 130 < c[1] < 175 and 130 < c[2] < 175)
    app.tap_id("grow")
    app.wait_shot(lambda s: 20 < drawn_height(s) < 80, "constraint animation: drawn between 10 and 90 pt mid-animation")
    app.wait_log(r"^grow done height=90")
    assert abs(drawn_height(app.wait_shot_still()) - 90) <= 2, "constraint animation ends at 90 pt"

    scroll = frame(app.view_dump(), "scroll")
    app.tap_id("inner")                                                # from one text field to another
    assert frame(app.view_dump(), "bar")[1] < 700, "the keyboard is up (the bar rides it)"
    assert "keyboard will hide" not in app.log, "moving between text fields keeps the keyboard up (no hide)"
    x, y = scroll[0] + scroll[2] / 2, scroll[1] + 10                  # above the keyboard
    app.drag(x, y + 70, x, y, seconds=0.3)
    app.wait_log(r"^keyboard will hide")                               # keyboardDismissMode .onDrag
    app.wait_view(lambda d: frame(d, "bar")[1] == 796, what="the keyboard went down (bar back above the safe area)")

    app.tap_id("interactive")                                          # .interactive: only dragging down into the keyboard
    app.wait_log(r"^dismiss mode interactive")
    app.tap_id("field")                                                # (the drag scrolled the inner field away)
    app.wait_view(lambda d: frame(d, "bar")[1] < 700, what="the keyboard is up again")
    hides = app.log.count("keyboard will hide")
    app.drag(x, y + 70, x, y, seconds=0.3)                             # up: the keyboard stays
    app.wait_log(r"^drag ended", count=2)
    assert frame(app.view_dump(), "bar")[1] < 700 and app.log.count("keyboard will hide") == hides, "dragging up keeps the keyboard"
    app.drag(x, y, x, frame(app.view_dump(), "bar")[1] + 120, seconds=0.5)   # down into the keyboard
    app.wait_log(r"^keyboard will hide", count=hides + 1)
    app.wait_view(lambda d: frame(d, "bar")[1] == 796, what="interactive: dragging into the keyboard dismisses it")

    app.send("rotate left")
    dump = app.wait_view(lambda d: (frame(d, "readable") or (0, 0, 0))[2] == 672, what="readable width 672 in landscape")
    r, root_w = frame(dump, "readable"), max(float(w) for w in re.findall(r"; ([\d.]+) x [\d.]+\)", dump))
    assert abs(r[0] + r[2] / 2 - root_w / 2) <= 1, f"the readable guide is centred {r} in {root_w}"
    assert app.quit() == 0, "exits cleanly"
