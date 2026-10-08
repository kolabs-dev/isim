"""Share and Action extensions under `isim boot` (HelloShare + HelloPush). The share sheet lists the app's own and the
installed apps' extensions whose NSExtensionActivationRule accepts the items (none for an image), hosts the Share
extension (SLComposeServiceViewController: the shared text, configuration item, Post -> completeRequest, attachments
loaded through NSItemProvider) and the Action extension (returned items reach completionWithItemsHandler; Cancel ->
cancelRequest). Port of tests/ui/share.sh."""
import re

from isimtest import count_px

SHARE = "dev.isim.samples.HelloShare"


def fuzzy(target, fuzz=0.2):
    """ImageMagick-style -fuzz match: RGB distance within `fuzz` of the full range."""
    lim = (fuzz * 255) ** 2 * 3
    return lambda c: sum((a - b) ** 2 for a, b in zip(c, target)) <= lim


def test_share(launch):
    dev = launch(None, install=["HelloShare", "HelloPush"], env={"ISIM_NOTIFICATION_PERMISSION": "allow"})
    dev.send("launch dev.isim.samples.HelloPush")
    dev.wait_tap_id("share")
    dev.wait_log(r"HelloPush.*share sheet lists ")
    dev.wait_tap_id("share-close")
    dev.wait_view(r"id=share-close", gone=True)

    dev.send(f"launch {SHARE}")
    dev.wait_tap_id("shareText")
    sheet = dev.wait_view(r"id=share-Uppercase")
    dev.wait_still()
    sheet_shot = dev.screenshot("sheet")
    dev.tap_id(f"share-ext-{SHARE}.ShareNote")
    compose = dev.wait_view(r"id=sl-config-Folder")
    dev.wait_still()
    dev.screenshot("compose")
    dev.tap_id("sl-post")
    dev.wait_log(rf"share finished type={re.escape(SHARE)}.ShareNote")
    dev.wait_view(r"id=sl-post", gone=True)
    dev.wait_still()

    dev.tap_id("shareText")
    dev.wait_tap_id("share-Uppercase")
    dev.wait_log(r"Uppercase: got ")
    action = dev.wait_view(r"id=done")
    dev.wait_still()
    dev.screenshot("action")
    dev.tap_id("done")
    dev.wait_log(rf"share finished type={re.escape(SHARE)}.Uppercase completed=true")
    result = dev.wait_view(r"id=result text=SHARED NOTE TEXT")
    dev.wait_still()

    dev.tap_id("shareText")
    dev.wait_tap_id("share-Uppercase")
    dev.wait_tap_id("cancel")
    dev.wait_log(r"completed=false")
    dev.wait_view(r"id=cancel", gone=True)
    dev.wait_still()
    dev.tap_id("shareImage")
    dev.wait_tap_id("share-close")
    dev.wait_view(r"id=share-close", gone=True)
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log

    def has(s):
        return s in log
    assert re.search(r"HelloPush.*share sheet lists 1 share and 1 action extension\(s\)", log), \
        "another app's share sheet lists the installed app's extensions"
    assert re.search(rf"__IsimShareApp.*id=share-ext-{re.escape(SHARE)}.ShareNote", sheet) and "id=share-Uppercase" in sheet, \
        "share sheet: Share extension in the app row, Action in the list"
    assert count_px(sheet_shot, (28, 528, 50, 50), fuzzy((0x2b, 0x9c, 0xfc))) > 300, "the row shows the containing app's icon"
    assert has(f"hosting share extension {SHARE}.ShareNote (“Notes” from Share) in the app process with 2 attachment(s)") \
        and has("ShareNote: 1 input item(s), attachments public.plain-text,public.url"), \
        "Share extension hosted with the items as NSItemProviders"
    assert 'id=sl-text text="Shared note text"' in compose and "id=sl-config-Folder" in compose and \
        has("compose sheet “Notes”"), "compose sheet: text, title, configuration item"
    assert has("ShareNote: posted “Shared note text” with https://example.com/article") and \
        has(f"share finished type={SHARE}.ShareNote completed=true"), "Post loads the URL item and completes the request"
    assert has("Uppercase: got “Shared note text”") and \
        has(f'share finished type={SHARE}.Uppercase completed=true returned=["SHARED NOTE TEXT"]') and result and action, \
        "Action extension gets the text and returns items"
    assert has("extension request cancelled (NSCocoaErrorDomain 3072)") and \
        has(f"share finished type={SHARE}.Uppercase completed=false returned=[] error=3072"), \
        "cancelRequest reports not completed with the error"
    assert len(re.findall(r"share sheet lists", log)) == 4 and "lists 0 share" not in log, \
        "an image is not accepted by the text/URL rules"
