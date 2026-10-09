"""View controller-based state restoration (HelloRestoration, an app without scenes) under isim boot: going home
saves the controllers with restoration identifiers; after a device restart the next launch rebuilds them — the
list found by its path, the detail from its restoration class, the presented About from the app delegate, the
navigation stack, the table's selection (UIDataSourceModelAssociation) and offset, a registered object and the app
delegate's state — before didFinishLaunching. Closing the app in the app switcher discards the state. Background
fetch: `bgtask BUNDLE --fetch` (UIBackgroundModes fetch and a minimum interval; an app without them is not fetched)."""
import pytest
from isimtest import rgb

APP = "dev.isim.samples.HelloRestoration"


@pytest.mark.os_matrix
def test_restoration(launch):
    dev = launch(None, install=["HelloRestoration", "HelloPasteboard"])
    dev.send(f"launch {APP}")
    dev.wait_log(r'didFinishLaunching: stack \["list"\], presented none')
    dev.wait_opened("HelloRestoration")
    dev.drag(200, 700, 200, 400, 0.4)                                   # scroll the list, then open an item
    dev.wait_still()
    dev.tap(200, 500)
    row = int(dev.wait_log(r"selected Item (\d+)").group(1))
    assert row > 12, "an item below the first screen"
    dev.wait_view(r"id=detail-label")
    dev.wait_tap_id("increment").wait_tap_id("increment")
    dev.wait_view(rf"text=Item {row} · count 2")
    dev.wait_tap_id("about")                                            # a presented controller
    dev.wait_view(r"id=about-label")
    dev.wait_shot(lambda s: rgb(s, 200, 150)[2] < 60, what="the About sheet fully up (yellow)")
    dev.wait_shot_still()
    dev.screenshot("before-home")
    dev.send("home")
    dev.wait_log(rf"detail encoded Item {row} count 2")
    dev.wait_log(rf"list encoded: selected {row - 1}, offset (\d+)")
    offset = int(dev.wait_log(r"list encoded: selected \d+, offset (\d+)").group(1))
    assert offset > 100, "the list was scrolled"
    dev.wait_log(r"state restoration: saved \d+ objects")
    assert dev.quit() == 0

    dev = launch(None, install=["HelloRestoration", "HelloPasteboard"])  # a device restart
    dev.send(f"launch {APP}")
    dev.wait_log(r"willFinishLaunching")
    dev.wait_log(r"should restore: saved by version 7, secure true")
    dev.wait_log(rf"restoration class creates nav/detail for Item {row}")
    dev.wait_log(r"detail decoded count 2")
    dev.wait_log(r"settings decoded visits 1")
    dev.wait_log(r"app delegate decoded: from the app delegate")
    dev.wait_log(r"app delegate creates nav/detail/about")
    dev.wait_log(r"about decoded \(opened earlier: true\)")
    dev.wait_log(r"state restoration: restored 4 of 4 view controllers")
    dev.wait_log(r'didFinishLaunching: stack \["list", "detail"\], presented none')   # restored before didFinishLaunching
    dev.wait_log(rf"list finished restoring: selected Item {row}, offset {offset}")
    dev.wait_log(r"settings finished restoring")
    dev.wait_log(r"state restoration: finished \(1 views\)")
    dev.wait_opened("HelloRestoration")
    dev.wait_view(r"id=about-label")                                    # About is presented again
    dev.wait_shot_still()
    dev.screenshot("restored-about")
    dev.wait_view(rf"text=Item {row} · count 2")                         # the detail underneath, with its count

    dev.send("home")                                                    # background fetch
    dev.send(f"bgtask {APP} --fetch")
    dev.wait_log(r"performFetch: state background")
    dev.wait_log(r"background fetch finished")
    dev.send("bgtask dev.isim.samples.HelloPasteboard --fetch")
    dev.wait_log(r"background fetch: no UIBackgroundModes fetch in Info\.plist")

    dev.send("switcher")                                                # closed in the app switcher: no state
    dev.wait_log(r"app switcher \(")
    dev.send("swipeid switcher-HelloRestoration 0 -300 0.3")
    dev.wait_log(r"HelloRestoration\.app exited")
    dev.send("home")
    dev.send(f"launch {APP}")
    dev.wait_log(r'didFinishLaunching: stack \["list"\], presented none')
    assert dev.count(r"should restore:") == 1, "the state was discarded"
    assert dev.quit() == 0
