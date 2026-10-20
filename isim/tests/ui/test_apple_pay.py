"""Apple Pay (HelloApplePay): isim's simulated payment sheet with the device's test cards. The coffee order
(PKPaymentButton, PKPaymentAuthorizationViewController) goes through the sheet's rows: the delegate hears the default
card and the redacted shipping address when it appears, then a shipping method, a coupon code and an address it
reports as unserviceable (Pay is disabled until another is chosen), and authorizes with isim's test token. The
donation (PKPaymentAuthorizationController) is declined once ("Payment Not Completed") and retried. SwiftUI's
PayWithApplePayButton cancels, then pays with the price its onApplePayPaymentMethodChange sets. With ISIM_APPLE_PAY=0
the device has no cards: canMakePayments() is false and the button shows its fallback."""
import os
import subprocess

import pytest

from isimtest import ISIM


def total(app, text):
    app.wait_view(r"id=pk-total.*" + text.replace("$", r"\$").replace(".", r"\."), what=f"the total {text}")


@pytest.mark.os_matrix
def test_apple_pay(launch, device_data):
    app = launch("HelloApplePay")
    app.wait_log(r"can pay: true visa\+mc\+amex true jcb false debit true")
    app.wait_log(r"networks: Visa,MasterCard,AmEx,Discover")
    app.wait_log(r"incomplete request: refused")
    app.wait_log(r"error: PKPaymentErrorDomain 1 email Enter an email")
    app.wait_view(r"text=canMakePayments yes")
    app.wait_still()
    app.screenshot("buttons")

    # the coffee order: the sheet appears with the default card and the redacted shipping address
    app.wait_tap_id("buy-coffee")
    app.wait_log(r"coffee: presented")
    app.wait_log(r"coffee: card Visa 4242 Visa")
    app.wait_log(r"coffee: ship to Cupertino 95014 street=redacted name=nil")
    total(app, "$12.00")
    app.wait_view(r"text=PAY ISIM COFFEE")
    app.wait_still()
    app.screenshot("sheet")

    # a shipping method, then a coupon code
    app.wait_tap_id("pk-method")
    app.wait_view(r"text=SHIPPING METHOD")
    app.wait_tap_id("pk-option-1")
    app.wait_log(r"coffee: shipping express")
    total(app, "$17.00")
    app.wait_tap_id("pk-coupon")
    app.type("ISIM10")
    app.wait_tap_id("pk-coupon-apply")
    app.wait_log(r"coffee: coupon ISIM10 errors=0")
    total(app, "$15.80")
    app.wait_view(r"text=Coupon ISIM10")

    # an address the delegate cannot serve: its error shows on the row and Pay is disabled
    app.wait_tap_id("pk-shipping")
    app.wait_tap_id("pk-option-1")
    app.wait_log(r"coffee: ship to New York 10001 street=redacted")
    app.wait_view(r"text=We don't deliver to New York yet")
    app.wait_until(lambda: not app.find(id="pk-pay").enabled, what="Pay disabled")
    app.wait_still()
    app.screenshot("unserviceable")
    app.wait_tap_id("pk-shipping")
    app.wait_tap_id("pk-option-0")
    app.wait_log(r"coffee: ship to Cupertino 95014", count=2)
    app.wait_view(r"text=We don't deliver", gone=True)
    app.wait_until(lambda: app.find(id="pk-pay").enabled, what="Pay enabled")

    # pay: the full contact after authorization, isim's test token
    app.wait_tap_id("pk-pay")
    app.wait_log(r"coffee: will authorize")
    app.wait_log(r"coffee: authorized method=Visa 4242 network=Visa type=2 token=isim-test amount=15\.8 id=64 shipping=express "
                 r"contact=Jane Appleseed / 1 Test Street, Cupertino / jane\.appleseed@example\.com")
    app.wait_log(r"isim PassKit: authorization result success")
    app.wait_log(r"isim PassKit: Wallet added order order\.dev\.isim\.samples\.coffee coffee-42")
    app.wait_log(r"coffee: finished paid=true")
    orders = subprocess.run([str(ISIM), "wallet", "orders"], env=dict(os.environ, ISIM_DATA=str(device_data)),
                            stdout=subprocess.PIPE, text=True, timeout=60).stdout
    assert "order.dev.isim.samples.coffee coffee-42  $15.80  merchant.dev.isim.samples.coffee  https://orders.example.com/" in orders, orders
    app.wait_view(r"text=coffee paid")

    # the donation: declined once, then retried on the same sheet
    app.wait_tap_id("decline-next")
    app.wait_log(r"donation: decline next")
    app.wait_tap_id("donate")
    app.wait_log(r"donation: presented true")
    total(app, "$5.00")
    app.wait_tap_id("pk-pay")
    app.wait_log(r"donation: authorized method=Visa 4242 .* decline=true")
    app.wait_view(r"text=Payment Not Completed")
    app.wait_view(r"text=Try Again")
    app.wait_still()
    app.screenshot("not-completed")
    app.wait_tap_id("pk-pay")
    app.wait_log(r"donation: authorized .* decline=false")
    app.wait_log(r"donation: finished")
    app.wait_log(r"donation: dismissed")
    app.wait_view(r"text=donated")

    # SwiftUI: canceled once (after choosing the debit card), then paid
    app.wait_view(r"id=pk-total", gone=True)
    app.wait_tap_id("tip")
    app.wait_log(r"tip: card Visa 4242")
    total(app, "$2.10")
    app.wait_tap_id("pk-card")
    app.wait_view(r"text=CARDS")
    app.wait_tap_id("pk-option-1")
    app.wait_log(r"tip: card Mastercard 4444")
    total(app, "$2.00")
    app.wait_tap_id("pk-cancel")
    app.wait_log(r"tip: finished")
    assert "tip: authorized" not in app.log
    app.wait_view(r"id=pk-total", gone=True)
    app.wait_tap_id("tip")
    app.wait_log(r"tip: card Visa 4242", count=2)
    total(app, "$2.10")
    app.wait_tap_id("pk-pay")
    app.wait_log(r"tip: will authorize")
    app.wait_log(r"tip: authorized method=Visa 4242 network=Visa type=2 token=isim-test amount=2\.1 ")
    app.wait_log(r"tip: finished", count=2)
    app.wait_view(r"text=tipped")
    assert app.quit() == 0


def test_apple_pay_no_cards(launch):
    app = launch("HelloApplePay", env={"ISIM_APPLE_PAY": "0"})
    app.wait_log(r"can pay: false visa\+mc\+amex false jcb false debit false")
    app.wait_view(r"text=Apple Pay is not set up")
    app.wait_tap_id("buy-coffee")
    app.wait_log(r"coffee: cannot pay")
    app.wait_log(r"isim PassKit: PKPaymentAuthorizationViewController: no card in Wallet")
    app.wait_tap_id("donate")
    app.wait_log(r"donation: presented false")
    assert app.quit() == 0
