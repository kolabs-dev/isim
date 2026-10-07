#!/usr/bin/env bash
# UI test (isim boot, HelloShare + HelloPush): Share and Action extensions. The share sheet lists the app's own and the
# installed apps' extensions whose NSExtensionActivationRule accepts the items (none for an image), hosts the Share
# extension (SLComposeServiceViewController: the shared text, configuration item, Post -> completeRequest, attachments
# loaded through NSItemProvider) and the Action extension (returned items reach completionWithItemsHandler; Cancel ->
# cancelRequest).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloShare; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/share; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloShare.app out/apps/HelloPush.app >/dev/null
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 ISIM_NOTIFICATION_PERMISSION=allow timeout 120 out/bin/isim boot --headless --script "wait 1;
  launch dev.isim.samples.HelloPush; wait 2; tapid share; wait 1.2; dump; tapid share-close; wait 1;
  launch dev.isim.samples.HelloShare; wait 2; tapid shareText; wait 1.2; shot $shots/sheet.png; dump;
  tapid share-ext-dev.isim.samples.HelloShare.ShareNote; wait 1.5; shot $shots/compose.png; dump; tapid sl-post; wait 2; dump;
  tapid shareText; wait 1.2; tapid share-Uppercase; wait 1.5; shot $shots/action.png; dump; tapid done; wait 2; dump;
  tapid shareText; wait 1.2; tapid share-Uppercase; wait 1.5; tapid cancel; wait 2;
  tapid shareImage; wait 1.2; dump; tapid share-close; wait 1; quit" 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF -- "$1" <<<"$log"; }
check "another app's share sheet lists the installed app's extensions" 'grep -q "HelloPush.*share sheet lists 1 share and 1 action extension(s)" <<<"$log"'
check "share sheet: Share extension in the app row, Action in the list" 'grep -q "__IsimShareApp.*id=share-ext-dev.isim.samples.HelloShare.ShareNote" <<<"$log" && grep -q "id=share-Uppercase" <<<"$log"'
blue() { magick "$1" -crop 50x50+28+528 +repage -fuzz 20% -fill black +opaque '#2b9cfc' -fill white -opaque '#2b9cfc' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "the row shows the containing app's icon"                       '[ "$(blue "$shots/sheet.png")" -gt 300 ]'
check "Share extension hosted with the items as NSItemProviders"       'has "hosting share extension dev.isim.samples.HelloShare.ShareNote (“Notes” from Share) in the app process with 2 attachment(s)" && has "ShareNote: 1 input item(s), attachments public.plain-text,public.url"'
check "compose sheet: text, title, configuration item"                'grep -q "id=sl-text text=\"Shared note text\"" <<<"$log" && grep -q "id=sl-config-Folder" <<<"$log" && has "compose sheet “Notes”"'
check "Post loads the URL item and completes the request"             'has "ShareNote: posted “Shared note text” with https://example.com/article" && has "share finished type=dev.isim.samples.HelloShare.ShareNote completed=true"'
check "Action extension gets the text and returns items"             'has "Uppercase: got “Shared note text”" && has "share finished type=dev.isim.samples.HelloShare.Uppercase completed=true returned=[\"SHARED NOTE TEXT\"]" && grep -q "id=result text=SHARED NOTE TEXT" <<<"$log"'
check "cancelRequest reports not completed with the error"           'has "extension request cancelled (NSCocoaErrorDomain 3072)" && has "share finished type=dev.isim.samples.HelloShare.Uppercase completed=false returned=[] error=3072"'
check "an image is not accepted by the text/URL rules"               '[ "$(grep -c "share sheet lists" <<<"$log")" = 4 ] && ! grep -q "lists 0 share" <<<"$log"'
check "exits cleanly"                                                 '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- log"; grep -v "^ " <<<"$log" | tail -50; }
exit $fail
