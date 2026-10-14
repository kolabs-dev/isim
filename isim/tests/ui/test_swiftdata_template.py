"""Xcode's iOS App template with SwiftData storage (HelloSwiftDataTemplate, issue #227): Schema, ModelConfiguration
(schema:isStoredInMemoryOnly:), ModelContainer(for:configurations:), .modelContainer on the scene, @Query refreshing
after insert and delete, the toolbar's Edit and icon-only Add Item buttons; and at launch, fetches with a predicate,
sort, offset and limit, rollback and delete(model:where:)."""
import re

import pytest

from isimtest import rgb


def rows(app):
    return [e for e in app.snapshot() if re.fullmatch(r"\d+/\d+/\d{4}, \d+:\d\d:\d\d\s?[AP]M", e.label)]


@pytest.mark.os_matrix                                                  # the toolbar is system UI
def test_swiftdata_template(launch):
    app = launch("HelloSwiftDataTemplate")
    app.wait_log(r"^sd identity ")
    log = app.log
    assert "sd schema [\"Score\"] configs=1 memory=true" in log
    assert "sd insertion-order ana,bo,cy,di,ed" in log, "unsorted fetches keep insertion order"
    assert "sd sorted cy,ed,ana,di,bo" in log, "SortDescriptor(\\.points, order: .reverse)"
    assert "sd filtered ana,cy,ed" in log, "#Predicate { $0.points >= 30 }, sorted by player"
    assert "sd page di,ana count=5" in log, "fetchOffset 1, fetchLimit 2 after sorting"
    assert "sd rollback ana,bo,cy,di,ed changes=false" in log, "rollback undoes an insert and a delete since save()"
    assert "sd delete-where ana,cy,ed" in log
    assert "sd identity id=true context=true hashable=1" in log

    # the template: an empty list, Edit and an icon-only "+" (labelled Add Item for VoiceOver)
    add = app.wait_for(label="Add Item")
    assert add.w < 40, f"the toolbar shows the Label's icon only: {add}"
    assert not rows(app)
    add.tap()
    app.wait_log(r"^sd items 1$")
    app.wait_for(label="Add Item").tap()
    app.wait_log(r"^sd items 2$")
    shot = app.screenshot("two-items")
    assert len(rows(app)) == 2, rows(app)

    # Edit, then delete the first row (onDelete -> modelContext.delete)
    app.wait_for(label="Edit").tap()
    app.wait_for(label="Done")
    first = rows(app)[0]
    app.tap(first.x + 18, first.y + first.h / 2)                       # the red delete control
    app.wait_view(r"text=Delete\b")
    app.tap_text("Delete")
    app.wait_log(r"^sd items 1$", count=2)                              # back to one item
    assert len(rows(app)) == 1
    assert rgb(shot, 5, 200)[0] > 200, "the list's grouped background"
