"""Audio graphs on isim's VoiceOver (issue #425; HelloSwiftUI -audiograph): a SwiftUI chart with
accessibilityChartDescriptor(_:) and a UIKit view conforming to AXChart get the rotor's Audio Graph (Describe Chart,
Play Audio Graph, Chart Details); AXLiveAudioGraph plays updated values."""
import re


def test_audio_graph(launch):
    app = launch("HelloSwiftUI", args=["-audiograph"])
    app.wait_log(r"^ax chart Rainfall in 2026 x=Month y=100\.0 first=Jan 78\.0$")    # the Swift API round-trips
    app.wait_view(r"id=rain")
    app.wait_still()
    app.screenshot("audio-graph")

    def rotor_to(name):
        for _ in range(8):
            n = app.log.count("VoiceOver rotor: ")
            app.send("voiceover rotor")
            app.wait_log(r"VoiceOver rotor: ", count=n + 1)
            if app.log.rsplit("VoiceOver rotor: ", 1)[1].split("\n")[0] == name:
                return
        raise AssertionError(f"no rotor {name}")

    app.send("voiceover on")
    app.send("voiceover focus rain")
    app.wait_log(r'VoiceOver: "Rainfall chart')
    rotor_to("Audio Graph")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver audio graph item: Describe Chart")
    app.send("voiceover activate")
    app.wait_log(r"VoiceOver describe chart: Rainfall in 2026\. Rainfall falls from January to June\. "
                 r"X axis: Month\. 6 categories, Jan to Jun\. Y axis: Rainfall\. From 0 millimeters to 100 millimeters\. 1 series")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver audio graph item: Play Audio Graph")
    app.send("voiceover activate")
    m = app.wait_log(r"VoiceOver audio graph: “Rainfall” 6 points discrete (\d+)–(\d+) Hz")
    assert int(m.group(1)) < int(m.group(2)), "higher values sound higher"
    app.send("voiceover down")
    app.wait_log(r"VoiceOver audio graph item: Chart Details")
    app.send("voiceover activate")
    app.wait_log(r"VoiceOver chart details: Rainfall: 6 points\. Minimum 12 millimeters at Jun\. "
                 r"Maximum 78 millimeters at Jan\. Mean 46 millimeters")

    app.send("voiceover focus temperatures")                     # UIKit: the view conforms to AXChart
    app.wait_log(r'VoiceOver: "Temperatures')
    rotor_to("Audio Graph")
    app.send("voiceover down")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver audio graph item: Play Audio Graph", count=2)
    app.send("voiceover activate")
    app.wait_log(r"VoiceOver audio graph: “Daily high” 7 points continuous 265–698 Hz")
    app.send("voiceover focus live")
    app.send("voiceover activate")
    app.wait_log(r"live audio graph value 0\.5 \(440 Hz\)")
    app.wait_log(r"^ax live done$")
    assert "live audio graph stopped" in app.log
    rotors = re.findall(r"VoiceOver rotor: (.*)", app.log)
    assert "Audio Graph" in rotors
    assert app.quit() == 0
