"""Accessibility (HelloAccessibility): isim's VoiceOver walks the accessibility tree in order (labels, values, traits,
hints; a container's accessibilityElements order; SwiftUI accessibilityAddTraits / .combine / accessibilityValue /
accessibilityHidden), draws its cursor, activates (synthesized tap), adjusts a slider, runs a custom action, speaks an
announcement; Dynamic Type follows a content size change at runtime (UIKit label with
adjustsFontForContentSizeCategory, UIFontMetrics, SwiftUI text grows in the dump); Settings > Accessibility values from
the device preferences (Larger Text, Bold Text, Reduce Motion, Increase Contrast, Reduce Transparency, VoiceOver).
Port of tests/ui/accessibility.sh."""
import plistlib
import re

from isimtest import rgb

EXPECT = ["Settings, Heading", "Play, Button. Plays the song.", "Wi-Fi, Switch button, On",
          "Volume, 50%, Adjustable. Swipe up or down with one finger to adjust the value.",
          "Message from Ana. Actions available.", "Tue, 5 thousand steps", "Mon, 3 thousand steps", "Announce, Button",
          "Dynamic Type body", "SwiftUI part, Heading", "Favorites",
          "Rating, 3 stars, Adjustable. Swipe up or down with one finger to adjust the value.", "Body text",
          "Bigger text, Button"]


def spoken(app):
    return re.findall(r'VoiceOver: "([^"]*)"', app.log)


def swiftui_body_height(tree):
    m = re.search(r"x ([0-9.]+)\).* id=swiftui-body", tree)
    return float(m.group(1)) if m else None


def test_voiceover_and_dynamic_type(launch):
    app = launch("HelloAccessibility", env={"ISIM_DUMP_ACCESSIBILITY": "1"})
    app.send("voiceover on")
    app.wait_log(r'VoiceOver: "Settings, Heading"')
    for _ in range(14):
        app.send("voiceover next")
    app.wait_log(r"VoiceOver: \(end of list\)")                          # the end of the list
    assert spoken(app)[:14] == EXPECT, f"VoiceOver reads the screen in order: {spoken(app)[:14]}"
    app.wait_until(lambda: max(rgb(app.screenshot("cursor"), 17, 740)) < 40, what="VoiceOver cursor drawn (black frame)")

    app.send("voiceover off").send("voiceover on")
    app.wait_log(r'VoiceOver: "Settings, Heading"', count=2)
    app.send("voiceover next").send("voiceover activate")
    app.wait_log(r"^play tapped")                                        # activate taps the button ...
    app.send("voiceover next").send("voiceover activate")
    app.wait_log(r"^wifi false")                                         # ... and the switch
    app.send("voiceover next").send("voiceover increment")
    app.wait_log(r"^volume 0\.6")
    app.wait_log(r'VoiceOver: "60%"')                                    # increment adjusts the slider
    app.send("voiceover next").send("voiceover action")
    app.wait_log(r'VoiceOver: "Delete"')
    app.wait_log(r"^deleted message")                                    # custom action
    app.send("voiceover next").send("voiceover next").send("voiceover next").send("voiceover activate")
    app.wait_log(r'accessibility notification announcement "Download finished"')
    app.wait_log(r'VoiceOver: "Download finished"')                      # announcement posted and spoken
    app.send("voiceover off")
    app.wait_log(r"^voiceover running false")
    assert app.has(r"^voiceover running true"), "status notifications"
    first = app.wait_view(r'id=body text=Dynamic Type body ax="Dynamic Type body"')   # dump shows ax descriptions
    assert swiftui_body_height(first) == 21, f"SwiftUI text at the default size: {swiftui_body_height(first)}"
    assert app.has(r"^swiftui env reduceMotion false dynamicType large bold false"), "SwiftUI environment defaults"
    app.wait_tap_id("bigger")
    app.wait_log(r"^changed to UICTContentSizeCategoryAccessibilityXL: category UICTContentSizeCategoryAccessibilityXL "
                 r"accessibility 1 body 40 pt scaled10 23\.5")                 # Dynamic Type change: UIKit font + metrics
    app.wait_until(lambda: (swiftui_body_height(app.view_dump()) or 0) >= 45, what="Dynamic Type change: SwiftUI text grows")
    assert app.quit() == 0


def test_settings_from_preferences(launch, device_data):
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True)
    prefs.write_bytes(plistlib.dumps({"ISIMContentSizeCategory": "UICTContentSizeCategoryXXXL", "ISIMBoldText": True,
                                      "ISIMReduceMotion": True, "ISIMIncreaseContrast": True,
                                      "ISIMReduceTransparency": True, "ISIMVoiceOver": True}))
    app = launch("HelloAccessibility")
    app.wait_log(r"^launch: category UICTContentSizeCategoryXXXL accessibility 0 body 23 pt scaled10 13\.5 bold 1 "
                 r"reduceMotion 1 contrast 1 transparency 1")             # size, bold, motion, contrast, transparency
    app.wait_log(r"^swiftui env reduceMotion true dynamicType xxxLarge bold true")   # SwiftUI environment follows
    app.wait_log(r"isim: VoiceOver on")
    app.wait_log(r'VoiceOver: "Settings, Heading"')                      # VoiceOver on from Settings at launch
    assert app.quit() == 0
