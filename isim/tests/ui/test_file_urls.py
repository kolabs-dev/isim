"""Foundation's URL file APIs (HelloFileURLs, issue #267): URL.DirectoryHint (URL(filePath:directoryHint:relativeTo:),
appending(path:directoryHint:)), URL.standardized and standardizedFileURL, security-scoped access (adapted: always
granted for file URLs), bookmarks (resolved after a rename: stale; the resource values kept in them; bookmark files;
an error once the file is gone) and NSFileVersion (adding a version by moving a copy, listing, finding by persistent
identifier, restoring, removing; the current version cannot be removed); for-in over FileManager enumerators (fast
enumeration) keeps the objects it hands out alive."""


def test_file_urls(launch):
    app = launch("HelloFileURLs")
    app.wait_log(r"^hint dir=true file=false inferred=true checked=true relative=true appended=true$")
    app.wait_log(r"^standardized web=https://example.com/a/c\?q=1 file=/tmp/y/z.txt$")
    app.wait_log(r"^scope start=true web=false$")
    app.wait_log(r"^bookmark magic=book same=note.txt stale=false$")
    app.wait_log(r"^bookmark moved=renamed.txt stale=true name=note.txt size=5$")       # values from when it was made
    app.wait_log(r"^bookmark file round trip=true$")
    app.wait_log(r"^bookmark gone error=4$")                                             # NSFileNoSuchFileError
    app.wait_log(r"^versions current=draft others=1 conflicts=0 found=true copyMoved=true$")
    app.wait_log(r"^versions restored=version 1$")
    app.wait_log(r"^versions after remove=0$")
    app.wait_log(r"^versions current remove error=513$")                                 # NSFileWriteNoPermissionError
    # for-in over FileManager enumerators: the iterator must not release what fast enumeration hands out unretained
    app.wait_log(r"^enumerated paths=36 urls=36 still alive=200$")
    assert app.quit() == 0, "exits cleanly"
