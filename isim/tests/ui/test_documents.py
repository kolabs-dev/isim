"""UIDocumentPickerViewController and UIDocumentBrowserViewController (HelloDocuments): On My iPhone ($ISIM_DATA/Files,
with a file another app left there) and the sample's shared Documents folder; opening a copy into the Inbox, opening in
place with multiple selection, picking a folder, exporting a copy and moving, the legacy Import mode with type
identifiers, starting in directoryURL, cancelling, and a document browser creating and opening a document."""


def test_documents(launch, device_data):
    files = device_data / "Files"
    files.mkdir(parents=True, exist_ok=True)
    (files / "Shared.txt").write_text("from another app")
    app = launch("HelloDocuments")

    def picker(button, *path):
        app.wait_tap_id(button)
        app.wait_view(r"id=docs-cancel")
        for p in path:
            app.wait_tap_id(f"docs-item-{p}")

    def closed():
        app.wait_view(r"id=docs-cancel", gone=True)

    picker("open-text")                                                # On My iPhone: the app folder and the shared file
    dump = app.wait_view(r"id=docs-item-Documents-Demo")
    assert "id=docs-item-Shared.txt" in dump, "On My iPhone lists the device's files"
    app.wait_tap_id("docs-item-Documents-Demo")
    app.wait_tap_id("docs-item-Notes.txt")
    app.wait_log(r'picked Notes.txt in inbox mode=0 "Shopping: milk, bread"')
    closed()

    picker("open-multi", "Documents-Demo", "Notes.txt", "Swatch.png")  # in place, two files
    app.wait_tap_id("docs-open")
    app.wait_log(r"picked Swatch.png in documents mode=1 \([1-9][0-9]* bytes\)")       # (the PNG size depends on the host zlib)
    closed()

    picker("open-folder", "Documents-Demo", "Reports")                  # a folder
    app.wait_tap_id("docs-open")
    app.wait_log(r"picked Reports in documents mode=1 \(folder\)")
    closed()

    picker("export-copy")                                              # export a copy to On My iPhone
    app.wait_tap_id("docs-export")
    app.wait_log(r'picked Export.txt in on-my-iphone mode=2 "made by the sample"')
    closed()
    assert (files / "Export.txt").read_text() == "made by the sample"

    picker("export-move", "Documents-Demo")                             # move into the app's Documents
    app.wait_tap_id("docs-export")
    app.wait_log(r'picked Moved.txt in documents mode=3 "made by the sample"')
    closed()

    picker("import-json", "Documents-Demo", "Data.json")                # legacy Import mode
    app.wait_log(r'picked Data.json in inbox mode=0 "\{"answer": 42\}"')
    closed()

    picker("open-reports", "Q3.txt")                                    # directoryURL: starts in Reports
    app.wait_log(r'picked Q3.txt in documents mode=1 "Q3: up"')
    closed()

    picker("open-text")
    app.wait_tap_id("docs-cancel")
    app.wait_log(r"^picker cancelled")
    closed()

    app.wait_tap_id("browser")                                          # the document browser
    app.wait_tap_id("docs-create")
    app.wait_log(r"browser created Untitled.txt template gone=true")
    app.wait_tap_id("docs-item-Untitled.txt")
    app.wait_log(r'browser opened \["Untitled.txt"\] new document')
    app.wait_tap_id("browser-done")
    app.wait_view(r"id=docs-create", gone=True)
    assert (files / "Untitled.txt").exists(), "the created document is in On My iPhone"
    assert app.quit() == 0, "exits cleanly"
