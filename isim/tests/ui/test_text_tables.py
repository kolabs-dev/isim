"""Text blocks and tables in attributed strings (HelloTextTables): NSTextTable / NSTextTableBlock cells (header row
background, collapsed 1 pt borders, padding, a cell spanning three columns, a 40% column, centred and middle-aligned
text) and an NSTextBlock quote, in a UILabel and drawn by NSAttributedString.draw(in:) with boundingRect; the block
model's accessors and NSParagraphStyle copies keep the blocks. The per-edge setters are iOS 27 (the quote's leading
border); before, the quote is framed on every edge."""
import pytest
from isimtest import rgb, screen_frames


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_text_tables(launch, ios):
    app = launch("HelloTextTables")
    app.wait_log(r"^htt cell row 0 column 0 columns 3 width 40% percentage true$")
    app.wait_log(r"^htt copy keeps blocks true$")
    m = app.wait_log(r"^htt bounding (\d+)x(\d+)$")
    w, h = int(m[1]), int(m[2])
    assert 180 < w < 300 and 150 < h < 190, f"boundingRect: the table's size, five rows of about 33 pt: {m[0]}"
    tree = app.wait_view(r"id=drawn-table")
    f = screen_frames(tree)
    lx, ly, lw, lh = f["table-label"]
    assert 220 < lh < 280, f"the label's height: the table and the quote: {f['table-label']}"
    assert abs(f["drawn-table"][3] - h) <= 1, "the drawn view is as tall as boundingRect"
    app.wait_still()
    img = app.screenshot("tables")
    gray, white, yellow = rgb(img, lx + 5, ly + 5), rgb(img, lx + 5, ly + 50), rgb(img, lx + 5, ly + h - 8)
    assert 215 <= gray[0] <= 240 and gray[2] >= 225, f"the header row's background (systemGray5): {gray}"
    assert min(white) >= 245, f"a data cell: no background: {white}"
    assert yellow[0] > 240 and yellow[2] < 225, f"the footer cell spanning the row: yellow: {yellow}"
    border = rgb(img, lx, ly + 50)
    assert max(border) < 235, f"the table's left border: {border}"
    inner = min(range(int(lx) + 60, int(lx) + w), key=lambda x: sum(rgb(img, x, ly + 50)))
    assert sum(rgb(img, inner, ly + 50)) < 3 * 235, "a column border inside the table"
    qy = ly + h + 30                                                     # inside the quote, below the table
    tint = rgb(img, lx + lw - 10, qy)
    assert tint[2] > tint[0] + 8, f"the quote's light blue background: {tint}"
    if major(ios) >= 27:
        edge = rgb(img, lx + 2, qy)
        assert edge[2] > 180 and edge[0] < 80, f"the quote's 4 pt leading border (per-edge, iOS 27): {edge}"
    dy = f["drawn-table"][1]                                             # NSAttributedString.draw(in:): the same table
    assert rgb(img, lx + 5, dy + 5) == gray, "the drawn table's header row"
    assert app.quit() == 0
