"""SwiftUI's Image, Font and Text initialisers (HelloSwiftUIImageText, issue #209): decorative and labelled bundle
images (accessibility), a CGImage with a scale and an orientation, variable-value symbols (isim lights Adwaita's
signal levels), Font from a CTFont and a UIFont, Font.custom relative to a text style (Dynamic Type),
Font.width, Text from a LocalizedStringResource and from another strings table."""
import re

from isimtest import rgb, screen_frames


def report(app):
    app.wait_log(r"^hsit reported$")
    return {m[0]: m[1] for m in re.findall(r"^hsit (\S+) (.*)$", app.log, re.M)}


def test_swiftui_image_text(launch):
    app = launch("HelloSwiftUIImageText")
    r = report(app)
    assert "element=false" in r["decorative"] and "label=-" in r["decorative"], f"Image(decorative:): hidden: {r['decorative']}"
    assert "element=true label=Gold star trait=image" in r["labelled"], f"Image(_:bundle:label:): {r['labelled']}"
    assert "size=40x40" in r["labelled"], f"the bundle's star.svg (40 x 40): {r['labelled']}"
    assert "size=30x60" in r["cg"] and "label=Halves" in r["cg"], f"a 60 x 30 px CGImage turned right at scale 1: {r['cg']}"
    assert "size=30x15" in r["cg-decorative"] and "element=false" in r["cg-decorative"], f"scale 2: half size: {r['cg-decorative']}"
    assert "font=Georgia-Bold size=21.0" in r["ctfont"], f"Font(CTFont): its face and size: {r['ctfont']}"
    assert "size=19.0" in r["uifont"] and "Italic" in r["uifont"], f"Font(UIFont): {r['uifont']}"
    assert "font=AvenirNext-Regular size=20.0" in r["relative"], f"Font.custom(relativeTo:) at the default size: {r['relative']}"
    assert "text=From a LocalizedStringResource" in r["resource"], r["resource"]
    assert "text=Hello from the Menu table" in r["table"], f"Text(_:tableName:): the Menu table: {r['table']}"
    assert "text=Hello from Localizable" in r["default-table"], r["default-table"]
    assert re.search(r"^hsit Font\.Width\.condensed=-0\.2$", app.log, re.M), "Font.Width's value"
    app.screenshot("image-text")
    assert app.quit() == 0


def test_swiftui_variable_symbols_differ(launch):
    """wifi at 0, 0.5 and 1 draws three different signal levels (more lit pixels as the value grows)."""
    app = launch("HelloSwiftUIImageText")
    app.wait_log(r"^hsit reported$")
    f = screen_frames(app.view_dump())
    img = app.screenshot("wifi")

    def ink(key):
        x, y, w, h = (round(v) for v in f[key])
        return sum(1 for i in range(x, x + w) for j in range(y, y + h) if sum(rgb(img, i, j)) < 300)
    a, b, c = ink("wifi-0"), ink("wifi-half"), ink("wifi-1")
    assert a < b < c, f"variable value lights more of the symbol: {a} {b} {c}"
    assert app.quit() == 0


def test_font_relative_to_dynamic_type(launch):
    """Font.custom(_:size:relativeTo: .title) grows with Larger Text like the title style."""
    app = launch("HelloSwiftUIImageText", env={"ISIM_CONTENT_SIZE": "UICTContentSizeCategoryAccessibilityL"})
    r = report(app)
    size = float(re.search(r"size=([0-9.]+) text=Custom", r["relative"]).group(1))
    assert size > 20, f"scaled with Dynamic Type: {r['relative']}"
    assert app.quit() == 0
