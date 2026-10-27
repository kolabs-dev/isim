"""QuickLookThumbnailing (HelloQuickLookExtensions -thumbnails, issue #359): QLThumbnailGenerator's best
representation of five files: the app's RecipeThumbnail extension (a QLThumbnailProvider, loaded into the app) draws the
.recipe's; isim makes a PNG's (ImageIO), a PDF's (PDFKit, the first page) and a text file's; the .palette, which no
extension thumbnails, gets its icon. Also generateRepresentations' updates (icon, low quality, thumbnail), saving as a
JPEG, and a missing file's error."""
from isimtest import count_px, screen_frames


def test_quicklook_thumbnails(launch):
    app = launch("HelloQuickLookExtensions", args=["-thumbnails"])
    app.wait_log(r"^qlx thumbnail provider Pancakes 110x110 scale \d")
    app.wait_log(r"QuickLookThumbnailing: dev\.isim\.samples\.HelloQuickLookExtensions\.RecipeThumbnail \(RecipeThumbnail\.ThumbnailProvider\) made the thumbnail of Pancakes\.recipe")
    app.wait_log(r"^qlx thumbnail Pancakes\.recipe thumbnail 110x110 type dev\.isim\.samples\.recipe$")
    app.wait_log(r"^qlx thumbnail Photo\.png thumbnail 110x73 type public\.png$")
    app.wait_log(r"^qlx thumbnail Page\.pdf thumbnail 8[45]x110 type com\.adobe\.pdf$")
    app.wait_log(r"^qlx thumbnail Notes\.txt thumbnail 8[45]x110 type public\.plain-text$")
    app.wait_log(r"^qlx thumbnail Sunset\.palette icon 110x110 type dev\.isim\.samples\.palette$")
    app.wait_log(r"^qlx thumbnail updates 0,1,2$")
    app.wait_log(r"^qlx thumbnail saved true 64x43$")
    app.wait_log(r"^qlx thumbnail missing true true$")
    f = screen_frames(app.wait_view(r"id=thumb-Pancakes\.recipe"))
    shot = app.wait_shot(lambda s: count_px(s, f["thumb-Pancakes.recipe"], lambda c: c[0] > 230 and 120 < c[1] < 180 and c[2] < 60) > 3000,
                         "the extension's orange recipe card")
    assert count_px(shot, f["thumb-Photo.png"], lambda c: c[2] > 200 and c[0] < 80) > 2000, "the PNG's blue thumbnail"
    assert count_px(shot, f["thumb-Page.pdf"], lambda c: c[1] > 150 and c[0] < 120 and c[2] < 120) > 500, "the PDF's green band"
    assert count_px(shot, f["thumb-Sunset.palette"], lambda c: c[0] > 245 and c[1] > 245 and c[2] > 245) > 1500, "the palette's icon (a white page)"
    assert app.quit() == 0
