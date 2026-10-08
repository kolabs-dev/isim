"""SwiftUI text (HelloText): Text + Text, Markdown runs and link taps, live relative/timer text, date styles and
interpolation, formatter text, textCase, underline/strikethrough/kerning/baselineOffset, middle truncation, wrapping of
mixed-style text, imageScale, Text(_:format:) and Text(AttributedString). Port of tests/ui/text.sh."""
import re


def after(text, pattern, n):
    """Each line matching `pattern` with the n lines after it (grep -A n)."""
    lines, out = text.splitlines(), []
    for i, line in enumerate(lines):
        if re.search(pattern, line):
            out += lines[i:i + n + 1]
    return "\n".join(out)


def width(text, ident):
    m = re.search(rf"; ([0-9.]+) x [0-9.]+\).* id={ident}\b", text)
    return float(m.group(1)) if m else None


def timer(text):
    m = re.search(r"id=timer text=([0-9:]*)", text)
    return m and m.group(1)


def test_text(launch):
    app = launch("HelloText")
    first = app.wait_view(r"id=timer text=")
    assert "id=concat text=Hello, World!" in first and re.search(r"UILabel \([0-9.]+ 0; [0-9.]+ x 21\) text=World", first), \
        "Text + Text keeps per-part styles on one line"
    assert "id=markdown text=Bold, italic, code, gone and a link" in first and "id=verbatim text=**not markdown**" in first, \
        "Markdown literal: styled runs, verbatim untouched"
    assert "id=date text=January 2, 2026" in first and "id=interp text=Due January 2, 2026" in first, \
        "Text(date, style: .date) + interpolation"
    assert re.search(r"id=relative text=2 min, [0-9]+ sec", first), "Text(date, style: .relative)"
    assert re.search(r"id=timer text=(5:00|4:5[0-9])", first), f"Text(timerInterval:) starts at 5:00: {timer(first)}"
    assert "id=formatter text=1,234.50" in first, "Text(_:formatter:)"
    assert "id=upper text=SHOUTING" in first, "textCase(.uppercase)"
    assert re.search(r"UIView \(0 1[0-9.]*; 88 x 1\)", after(first, "id=underline", 2)) and \
        "UIView (" in after(first, "id=strike", 2), "underline / strikethrough lines"
    assert "UILabel (17 0; 12 x 21) text=P" in after(first, "id=kerned", 2), "kerning spaces the characters"
    assert "UILabel (0 -8; 7 x 15) text=2" in first, "baselineOffset raises the run"
    assert "text=The quick…lazy dog" in first, "truncationMode(.middle)"
    assert re.search(r"UILabel \(0 21; [0-9.]+ x 21\) text=sentence", after(first, "id=wrapped", 6)), \
        "mixed-style text wraps by words"
    s, m, l = (width(first, f"star-{k}") for k in ("small", "medium", "large"))
    assert s and m and l and s < m < l, f"imageScale small < medium < large: {s} {m} {l}"
    assert "id=format-number text=1,234.5" in first and "id=format-percent text=25%" in first and \
        re.search(r"id=format-interp text=Total .19.99", first), "Text(_:format:) and format interpolation"
    assert "id=attributed text=Plain, strong and a site red" in first, "Text(AttributedString)"

    app.wait_until(lambda: timer(app.view_dump()) not in (None, timer(first)), timeout=5,
                   what="Text(timerInterval:) counts down live")
    app.tap_text("link")
    app.wait_log(r"^open https://example\.com/docs")                 # Markdown link opens through openURL
    app.tap_text("site")
    app.wait_log(r"^open https://isim\.dev")
    app.wait_view(r"id=opened text=opened isim\.dev")                # AttributedString link
    assert app.quit() == 0
