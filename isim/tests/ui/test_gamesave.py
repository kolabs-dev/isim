"""GameSave's synced directory (HelloGameSave; issue #393). Two devices (Pat and Sam) share isim's simulated iCloud
($ISIM_GAMESAVE): Pat's save is uploaded and Sam's copy downloads it; Sam goes offline (`gamesave offline`) and levels
up while Pat levels up twice and uploads; when Sam is back online its directory is conflicted with both versions (Sam's
level 3 on this device, Pat's level 4 in iCloud); Sam keeps its own, which is uploaded, and Pat gets it on reopening.
Then the directory closes."""


def test_gamesave(launch, tmp_path):
    pat = launch("HelloGameSave", data=tmp_path / "pat", animations=False)
    pat.wait_log(r"HelloGameSave: state syncing")
    pat.wait_log(r"HelloGameSave: state ready")
    pat.wait_log(r"HelloGameSave: level 0")
    pat.tap_id("levelup")
    pat.tap_id("levelup")
    pat.wait_log(r"HelloGameSave: level 2")
    pat.tap_id("upload")
    pat.wait_log(r"HelloGameSave: upload true")
    pat.wait_log(r"isim GameSave: iCloud\.dev\.isim\.samples\.HelloGameSave uploaded version 1")

    # Sam's device downloads it
    sam = launch("HelloGameSave", data=tmp_path / "sam", animations=False)
    sam.wait_log(r"isim GameSave: iCloud\.dev\.isim\.samples\.HelloGameSave downloaded version 1")
    sam.wait_log(r"HelloGameSave: level 2")

    # Sam offline: its change stays local
    sam.send("gamesave offline")
    sam.wait_log(r"HelloGameSave: state offline")
    sam.tap_id("levelup")
    sam.wait_log(r"HelloGameSave: level 3")
    sam.tap_id("upload")
    sam.wait_log(r"HelloGameSave: upload false")

    # Pat moves on
    pat.tap_id("levelup")
    pat.tap_id("levelup")
    pat.wait_log(r"HelloGameSave: level 4")
    pat.tap_id("finish")
    pat.wait_log(r"HelloGameSave: finished syncing")
    pat.wait_log(r"uploaded version 2")

    # Sam back online: a conflict
    sam.send("gamesave online")
    sam.wait_log(r"HelloGameSave: state conflicted 2")
    sam.wait_log(r"HelloGameSave: version local level 3 from iPhone[\w ]* dated true")
    sam.wait_log(r"HelloGameSave: version iCloud level 4 from iPhone[\w ]* dated true")
    sam.tap_id("keep-local")
    sam.wait_log(r"HelloGameSave: level 3", count=2)
    sam.wait_log(r"uploaded version 3")

    # Pat reopens: Sam's level
    pat.tap_id("reopen")
    pat.wait_log(r"downloaded version 3")
    pat.wait_log(r"HelloGameSave: level 3")

    sam.tap_id("close")
    sam.wait_log(r"HelloGameSave: state closed")
    for d in (pat, sam):
        assert "not open" not in d.log
        assert d.quit() == 0
