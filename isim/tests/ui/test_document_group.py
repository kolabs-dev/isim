"""SwiftUI DocumentGroup (HelloDocumentGroup): a FileDocument created from the launch view, edited through its
binding (undo, autosave to a FileWrapper), closed and reopened from the browser; \\.documentConfiguration and
\\.undoManager; a ReferenceFileDocument saved from snapshots; DocumentGroup(viewing:) opening documents read-only."""
import pytest


@pytest.mark.os_matrix
def test_document_group(launch, ios, device_data):
    if int(str(ios[0] or 18).split(".")[0]) < 18:
        pytest.skip("the document launch view is iOS 18")
    app = launch("HelloDocumentGroup")
    app.wait_view(r"id=launch-title text=Text Docs")                      # the app's name on the launch view
    app.wait_tap_id("launch-primary")                                      # Create Document
    app.wait_log(r'^write "Hello"$')                                       # the new document's file
    app.wait_log(r'^read "Hello" as public.plain-text$')
    app.wait_view(r"id=doc-info text=file Untitled.txt editable yes undo yes")
    app.tap_id("doc-text")
    app.type(", world")
    app.wait_log(r'^text "Hello, world"$')
    app.wait_log(r'^write "Hello, world"$')                                # autosave
    app.wait_until(lambda: (device_data / "Files" / "Untitled.txt").read_text() == "Hello, world", what="saved in On My iPhone")
    app.wait_until(lambda: (e := app.find(id="document-undo")) is not None and e.enabled, what="Undo enabled")
    app.tap_id("document-undo")
    app.wait_log(r'^text "Hello"$')                                        # the typing is one undoable edit
    app.tap_id("documents")                                                # back to the launch view: closed
    app.wait_view(r"id=document-launch")
    app.wait_until(lambda: (device_data / "Files" / "Untitled.txt").read_text() == "Hello", what="saved when closed")
    app.wait_tap_id("docs-item-Untitled.txt")                              # reopen from the browser
    app.wait_log(r'^read "Hello" as public.plain-text$', count=2)
    app.wait_view(r"id=doc-info text=file Untitled.txt")
    assert app.quit() == 0, "exits cleanly"


def test_reference_document(launch, device_data):
    app = launch("HelloDocumentGroup", env={"MODE": "reference"})
    app.wait_tap_id("launch-primary")
    app.wait_log(r'^write snapshot "Notes"$')
    app.wait_view(r"id=notes-text text=Notes")
    app.tap_id("append")
    app.wait_view(r"id=notes-text text=Notes!")
    app.wait_log(r'^write snapshot "Notes!"$')                             # the change is saved from a snapshot
    app.wait_until(lambda: (device_data / "Files" / "Untitled.txt").read_text() == "Notes!", what="saved")
    assert app.quit() == 0, "exits cleanly"


def test_viewing_document(launch, device_data):
    (device_data / "Files").mkdir(parents=True, exist_ok=True)
    (device_data / "Files" / "Seen.txt").write_text("read only")
    app = launch("HelloDocumentGroup", env={"MODE": "viewer"})
    dump = app.wait_view(r"id=document-launch")
    assert "id=launch-primary" not in dump or "hidden id=launch-primary" in dump, "viewing: no Create Document"
    app.wait_tap_id("docs-item-Seen.txt")
    app.wait_view(r"id=doc-info text=file Seen.txt editable no")
    assert app.quit() == 0, "exits cleanly"


@pytest.mark.os_matrix
def test_url_document(launch, ios, device_data):
    """iOS 27: an @Observable Document made by DocumentGroup(editor:makeDocument:), read by a
    FileWrapperDocumentReader and applied, saved from snapshots by a FileWrapperDocumentWriter."""
    if int(str(ios[0] or 18).split(".")[0]) < 27:
        pytest.skip("URL-based documents are iOS 27")
    app = launch("HelloDocumentGroup", env={"MODE": "url"})
    app.wait_tap_id("launch-primary")
    app.wait_log(r"^make document for a new file$")
    app.wait_log(r'^write "New note" over nothing$')                       # the new file, by the writer
    app.wait_log(r"^make document for Untitled.txt$")
    app.wait_log(r'^apply "New note" previous nil$')                        # read, then applied
    app.wait_tap_id("note-text")
    app.type("!")
    app.tap_id("documents")                                                # closing saves the change
    app.wait_log(r'^write "New note!" over the file$')
    app.wait_until(lambda: (device_data / "Files" / "Untitled.txt").read_text() == "New note!", what="saved")
    assert app.quit() == 0, "exits cleanly"
