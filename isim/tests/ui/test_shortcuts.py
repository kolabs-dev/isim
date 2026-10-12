"""App Intents under `isim boot` (HelloSiri, "Coffee Club"): the home screen reads the app's App Shortcuts (metadata
mode), the Shortcuts app lists them as tiles with the app's other actions and runs them (an AppEnum parameter asked
for, a confirmation with a snippet view, the result dialog and snippet), Siri matches App Shortcut phrases
(${applicationName}, an AppEnum parameter named in the phrase, an entity from suggestedEntities() and from
updateAppShortcutParameters()), asks for a required String parameter (requestValueDialog, Type to Siri), opens the app
for an OpenIntent, keeps a value and a dialog, refuses an intent that requires authentication while locked, and
Spotlight lists App Shortcuts and runs them. The Siri UI follows the iOS version: the orb (iOS 17), the glowing edge
(iOS 18+)."""
import re

import pytest

from isimtest import mean_rgb

APP = "dev.isim.samples.HelloSiri"


def boot(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut\(s\), 6 intent\(s\)")
    return dev


def siri(dev, pattern):
    """the Siri UI's parts (dump) once one matches"""
    return dev.wait_dump(pattern)


@pytest.mark.os_matrix
def test_shortcuts_app(launch):
    dev = boot(launch)
    dev.send("launch dev.isim.shortcuts")
    dev.wait_tap_id(f"app-shortcuts-{APP}")
    page = dev.wait_view(rf"id=shortcut-{APP}-3")
    dev.wait_still()
    dev.screenshot("shortcuts-app")
    assert all(f"id=shortcut-{APP}-{i}" in page for i in range(4)), "the app's four App Shortcuts as tiles"
    assert "id=action-ClearOrdersIntent" in page and "ResetIntent" not in page and "id=action-OrderCoffeeIntent" not in page, \
        "Actions: discoverable intents that are not App Shortcuts"
    assert re.search(r"Try saying “Order a coffee in Coffee Club”", page), "the phrase hint names the app"

    dev.tap_id(f"shortcut-{APP}-0")                                     # Order Coffee: the drink is asked for
    m = siri(dev, r"id=siri-option-2 text=Cappuccino")
    out = dev.log[m.start() - 2000 if m.start() > 2000 else 0:]
    assert "id=siri-card text=What would you like to drink?" in out and "id=siri-option-1 text=Latte" in out, \
        "the AppEnum parameter's cases (requestValueDialog)"
    assert "id=siri-orb" not in out and "id=siri-glow" not in out, "runs from Shortcuts show the card without Siri"
    dev.tap_id("siri-option-1")
    siri(dev, r"id=siri-confirm text=Order")
    dev.wait_dump(r"id=siri-snippet")
    dev.screenshot("shortcuts-confirm")
    dev.tap_id("siri-confirm")
    siri(dev, r"id=siri-card text=Your latte is on its way\.")
    dev.wait_dump(r"id=siri-snippet")
    result = dev.screenshot("shortcuts-result")
    dev.wait_log(r"HelloSiri: ordered 1 latte")

    dev.tap_id(f"action-ClearOrdersIntent")                              # an action that is not an App Shortcut
    siri(dev, r"id=siri-card text=Orders cleared\.")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert re.search(r"isim AppIntents: 4 App Shortcut\(s\), 6 intent\(s\)", log), "the app's metadata mode lists them"
    assert re.search(r"SpringBoard: running “Order Coffee” \(HelloSiri.OrderCoffeeIntent\) in Coffee Club \(in the background\)", log), \
        "the intent runs in the app, launched in the background"
    assert re.search(r"SpringBoard: Siri asks “Order 1 latte\?” \(Order / Cancel\)", log), "requestConfirmation with the action name"
    assert re.search(r"isim AppIntents: snippet view 3\d\d x \d+", log), "snippet views drawn by the app"
    assert re.search(r"HelloSiri: orders cleared", log)
    green = mean_rgb(result, (40, 150, 40, 10))
    assert green[1] > green[0] and green[1] > green[2], f"the result's snippet (green) is shown on the card {green}"


@pytest.mark.os_matrix
def test_siri_app_shortcuts(launch, ios):
    os_version = int(str(ios[0]).split(".")[0])
    dev = boot(launch)
    dev.send("siri")                                                     # listening (the side button held)
    ui = siri(dev, r"IsimSiri .*mode=listening")
    out = dev.log[ui.start():]
    shot = dev.screenshot("siri-listening")
    if os_version >= 18:
        siri(dev, r"id=siri-glow")
        edge = mean_rgb(shot, (0, 400, 4, 40))
        assert max(edge) - min(edge) > 40, f"iOS 18+: the glowing edge {edge}"
    else:
        siri(dev, r"id=siri-orb")
    dev.send("siri dismiss")
    dev.wait_log(r"SpringBoard: Siri dismissed")

    dev.send("siri Order a cappuccino in Coffee Club")                  # the AppEnum value named in the phrase
    siri(dev, r"id=siri-card text=Order 1 cappuccino\?")
    dev.screenshot("siri-confirm")
    dev.send("siri yes")
    siri(dev, r"id=siri-card text=Your cappuccino is on its way\.")
    dev.screenshot("siri-result")
    dev.send("siri How many coffees did I have in Coffee Club")
    siri(dev, r"id=siri-card text=You’ve ordered 1 cup today\.")

    dev.send("siri add a tasting note in coffee club")                  # a required String: requestValueDialog, Type to Siri
    siri(dev, r"id=siri-field")
    dev.wait_dump(r"id=siri-card text=What should the note say\?")
    dev.type("Nutty and sweet")
    dev.send("key return")
    siri(dev, r"id=siri-card text=Noted: “Nutty and sweet”\.")

    dev.send("siri Show Harbor in Coffee Club")                          # OpenIntent: an entity, the app opens
    dev.wait_log(r"HelloSiri: showing cafe Harbor")
    dev.wait_log(r"SpringBoard: Coffee Club opens")
    dev.wait_view(r"id=cafe text=Cafe: Harbor")
    dev.send("siri Show Station in Coffee Club")                         # not a cafe yet
    siri(dev, r"id=siri-card text=Sorry, I can’t help with that here\.")
    dev.wait_tap_id("addCafe")                                           # updateAppShortcutParameters()
    dev.wait_log(r"App Shortcut parameters updated \(1 parameter\(s\)\)")
    dev.send("siri Show Station in Coffee Club")
    dev.wait_log(r"HelloSiri: showing cafe Station")

    dev.send("home")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.send("siri add a tasting note in Coffee Club")                  # authenticationPolicy while locked
    siri(dev, r"id=siri-card text=You’ll need to unlock your iPhone first\.")
    dev.send("siri dismiss")
    dev.send("unlock")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert "SpringBoard: Siri matched the App Shortcut “Order a … in Coffee Club” of Coffee Club" in log and \
        re.search(r"isim AppIntents: drink = Cappuccino", log), "the phrase's parameter is the intent's value"
    assert re.search(r"HelloSiri: note “Nutty and sweet”", log), "the typed answer is the parameter's value"
    assert re.search(r"isim AppIntents: CupsToday|SpringBoard: Siri says “You’ve ordered 1 cup today\.”", log)
    assert re.search(r"SpringBoard: Siri did not understand “Show Station in Coffee Club”", log), \
        "entities Siri does not know yet are not matched"


@pytest.mark.os_matrix
def test_spotlight_app_shortcuts(launch):
    dev = boot(launch)
    dev.send("spotlight")
    dev.wait_view(r"id=spotlight-field")
    dev.type("order")
    dev.wait_log(r"SpringBoard: Spotlight “order”: 0 app\(s\), 0 item\(s\), 1 shortcut\(s\)")
    dev.wait_view(rf"id=spotlight-shortcut-{APP}-0")
    dev.wait_still()
    dev.screenshot("spotlight")
    dev.tap_id(f"spotlight-shortcut-{APP}-0")
    siri(dev, r"id=siri-option-0 text=Espresso")
    dev.send("siri espresso")                                            # said instead of tapped
    siri(dev, r"id=siri-confirm")
    dev.tap_id("siri-cancel")
    siri(dev, r"id=siri-card text=OK\.")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert "SpringBoard: Spotlight runs the App Shortcut “Order Coffee”" in log and \
        re.search(r"isim AppIntents: Order Coffee cancelled", log), "Spotlight runs it; Cancel ends it"
