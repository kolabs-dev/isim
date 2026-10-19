"""UIKit's iOS 14+ configuration APIs from Objective-C (HelloConfigurationsObjC, issue #235): configuration states and
custom keys, window scene placements, keypad HID usages, cell and supplementary registrations, a diffable data source's
outline (section snapshot handlers) and reordering handlers, a cell subclass's -updateConfigurationUsingState: and its
configurationUpdateHandler, and symbol effects on an image view (Symbols.framework)."""


def test_configurations_objc(launch):
    app = launch("HelloConfigurationsObjC")
    app.wait_log(r"^co list items=")
    log = app.log
    assert "co state selected=1 editing=1 drag=1 badge=new copy=sale equal=0 reequal=1" in log
    assert "co view state disabled=0 is-cell=0" in log
    assert "co placement prominent=2 standard=1 back=UIWindowSceneStandardPlacement equal=1" in log
    assert "co hid a=4 keypad1=89 keypadEnter=88" in log
    assert "co list items=Citrus,Berries,Blueberry,Raspberry" in log, "Citrus starts collapsed, Berries expanded"
    app.wait_log(r"^co header UICollectionElementKindSectionHeader section=0$")
    app.wait_view(r"id=header")

    # the outline: expanding asks the handlers; Berries may not collapse
    citrus = app.wait_for(id="group-Citrus")
    app.tap(citrus.x + citrus.w - 16, citrus.y + citrus.h / 2)
    app.wait_log(r"^co will expand Citrus$")
    app.wait_view(r"id=fruit-Lime")
    berries = app.wait_for(id="group-Berries")
    app.tap(berries.x + berries.w - 16, berries.y + berries.h / 2)
    app.wait_view(r"id=fruit-Blueberry")
    assert "co will collapse Berries" not in app.log, "shouldCollapseItemHandler said no"

    # reordering in editing mode (the reorder accessory)
    app.wait_tap_id("edit")
    app.wait_log(r"^co editing 1$")
    app.wait_view(r"id=accessory-reorder")
    app.wait_still()
    lime, lemon = app.wait_for(id="fruit-Lime"), app.wait_for(id="fruit-Lemon")
    gx = lime.x + lime.w - 20
    app.drag(gx, lime.y + lime.h / 2, gx, lemon.y + lemon.h / 2 - 4, 0.6)
    app.wait_log(r"^co will reorder sections=1$")
    app.wait_log(r"^co reordered: Lime,Lemon,Orange$")
    app.wait_tap_id("edit")
    app.wait_log(r"^co editing 0$")

    # selection: the cell's override and its configurationUpdateHandler see the state
    app.wait_for(id="fruit-Orange").tap()
    app.wait_log(r"^co handler Orange selected=1$")
    app.wait_log(r"^co update Orange selected=1 editing=0$")
    app.wait_view(r"text=Orange ✓")

    # symbol effects from Objective-C
    app.wait_tap_id("bounce")
    app.wait_log(r"^co bounce finished=1 effect=NSSymbolBounceEffect sender=1$")
    app.wait_tap_id("pulse")
    app.wait_log(r"^co pulse added$")
    app.wait_log(r"^co pulse removed finished=1$")
    app.wait_log(r"^co replaced finished=1 transition=NSSymbolReplaceContentTransition$")
    assert app.quit() == 0
