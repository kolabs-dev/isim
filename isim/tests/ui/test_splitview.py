"""NavigationSplitView (HelloSplit). iPad: three columns side by side with their widths, selection in the sidebar and
content lists, columnVisibility (.detailOnly / the sidebar button / .all), the prominentDetail style (the sidebar floats
over the columns). iPhone: the columns as a navigation stack. Port of tests/ui/splitview.sh."""
from isimtest import screen_frames


def test_ipad_columns(launch):
    app = launch("HelloSplit", device="ipadpro11")
    f0 = screen_frames(app.wait_view(r"id=detail-text\b"))
    sb, ct, dt = f0.get("folder-Inbox"), f0.get("item-1"), f0.get("detail-text")
    assert sb and ct and dt and sb[0] < 240 and 240 <= ct[0] < 560 and dt[0] >= 560, \
        f"three columns side by side (sidebar 240 pt, content 320 pt): {sb} {ct} {dt}"
    app.wait_tap_id("folder-Archive")
    app.wait_tap_id("item-2")
    app.wait_view(r"text=Message 2 in Archive")                      # selecting in the content column shows the detail

    app.wait_tap_id("detail-only")
    app.wait_log(r"visibility detailOnly")
    app.wait_view(r"hidden id=isim-split-sidebar\b")                  # .detailOnly hides the sidebar ...
    tree = app.wait_view(r"hidden id=isim-split-content\b")           # ... and the content column
    assert "hidden id=isim-split-sidebar" in tree, ".detailOnly hides the sidebar and content columns"
    app.wait_tap_id("isim-split-toggle")
    app.wait_log(r"visibility all")                                  # columnVisibility follows the sidebar button
    app.wait_tap_id("prominent")

    def floating():
        f = screen_frames(app.view_dump())
        s, c = f.get("folder-Inbox"), f.get("item-1")
        return s and c and s[0] < 240 and c[0] < 240 and (s, c)
    app.wait_until(floating, what="prominentDetail: the sidebar floats over the content column")
    assert app.quit() == 0


def test_iphone_stack(launch):
    app = launch("HelloSplit")
    app.wait_tap_id("folder-Trash")
    app.wait_tap_id("item-3")
    app.wait_view(r"text=Message 3 in Trash")                        # the columns push like a stack
    assert app.quit() == 0
