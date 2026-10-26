"""Quick Look Preview extension API from Objective-C (QuickLookObjCTest.app, issue #333): a QLPreviewProvider subclass
answers with QLPreviewReply's Objective-C initializers (UTType data with an attachment, a drawing, a file URL)."""
from isimtest import need_apps


def test_quicklook_objc(launch):
    need_apps("QuickLookObjCTest")
    app = launch("QuickLookObjCTest")
    p = "QuickLookObjC: "
    app.wait_log(p + r"provider handles requests 1")
    app.wait_log(p + r"reply title Note encoding utf8 1 attachment public\.png 1")
    app.wait_log(p + r"drawing 1 file 1 title ''")
    assert app.quit() == 0
