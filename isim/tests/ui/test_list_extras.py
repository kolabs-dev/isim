"""Table, collection view, layout, diffable and configuration members (HelloListExtras): the indexed collation, the
Objective-C diffable data sources (animated changes, an outline section snapshot), header and footer rects, rows in a
rect, cell state transitions, a flow layout subclass's attributes class, update items and appearing attributes, the
standard reorder gesture (interactive movement), anchored badges, the insert / multiselect / pop-up menu accessories,
separator and background configurations, attributed and transformed list content, list content view layout guides."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_list_extras(launch, ios):
    v = major(ios)
    app = launch("HelloListExtras")
    app.wait_log(r"^lx ada at 1-0$")
    log = app.log
    assert "lx collation sections #,A,B,E,G,Z" in log, "names sort into A-Z and # (É under E)"
    assert "lx header at section top true footer at bottom true" in log
    assert "lx rows in top area 3" in log
    assert "lx translating true" in log

    # an animated snapshot change: Ann comes in before Ada, Bob leaves; editing transitions the cells
    app.wait_tap_id("change")
    app.wait_log(r"^lx snapshot applied 7$")
    app.wait_log(r"^lx cell will transition 1$")
    app.wait_log(r"diffable data source applied 6 section\(s\), 7 item\(s\)")

    # the grid: its own attributes class, a long press drags an item to a new place, an added item appears
    app.tap_id("tab-Grid")
    app.wait_log(r"^lx attributes class GridAttributes x 8$")
    assert "lx standard gesture true" in app.log
    first = app.wait_for(id="grid-5")
    target = app.wait_for(id="grid-7")
    x1, y1 = first.center
    x2, y2 = target.center
    app.send(f"longdrag {x1:.0f} {y1:.0f} {x2 + 4:.0f} {y2:.0f} 0.8 1.0")
    app.wait_log(r"interactive movement of 0-4 began")
    app.wait_log(r"^lx moved 5 to 6 order 1,2,3,4,6,7,5,8$")
    app.wait_tap_id("add")
    app.wait_log(r"^lx update items 0$")
    app.wait_log(r"^lx appearing 8$")

    # lists: outline, badges, guides, accessories
    app.tap_id("tab-Lists")
    app.wait_log(r"^lx guides text after image true secondary true$")
    log = app.log
    assert "lx outline visible 6 level 1 parent Fruit expanded 1" in log
    assert "lx children snapshot Apple,Pear" in log
    assert "lx badge centre on corner true visible 3" in log
    if v >= 18:
        assert "lx background copy keeps true" in log
    app.wait_tap_id("accessory-popupmenu")
    app.wait_tap_id("menu-High")
    app.wait_log(r"^lx popup now High$")
    app.wait_log(r"pop-up menu accessory shows High")
    app.wait_tap_id("accessory-insert")
    app.wait_log(r"^lx insert ")
