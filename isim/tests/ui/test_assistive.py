"""Assistive technologies (HelloAssistive, UIKit): the VoiceOver rotor (a custom rotor from the view controller's view,
Headings, Actions, Adjust Value) with swipe up/down; Switch Control (item scanning highlight, select, auto scanning,
the status notification); Voice Control (tap by label and by accessibilityUserInputLabels, show numbers + tap N,
scroll down); the Large Content Viewer at an accessibility text size; feedback generators shown as rings."""
import re

import pytest
from isimtest import rgb


@pytest.mark.os_matrix
def test_voiceover_rotor(launch, ios):
    app = launch("HelloAssistive")
    app.wait_view(r"id=apple")
    app.send("voiceover on")
    app.wait_log(r"VoiceOver: \"Fruits, Heading\"")
    app.send("voiceover rotor")                                         # the custom rotor comes first
    app.wait_log(r"VoiceOver rotor: Favorites")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver: \"Banana, Button\"")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver: \"Carrot, Button\"")
    app.send("voiceover down")
    app.wait_log(r"rotor Favorites: no more items")
    app.send("voiceover up")
    app.wait_log(r"VoiceOver: \"Banana, Button\"", count=2)
    app.send("voiceover rotor")                                         # Headings
    app.wait_log(r"VoiceOver rotor: Headings")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver: \"Vegetables, Heading\"")
    app.send("voiceover next").send("voiceover next")                   # Carrot, then Mail (custom actions)
    app.wait_log(r"VoiceOver: \"Mail, Button")
    app.send("voiceover rotor")                                         # Headings -> Actions (Mail has actions)
    app.wait_log(r"VoiceOver rotor: Actions")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver: \"Flag\"")
    app.send("voiceover activate")
    app.wait_log(r"^action Flag")
    app.send("voiceover next").send("voiceover next")                   # Send, then the slider
    app.wait_log(r"VoiceOver: \"Volume")
    for _ in range(3):
        app.send("voiceover rotor")
        if app.has(r"VoiceOver rotor: Adjust Value"):
            break
    app.wait_log(r"VoiceOver rotor: Adjust Value")
    app.send("voiceover up")                                            # up increments, like iOS
    app.wait_log(r"^volume 0\.6")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_switch_and_voice_control(launch, ios):
    app = launch("HelloAssistive")
    app.wait_view(r"id=apple")
    app.send("switchcontrol on")
    app.wait_log(r"switch control running true")
    app.wait_log(r"Switch Control: Fruits")
    app.send("switchcontrol next")
    app.wait_log(r"Switch Control: Apple")
    app.wait_view(r"id=isim-switch-control")
    app.wait_still()
    shot = app.screenshot("switch-control")
    apple = app.wait_for(id="apple")
    blue = lambda c: c[2] > 200 and c[0] < 60 and c[1] < 160
    assert any(blue(rgb(shot, apple.x + apple.w / 2, apple.y + dy)) for dy in range(-10, 4)), "the scanning highlight around the item"
    app.send("switchcontrol select")
    app.wait_log(r"^tapped Apple")
    app.send("switchcontrol auto0.3")                                   # auto scanning moves on by itself
    app.wait_log(r"Switch Control: Banana")
    app.send("switchcontrol stop").send("switchcontrol off")
    app.wait_log(r"switch control running false")

    app.send("voicecontrol tap Carrot")                                 # Voice Control
    app.wait_log(r"^tapped Carrot")
    app.send("voicecontrol tap submit")                                  # accessibilityUserInputLabels
    app.wait_log(r"^tapped Send")
    app.send("voicecontrol show numbers")
    app.wait_view(r"id=isim-voice-control")
    app.wait_still()
    app.screenshot("voice-numbers")
    app.send("voicecontrol tap 2")                                       # Apple, Banana, … numbered in order
    app.wait_log(r"^tapped Banana")
    app.send("voicecontrol hide numbers")
    app.send("voicecontrol scroll down")
    app.wait_log(r"Voice Control scrolled down")
    app.wait_view(r"id=far")
    app.wait_still()                                                    # the scroll has settled
    app.send("voicecontrol tap Far")
    app.wait_log(r"^tapped Far")
    app.send("voicecontrol tap Nothing")
    app.wait_log(r"no item named \"Nothing\"")
    assert app.quit() == 0


def test_large_content_and_haptics(launch):
    app = launch("HelloAssistive", env={"ISIM_CONTENT_SIZE": "UICTContentSizeCategoryAccessibilityL"})
    bar = app.wait_for(id="bar")
    app.send(f"longdrag {bar.x + 160:.0f} {bar.y + 30:.0f} {bar.x + 162:.0f} {bar.y + 30:.0f} 0.8 0.3")
    app.wait_log(r"large content viewer \"Star\"")
    app.wait_log(r"large content ended on Star")
    app.send("tapid impact")                                             # a heavy impact at (300, 120)
    m = app.wait_log(r"haptic impact \(heavy\) at (\d+),(\d+)")
    x, y = int(m.group(1)), int(m.group(2))
    ring = app.wait_shot(lambda s: any(rgb(s, x + 36 + d, y)[0] < 200 for d in range(-5, 3)), what="the impact ring (36 pt for a heavy impact)")
    assert ring
    app.send("tapid success")
    app.wait_log(r"haptic notification \(success\) at \d+,\d+")
    app.send("tapid select")
    app.wait_log(r"haptic selection at \d+,\d+")
    assert app.quit() == 0
