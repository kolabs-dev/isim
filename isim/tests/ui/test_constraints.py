"""Auto Layout extras (HelloConstraints): Visual Format Language (standard spacing, sizes, metrics, priorities,
alignment options), keyboardLayoutGuide following the keyboard, registerForTraitChanges.
Port of tests/ui/constraints.sh."""
import re

from isimtest import poll


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
    poll(lambda: re.search(r".*id=bar.*", app.view_dump()).group(0) != bar, "keyboard guide: bar rides the keyboard")

    app.tap_id("dark")
    app.wait_log(r"^style changed 1 -> 2")                             # registerForTraitChanges
    assert app.quit() == 0, "exits cleanly"
