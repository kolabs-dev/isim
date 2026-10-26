"""Quick Look Preview extensions (HelloQuickLookExtensions, issue #333): QLPreviewController previews the app's own file
types with its two extensions, loaded into the app: RecipePreview (view-based, QLPreviewingController's
preparePreviewOfFile(at:completionHandler:)) shows a .recipe in its own view; PreviewProvider (a QLPreviewProvider)
answers with QLPreviewReply: a bitmap drawing for a .palette (bottom-left origin), HTML with a "cid:" image attachment
for a .memo, a PDFKit document for an .invoice; the reply's title names the item."""
from isimtest import rgb, screen_frames


def test_quicklook_view_based(launch):
    app = launch("HelloQuickLookExtensions", args=["-index", "0"])
    app.wait_log(r"^qlx types recipe true$")
    app.wait_log(r"preview extension dev\.isim\.samples\.HelloQuickLookExtensions\.RecipePreview \(view-based, .*PreviewViewController\) for Pancakes\.recipe")
    app.wait_log(r"^qlx recipe prepared Pancakes ingredients 4$")
    app.wait_log(r"preview extension dev\.isim\.samples\.HelloQuickLookExtensions\.RecipePreview prepared Pancakes\.recipe")
    app.wait_log(r"item 1 of 4: Pancakes\.recipe \(extension\)")
    tree = app.wait_view(r"id=recipe-ingredients")
    assert "Pancakes" in tree and "250 g flour" in tree, "the extension's view shows the recipe"
    f = screen_frames(tree)
    tx, ty, tw, th = f["recipe-title"]
    app.wait_still()
    img = app.screenshot("recipe")
    bg = rgb(img, tx + tw + 20, ty - 12)
    assert bg[0] > 245 and 235 < bg[1] < 252 and bg[2] < 240, f"the extension's cream background: {bg}"
    assert app.quit() == 0


def test_quicklook_data_based_drawing(launch):
    app = launch("HelloQuickLookExtensions", args=["-index", "1"])
    app.wait_log(r"preview extension dev\.isim\.samples\.HelloQuickLookExtensions\.PreviewProvider \(data-based, PreviewProvider\.PreviewProvider\) for Sunset\.palette")
    app.wait_log(r"^qlx provider palette colours 5$")
    app.wait_log(r"replied with drawing \(Sunset\.png\) title “Sunset palette”")
    app.wait_log(r"item 2 of 4: Sunset palette \(extension reply: image\)")
    tree = app.wait_view(r"id=ql-image")
    f = screen_frames(tree)
    x, y, w, h = f["ql-pager"]                     # the image page fills the pager (its frame is the second page's)
    app.wait_still()
    img = app.screenshot("palette")
    # the 300 x 200 pt drawing (at the screen's scale) fitted to the page's width, centred: swatches over a dark band
    # at the bottom (the bitmap context's origin)
    s = w / 300
    left, top = x, y + (h - 200 * s) / 2
    first = rgb(img, left + 30 * s, top + 60 * s)
    assert first[0] > 230 and 70 < first[1] < 120 and first[2] < 90, f"the first swatch (#FF5E3A): {first}"
    last = rgb(img, left + 270 * s, top + 60 * s)
    assert last[2] > 180 and last[0] < 120, f"the last swatch (#5856D6): {last}"
    band = rgb(img, left + 150 * s, top + 185 * s)
    assert max(band) < 110, f"the dark band drawn at y 0..40 sits at the bottom: {band}"
    assert "Sunset palette" in app.view_dump(), "the reply's title in the bar"
    assert app.quit() == 0


def test_quicklook_data_based_html_and_pdf(launch):
    app = launch("HelloQuickLookExtensions", args=["-index", "2"])
    app.wait_log(r"^qlx provider memo items 2 attachment true$")
    app.wait_log(r"replied with data \(Standup\.html\) title “Memo: Standup”")
    app.wait_log(r"item 3 of 4: Memo: Standup \(extension reply: (html|text)\)")
    assert app.quit() == 0

    app = launch("HelloQuickLookExtensions", args=["-index", "3"])
    app.wait_log(r"^qlx provider invoice lines 3$")
    app.wait_log(r"replied with pdf \(March\.pdf\) title “Invoice 42”")
    app.wait_log(r"item 4 of 4: Invoice 42 \(extension reply: pdf\)")
    tree = app.wait_view(r"id=ql-pdf-page-1")
    f = screen_frames(tree)
    x, y, w, h = f["ql-pdf-page-1"]
    x %= f["ql-pager"][2]                          # (frames ignore the pager's scrolling: the fourth page)
    app.wait_still()
    img = app.screenshot("invoice")
    head = rgb(img, x + w / 2, y + 10)
    assert head[2] > 150 and head[0] < 120, f"the invoice's indigo header, drawn by the extension: {head}"
    assert app.quit() == 0
