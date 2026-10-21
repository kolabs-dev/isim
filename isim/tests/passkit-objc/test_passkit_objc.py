"""PassKit from Objective-C (PassKitObjCTest.app, issue #566): #import <PassKit/PassKit.h> over the PassKit Swift overlay
and isim's simulated Apple Pay sheet. A request with Apple's constants and summary items, the errors, results and
updates an app reports, PKPaymentButton and PKAddPassButton, Wallet (a refused pass, the library), and two payments:
PKPaymentAuthorizationController with an Objective-C delegate that changes the total for a shipping method, and
PKPaymentAuthorizationViewController with a delegate that implements only some methods."""
from isimtest import need_apps


def test_passkit_objc(launch):
    need_apps("PassKitObjCTest")
    app = launch("PassKitObjCTest")
    p = "PassKitObjC: "
    app.wait_log(p + r"request networks Visa,MasterCard capabilities 9 fields email,post shipping 1 methods PKShippingMethod 3-5 days pending 1 1\.5")
    app.wait_log(p + r"can pay 1 visa 1 jcb 0 credit 1 available Visa,MasterCard,AmEx,Discover")
    app.wait_log(p + r"error PKPaymentErrorDomain 1 email Enter an email / 1 postalCode")
    app.wait_log(p + r"result 1 errors 1 update 1 errors 1 items 2 methods 2")
    app.wait_log(p + r"pass refused domain PKPassKitErrorDomain code 1 library 1 passes \d+ secure 0 add 1")
    app.wait_log(p + r'buttons PKPaymentButton "Buy with Apple Pay" radius 8 / PKPaymentButton "Check out with Apple Pay" / PKAddPassButton style 1')

    # the controller: a debit card (the request asks for debit), a shipping method that changes the total, then the payment
    app.wait_tap_id("objc-pay")
    app.wait_log(p + r"controller delegate 1")
    app.wait_log(p + r"controller presented 1")
    app.wait_view(r"id=pk-total.*\$10\.00", what="the total $10.00")
    app.wait_tap_id("pk-method")
    app.wait_tap_id("pk-option-1")
    app.wait_log(p + r"controller shipping express total 15")
    app.wait_view(r"id=pk-total.*\$15\.00", what="the total $15.00")
    app.wait_tap_id("pk-pay")
    app.wait_log(p + r"controller will authorize")
    app.wait_log(p + r"controller authorized method=Mastercard 4444 network=MasterCard type=1 token=isim-test shipping=express "
                 r"email=jane\.appleseed@example\.com city=Cupertino")
    app.wait_log(p + r"controller finished")
    app.wait_log(p + r"controller dismissed")
    app.wait_view(r"id=pk-total", gone=True)

    # the view controller: an incomplete request is refused; the delegate hears the card change and authorizes
    app.wait_tap_id("objc-sheet")
    app.wait_log(p + r"view controller incomplete nil delegate 1")
    app.wait_log(p + r"view controller card Visa 4242")
    app.wait_tap_id("pk-card")
    app.wait_tap_id("pk-option-1")
    app.wait_log(p + r"view controller card Mastercard 4444")
    app.wait_tap_id("pk-pay")
    app.wait_log(p + r"view controller authorized Mastercard 4444")
    app.wait_log(p + r"view controller finished")
    app.wait_log(p + r"view controller dismissed")
    assert app.quit() == 0
