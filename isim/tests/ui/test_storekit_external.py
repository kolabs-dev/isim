"""StoreKit external purchases (issue #396, HelloExternalPurchase): eligibility from the app's entitlements and
Info.plist regions against the storefront (USA), the disclosure sheet answered by tapping Continue or Cancel, the
external purchase token, the link out after the notice, and an ineligible custom link (its region is the Netherlands)."""
from isimtest import need_apps

APP = "HelloExternalPurchase"


def test_storekit_external(launch):
    need_apps(APP)
    app = launch(APP, os_version="18.4")                               # the custom link needs iOS 18.1
    app.wait_log(r"eligibility: canPresent true canOpen true urls plans,gift custom false")
    app.tap_id("purchase")
    app.wait_log(r"isim StoreKit: external purchase notice \(in app\)")
    app.wait_view("sk-external-continue")
    app.tap_id("sk-external-cancel")
    app.wait_log(r"external purchase: cancelled")
    app.tap_id("purchase")
    app.wait_view("sk-external-continue")
    app.tap_id("sk-external-continue")
    app.wait_log(r"external purchase: continued, token bundle dev\.isim\.samples\.HelloExternalPurchase type EXTERNAL_PURCHASE id 36")
    app.tap_id("custom")
    app.wait_log(r"custom link: error notEntitled")
    app.tap_id("link")                                                  # last: the link opens Safari over the app
    app.wait_view("sk-external-continue")
    app.tap_id("sk-external-continue")
    app.wait_log(r"isim StoreKit: external purchase link opens https://shop\.isim\.example/buy")
    app.wait_log(r"link: returned")
    assert app.quit() == 0


def test_storekit_external_scripted(launch):
    """ISIM_STOREKIT_EXTERNAL_NOTICE answers the notice without a sheet."""
    need_apps(APP)
    app = launch(APP, env={"ISIM_STOREKIT_EXTERNAL_NOTICE": "cancel"})
    app.wait_log(r"eligibility: ")
    app.tap_id("purchase")
    app.wait_log(r"answered cancel \(ISIM_STOREKIT_EXTERNAL_NOTICE\)")
    app.wait_log(r"external purchase: cancelled")
    assert app.quit() == 0
