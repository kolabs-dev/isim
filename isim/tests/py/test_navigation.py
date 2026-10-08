"""UIKit containers (HelloNavigation): tab bar with badge, large title collapsing on scroll, push/pop, back button and
back swipe, toolbar items, hidesBottomBarWhenPushed, bar button menus, tab switching. Port of tests/ui/navigation.sh
with condition waits instead of fixed sleeps."""


def nav_bar_height(app):
    bars = [e for e in app.snapshot() if e.type == "navigationBar"]
    return round(bars[0].h) if bars else None


def test_navigation(launch):
    app = launch("HelloNavigation")
    app.wait_for(id="tab-Library")
    assert app.find(id="tab-Inbox"), "tab bar with items"
    assert app.find(id="bar-Sort"), "large title bar items"
    assert nav_bar_height(app) == 158, "large title"

    app.drag(200, 600, 200, 300, 0.4)
    app.sleep(0.6)                                     # the collapse animates
    assert nav_bar_height(app) == 106, "large title collapses on scroll"
    app.drag(200, 300, 200, 700, 0.4)
    app.sleep(0.6)

    app.wait_for(id="book-3").tap()
    app.wait_log("detail 3 appears")
    app.wait_for(label="Details of book 3")
    app.wait_for(id="bar-Favorite").tap()
    app.wait_log("favorite tapped")

    app.wait_for(id="read").tap()
    app.wait_log("reader appeared, tab bar hidden: true")
    app.wait_for(id="nav-back").tap()
    app.wait_log("detail 3 appears", count=2)
    app.wait_for(id="nav-back").tap()
    app.wait_log("list appears", count=2)              # back button pops (twice)

    app.wait_for(id="book-5").tap()
    app.wait_log("detail 5 appears")
    app.sleep(0.4)                                     # push animation done before the edge swipe
    app.drag(3, 400, 330, 400, 0.4)
    app.wait_log("list appears", count=3)              # back swipe pops

    app.wait_for(id="bar-Sort").tap()
    app.wait_for(id="menu-Date").tap()
    app.wait_log("sort date")
    app.wait_for(id="tab-Inbox").tap()
    app.wait_log("inbox appeared")
    assert app.quit() == 0
