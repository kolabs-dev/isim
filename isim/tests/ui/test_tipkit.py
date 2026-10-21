"""TipKit (HelloTips, "Recipes"): Tips.configure (a second call throws), an inline TipView counted against
MaxDisplayCount and closed with its xmark (invalidated .tipClosed, also after a relaunch), a tip shown once its #Rule
over a @Parameter holds (statusUpdates), with actions, a tip whose rule counts an event's donations (donatedWithin), a
popoverTip on a toolbar button dismissed by a tap outside, the display frequency (a new tip waits; IgnoresDisplayFrequency
does not), an ordered TipGroup (iOS 18), and the UIKit views (TipUIView, TipUIPopoverViewController)."""
import pytest

APP = "HelloTips"


def dismiss_share_tip(app):
    """the share button's popover tip shows at launch; a tap outside it closes it (and does nothing else, as on iOS)"""
    if "id=tip-ShareTip" in app.view_dump():
        app.tap(200, 700)
        app.wait_view(r"id=tip-ShareTip\b", gone=True)


@pytest.mark.os_matrix
def test_tips(launch):
    app = launch(APP)
    app.wait_log(r"isim TipKit: configured \(display frequency immediate")
    app.wait_log(r"HelloTips: second configure: The tips datastore was already configured\.")
    app.wait_view(r"id=tip-FavoriteTip\b")
    app.wait_log(r"isim TipKit: FavoriteTip shown \(1\)")
    app.wait_view(r"id=tip-ShareTip\b")                                   # the popover on the share button
    app.wait_still()
    app.screenshot("tips")
    tree = app.view_dump()
    assert "tip-ShoppingListTip" not in tree and "tip-TimerTip" not in tree, "their rules do not hold yet"
    app.tap(200, 700)                                                       # outside the popover: closed
    app.wait_log(r"isim TipKit: ShareTip invalidated \(tipClosed\)")
    app.wait_view(r"id=tip-ShareTip\b", gone=True)

    app.wait_tap_id("addRecipes")                                           # the @Parameter: the rule holds
    app.wait_log(r"HelloTips: shopping tip available")
    app.wait_view(r"id=tip-ShoppingListTip\b")
    app.wait_tap_id("tipaction-ShoppingListTip-make-list")
    app.wait_log(r"HelloTips: action make-list \(0\)")
    app.wait_log(r"isim TipKit: ShoppingListTip invalidated \(actionPerformed\)")
    app.wait_view(r"id=tip-ShoppingListTip\b", gone=True)

    for r in ("Pancakes", "Ramen", "Tacos"):                                # the event's donations
        app.wait_tap_id(f"recipe-{r}")
        app.wait_log(rf"HelloTips: viewed {r}")
    app.wait_view(r"id=tip-TimerTip\b")
    app.wait_still()
    app.screenshot("timer-tip")
    app.tap_id("tipclose-FavoriteTip")
    app.wait_log(r"isim TipKit: FavoriteTip invalidated \(tipClosed\)")
    app.wait_view(r"id=tip-FavoriteTip\b", gone=True)
    app.wait_tap_id("status")
    app.wait_log(r"HelloTips: favorite .*, shopping invalidated\(.*actionPerformed\)")
    assert app.quit() == 0

    again = launch(APP)                                                     # the same device: the datastore persists
    again.wait_log(r"isim TipKit: configured")
    again.wait_tap_id("status")
    again.wait_log(r"HelloTips: .*shopping invalidated\(.*actionPerformed\)")
    assert "tip-ShareTip" not in again.view_dump(), "the closed popover tip stays closed"
    assert again.quit() == 0


def test_display_frequency(launch):
    """hourly: the first tip shows; another whose rule holds waits for the next hour; IgnoresDisplayFrequency shows"""
    app = launch(APP, env={"TIPS_FREQUENCY": "hourly"})
    app.wait_log(r"isim TipKit: configured \(display frequency hourly")
    m = app.wait_log(r"isim TipKit: (FavoriteTip|ShareTip) shown \(1\)")
    app.wait_still()
    other = "ShareTip" if m.group(1) == "FavoriteTip" else "FavoriteTip"
    assert f"id=tip-{other}" not in app.view_dump(), "one new tip per display frequency period"
    dismiss_share_tip(app)
    app.wait_tap_id("addRecipes")
    app.wait_log(r"HelloTips: has recipes")
    for r in ("Pancakes", "Ramen", "Tacos"):
        app.wait_tap_id(f"recipe-{r}")
        app.wait_log(rf"HelloTips: viewed {r}")
    app.wait_view(r"id=tip-TimerTip\b")                                     # IgnoresDisplayFrequency
    app.wait_tap_id("status")
    app.wait_log(r"HelloTips: .*shopping pending")
    assert "tip-ShoppingListTip" not in app.view_dump(), "a new tip waits for the display frequency"
    assert app.quit() == 0


def test_tip_group_and_uikit(launch):
    """iOS 18: an ordered TipGroup shows its tips one after the other; UIKit's TipUIView and TipUIPopoverViewController"""
    app = launch(APP, os_version="18.0")
    app.wait_log(r"isim TipKit: ShareTip shown")
    app.wait_still()
    dismiss_share_tip(app)
    app.wait_tap_id("onboarding")
    app.wait_view(r"id=tip-WelcomeTip\b")
    app.wait_view(r"id=currentTip text=Current: WelcomeTip")
    app.tap_id("tipclose-WelcomeTip")
    app.wait_view(r"id=currentTip text=Current: SearchTip")
    app.wait_view(r"id=tip-SearchTip\b")
    app.drag(200, 300, 200, 900, 0.3)                                       # the sheet down
    app.wait_view(r"id=currentTip", gone=True)
    app.wait_tap_id("uikit")
    app.wait_log(r"HelloTips: UIKit tip view shown")
    app.wait_view(r"id=tip-BookmarkTip\b")
    app.wait_tap_id("popoverTipButton")
    app.wait_log(r"HelloTips: UIKit popover tip presented")
    app.wait_view(r"id=tip-ShareTip\b")
    app.wait_still()
    app.screenshot("uikit-tips")
    assert app.quit() == 0
