"""App Intents under `isim boot` (HelloSiri, "Coffee Club"): the home screen reads the app's App Shortcuts (metadata
mode), the Shortcuts app lists them as tiles with the app's other actions and runs them (an AppEnum parameter asked
for, a confirmation with a snippet view, the result dialog and snippet), Siri matches App Shortcut phrases
(${applicationName}, an AppEnum parameter named in the phrase, an entity from suggestedEntities() and from
updateAppShortcutParameters()), asks for a required String parameter (requestValueDialog, Type to Siri), opens the app
for an OpenIntent, keeps a value and a dialog, refuses an intent that requires authentication while locked, and
Spotlight lists App Shortcuts and runs them. The Siri UI follows the iOS version: the orb (iOS 17), the glowing edge
(iOS 18+). Also (issue #308): an intent donation listed and run from the Shortcuts app's Siri Suggestions, indexed
entities in Spotlight running the OpenIntent, OpenURLIntent from a URL representation, unique and transient entities,
camera capture and audio recording intents, relevant intents, schema intents, and (iOS 26) a snippet intent."""
import re

import pytest

from isimtest import mean_rgb

APP = "dev.isim.samples.HelloSiri"


def boot(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut\(s\), 16 intent\(s\)")
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
    sm = dev.wait_dump(r"\(([0-9.]+) ([0-9.]+); ([0-9.]+) x ([0-9.]+)\) id=siri-snippet")
    sx, sy, sw, sh = (float(v) for v in sm.groups())
    result = dev.screenshot("shortcuts-result")
    dev.wait_log(r"HelloSiri: ordered 1 latte")

    dev.tap_id(f"action-ClearOrdersIntent")                              # an action that is not an App Shortcut
    siri(dev, r"id=siri-card text=Orders cleared\.")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert re.search(r"isim AppIntents: 4 App Shortcut\(s\), 16 intent\(s\)", log), "the app's metadata mode lists them"
    assert re.search(r"SpringBoard: running “Order Coffee” \(HelloSiri.OrderCoffeeIntent\) in Coffee Club \(in the background\)", log), \
        "the intent runs in the app, launched in the background"
    assert re.search(r"SpringBoard: Siri asks “Order 1 latte\?” \(Order / Cancel\)", log), "requestConfirmation with the action name"
    assert re.search(r"isim AppIntents: snippet view 3\d\d x \d+", log), "snippet views drawn by the app"
    assert re.search(r"HelloSiri: orders cleared", log)
    green = mean_rgb(result, (sx + sw - 50, sy + sh / 2 - 4, 30, 8))
    assert green[1] > green[0] and green[1] > green[2], f"the result's snippet (green) is shown on the card {green}"


@pytest.mark.os_matrix
def test_siri_app_shortcuts(launch, ios):
    os_version = int(str(ios[0] or 18).split(".")[0])
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
    card = siri(dev, r"id=siri-card text=Your cappuccino is on its way\.")
    result = dev.screenshot("siri-result")
    if os_version >= 26:                                                 # frosted glass: no sharp home screen behind it
        m = re.search(r"\((\S+) (\S+); (\S+) x (\S+)\) id=siri-card\b", card.string)
        assert m, "the Siri card's frame"
        if m:
            x, y, w, h = (float(v) for v in m.groups())
            # a strip in the card's 18 pt right padding (past the snippet), clear of its 32 pt corners
            strip = [sum(result.getpixel((int(x + w - 15 + i), int(y + 34 + j)))) for i in range(6) for j in range(int(h - 68))]
            spread = max(strip) - min(strip)
            assert spread < 60, f"iOS 26: the card's glass shows no ghost of the icons behind it (spread {spread})"
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


def test_app_intents_discovery(launch):
    dev = boot(launch)
    dev.wait_log(r"SpringBoard: Coffee Club: schema intents: system\.search \(HelloSiri\.SearchCafesIntent\), "
                 r"system\.searchInApp \(HelloSiri\.FindInMenuIntent\)")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("donateOrder")
    dev.wait_log(r"HelloSiri: donated an order [0-9A-F-]{36}")
    dev.tap_id("indexCafes")
    dev.wait_log(r"HelloSiri: indexed 3 cafes, Harbor is coffeeclub://cafe/Harbor, schema intent true assistant only false")
    dev.wait_log(r"1 relevant intent\(s\) for CafeWidget")
    dev.wait_log(r"HelloSiri: packages 0")

    # the donation in the Shortcuts app's Siri Suggestions, run with its values
    dev.send("launch dev.isim.shortcuts")
    dev.wait_tap_id(f"app-shortcuts-{APP}")
    dev.wait_view(r"text=Order Coffee · Latte, 2")
    dev.wait_still()
    dev.screenshot("siri-suggestions")
    dev.tap_text("Order Coffee · Latte, 2")
    siri(dev, r"id=siri-card text=Order 2 latte\?")
    dev.tap_id("siri-confirm")
    siri(dev, r"id=siri-card text=Your latte is on its way\.")
    dev.wait_log(r"HelloSiri: ordered 2 latte")
    # the unique entity is filled in; a transient entity is the value
    dev.wait_still()
    dev.tap_id("action-ToggleDecafIntent")
    siri(dev, r"id=siri-card text=Decaf is on\.")
    dev.wait_still()
    dev.tap_id("action-CafeWeatherIntent")
    siri(dev, r"id=siri-card text=It’s sunny, 21° at Downtown\.")
    dev.wait_still()
    dev.tap_id("action-RecordTastingIntent")
    siri(dev, r"id=siri-card text=Recording your tasting\.")
    dev.wait_still()
    dev.tap_id("action-LatteArtCameraIntent")                            # in the app, in the foreground
    dev.wait_log(r"HelloSiri: camera capture: last photo none, now latte-art-1")
    dev.wait_view(r"id=donateOrder")
    dev.send("home")
    dev.send("launch dev.isim.shortcuts")
    page = dev.wait_view(lambda d: f"id=app-shortcuts-{APP}" in d or "id=action-DirectionsIntent" in d, what="the Shortcuts app")
    if "id=action-DirectionsIntent" not in page:
        dev.tap_id(f"app-shortcuts-{APP}")
    relaunch = rf"^.*SpringBoard: launching Coffee Club \({re.escape(APP)}\)$"   # a launch without a URL
    relaunches = len(re.findall(relaunch, dev.log, re.M))
    opens = len(re.findall(r"SpringBoard: Coffee Club opens", dev.log))
    dev.wait_tap_id("action-DirectionsIntent")                           # OpenURLIntent(urlRepresentable:): the app's URL
    siri(dev, r"id=siri-option-1 text=Harbor")
    dev.tap_id("siri-option-1")
    dev.wait_log(r"HelloSiri: directions to Harbor")
    dev.wait_log(r"HelloSiri: opened coffeeclub://cafe/Harbor")
    dev.wait_log(r"SpringBoard: Coffee Club opens", count=opens + 1)     # the run is over

    # an indexed entity in Spotlight runs the app's OpenIntent for it
    dev.wait_view(r"id=cafe text=Cafe:")
    dev.send("home")
    dev.wait_view(r"id=home-dock")                                       # Spotlight opens from the home screen
    assert len(re.findall(relaunch, dev.log, re.M)) == relaunches, "the opened URL brought the app forward: no second launch"
    dev.wait_still()
    dev.send("spotlight")
    dev.wait_view(r"id=spotlight-field")
    dev.type("Harbor")
    dev.wait_view(r"id=spotlight-item-appentity_HelloSiri\.CafeEntity_Harbor")
    dev.wait_still()
    dev.screenshot("spotlight-entity")
    dev.tap_id("spotlight-item-appentity_HelloSiri.CafeEntity_Harbor")
    dev.wait_log(r"SpringBoard: Spotlight opens HelloSiri\.CafeEntity Harbor with HelloSiri\.ShowCafeIntent")
    dev.wait_log(r"HelloSiri: showing cafe Harbor", count=1)
    dev.wait_view(r"id=cafe text=Cafe: Harbor")
    dev.wait_tap_id("deleteDonations")
    dev.wait_log(r"HelloSiri: deleted 1 donation\(s\)")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert re.search(r"isim AppIntents: donated “Order Coffee · Latte, 2”", log), "the donation's title names its values"
    assert re.search(r"isim AppIntents: settings = Settings \(the unique entity\)", log), "the unique entity is not asked for"
    assert re.search(r"isim AppIntents: 3 Cafe entities indexed in Spotlight", log)


def test_snippet_intent(launch):
    """iOS 26: a snippet intent's view in Siri's card"""
    dev = launch(None, install=["HelloSiri"], os_version="26.0", device="iphone17")
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut\(s\), 16 intent\(s\)")
    dev.send("launch dev.isim.shortcuts")
    dev.wait_tap_id(f"app-shortcuts-{APP}")
    dev.wait_tap_id("action-OrderStatusIntent")
    siri(dev, r"id=siri-card text=Here’s your order\.")
    dev.wait_dump(r"id=siri-snippet")
    dev.wait_still()
    dev.screenshot("snippet-intent")
    assert dev.quit() == 0, "exits cleanly"
    assert re.search(r"isim AppIntents: snippet intent HelloSiri\.OrderStatusSnippet", dev.log)

