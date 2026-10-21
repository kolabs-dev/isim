"""AuthenticationServices from Objective-C (HelloAuthObjC, issue #305): the classes under Apple's Objective-C names and
selectors. preferImmediatelyAvailableCredentials with nothing saved fails with notInteractive. An
ASAuthorizationAppleIDButton starts Sign in with Apple (the sheet, the credential with name and email, the credential
state); a passkey is registered, then asserted from the chooser sheet; ASWebAuthenticationSession shows the consent
alert and is cancelled, with a presentation provider that has Apple's selector and with one that has only the selector
apps built before isim 0.27 implement. Issue #306: the passkey's PRF and largeBlob extensions, conditional
registration (iOS 18; refused, nothing saved for the account) and a virtual security key."""
import pytest

APP = "dev.isim.samples.HelloAuthObjC"

pytestmark = pytest.mark.os_matrix          # the sheets and the alert are system UI


def test_auth_objc(launch, device_data, ios):
    app = launch("HelloAuthObjC")
    app.wait_log(r"^au button ASAuthorizationAppleIDButton radius=12$")
    app.wait_log(r"^au unknown user state=2 error=nil$")
    app.wait_log(r"^au callbacks scheme=1 other=0 https=1 wrongPath=0$")
    app.wait_log(r"^au authorization error=com\.apple\.AuthenticationServices\.AuthorizationError/1005 notInteractive=1 canceled=0$")

    # Sign in with Apple from the button
    app.wait_tap_id("objc-siwa")
    app.wait_log(r"^au apple id request scopes=full_name,email operation=implicit provider=1$")
    app.wait_log(r"^au anchor for controller requests=1$")
    app.wait_view(r"id=siwa-title")
    app.tap_id("siwa-continue")
    app.wait_log(r"^au apple id credential name=Taylor Appleseed email=taylor@example\.com state=objc-state scopes=full_name,email "
                 r"realUser=2 code=1 token=3 parts provider=1$")
    app.wait_log(r"^au apple id state=1 authorized=1 error=nil$")
    app.wait_view(r"id=siwa-title", gone=True)
    app.wait_still()

    # a passkey: registered, then asserted from the chooser (a password request alongside, nothing saved for it)
    app.tap_id("passkey-register")
    app.wait_log(r"^au registration rp=objc\.example\.com attestation=none verification=required$")
    app.wait_view(r"id=passkey-title")
    app.tap_id("passkey-continue")
    app.wait_log(r"^au passkey registered id=\d+ attestation=1 type=webauthn\.create attachment=0$")
    app.wait_log(r"^au passkey extensions prf=1 key=32 largeBlob=1$")
    assert (device_data / "Library/isim/AppleAccount/Passkeys/objc.example.com.json").is_file()
    app.wait_view(r"id=passkey-title", gone=True)
    app.wait_still()
    app.tap_id("passkey-signin")
    chooser = app.wait_view(r"id=signin-title")
    assert "text=Passkey for objc.example.com" in chooser
    app.tap_id("signin-continue")
    app.wait_log(r"^au passkey assertion user=user-7 authData=37 signature=1 type=webauthn\.get origin=https://objc\.example\.com$")
    app.wait_log(r"^au passkey assertion extensions prf=1 written=1$")
    app.wait_view(r"id=signin-title", gone=True)
    app.wait_still()

    # conditional registration (iOS 18): nothing saved for the account, refused without a sheet
    app.tap_id("passkey-conditional")
    if int(str(ios[0] or "18").split(".")[0]) >= 18:
        app.wait_log(r"^au conditional style=1$")
        app.wait_log(r"^au authorization error=com\.apple\.AuthenticationServices\.AuthorizationError/1004 notInteractive=0 canceled=0$")
    else:
        app.wait_log(r"^au conditional needs iOS 18$")

    # a virtual security key: the sheet, then the chooser
    app.tap_id("securitykey-register")
    app.wait_log(r"^au security key request algorithm=-7 resident=required prfCheck=1$")
    app.wait_view(r"id=securitykey-title")
    app.tap_id("securitykey-continue")
    app.wait_log(r"^au security key registered id=32 transports=usb attachment=1 prf=1$")
    assert (device_data / "Library/isim/SecurityKey/objc.example.com.json").is_file()
    app.wait_view(r"id=securitykey-title", gone=True)
    app.wait_still()
    app.tap_id("securitykey-signin")
    keys = app.wait_view(r"id=signin-title")
    assert "text=Security key · objc.example.com" in keys
    app.tap_id("signin-continue")
    app.wait_log(r"^au security key assertion user=user-7 same=1 appID=0 attachment=1 prf=32 differs=1$")
    app.wait_view(r"id=signin-title", gone=True)
    app.wait_still()

    # ASWebAuthenticationSession: the consent alert, cancelled (Apple's selector, then the old one)
    for button, label, anchor in (("web", "web", r"^au anchor for web session$"),
                                  ("web-legacy", "web legacy", r"^au legacy anchor for ASWebAuthenticationSession$")):
        app.tap_id(button)
        app.wait_log(anchor)
        app.wait_log(rf"^au {label} canStart=1 start=1 running=1$")
        app.wait_view(r"text=Cancel")
        app.tap_text("Cancel")
        app.wait_log(rf"^au {label} done url=\(null\) error=com\.apple\.AuthenticationServices\.WebAuthenticationSession/1 canceled=1$")
        app.wait_view(r"text=Cancel", gone=True)
        app.wait_still()
    assert app.quit() == 0, "exits cleanly"
