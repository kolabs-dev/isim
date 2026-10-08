"""The HelloSwiftUI sample on isim's SwiftUI: state, onChange, task, Form layout, text input with @FocusState, toolbar
items, NavigationLink push/pop. Port of tests/ui/swiftui.sh."""
import pytest


@pytest.mark.os_matrix
def test_swiftui(launch, ios):
    app = launch("HelloSwiftUI")
    app.wait_tap("increment")
    app.wait_log(r"count 0 -> 1")
    app.tap_id("increment")
    app.wait_log(r"count 1 -> 2")                                   # @State + onChange(old, new)
    app.wait_log(r"task finished")                                  # .task runs (MainActor) and updates

    app.tap_id("name-field")
    app.wait_tree(r"id=isim-kb-a\b")
    for k in "ada":
        app.tap_id(f"isim-kb-{k}")
    tree = app.wait_tree(r'text="Ada" \(editing\)')                 # TextField + system keyboard
    assert "text=Loaded by .task" in tree, ".task updates the view"
    assert "text=2" in tree, "LabeledContent shows the count"
    assert "text=COUNTER" in tree, "section headers uppercased"
    assert "text=Hello, Ada!" in tree, "footer follows the binding"
    assert "id=done" in tree, "toolbar Done"
    assert app.has(r"editing true"), "@FocusState"

    app.tap_id("done")
    app.wait_log(r"editing false")                                  # @FocusState + toolbar Done
    app.tap_text("Details")
    app.wait_tree(r"text=The counter is at 2\.")                    # NavigationLink pushes (inline)
    app.wait_tap("isim-nav-back")
    app.wait_tap("reset")
    app.wait_log(r"count 2 -> 0")                                   # back pops, root state kept
    assert app.quit() == 0
