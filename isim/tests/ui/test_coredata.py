"""Core Data (HelloCoreData, built from HelloCoreData.xcodeproj with its .xcdatamodeld by `isim build`): SwiftUI
@FetchRequest / @SectionedFetchRequest list, add and delete through the viewContext, @ObservedObject rows, a
background save merged into the view, a predicate change, and persistence of the SQLite store across a relaunch.
Port of tests/ui/coredata.sh."""


def test_coredata(launch):
    app = launch("HelloCoreData")
    app.wait_log(r"launch items 0")
    first = app.wait_view(r"text=count 0")
    assert "text=No items" in first, "@FetchRequest: empty list on first launch"
    for n in (1, 2, 3):
        app.tap_id("add")
        app.wait_log(rf"added Item {n}")
    three = app.wait_view(r"text=count 3")
    assert "text=Item 2" in three, "insert + save updates the @FetchRequest list"
    app.wait_view(r"text=groups even:1 odd:2", what="@SectionedFetchRequest groups")
    app.screenshot("three")
    app.wait_tap_id("delete-Item_2")
    app.wait_log(r"deleted Item 2")
    app.wait_view(r"text=count 2", what="delete + save removes the row")
    app.wait_tap_id("star-Item_3")
    app.wait_view(r"text=★", what="@ObservedObject row updates when its object changes")
    assert app.quit() == 0, "exits cleanly"
    assert "store loaded HelloCoreData.sqlite" in app.log, \
        "model compiled from the .xcdatamodeld, SQLite store in the app container"

    app = launch("HelloCoreData")                                       # same device data: the store persists
    app.wait_log(r"launch items 2")
    relaunched = app.wait_view(r"text=Item 3")
    assert "text=Item 2" not in relaunched, "store persists across a relaunch"
    assert "text=★" in relaunched, "starred flag persisted"
    app.wait_tap_id("addBackground")
    app.wait_log(r"background saved")
    app.wait_view(lambda d: "text=Background item" in d and "text=count 3" in d,
                  what="background context save merges into the list")
    app.wait_tap_id("starredOnly")
    app.wait_log(r"filter starred true")
    app.wait_view(r"text=count 1", what="changing nsPredicate re-fetches (starred only)")
    app.screenshot("starred")
    assert app.quit() == 0, "exits cleanly"
