"""SwiftUI lists and navigation (HelloLists): leading/trailing swipe actions, swipe to delete, contextMenu, row badge,
EditButton + delete buttons + reordering (onDelete / onMove), .searchable (+ Cancel), .refreshable (pull to refresh),
navigationDestination(isPresented:) with \\.isPresented and dismiss, NavigationSplitView with List(selection:) on
iPhone, sheet detents (medium -> large by dragging, drag down to dismiss), toolbar(.hidden) for the navigation bar and
the tab bar. Port of tests/ui/lists.sh."""
import re


def after(text, pattern, n):
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if re.search(pattern, line):
            return "\n".join(lines[i:i + n + 1])
    return ""


def test_rows(launch):
    app = launch("HelloLists")
    first = app.wait_tree(r"id=fruit-Apple\b")
    assert re.search(r"UILabel \(3[0-9.]+ 11\.5; [0-9.]+ x 21\) text=3$", first, re.M), "row badge"
    app.send("swipeid fruit-Apple 120 0 0.4")
    app.wait_tree(r"text=Pin$")
    app.tap_text("Pin")
    app.wait_log(r"^pin Apple")                                          # leading swipe action
    app.wait_view("fruit-Date")
    app.send("swipeid fruit-Date -150 0 0.4")
    app.wait_tree(r"text=Delete$")
    app.tap_text("Delete")
    app.wait_log(r"^deleted Date")                                       # trailing swipe: Delete (onDelete)
    app.send("holdid fruit-Cherry 0.9")
    app.wait_tap("menu-Copy")
    app.wait_log(r"^copy Cherry")                                        # contextMenu on long press
    app.wait_view("menu-Copy", gone=True)
    app.wait_tree(r"text=Edit$")
    app.tap_text("Edit")
    tree = app.wait_tree(r"id=edit-state text=editing")
    assert "id=row-delete-0" in tree and "id=row-move-0" in tree, "EditButton: edit mode + controls"
    app.wait_tap("row-delete-1")
    app.wait_tree(r"text=Delete$")
    app.tap_text("Delete")
    app.wait_log(r"^deleted Banana")                                     # edit mode delete button
    app.wait_view("row-move-0")
    app.send("swipeid row-move-0 0 50 0.8")
    app.wait_log(r"^order Cherry,Apple")                                 # onMove reorders with the handle
    app.tap_text("Done")
    app.wait_tree(r"id=edit-state text=not editing")                     # Done leaves edit mode
    assert app.quit() == 0


def test_refresh_search_destinations(launch):
    app = launch("HelloLists")
    app.wait_view("fruit-Apple")
    app.drag(200, 450, 200, 750, 0.6)
    app.wait_log(r"^refreshed 1")
    app.wait_tree(r"id=refresh-count text=refreshed 1")                  # refreshable: pull to refresh
    app.wait_tap("search-field")
    app.type("Ch")
    app.wait_log(r"^query Ch")
    searched = app.wait_tree(r'text="Ch"')
    assert "id=fruit-Cherry" in searched and "id=fruit-Apple" not in searched, "searchable: typing filters"
    app.tap_id("search-cancel")
    app.wait_log(r"^query $")                                            # searchable: Cancel clears
    app.wait_tree(r"text=Show detail$")
    app.tap_text("Show detail")
    tree = app.wait_tree(r"id=detail text=Detail page")                  # navigationDestination(isPresented:)
    assert "id=presented text=presented" in tree, "\\.isPresented in the destination"
    app.wait_tap("close-detail")
    tree = app.wait_view("close-detail", gone=True)
    app.wait_until(lambda: (lambda t: "text=Show detail" in t and "id=detail text" not in t)(app.tree()),
                   what="dismiss pops the destination")
    app.tap_text("Open item")
    app.wait_tree(r"id=item-page text=Item Kiwi")
    app.wait_log(r"^picked Kiwi")                                        # navigationDestination(item:)
    app.wait_tap("isim-nav-back")
    app.wait_log(r"^picked nil")                                         # back clears it
    assert app.quit() == 0


def test_split_view_on_iphone(launch):
    app = launch("HelloLists")
    app.wait_tap("tab-Split")
    app.wait_tree(r"text=Lemon$")
    app.tap_text("Lemon")
    app.wait_log(r"^selection 2")
    app.wait_tree(r"id=split-detail text=Selected Lemon")                # NavigationSplitView: select -> detail
    assert app.quit() == 0


def test_sheet_detents_and_hidden_bars(launch):
    app = launch("HelloLists")
    app.wait_tap("tab-More")
    app.wait_tap("open-sheet")
    tree = app.wait_tree(r"\(0 437; 402 x 437\) id=sheet-card")
    assert "id=detent-name text=medium" in tree, "sheet detent .medium"
    app.sleep(0.4)                                                       # the sheet has slid up
    app.drag(200, 447, 200, 147, 0.6)
    tree = app.wait_tree(r"\(0 72; 402 x 802\) id=sheet-card")
    app.wait_tree(r"id=detent-name text=large")                          # drag to .large updates the selection
    app.sleep(0.4)
    app.drag(200, 82, 200, 760, 0.6)
    app.wait_log(r"^sheet dismissed")                                    # drag down dismisses the sheet
    app.wait_tree(r"text=Full screen page$")
    app.tap_text("Full screen page")
    last = app.wait_view("barless")
    last = app.wait_until(lambda: (lambda t: t if re.search(r"_SUITabBar \(.*\) hidden id=isim-tabbar", t) and
                                   "_SUINavBar (0 0; 402 x 106) hidden" in after(t, "id=barless", 30) else None)(app.tree()),
                          what="toolbar(.hidden) for the nav bar and the tab bar")
    assert app.quit() == 0
