"""Text interactions for a custom UITextInput and find and replace (HelloTextKit -find): UITextInteraction's tap and
double tap, the selection display's cursor, the loupe session and drop position animator; the find navigator (count,
next, replace all, Done) and Cmd+F in a text view."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_text_find(launch, ios):
    v = major(ios)
    app = launch("HelloTextKit", args=["-find"])
    app.wait_log(r"^tf ready$")
    assert "tf interaction mode true gestures 3 input true" in app.log
    if v >= 17:
        assert "tf loupe true" in app.log and "tf drop cursor x 60" in app.log

    # a tap places the cursor (12 pt characters), the selection display shows it
    app.wait_tap_id("canvas")
    app.wait_log(r"^tf interaction will begin$")
    app.wait_log(r"text interaction placed the cursor at 13")
    app.wait_log(r"^tf interaction did end$")
    app.wait_for(id="isim-text-cursor")

    # the find navigator: three results, the next one, replace all, Done
    app.wait_tap_id("find")
    app.wait_log(r"find navigator shown with replace")
    app.wait_log(r"find count 1 of 3")
    app.wait_tap_id("isim-find-next")
    app.wait_log(r"find count 2 of 3")
    app.wait_tap_id("isim-find-replace-field")
    app.send("type a")
    app.wait_tap_id("isim-find-replace-all")
    app.wait_log(r'find replaced all 3 "the" with "a"')
    app.wait_tap_id("isim-find-done")
    app.wait_log(r"find navigator dismissed")
    app.wait_tap_id("check")
    app.wait_log(r"^tf notes a cat and a dog and a bird session false visible false$")

    # Cmd+F in the text view
    app.wait_tap_id("notes")
    app.send("keydown cmd; keydown f; keyup f; keyup cmd")
    app.wait_log(r"find navigator shown$")
