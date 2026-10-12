"""SiriKit under `isim boot` (HelloSiri, "Coffee Club"): Siri authorization (the app's alert, remembered, Settings >
the app > Siri), INSendMessageIntent in the Intents extension (a recipient disambiguated, the message read back with
the Intents UI extension's view, sent; missing values asked for; an unsupported recipient), INSearchForMessagesIntent
from the structured script form (an async handler), INStartCallIntent continued in the app (NSUserActivity with its
INInteraction), INAddTasksIntent, INPlayMediaIntent played in the app (.handleInApp), INCreateNoteIntent handled in
the app (application(_:handlerFor:)), donations as Siri Suggestions in the Shortcuts app, and a voice shortcut added
with INUIAddVoiceShortcutViewController and run by saying its phrase."""
import re

import pytest

APP = "dev.isim.samples.HelloSiri"


def siri(dev, pattern):
    return dev.wait_dump(pattern)


def allow_siri(dev):
    dev.send(f"launch {APP}")
    dev.wait_tap_id("allowSiri")
    dev.wait_log(r"isim Intents: asking for Siri access")
    dev.wait_for(label="Allow").tap()
    dev.wait_log(r"HelloSiri: Siri authorization 3")
    dev.send("home")


@pytest.mark.os_matrix
def test_sirikit_messages(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    dev.send("siri send a message to Ben saying hi")                     # not allowed yet
    siri(dev, r"id=siri-card text=You’ll need to open Coffee Club and allow it to use Siri first\.")
    dev.send("siri dismiss")
    allow_siri(dev)

    dev.send("siri send a message to Anna saying See you at 9")         # two Annas: disambiguation
    siri(dev, r"id=siri-option-1 text=Anna Lee")
    dev.screenshot("sirikit-which")
    dev.tap_id("siri-option-1")
    siri(dev, r"id=siri-card text=Ready to send it\?")
    dev.wait_dump(r"id=siri-snippet")                                    # the Intents UI extension's view
    dev.screenshot("sirikit-confirm")
    dev.tap_id("siri-confirm")
    siri(dev, r"id=siri-card text=OK, I sent your message to Anna Lee\.")

    dev.send("siri send a message")                                      # needsValue twice
    siri(dev, r"id=siri-card text=Who do you want to message\?")
    dev.send("siri Ben")
    siri(dev, r"id=siri-card text=What do you want to say\?")
    dev.send("siri The beans are in")
    siri(dev, r"id=siri-confirm text=Send")
    dev.send("siri send")
    siri(dev, r"id=siri-card text=OK, I sent your message to Ben Ito\.")

    dev.send("siri send a message to Zoe saying hi using Coffee Club")   # unsupported
    siri(dev, r"id=siri-card text=Sorry, Coffee Club can’t do that with “Zoe”\.")
    dev.send("siri intent SearchForMessages senders=Ben")                # the structured form; an async handler
    siri(dev, r"id=siri-card text=You have 2 messages\.")
    dev.wait_dump(r"id=siri-detail text=Ben Ito: See you at the bar at 9")
    dev.send("siri dismiss")

    dev.send(f"launch {APP}")
    dev.wait_view(r"id=sent text=Sent: Ben Ito: The beans are in")
    dev.send("home")
    dev.send("launch dev.isim.settings")                                 # Settings > Coffee Club > Siri
    dev.wait_tap_id(f"settings-app-{APP}")
    dev.wait_view(r"id=settings-app-siri")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert "HelloSiri: extension: recipient Anna: 2 member(s)" in log and "isim Intents: recipients: disambiguation" in log, \
        "the extension's resolve asks which Anna"
    assert re.search(r"isim: Intents UI extension rendered 3\d\d x 90", log) and "HelloSiri: Intents UI configured for “See you at 9”" in log, \
        "the Intents UI extension draws the confirmation"
    assert "HelloSiri: extension: sent “See you at 9” to Anna Lee" in log and "HelloSiri: extension: sent “The beans are in” to Ben Ito" in log
    assert "HelloSiri: extension: found 2 message(s)" in log


@pytest.mark.os_matrix
def test_sirikit_app_handling(launch):
    dev = launch(None, install=["HelloSiri"], env={"ISIM_SIRI_PERMISSION": "allow"})
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("allowSiri")                                         # answered by ISIM_SIRI_PERMISSION
    dev.wait_log(r"HelloSiri: Siri authorization 3")
    dev.wait_tap_id("donate")
    dev.wait_log(r"HelloSiri: donated ok")
    dev.wait_tap_id("addToSiri")                                         # Add to Siri: the phrase is prefilled
    dev.wait_view(r"id=siri-shortcut-phrase")
    dev.wait_still()
    dev.screenshot("add-to-siri")
    dev.tap_id("siri-shortcut-done")
    dev.wait_log(r"HelloSiri: added voice shortcut “On my way”")
    dev.send("home")

    dev.send("siri call Ben Ito")                                        # continued in the app
    dev.wait_log(r"HelloSiri: continued INStartCallIntent: Calling Ben Ito")
    dev.send("home")
    dev.send("siri add oat milk to my shopping list")
    siri(dev, r"id=siri-card text=OK, I added “oat milk” to your shopping list\.")
    dev.send("siri play Morning Jazz")                                   # .handleInApp
    dev.wait_log(r"HelloSiri: playing Morning Jazz Mix")
    siri(dev, r"id=siri-card text=Now playing Morning Jazz Mix\.")
    dev.send("siri create a note saying Try the Kenyan beans")           # INIntentsSupported: in the app
    siri(dev, r"id=siri-card text=OK, I made a note in Coffee Club\.")
    dev.send("siri on my way")                                           # the voice shortcut
    siri(dev, r"id=siri-card text=Ready to send it\?")
    dev.send("siri yes")
    siri(dev, r"id=siri-card text=OK, I sent your message to Ben Ito\.")
    dev.send("siri dismiss")

    dev.send("launch dev.isim.shortcuts")                                # voice shortcuts and Siri Suggestions
    dev.wait_view(r"id=voice-On my way")
    dev.wait_tap_id(f"app-shortcuts-{APP}")
    page = dev.wait_view(r"id=suggestion-")
    dev.wait_still()
    dev.screenshot("shortcuts-suggestions")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert "HelloSiri: extension: call Ben Ito continues in the app" in log and "SpringBoard: Siri continues INStartCallIntent in Coffee Club" in log
    assert "HelloSiri: extension: added oat milk" in log
    assert "HelloSiri: handler for INCreateNoteIntent in the app" in log and "HelloSiri: note from Siri “Try the Kenyan beans”" in log
    assert "SpringBoard: Siri matched the voice shortcut “On my way” of Coffee Club" in log
    assert "isim Intents: donated INSendMessageIntent" in log and re.search(r"Message Anna Haro: “Flat white\?”", page), \
        "the donated interaction is a Siri Suggestion"
