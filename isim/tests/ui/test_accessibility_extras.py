"""Further accessibility APIs (HelloAccessibilityExtras): Settings > Accessibility values and their notifications (script
`accessibility SETTING on|off`), Guided Access (script `guidedaccess`), VoiceOver's use of attributed labels (heading
level, spell out), expanded status, iOS 17 block-based properties, data tables, a picker's accessibility delegate,
reading content and scroll status (script `voiceover scroll`), the focused element, announcement priority; custom
actions and rotors, location descriptors, coordinate conversions, hit testing, image views that grow at the
accessibility text sizes."""
import plistlib

import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_accessibility_extras(launch, ios):
    v = major(ios)
    app = launch("HelloAccessibilityExtras")
    app.wait_log(r"^ax ready$")
    log = app.log
    assert ("ax settings guided false mono false speakScreen false speakSelection false assistiveTouch false "
            "shakeToUndo true ear 0") in log
    assert "ax attributed label Bye pitch 1.2 now Bye" in log, "the attributed label follows the plain one"
    assert "ax label block From block" in log and "ax textual context stored true block true" in log
    assert "ax action Copy image true attributed Copy" in log and "ax rotor Headings type true" in log
    assert "ax screen rect 11,22 3x4" in log and "ax screen path 10,20" in log
    assert "ax image size 17 category false" in log
    assert 'isim: accessibility notification announcement "Saved" priority high queued' in log
    if v >= 18:
        assert "ax hit test Details" in log

    # Settings > Accessibility switches post their notifications (both names of Differentiate Without Color)
    app.send("accessibility monoaudio on")
    app.wait_log(r"^ax note monoAudio true$")
    app.send("accessibility differentiate on")
    app.wait_log(r"^ax note differentiate true$")
    app.wait_log(r"^ax note shouldDifferentiate true$")

    # Guided Access: the app's restriction is listed and switched; features configure only during a session
    app.send("guidedaccess on")
    app.wait_log(r'isim: Guided Access restriction com.example.purchases "Purchases" \(Buying in the app\)')
    app.wait_log(r"^ax configure true error none$")
    app.send("guidedaccess restrict com.example.purchases deny")
    app.wait_log(r"^ax restriction com.example.purchases deny state deny$")
    app.send("guidedaccess off")
    app.wait_log(r"^ax note guidedAccess false$")

    # VoiceOver
    app.send("voiceover on")
    app.wait_log(r'VoiceOver: "Chapter, Heading level 2"')                 # the heading level from the attributed label
    app.wait_log(r"^ax focused Chapter by UIAccessibilityNotificationVoiceOverIdentifier$")
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Code A B C"')                               # spelled out
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Details, Button, Collapsed"' if v >= 18 else r'VoiceOver: "Details, Button"')
    if v >= 18:
        app.send("voiceover activate")
        app.wait_log(r"^ax details expanded$")
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Counter, 3, Adjustable\.')                  # label, value and traits from blocks
    app.send("voiceover increment")
    app.wait_log(r"^ax counter 4$")
    app.wait_log(r'VoiceOver: "4"')
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "A1, Row 1, Column 1"')                      # a data table cell
    for _ in range(3):
        app.send("voiceover next")
    app.wait_log(r'VoiceOver: "B2, Row 2, Column 2"')
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Size, Medium, 2 of 3, Adjustable\. Pick a size\."')   # the picker's accessibility delegate
    app.send("voiceover increment")
    app.wait_log(r"^ax picker selected Large$")
    app.wait_log(r'VoiceOver: "Large, 3 of 3"')
    app.send("voiceover next")
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Photo one"')
    app.send("voiceover scroll left")                                       # three fingers left: the next page
    app.wait_log(r"isim: VoiceOver scrolled left: Photo 2 of 3")
    app.send("voiceover read")
    app.wait_log(r'VoiceOver: "Once upon a time\. The end\."')             # reading content: the page
    app.send("voiceover off")
    assert app.quit() == 0


def test_accessibility_extras_settings(launch, device_data):
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True)
    prefs.write_bytes(plistlib.dumps({"ISIMContentSizeCategory": "UICTContentSizeCategoryAccessibilityXL",
                                      "ISIMMonoAudio": True, "ISIMShakeToUndo": False, "ISIMSpeakScreen": True}))
    app = launch("HelloAccessibilityExtras")
    app.wait_log(r"^ax ready$")
    assert "mono true speakScreen true speakSelection false assistiveTouch false shakeToUndo false" in app.log
    assert "ax image size 40 category true" in app.log, "an adjusting image view grows with the body text (40 / 17)"
    assert app.quit() == 0
