"""UITableView (HelloTable): UITableViewController, subtitle cells, self-sizing rows, cell reuse, sticky plain headers,
selection, swipe to delete (button and full swipe), custom swipe actions, edit mode, animated inserts, inset-grouped
value cells with checkmarks / detail button / footers, diffable data source; leading swipe actions, the section
index and row prefetching. Port of tests/ui/table.sh."""
import re

import pytest
from isimtest import count_px, rgb


def sticky_header(dump):
    """A plain section header pinned under the navigation bar: its y is the content offset plus the 106 pt bar."""
    off = 0
    for line in dump.splitlines():
        m = re.search(r"UITableView \(.*offset (-?[0-9.]+)", line)
        if m:
            off = float(m.group(1))
        h = re.search(r"UITableViewHeaderFooterView \(0 (-?[0-9.]+);", line)
        if h and off > 500 and 105.5 < float(h.group(1)) - off < 106.5:
            return True
    return False


@pytest.mark.os_matrix
def test_table(launch, ios):
    if ios[0] == "17":
        pytest.skip("not run under iOS 17 (as in the shell suite)")
    app = launch("HelloTable")
    first = app.wait_view(r"id=row-note")
    assert "id=row-Fruit1" in first and "text=sweet" in first, "rows with subtitle cells"
    assert re.search(r"UITableViewCell \(0 [0-9.]+; 402 x (8[0-9]|9[0-9])\) id=row-note", first), \
        "self-sizing multi-line row"
    app.tap_id("row-Fruit3")
    app.wait_log(r"selected Fruit 3")                                   # row selection
    app.send("swipeid row-Fruit2 -150 0 0.3")
    app.wait_tap_id("swipe-Delete")
    app.wait_log(r"deleted Fruit 2, rows 30")                           # swipe reveals Delete, commits
    app.wait_still()
    app.send("swipeid row-Fruit4 -360 0 0.25")
    app.wait_log(r"deleted Fruit 4, rows 29")                           # full swipe deletes
    app.wait_still()
    app.tap_id("bar-Edit")
    app.wait_log(r"editing true table true")
    editing = app.wait_view(r"UITableViewCell \(0 [0-9.]+; 402 x 10[0-9]\) id=row-note",
                            what="edit mode re-sizes rows")
    app.screenshot("editing")
    app.tap_id("bar-Done")
    app.wait_log(r"editing false table false")                          # edit mode (editButtonItem)
    app.wait_still()
    app.tap(34, 84)
    app.wait_log(r"inserted New fruit 1, rows 30")                      # animated insert
    app.wait_still()
    for _ in range(3):
        app.drag(200, 700, 200, 150, 0.15)
        app.wait_still()
    scrolled = app.view_dump()
    for _ in range(2):
        app.drag(200, 700, 200, 150, 0.15)
        app.wait_still()
    app.send("swipeid row-Vegetable20 -200 0 0.3")
    app.wait_tap_id("swipe-Flag")
    app.wait_log(r"flagged Vegetable 20")
    app.wait_still()
    app.send("swipeid row-Vegetable19 -200 0 0.3")
    app.wait_tap_id("swipe-Remove")
    app.wait_log(r"deleted Vegetable 19, rows 19")                      # custom swipe actions
    app.tap_id("tab-Settings")
    app.wait_tap_id("sound-Glass")
    app.wait_log(r"sound Glass, checked rows \[2\]")                    # checkmarks follow selection
    app.tap_id("set-name")
    app.wait_log(r"open name")
    app.wait_still()
    app.tap(355, 262)
    app.wait_log(r"detail button row 1")                                # disclosure row + detail button
    app.tap_id("tab-Diffable")
    app.wait_tap_id("bar-Odd")
    app.wait_log(r"diffable rows \[100, 1, 3, 5, 7\]")                  # diffable data source apply
    assert app.quit() == 0, "exits cleanly"
    cells = re.search(r"cells created ([0-9]+)", app.log)
    assert cells and int(cells.group(1)) < 30 and re.search(r"visible [1-9]", app.log), "cells are reused"
    assert sticky_header(scrolled), "sticky section header"

    # leading swipe actions, the section index and prefetching (a fresh launch)
    app = launch("HelloTable")
    app.wait_view(r"id=row-Fruit5")
    app.send("swipeid row-Fruit5 150 0 0.3")
    pin = app.wait_view(r"id=swipe-Pin")
    leading = app.wait_shot(lambda s: (c := rgb(s, 30, 510))[0] > 230 and c[1] < 215 and c[2] < 150,
                            "leading swipe action button (pixels)")
    app.tap_id("swipe-Pin")
    app.wait_log(r"pinned Fruit 5")
    app.wait_still()
    app.send("swipeid row-Fruit6 300 0 0.25")
    app.wait_log(r"pinned Fruit 6")                                     # leading swipe actions (button, full swipe)
    app.wait_still()
    app.tap_id("isim-index-V")
    app.wait_log(r"index V: section 1 at the top true")
    index = app.wait_still()
    shot = app.screenshot("index")
    app.tap_id("isim-index-F")
    app.wait_log(r"index F: section 0 at the top true")
    app.wait_still()
    app.drag(200, 700, 200, 300, 0.3)
    app.wait_still()
    app.drag(200, 300, 200, 700, 0.3)
    app.wait_log(r"^cancel prefetch [0-9]+ rows")
    assert app.quit() == 0, "exits cleanly"
    assert re.search(r"_IsimTableIndexView \([0-9.]+ [0-9.]+; 16 x [0-9.]+\) id=isim-section-index", index) and \
        "id=isim-index-search" in index and \
        count_px(shot, (386, 420, 16, 55), lambda c: c[0] > 120 and c[2] > 200 and c[1] < 120) > 5, \
        "section index: titles, magnifier, jumps to sections"
    assert re.search(r"^prefetch [0-9]+ rows from 0/", app.log, re.M) and \
        re.search(r"^prefetch [0-9]+ rows from 1/", app.log, re.M), \
        "prefetching ahead of scrolling, cancelled when the direction turns"
