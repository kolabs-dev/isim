"""Writing NSAttributedString documents (HelloDocumentExport, issue #239): data(from:documentAttributes:) as RTF
(Cocoa's header, a HYPERLINK field, Unicode escapes, the paper size) read back with every attribute — fonts and
faces, colours and backgrounds, underline, links, baseline offset, alignment and indents; fileWrapper(from:) as an
RTFD package (TXT.rtf and the attachment's file) read back from its URL with the attachment; RTFD as data (the
FileWrapper's serialized form); HTML in Cocoa's writer's shape read back (fonts at 3/4 size, as Cocoa's round trip
does); plain text in UTF-16."""
import re


def test_document_export(launch):
    app = launch("HelloDocumentExport")
    app.wait_log(r"^plain bytes=")
    log = app.log

    def line(prefix):
        m = re.search(rf"^{re.escape(prefix)}(.*)$", log, re.M)
        assert m, prefix
        return m.group(1)

    def probe(tag, word, *parts):
        got = line(f"probe {tag} {word} ")
        for p in parts:
            assert p in got, f"{tag} {word}: {p} in {got}"

    text = r"Title\nPlain, italic, red, under, link, xup and café — 日本.\nIndented paragraph\n end"
    assert line("rtf head=") == r"{\rtf1\ansi\ansicpg1252\c link=true unicode=true"
    assert line("rtf string=") == f"{text} paper=595x842", "the attachment is dropped from RTF"
    probe("rtf", "Title", "family=Helvetica", "size=24", "bold=true", "align=1")
    probe("rtf", "Plain", "size=14", "bold=false", "italic=false")
    probe("rtf", "italic", "italic=true")
    probe("rtf", "red", "color=ff0000", "bg=ffff00")
    probe("rtf", "under", "underline=1")
    probe("rtf", "link", "link=https://example.com/doc")
    probe("rtf", "up", "baseline=4")
    probe("rtf", "Indented", "indent=36")

    assert line("rtfd files=") == "TXT.rtf,box.png"
    assert line("rtfd type=") == "NSRTFD attachments=1 file=box.png bounds=40x20 image=120x60"
    probe("rtfd", "red", "color=ff0000", "bg=ffff00")
    assert line("rtfd tail=") == r"\n[obj] end", "the attachment character, without the RTFD placeholder"
    assert line("rtfd data attachments=") == "1 same=true"
    assert line("serialized files=") == "TXT.rtf,box.png"

    assert line("html generator=") == "true link=true spans=true"
    assert line("html string=").startswith(r"Title\nPlain, italic, red, under, link, xup and café — 日本.\nIndented paragraph\n")
    probe("html", "Title", "family=Helvetica", "size=18", "bold=true", "align=1")
    probe("html", "italic", "italic=true", "size=11")
    probe("html", "red", "color=ff0000", "bg=ffff00")
    probe("html", "link", "link=https://example.com/doc", "underline=1")

    assert line("plain bytes=") == f"164 string={text}"
    app.wait_view(r"id=doc")
    assert app.quit() == 0, "exits cleanly"
