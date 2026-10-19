"""SwiftUI accessibility modifiers on isim's VoiceOver (HelloSwiftUI -accessibility): heading levels (View and Text),
custom content (high importance read with the element, the rest in the rotor's More Content), custom rotors (ForEach
ids, a namespace entry through a system rotor), accessibilityChildren and accessibilityRepresentation (synthetic
elements, not drawn), a linked group (its elements follow each other), @AccessibilityFocusState, and scroll, zoom and
direct touch actions."""
import re

from isimtest import screen_frames


def spoken(app):
    return re.findall(r'VoiceOver: "([^"]*)"', app.log)


def test_swiftui_accessibility(launch):
    app = launch("HelloSwiftUI", args=["-accessibility"])
    f = screen_frames(app.wait_view(r"id=pad"))

    def focus(ident, said):
        app.send(f"voiceover focus {ident}")
        app.wait_log(rf'VoiceOver: "{re.escape(said)}[".]')

    def rotor_to(name):
        for _ in range(8):
            n = app.log.count("VoiceOver rotor: ")
            app.send("voiceover rotor")
            app.wait_log(r"VoiceOver rotor: ", count=n + 1)
            if app.log.rsplit("VoiceOver rotor: ", 1)[1].split("\n")[0] == name:
                return
        raise AssertionError(f"no rotor {name}")

    app.send("voiceover on")
    app.wait_log(r'VoiceOver: "Fruits, Heading level 2"')                   # Text.accessibilityHeading
    app.send("voiceover next")
    app.wait_log(r'VoiceOver: "Details, Heading level 3"')

    focus("facts", "Apple facts, Color, Red")                                 # high importance with the element
    rotor_to("More Content")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver more content: Grown in, Kazakhstan")
    app.send("voiceover down")
    app.wait_log(r"VoiceOver more content: Calories, 52")

    focus("fruit-1", "Apple")                                                 # a rotor of ForEach ids
    rotor_to("Favorites")
    app.send("voiceover down")
    app.wait_log(r'VoiceOver: "Banana"')
    app.send("voiceover down")
    app.wait_log(r'VoiceOver: "Date"')
    app.send("voiceover down")
    app.wait_log(r"VoiceOver rotor Favorites: no more items")
    rotor_to("Headings")                                                      # the Headings system rotor, replaced
    app.send("voiceover down")
    app.wait_log(r'VoiceOver: "Origin"')

    els = None
    app.send("voiceover off")
    app.send("voiceover on")
    app.wait_log(r"VoiceOver on")
    for _ in range(20):
        app.send("voiceover next")
    app.wait_log(r"VoiceOver: \(end of list\)")
    order = spoken(app)
    order = order[len(order) - order[::-1].index("Fruits, Heading level 2") - 1:]
    assert "Week 1, 3 hours" in order and "Week 2, 5 hours" in order, f"accessibilityChildren: {order}"
    assert any(o.startswith("Volume, 50%, Adjustable") for o in order), f"accessibilityRepresentation: {order}"
    a, b, m = order.index("Linked A"), order.index("Linked B"), order.index("Between")
    assert b == a + 1 and m > b, f"a linked group's elements follow each other: {order}"

    focus("volume", "Volume, 50%, Adjustable")
    app.send("voiceover increment")
    app.wait_log(r"^ax volume 6$")

    focus("focus-note", "Focus note, Button")                               # @AccessibilityFocusState
    app.send("voiceover activate")
    app.wait_log(r"^ax note focused true$")
    app.wait_log(r'VoiceOver: "Note"')
    focus("feed", "Feed")
    app.wait_log(r"^ax note focused false$")
    app.send("voiceover scroll down")                                         # accessibilityScrollAction
    app.wait_log(r"^ax scroll top$")
    app.send("voiceover scroll up")
    app.wait_log(r"^ax scroll bottom$")
    focus("map", "Map")
    app.send("voiceover zoom in")                                             # accessibilityZoomAction
    app.wait_log(r"^ax zoom in 0\.5 0\.5$")

    x, y, w, h = f["pad"]                                                     # direct touch: the tap reaches the app
    said = app.log.count('VoiceOver: "Pad"')
    app.send(f"tap {x + w / 2} {y + h / 2}")
    app.wait_log(r"^ax pad tapped$")
    assert app.log.count('VoiceOver: "Pad"') == said, "silentOnTouch: VoiceOver does not speak the area"
    assert app.quit() == 0


def test_swiftui_accessibility_not_drawn(launch):
    app = launch("HelloSwiftUI", args=["-accessibility"])
    tree = app.wait_view(r"id=isim-accessibility-representation")
    f = screen_frames(tree)
    shot = app.screenshot()
    x, y, w, h = f["chart"]
    from isimtest import rgb
    c = rgb(shot, int(x + 20), int(y + h / 2))
    assert c[0] > 200 and c[2] < 80, f"the chart is drawn, its synthetic children are not: {c}"
    assert app.quit() == 0
