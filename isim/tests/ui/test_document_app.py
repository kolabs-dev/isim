"""UIDocument and UIDocumentViewController (HelloDocumentApp): the iOS 18 launch view (launchOptions title, iOS 27
subtitle, the default Create Document action and a secondary action with a custom creation intent, the browser in a
sheet), creating a document through the browser delegate (activeDocumentCreationIntent), opening it as the
Info.plist's UIDocumentClass, documentDidOpen / navigationItemDidUpdate, editing with undo through the document's
undo manager and undoRedoItemGroup, autosave, closing back to the launch view and reopening from the browser; before
iOS 18 the empty state and the Documents button."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_document_app(launch, ios, device_data):
    v = major(ios)
    app = launch("HelloDocumentApp")
    if v < 18:                                                     # no launch view: UIKit's empty state
        dump = app.wait_view(r"id=document-empty")
        assert "id=document-launch" not in dump and app.find(id="documents"), "No Document, with a Documents button"
        assert app.quit() == 0
        return
    app.wait_view(r"id=document-launch")
    app.wait_for(label="Notes")
    subtitle = app.find(label="Plain text, saved as you type")
    assert bool(subtitle) == (v >= 27), "the subtitle shows from iOS 27"
    app.wait_view(r"id=docs-create")                               # the browser sheet over the launch view

    app.wait_tap_id("launch-secondary")                            # From Template: the custom intent
    app.wait_log(r"hd create intent template")
    app.wait_log(r'hd documentDidOpen Shopping title Shopping class TextDocument')
    app.wait_log(r'loaded Shopping.txt type public.plain-text "Milk, bread"')
    app.wait_view(r"id=document-launch", gone=True)
    assert (device_data / "Files" / "Shopping.txt").read_text() == "Milk, bread", "created in On My iPhone"

    app.wait_tap_id("editor")                                      # edit: undo registered, autosaved
    app.type(", eggs")
    app.wait_log(r'hd saving "Milk, bread, eggs"')
    app.wait_log(r"document saved Shopping.txt")
    assert (device_data / "Files" / "Shopping.txt").read_text() == "Milk, bread, eggs"
    app.wait_until(lambda: (e := app.find(id="document-undo")) is not None and e.enabled, what="Undo enabled")
    app.tap_id("document-undo")
    app.wait_log(r'hd saving "Milk, bread"')                       # the undo is a change too: saved again

    app.tap_id("documents")                                        # back: closes, the launch view again
    app.wait_log(r"hd state Shopping closed true")
    app.wait_view(r"id=document-launch")
    app.wait_tap_id("launch-primary")                              # Create Document: the default intent
    app.wait_log(r"hd create intent UIDocumentCreationIntentDefault")
    app.wait_log(r"hd documentDidOpen Untitled")
    app.tap_id("documents")
    app.wait_view(r"id=document-launch")
    app.wait_tap_id("docs-item-Shopping.txt")                      # reopen from the browser
    app.wait_log(r'loaded Shopping.txt type public.plain-text "Milk, bread"', count=2)
    app.wait_log(r"hd documentDidOpen Shopping", count=2)
    assert app.quit() == 0, "exits cleanly"
