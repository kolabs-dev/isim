#!/usr/bin/env bash
# UI test: UIKit presentation (HelloTransitions sample) — full screen / over full screen / flip presentations and
# their appearance callbacks, a sheet with custom + medium + large detents (grabber, animateChanges, drag between
# detents, swipe to dismiss), a popover (delegate .none) and an adapted one, a custom transition with a custom
# UIPresentationController and an interactive (cancelled, then finished) dismissal, UIPageViewController,
# a collapsed UISplitViewController, alert text fields, the share sheet (Copy to UIPasteboard, custom UIActivity)
# and UIContentUnavailableConfiguration.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTransitions; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/transitions; rm -rf "$ISIM_DATA"
script="wait 1; tapid demo-full; wait 0.8; tapid close-Full; wait 0.8;
 tapid demo-dissolve; wait 0.15; shot $shots/dissolve.png; wait 0.6; tapid close-Dissolve; wait 0.6;
 tapid demo-flip; wait 0.15; shot $shots/flip.png; wait 0.8; tapid close-Flip; wait 0.8;
 tapid demo-sheet; wait 0.8; shot $shots/sheet-medium.png; dump; tapid sheet-expand; wait 0.8; shot $shots/sheet-large.png; dump;
 drag 200 80 200 440 1.2; wait 0.8; dump; drag 200 470 200 870 0.2; wait 1;
 tapid demo-popover; wait 0.6; shot $shots/popover.png; dump; tap 200 800; wait 0.6;
 tapid demo-popsheet; wait 0.8; tapid close-Adapted; wait 0.8;
 tapid demo-custom; wait 0.8; shot $shots/custom.png; dump; drag 200 500 200 560 0.5; wait 1; drag 200 500 200 800 0.6; wait 1;
 tapid demo-pages; wait 1; drag 300 600 60 600 0.4; wait 1; tapid pages-last; wait 1; shot $shots/pages.png; tapid nav-back; wait 0.8;
 tapid demo-split; wait 1; tapid item-2; wait 1; dump; tapid nav-back; wait 0.8; tapid split-done; wait 0.5;
 tapid demo-alert; wait 0.8; tapid alert-OK; wait 0.3; type Kevin; wait 0.3; shot $shots/alert.png; tapid alert-OK; wait 0.8;
 tapid demo-share; wait 0.8; shot $shots/share.png; tapid share-Copy; wait 1; tapid demo-share; wait 0.8; tapid share-Shout; wait 1;
 tapid demo-unavailable; wait 1; shot $shots/unavailable.png; dump; tapid unavailable-Load; wait 0.2; shot $shots/loading.png; wait 1; dump; quit"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 120 out/bin/isim run out/apps/HelloTransitions.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
between() { sed -n "/$1/,/$2/p" <<<"$log"; }
check "full screen: presenter disappears and comes back" 'between "^menu appeared" "dismissed Full" | grep -q "menu will disappear" && grep -q "Full appeared, presenting true" <<<"$log" && between "Full disappeared" "dismissed Full" | grep -q "menu appeared"'
check "over full screen + cross dissolve keeps the presenter" 'grep -q "Dissolve appeared" <<<"$log" && ! between "dismissed Full" "dismissed Dissolve" | grep -q "menu will disappear"'
check "flip horizontal presents and dismisses"          'grep -q "Flip appeared, presenting true" <<<"$log" && grep -q "dismissed Flip" <<<"$log"'
check "sheet opens at the medium detent with a grabber"   'grep -q "UIView (0 437; 402 x 437) id=sheet-content" <<<"$log" && grep -q "__IsimGrabber (183 442; 36 x 5) id=isim-sheet-grabber" <<<"$log"'
check "animateChanges selects the large detent"           'grep -q "expanded to com.apple.UIKit.large" <<<"$log" && grep -q "UIView (0 72; 402 x 802) id=sheet-content" <<<"$log"'
check "dragging moves between detents"                     'grep -q "sheet detent com.apple.UIKit.medium" <<<"$log"'
check "swipe down dismisses the sheet"                     'grep -q "swiped away SheetContentViewController" <<<"$log"'
check "popover (delegate .none) anchored with an arrow"   'grep -q "isim: popover shown, arrow up" <<<"$log" && grep -q "Pop appeared" <<<"$log" && grep -Eq "__IsimPopoverView \([0-9.]+ 2[0-9][0-9]; 260 x 213\) id=isim-popover" <<<"$log"'
check "tap outside dismisses the popover"                 'grep -q "popover dismissed by tapping outside" <<<"$log"'
check "popover adapts to a sheet on iPhone"               'grep -q "popover adapted to a sheet" <<<"$log" && grep -q "dismissed Adapted" <<<"$log"'
check "custom presentation controller + animator"         'grep -q "custom presented, frame 437 437" <<<"$log" && grep -q "id=custom-dimming" <<<"$log"'
check "interactive dismissal: cancel, then finish"        'grep -q "custom dismissal cancelled" <<<"$log" && grep -q "custom dismissal finished" <<<"$log" && grep -q "custom dismissed" <<<"$log"'
check "UIPageViewController swipe"                        'grep -q "will turn to Page 2" <<<"$log" && grep -q "page turn completed true, now Page 2" <<<"$log"'
check "UIPageViewController setViewControllers animated"  'grep -q "jumped to Page 3" <<<"$log"'
check "UISplitViewController collapses on iPhone"         'grep -q "split collapsed true, stack 1" <<<"$log" && grep -q "split view controller found true" <<<"$log"'
check "showDetailViewController pushes the detail"        'grep -q "isim: split view shows detail Detail 2" <<<"$log" && grep -q "id=label-Detail 2" <<<"$log" && grep -q "split closed" <<<"$log"'
check "alert text field (OK enabled by typing)"           'grep -q "hello Kevin" <<<"$log" && [ "$(grep -c "hello" <<<"$log")" = 1 ]'
check "share sheet Copy fills UIPasteboard"              'grep -q "share finished: com.apple.UIKit.activity.CopyToPasteboard completed true, pasteboard \[\"Hello isim\"\] https://example.com/isim changeCount>0 true" <<<"$log"'
check "pasteboard is shared through device data"         'grep -q "Hello isim" "$ISIM_DATA/pasteboard.txt"'
check "custom UIActivity"                                 'grep -q "SHOUT: HELLO ISIM" <<<"$log" && grep -q "share finished: dev.isim.shout completed true" <<<"$log"'
check "content unavailable configuration"                'grep -q "inbox is empty" <<<"$log" && grep -q "id=content-unavailable text=No Mail | New messages appear here." <<<"$log"'
check "loading configuration, then content"              'grep -q "isim: content unavailable: Loading" <<<"$log" && grep -q "inbox shows 2 items" <<<"$log" && grep -q "id=inbox-label text=Welcome, Hello" <<<"$log"'
check "exits cleanly"                                     '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -50; }
exit $fail
