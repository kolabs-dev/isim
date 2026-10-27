"""SwiftUI Table (HelloLists -table): on iPhone a table is a list of its first column; on iPad it shows its column
headers and cells side by side, tapping a sortable header sorts by it (again: the other way) through the sortOrder
binding, and selecting a row sets the selection. -rows: TableRows with a context menu and an outline table."""
from isimtest import screen_frames


def test_table_iphone_first_column(launch):
    app = launch("HelloLists", args=["-table"])
    app.wait_log(r"table order Ada,Ben,Chloe,Dara")
    tree = app.wait_view(r"text=Ada")
    assert "Lisbon" not in tree and "London" not in tree, "only the first column shows on iPhone"
    assert "id=isim-table-header" not in tree, "no column headers on iPhone"
    app.tap_text("Ben")
    app.wait_log(r"table selected Ben")
    assert app.quit() == 0, "exits cleanly"


def test_table_ipad_columns_and_sorting(launch):
    app = launch("HelloLists", device="ipadpro11", os_version="18.0", args=["-table"])
    app.wait_log(r"table order Ada,Ben,Chloe,Dara")
    tree = app.wait_view(r"text=Lisbon")
    for t in ("Name", "Age", "City", "Ada", "36", "London"):
        assert f"text={t}" in tree, f"{t} shows on iPad"
    f = screen_frames(tree)
    name, age, city = f["isim-table-header-0"], f["isim-table-header-1"], f["isim-table-header-2"]
    assert name[0] < age[0] < city[0], "the headers are side by side, in order"
    app.wait_still()
    app.screenshot("ipad-table")
    app.tap_id("isim-table-header-0")                     # the sorted column: the other way
    app.wait_log(r"table order Dara,Chloe,Ben,Ada by reverse")
    app.tap_id("isim-table-header-1")                     # by age
    app.wait_log(r"table order Ben,Chloe,Ada,Dara by forward")
    app.tap_text("Chloe")
    app.wait_log(r"table selected Chloe")
    assert app.quit() == 0, "exits cleanly"


def test_table_rows_and_outline(launch):
    app = launch("HelloLists", device="ipadpro11", os_version="18.0", args=["-table", "-rows"])
    tree = app.wait_view(r"text=Taxes")
    for t in ("Documents", "Taxes", "Notes", "Music", "Lisbon"):
        assert f"text={t}" in tree, f"{t} shows (outline rows expanded)"
    app.send("holdid person-Ada 0.9")                     # the row's context menu
    app.wait_tap_id("menu-Greet Ada")
    app.wait_log(r"table greet Ada")
    assert app.quit() == 0, "exits cleanly"
