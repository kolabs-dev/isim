"""StoreKitTest from Objective-C (StoreKitTestObjCTest.app, issue #564): #import <StoreKitTest/StoreKitTest.h> over the
StoreKitTest Swift overlay and isim's local store, with HelloStoreTesting's Products.storekit in the app. A refused
configuration, a session's settings (storefront, locale, dialogs, time rate, failure error), a purchase outside the app,
the transaction list and a refund, SKTestErrorDomain errors (an unknown transaction, no subscription) and clearing."""
from isimtest import need_apps


def test_storekittest_objc(launch):
    need_apps("StoreKitTestObjCTest")
    app = launch("StoreKitTestObjCTest")
    p = "SKTestObjC: "
    app.wait_log(p + r"missing configuration refused domain SKTestErrorDomain")
    app.wait_log(p + r"session yes error none storefront USA locale en_US dialogs 1 rate 7 failure 4 transactions 0")
    app.wait_log(p + r"buy requested 1")
    app.wait_log(p + r"transaction dev\.isim\.store\.full_game state 1 refunded 0 ask 0 issue 0")
    app.wait_log(p + r"refund 1 refunded 1 revoked 1")
    app.wait_log(p + r"delete unknown 0 domain SKTestErrorDomain code 3")
    app.wait_log(p + r"renew without subscription 0 domain SKTestErrorDomain")
    app.wait_log(p + r"cleared 0")
    assert app.quit() == 0
