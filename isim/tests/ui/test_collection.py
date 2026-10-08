"""UICollectionView (HelloCollection): flow layout grid (UICollectionViewController, headers, multiple selection,
animated deletes and inserts, cell reuse), compositional layout (orthogonal carousel, repeated items in a group,
estimated headers, registrations, diffable data source), list layout (inset grouped, accessories, self-sizing).
Port of tests/ui/collection.sh."""
import re


def test_collection(launch):
    app = launch("HelloCollection")
    grid = app.wait_tree(r"id=tile-4\b")
    assert re.search(r"TileCell \(16 132; 110 x 80\) id=tile-4", grid) and "text=Favorites" in grid, \
        "flow layout grid + header"
    app.tap_id("tile-2")
    app.wait_log(r"grid selected 2, selected 1")
    app.tap_id("tile-5")
    app.wait_log(r"grid selected 5, selected 2")                     # multiple selection
    app.tap_id("bar-Remove")
    app.wait_log(r"grid removed 2, items 10")                        # animated delete of the selected items
    app.tap(368, 84)                                                  # the add button
    app.wait_log(r"grid inserted, items 11")
    app.wait_tree(r"id=tile-61\b")                                    # animated insert

    app.drag(200, 700, 200, 150, 0.15)
    app.sleep(1.2)                                                    # the fling decelerates
    app.drag(200, 700, 200, 150, 0.15)
    m = app.wait_log(r"grid cells created ([0-9]+), visible ([0-9]+)")
    assert int(m.group(1)) < 50 and int(m.group(2)) >= 1, f"cells are reused: {m.group(0)}"

    app.wait_tap("tab-Shelf")
    shelf = app.wait_tree(r"id=book-102\b")
    assert re.search(r"UICollectionViewCell \(205 [0-9.]+; 181 x 82\) id=book-102", shelf), \
        "compositional: two items per group"
    assert re.search(r"UICollectionViewListCell \(16 0; 370 x (2[0-9]|3[0-9])\)", shelf), \
        "estimated header sized to content"
    app.wait_view("featured-1")
    app.send("swipeid featured-1 -250 0 0.3")
    app.wait_settled(id="featured-2").tap()
    app.wait_log(r"shelf selected Featured 2")                       # orthogonal carousel scrolls
    app.tap_id("bar-Trim")
    app.wait_log(r"shelf books 13, first Title 4")                   # diffable apply (deletes)

    app.wait_tap("tab-List")
    lst = app.wait_tree(r"id=row-Coffee\b")
    assert re.search(r"UICollectionViewListCell \([0-9.]+ [0-9.]+; 362 x (9[0-9]|1[01][0-9])\) id=row-Coffee", lst), \
        "list self-sizing row"
    app.wait_tap("row-Milk")
    app.wait_log(r"list toggled Milk done true, accessories 1")
    app.wait_tap("row-Bread")
    app.wait_log(r"list toggled Bread done false, accessories 2")    # list accessories + reconfigure
    assert app.quit() == 0
