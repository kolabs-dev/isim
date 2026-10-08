"""UIKit presentation (HelloTransitions): full screen / over full screen / flip presentations and their appearance
callbacks, a sheet with custom + medium + large detents (grabber, animateChanges, drag between detents, swipe to
dismiss), a popover (delegate .none) and an adapted one, a custom transition with a custom UIPresentationController and
an interactive (cancelled, then finished) dismissal, UIPageViewController, a collapsed UISplitViewController, alert text
fields, the share sheet (Copy to UIPasteboard, custom UIActivity) and UIContentUnavailableConfiguration; on iPad
(regular width) sheets are centered cards, popovers stay popovers and the split view shows columns.
Port of tests/ui/transitions.sh."""
import re

import pytest

pytestmark = pytest.mark.os_matrix


def skip17(ios):
    if ios[0] == "17":
        pytest.skip("not part of the iOS 17 matrix")


def test_iphone(launch, ios, device_data):
    skip17(ios)
    app = launch("HelloTransitions")
    app.wait_log(r"^menu appeared")
    app.wait_tap("demo-full")
    app.wait_log(r"Full appeared, presenting true")
    app.wait_tap("close-Full")
    app.wait_log(r"dismissed Full")
    assert "menu will disappear" in app.between(r"^menu appeared", r"dismissed Full") and \
        "menu appeared" in app.between(r"Full disappeared", r"dismissed Full"), \
        "full screen: the presenter disappears and comes back"
    app.wait_tap("demo-dissolve")
    app.wait_log(r"Dissolve appeared")
    app.wait_tap("close-Dissolve")
    app.wait_log(r"dismissed Dissolve")
    assert "menu will disappear" not in app.between(r"dismissed Full", r"dismissed Dissolve"), \
        "over full screen + cross dissolve keeps the presenter"
    app.wait_tap("demo-flip")
    app.wait_log(r"Flip appeared, presenting true")
    app.wait_tap("close-Flip")
    app.wait_log(r"dismissed Flip")                                      # flip horizontal presents and dismisses

    app.wait_tap("demo-sheet")
    tree = app.wait_tree(r"UIView \(0 437; 402 x 437\) id=sheet-content")
    assert "__IsimGrabber (183 442; 36 x 5) id=isim-sheet-grabber" in tree, "sheet opens at the medium detent with a grabber"
    app.sleep(0.8)                                                       # the sheet has slid up (no event marks it)
    app.wait_tap("sheet-expand")
    app.wait_log(r"expanded to com\.apple\.UIKit\.large")
    app.wait_tree(r"UIView \(0 72; 402 x 802\) id=sheet-content")        # animateChanges selects the large detent
    app.sleep(0.5)
    app.drag(200, 80, 200, 440, 1.2)
    app.wait_log(r"sheet detent com\.apple\.UIKit\.medium")              # dragging moves between detents
    app.sleep(0.5)
    app.drag(200, 470, 200, 870, 0.2)
    app.wait_log(r"swiped away SheetContentViewController")              # swipe down dismisses the sheet

    app.wait_tap("demo-popover")
    app.wait_log(r"isim: popover shown, arrow up")
    app.wait_log(r"Pop appeared")
    app.wait_tree(r"__IsimPopoverView \([0-9.]+ 2[0-9][0-9]; 260 x 213\) id=isim-popover")   # anchored with an arrow
    app.tap(200, 800)
    app.wait_log(r"popover dismissed by tapping outside")
    app.wait_tap("demo-popsheet")
    app.wait_log(r"popover adapted to a sheet")
    app.wait_tap("close-Adapted")
    app.wait_log(r"dismissed Adapted")                                   # the popover adapts to a sheet on iPhone

    app.wait_tap("demo-custom")
    app.wait_log(r"custom presented, frame 437 437")
    app.wait_tree(r"id=custom-dimming\b")                                # custom presentation controller + animator
    app.sleep(0.3)
    app.drag(200, 500, 200, 560, 0.5)
    app.wait_log(r"custom dismissal cancelled")
    app.sleep(0.5)
    app.drag(200, 500, 200, 800, 0.6)
    app.wait_log(r"custom dismissal finished")
    app.wait_log(r"custom dismissed")                                    # interactive dismissal: cancel, then finish

    app.wait_tap("demo-pages")
    app.wait_view("pages-last")
    app.sleep(0.5)                                                       # the push has ended
    app.drag(300, 600, 60, 600, 0.4)
    app.wait_log(r"will turn to Page 2")
    app.wait_log(r"page turn completed true, now Page 2")                # UIPageViewController swipe
    app.wait_tap("pages-last")
    app.wait_log(r"jumped to Page 3")                                    # setViewControllers animated
    app.wait_tap("nav-back")

    app.wait_tap("demo-split")
    app.wait_log(r"split collapsed true, stack 1")
    app.wait_log(r"split view controller found true")                    # UISplitViewController collapses on iPhone
    app.wait_tap("item-2")
    app.wait_log(r"isim: split view shows detail Detail 2")
    app.wait_tree(r"id=label-Detail 2")                                  # showDetailViewController pushes the detail
    app.wait_tap("nav-back")
    app.wait_tap("split-done")
    app.wait_log(r"split closed")

    app.wait_tap("demo-alert")
    app.wait_tap("alert-OK")                                             # disabled until something is typed
    app.sleep(0.3)
    app.type("Kevin")
    app.sleep(0.3)
    app.tap_id("alert-OK")
    app.wait_log(r"hello Kevin")                                         # alert text field (OK enabled by typing)

    app.wait_tap("demo-share")
    app.wait_tap("share-Copy")
    app.wait_log(r'share finished: com\.apple\.UIKit\.activity\.CopyToPasteboard completed true, pasteboard '
                 r'\["Hello isim"\] https://example\.com/isim changeCount>0 true')   # Copy fills UIPasteboard
    assert "Hello isim" in (device_data / "pasteboard.txt").read_text(), "the pasteboard is shared through device data"
    app.wait_view("share-Copy", gone=True)
    app.wait_tap("demo-share")
    app.wait_tap("share-Shout")
    app.wait_log(r"SHOUT: HELLO ISIM")
    app.wait_log(r"share finished: dev\.isim\.shout completed true")     # custom UIActivity

    app.wait_view("share-Shout", gone=True)
    app.wait_tap("demo-unavailable")
    app.wait_log(r"inbox is empty")
    app.wait_tree(r"id=content-unavailable text=No Mail \| New messages appear here\.")   # content unavailable
    app.wait_tap("unavailable-Load")
    app.wait_log(r"isim: content unavailable: Loading")
    app.wait_log(r"inbox shows 2 items")
    app.wait_tree(r"id=inbox-label text=Welcome, Hello")                 # loading configuration, then content
    assert app.count(r"hello") == 1, "alert: one greeting"
    assert app.quit() == 0


def test_ipad(launch, ios):
    skip17(ios)
    app = launch("HelloTransitions", device="ipad")
    app.wait_tap("demo-sheet")
    app.wait_tree(r"UIView \(58 48; 704 x 1084\) id=sheet-content")      # the page sheet is a centered card
    app.sleep(0.4)
    app.drag(400, 70, 400, 700, 0.3)
    app.wait_log(r"swiped away SheetContentViewController")              # swipe down dismisses the card
    app.wait_tap("demo-popsheet")
    app.wait_log(r"isim: popover shown, arrow up")
    app.sleep(0.4)
    app.tap(700, 1100)
    app.wait_log(r"Adapted disappeared")                                 # the popover is not adapted
    app.wait_tap("demo-split")
    app.wait_log(r"split collapsed false, stack 1")
    app.wait_tap("item-3")
    app.wait_log(r"Detail 3 appeared")
    assert re.search(r"UINavigationController|id=label-Detail 3", app.log + app.tree()), \
        "split view shows columns side by side"
    assert "adapted to a sheet" not in app.log
    assert app.quit() == 0
