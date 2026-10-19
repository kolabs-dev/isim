"""SwiftUI file dialogs (HelloFileDialogs): fileImporter of one file (opened in place, security-scoped) and of several,
fileExporter of a FileDocument under its default name and of a collection, fileMover, onCancellation, isPresented
reset when the picker closes; TextField / SecureField prompts as placeholders, with textContentType."""
import re


def test_file_dialogs(launch, device_data):
    files = device_data / "Files"
    app = launch("HelloFileDialogs")

    def picker(button, *path):
        app.wait_tap_id(button)
        app.wait_view(r"id=docs-cancel")
        for p in path:
            app.wait_tap_id(f"docs-item-{p}")

    def closed():
        app.wait_view(r"id=docs-cancel", gone=True)

    picker("import", "File-Dialogs", "Notes.txt")                       # one file, in place
    app.wait_log(r'imported Notes.txt "milk, bread" presented=false')
    closed()

    picker("import-many", "File-Dialogs", "Notes.txt", "Todo.txt")      # several
    app.wait_tap_id("docs-open")
    app.wait_log(r'imported \["Notes.txt", "Todo.txt"\] \["call Sam", "milk, bread"\]')
    closed()

    picker("import-many")                                               # cancelled
    app.wait_tap_id("docs-cancel")
    app.wait_log(r"importer cancelled presented=false")
    closed()

    picker("export")                                                    # a copy of the document, to On My iPhone
    app.wait_tap_id("docs-export")
    app.wait_log(r'exported Report.txt in Files "exported text"')
    closed()
    assert (files / "Report.txt").read_text() == "exported text"

    picker("export-many")
    app.wait_tap_id("docs-export")
    app.wait_log(r'exported \["Untitled 1.txt", "Untitled 2.txt"\]')
    closed()
    assert (files / "Untitled 2.txt").read_text() == "two"

    picker("export-many")
    app.wait_tap_id("docs-cancel")
    app.wait_log(r"^exporter cancelled")
    closed()

    picker("move")                                                      # moved out of the app's Documents
    app.wait_tap_id("docs-export")
    app.wait_log(r"moved Move.txt to Files gone=true")
    closed()
    assert (files / "Move.txt").read_text() == "to be moved"

    dump = app.wait_view(r"id=email")                                   # prompts are the placeholders, with content types
    for want in ('id=email text="" placeholder="name@example.com" contentType=email',
                 'id=password text="" placeholder="Required" contentType=password',
                 'id=labelled text="" placeholder="Labelled by a view"'):
        assert want in dump, f"{want!r}: {dump}"
    app.wait_tap_id("email")
    app.send("type a@b.c")
    app.wait_log(r'email "a@b.c"')
    assert app.quit() == 0, "exits cleanly"
