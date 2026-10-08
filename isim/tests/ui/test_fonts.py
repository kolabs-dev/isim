"""UIFont / UIFontDescriptor (HelloFonts): symbolic traits (bold, italic, monospaced), weights through the traits
attribute, system designs, monospaced digits (font and feature settings), text styles, sizes, secure coding. The app
measures and renders text to check them; the test checks its rows on screen."""
import re


def test_fonts(launch):
    app = launch("HelloFonts")
    app.wait_log(r"font checks: \d+/\d+ passed")
    dump = app.wait_view(r"id=row7")
    for i, text in enumerate(("System 20", "Bold (symbolic traits)", "Italic", "Bold Italic", "Heavy (traits weight)",
                              "Serif design", "Monospaced design", "Headline text style")):
        assert re.search(rf"id=row{i} .*text={re.escape(text)}|text={re.escape(text)}.*id=row{i}", dump), f"row {i}: {text}"
    app.screenshot("fonts")
    assert app.quit() == 0, "exits cleanly"
    fails = [l for l in app.log.splitlines() if l.startswith("FAIL")]
    assert not fails, "\n".join(fails)
    m = re.search(r"font checks: (\d+)/(\d+) passed", app.log)
    assert m and m.group(1) == m.group(2) and int(m.group(2)) >= 14, m and m.group(0)
