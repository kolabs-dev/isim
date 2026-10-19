"""Cell configuration overrides (HelloCellOverrides, issue #242): Swift subclasses of UICollectionViewListCell,
UITableViewCell and UITableViewHeaderFooterView override updateConfiguration(using:) — UIKit calls it before layout
when the state changes, then the configurationUpdateHandler with the same state, as on iOS — and a cell adds a custom
state (UIConfigurationStateCustomKey) by overriding configurationState; the states are the Swift structs, bridged to
UIKit's Objective-C classes."""


def test_cell_overrides(launch):
    app = launch("HelloCellOverrides")
    app.wait_log(r"^cv override Inbox selected=false archived=false$")
    app.wait_log(r"^cv override Old mail selected=false archived=true$")     # the custom state from configurationState
    app.wait_log(r"^table override selected=false editing=false$")
    app.wait_log(r"^header override disabled=false$")
    log = app.log
    assert log.index("cv override Inbox selected=false") < log.index("cv handler selected=false"), "the override, then the handler"

    app.wait_tap_id("item0")                                         # selecting: the override sees the new state
    app.wait_log(r"^cv override Inbox selected=true archived=false$")
    app.wait_log(r"^cv handler selected=true$")
    app.wait_tap_id("row0")
    app.wait_log(r"^table override selected=true editing=false$")
    app.wait_view(r"text=Table row \(selected\)")
    assert app.quit() == 0, "exits cleanly"
