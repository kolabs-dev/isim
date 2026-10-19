"""NSAttributedString's document formats (HelloHTMLImport, issue #238): HTML imported with
NSAttributedString(data:options:documentAttributes:) — the text (entities, collapsed whitespace, list markers, a table
as tabs, preformatted spaces, line breaks), the attributes at each word (Times New Roman 12 by default, headings, bold /
italic / underline / strikethrough, CSS colours and backgrounds from inline styles and <style> rules by class and id,
links, monospaced code, superscript, alignment, text lists, the font tag), the document attributes, an image next to
a file URL as an attachment; RTF (sniffed) and plain text through the same API; NSMutableAttributedString.read(from:);
a remote URL refused. List markers are in the text before iOS 18 (TextKit 1's format) and drawn by TextKit 2 from
the text lists since (os_matrix), in the text on every version with textKit1ListMarkerFormatDocumentOption."""
import re

import pytest

TIMES = "family=Times New Roman"


@pytest.mark.os_matrix
def test_html_import(launch, ios):
    v = int(str(ios[0] or "18").split(".")[0])
    app = launch("HelloHTMLImport")
    app.wait_log(r"^remote error=NSCocoaErrorDomain 262")             # only file URLs
    log = app.log
    text = re.search(r"^html string=(.*)$", log, re.M).group(1)
    assert text.startswith(r"Heading\nPlain, bold, italic, under, strike, red, link, mono, xsup and café & <tags>.\n"), text
    lists = r"\n\t•\tfirst\n\t•\tsecond\n\t1.\tnested\n" if v < 18 else r"\nfirst\nsecond\nnested\n"
    for part in (r"\nStyled by a class rule.\nBig by id\nCentered\n", lists,
                 r"\nName\tValue\n", r"\n  keep   spaces\n", r"\nline\nbreak font tag"):
        assert part in text, f"{part!r} in {text!r}"
    assert "Ignored" not in text, "the head's title is not text"
    assert re.search(r"^doc type=NSHTML encoding=4$", log, re.M)

    def probe(word):
        m = re.search(rf"^probe {word} (.*)$", log, re.M)
        assert m, f"probe {word}"
        return m.group(1)

    expect = {
        "Heading": [TIMES, "size=24", "bold=true"],
        "Plain": [TIMES, "size=12", "bold=false", "italic=false", "color=000000", "align=4"],
        "bold": [TIMES, "bold=true", "italic=false"],
        "italic": ["italic=true", "bold=false"],
        "under": ["underline=1", "strike=0"],
        "strike": ["strike=1", "underline=0"],
        "red": ["color=ff0000", "bg=ffff00"],
        "link": ["link=https://example.com/x", "color=0000ee", "underline=1"],
        "mono": ["family=Courier", "size=10"],
        "sup": ["baseline=4", "size=10"],
        "Styled": ["color=008000", "italic=true"],                    # a .class rule
        "Big": ["size=18"],                                            # an #id rule
        "Centered": ["align=1"],                                       # p.class rule
        "first": ["lists=1"],
        "nested": ["lists=2"],
        "font tag": ["color=0000ff", "size=18"],
        "strong": ["family=Helvetica", "size=14", "bold=true"],       # RTF
        "text": ["family=Helvetica", "size=12", "bold=false"],        # plain text's default
    }
    for word, parts in expect.items():
        got = probe(word)
        for p in parts:
            assert p in got.split(" ") or p in got, f"{word}: {p} in {got}"
    assert v < 18 or re.search(r"^tk1 string=\\t•\\tone\\n\\t1.\\ttwo\\n$", log, re.M), "TextKit 1 markers with the option"
    assert re.search(r"^url attachments=1$", log, re.M), "the image next to the file"
    assert re.search(r"^rtf string=RTF strong text type=NSRTF$", log, re.M)
    assert re.search(r"^mutable string=read into a mutable string\\n$", log, re.M)
    app.wait_view(r"id=html")
    assert app.quit() == 0, "exits cleanly"
