"""View controller and container members (HelloControllerExtras): the More tab of a seven-tab bar, the tab bar's
item appearances, customizable navigation item groups (fixed, optional left out, pinned), the generic back button and
a back action, the title menu's Rename, hiding the bars on tap, the split view's collapsed environment and inspector
sheet, search tokens and the bookmark button, a popover with a source item and a custom background, a popover's
adaptive sheet, the share sheet from an activity items configuration, the document interaction options menu, the
video editor, a container forwarding appearance by hand, the colour and font picker additions and a
UIManagedDocument."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_controller_extras(launch, ios):
    v = major(ios)
    app = launch("HelloControllerExtras")
    app.wait_log(r"^ctl items is appearing true$")
    app.wait_log(r"^ctl managed document saved true opened true count 1 store true$")
    log = app.log
    assert "ctl ready label Items" in log, "@ViewLoading loads the view"
    assert "ctl tab appearance kept true copied true" in log
    assert "ctl more items Items,Split,Search,Present,More" in log, "four tabs and More"
    assert "ctl search tokens 1" in log
    if v >= 26:
        assert "ctl eyedropper false exposure 2" in log
    if v >= 18:
        assert "ctl language filter true copy true" in log

    # item groups: the fixed and pinned groups show, the optional one left out of the default customization doesn't
    app.wait_for(id="fixed")
    if v >= 26:
        app.wait_for(id="pinned")
    assert app.find(id="optional") is None

    # the title menu: Rename puts a field over the title (the title selected); Return renames the item
    app.tap_id("nav-title-menu")
    app.wait_tap_id("menu-Rename")
    app.wait_log(r"^ctl should rename$")
    app.wait_log(r"isim: renaming the title began")
    app.type("Renamed")                                                  # the title is selected: typing replaces it
    app.send("key return")
    app.wait_log(r"^ctl renamed Renamed item Renamed$")

    # push: the back button reads "Back" (generic mode), a tap in the content hides and shows the bars, the back
    # action runs instead of the pop
    app.tap_id("detail")
    app.wait_log(r"^ctl detail appeared tap recognizer true$")
    back = app.wait_for(id="nav-back")
    assert back.label == "Back", back.label
    app.tap(200, 500)
    app.wait_log(r"isim: navigation bars hidden")
    app.tap(200, 500)
    app.wait_log(r"isim: navigation bars shown")
    app.tap_id("nav-back")
    app.wait_log(r"^ctl back action$")
    app.wait_log(r"^ctl items is appearing true$", count=2)

    # split view: collapsed on iPhone; the inspector comes up as a sheet
    app.tap_id("tab-Split")
    app.wait_log(r"^ctl split collapsed true environment collapsed showing secondary true primary false inspector false$")
    if v >= 26:
        app.tap_id("inspector")
        app.wait_log(r"isim: split view inspector shown")
        app.wait_log(r"^ctl inspector appeared$")
        app.drag(200, 300, 200, 900, 0.3)                                # swipe the sheet down
        app.wait_view(r"isim-presentation", gone=True)

    # search: the bookmark button in the empty field, then Delete at the start removes the token
    app.tap_id("tab-Search")
    app.wait_tap_id("search-bookmark")
    app.wait_log(r"^ctl bookmark$")
    app.tap_id("search-field")
    app.send("key backspace")
    app.wait_log(r'isim: search token "Swift" removed')
    app.type("a")
    app.wait_log(r"^ctl search text 'a' tokens 0 scope true$")    # the scope bar on text entry
    app.tap_id("search-cancel")                                          # (the keyboard goes away)
    app.wait_log(r"isim: search controller inactive")

    # presentations
    app.tap_id("tab-Present")
    app.wait_tap_id("popover")
    app.wait_log(r"^ctl popover background arrow up$")
    app.wait_log(r"^ctl popover shown height 152 ")                     # 160 minus the background's content insets
    app.tap_id("close-popover")
    app.tap_id("adaptive")
    m = app.wait_log(r"^ctl adaptive shown height (\d+) screen (\d+)$")
    assert int(m[1]) < int(m[2]) * 0.6, "the adaptive sheet's medium detent"
    app.tap_id("close-adaptive")
    app.tap_id("share")
    app.wait_view(r"Config Title")
    app.tap_id("share-close")
    app.tap_id("options")
    app.wait_log(r"^ctl doc uti public.plain-text name notes.txt icons 1$")
    app.wait_log(r"^ctl doc will present options$")
    app.wait_view(r"isim-share-sheet")
    app.tap_id("share-close")
    app.wait_log(r"^ctl doc dismissed options$")
    app.tap_id("video")
    app.wait_log(r"^ctl can edit true missing false$")
    app.wait_tap_id("video-editor-save")
    app.wait_log(r"^ctl video saved mov exists true$")

    # More: the list of the other tabs; a pushed one shows, More again goes back to the list
    app.tap_id("tab-More")
    app.wait_log(r"^ctl selected more index none$")
    app.wait_tap_id("more-Six")
    app.wait_log(r"^ctl six appeared$")
    app.tap_id("tab-More")
    app.wait_tap_id("more-Five")
    # the container forwards appearance itself, and swaps its children with transition(from:to:)
    app.wait_log(r"^ctl child a appeared$")
    app.wait_log(r"^ctl five appeared$")
    app.tap_id("swap")
    app.wait_log(r"^ctl swapped true status bar child b true$")
    app.wait_log(r"^ctl child b appeared$")
    app.wait_log(r"^ctl child a disappeared$")

    # the document browser: renaming, a custom action in a document's menu and as a bar button while selecting
    assert "ctl renamed document Letter.txt error false transition 0.3" in app.log
    app.tap_id("tab-More")
    app.wait_tap_id("more-Seven")
    app.wait_view(r"docs-item-Letter\.txt")
    app.send("holdid docs-item-Letter.txt 0.8")
    app.wait_tap_id("menu-Tag")
    app.wait_log(r"^ctl action tag Letter.txt$")
    app.wait_tap_id("docs-select")
    app.tap_id("docs-item-Letter.txt")
    app.wait_tap_id("docs-action-tag")
    app.wait_log(r"^ctl action tag Letter.txt$", count=2)
    assert app.quit() == 0
