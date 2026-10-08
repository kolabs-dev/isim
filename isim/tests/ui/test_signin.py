"""isim's local AuthenticationServices + AdSupport (HelloSignIn). Run 1: quick sign-in without saved credentials,
a passkey sign-in with no passkey (canceled), Sign in with Apple from the SwiftUI button (sheet, Hide My Email,
unsigned identity token), credential state, passkey registration and sign-in (the app verifies the ECDSA signature
with CryptoKit), password sign-in from the keychain, IDFA zero until ATT "Allow". Run 2 (iOS 17 wording): the stored
user is authorized, `isim appleid <app> revoke` while the app runs posts credentialRevokedNotification, the state
becomes revoked, the UIKit button shows the first-time sheet again, cancel; the IDFA is stable per device.
Port of tests/ui/signin.sh."""
import os
import re
import subprocess

from isimtest import ISIM, rgb

APP = "dev.isim.samples.HelloSignIn"


def appleid(data, *args):
    p = subprocess.run([str(ISIM), "appleid", APP, *args], env=dict(os.environ, ISIM_DATA=str(data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.stdout


def test_signin(launch, device_data):
    app = launch("HelloSignIn")
    app.wait_log(r"launched; stored user")
    home = app.wait_shot(lambda s: rgb(s, 60, 237) == (0, 0, 0), "SwiftUI button: black, logo + label")
    app.wait_tap_id("quick-signin")
    app.wait_log(r"AuthorizationError 1005|authorization failed: .* 1005")
    app.tap_id("passkey-signin")
    app.wait_log(r"\(canceled\)")
    app.tap_id("swiftui-siwa")
    siwa = app.wait_view(r"id=siwa-title")
    siwa_shot = app.wait_shot(lambda s: (c := rgb(s, 60, 765))[0] < 30 and c[1] > 100 and c[2] > 230,
                              "sheet: blue Continue button")
    app.tap_id("siwa-hide-email")
    app.screenshot("siwa-hide")
    app.tap_id("siwa-continue")
    app.wait_log(r"identity token: ")
    app.wait_view(r"id=siwa-title", gone=True)
    app.wait_still()
    app.tap_id("state")
    app.wait_log(r"credential state: ")
    app.tap_id("passkey-register")
    passkey = app.wait_view(r"id=passkey-title")
    app.screenshot("passkey")
    app.tap_id("passkey-continue")
    app.wait_log(r"passkey registered: ")
    app.wait_view(r"id=passkey-title", gone=True)
    app.wait_still()
    app.tap_id("passkey-signin")
    chooser = app.wait_view(r"id=signin-title")
    app.screenshot("chooser")
    app.tap_id("signin-continue")
    app.wait_log(r"passkey assertion verified")
    app.wait_view(r"id=signin-title", gone=True)
    app.wait_still()
    app.tap_id("save-password")
    app.wait_log(r"password saved: ")
    app.tap_id("password-signin")
    app.wait_view(r"id=signin-continue")
    app.screenshot("password")
    app.tap_id("signin-continue")
    app.wait_log(r"password credential: ")
    app.wait_view(r"id=signin-continue", gone=True)
    app.wait_still()
    app.tap_id("idfa")
    app.wait_log(r"idfa: ")
    app.tap_id("att")
    app.wait_view(r"text=Allow")
    app.screenshot("att")
    app.tap_text("Allow")
    app.wait_log(r"tracking: ")
    assert app.quit() == 0, "exits cleanly"
    log1 = app.log + "\n" + "\n".join((siwa, passkey, chooser))

    def has(p):
        return re.search(p, log1, re.M)
    user = re.search(r"apple id credential: user=(\S+)", log1)
    user = user.group(1) if user else ""
    idfa = re.search(r"idfa: (\S+) zero=false", log1)
    idfa = idfa.group(1) if idfa else ""
    assert "AuthorizationError 1005" in log1 and "no saved credentials for these requests" in log1, \
        "no saved credentials: notInteractive, no sheet"
    assert "no passkey saved for login.example.com" in log1 and "AuthorizationError 1001 (canceled)" in log1, \
        "passkey sign-in without passkey: canceled"
    assert rgb(home, 60, 237) == (0, 0, 0) and "swiftui button: request scopes=full_name,email" in log1, \
        "SwiftUI button: black, logo + label"
    assert "id=siwa-title text=Create an account for Sign In using your Apple Account “taylor@example.com”." in siwa and \
        "id=as-simulation-note text=isim · local simulation, no Apple servers" in siwa and \
        "text=Hide My Email" in siwa and "text=Taylor Appleseed" in siwa, "Sign in with Apple sheet (iOS 18 wording)"
    assert siwa_shot, "sheet: blue Continue button"
    assert user and has(rf"apple id credential: user={re.escape(user)} name=Taylor Appleseed "
                        r"email=[0-9a-f]*@privaterelay.isim.invalid state=- realUser=true code=true"), \
        "credential: name + private relay email"
    assert has(rf"identity token: alg=none signature=none iss=isim-local-simulation sub=true aud={APP} "
               r"nonce=sample-nonce email=[0-9a-f]*@privaterelay"), "identity token: unsigned JWT (alg none)"
    assert "credential state: authorized" in log1, "credential state authorized"
    assert "id=passkey-title text=Save a passkey for “taylor”?" in passkey, "passkey sheet"
    assert "passkey registered: fmt=none rpIdHash=true flags=0x45 aaguidZero=true credentialID=true cose=true " \
        "clientData=true" in log1 and \
        (device_data / "Library/isim/AppleAccount/Passkeys/login.example.com.json").is_file(), \
        "passkey registration: attestation none, COSE"
    assert "id=signin-title text=Sign in to “login.example.com”?" in chooser and \
        "text=Passkey for login.example.com" in chooser, "passkey sign-in sheet lists the passkey"
    assert "passkey assertion verified: true tampered rejected: true clientData=true user=user-42" in log1, \
        "passkey assertion: ECDSA signature verifies"
    assert "password saved: true" in log1 and \
        "password credential: pat@example.com / ••••••••••••• matches=true" in log1, "password sign-in from the keychain"
    assert "idfa: 00000000-0000-0000-0000-000000000000 zero=true enabled=false" in log1 and \
        "tracking: authorized" in log1 and idfa, "IDFA zero until tracking is allowed"

    # run 2: revoke while the app runs (like Settings > Apple Account > Sign in with Apple > Stop Using)
    app = launch("HelloSignIn", device="iphone15", os_version="17.0")
    app.wait_tap_id("state")
    app.wait_log(r"credential state: ")
    revoke = appleid(device_data, "revoke")
    app.wait_log(r"credential revoked notification")
    app.tap_id("state")
    app.wait_log(r"credential state: ", count=2)
    app.tap_id("idfa")
    app.wait_log(r"idfa: ")
    app.tap_id("uikit-siwa")
    again = app.wait_view(r"id=siwa-title")
    app.screenshot("siwa-again")
    app.tap_id("siwa-cancel")
    app.wait_log(r"\(canceled\)")
    assert app.quit() == 0, "exits cleanly"
    log2 = app.log
    listed = appleid(device_data, "list")
    states = re.findall(r"^credential state: .*", log2, re.M)
    assert "launched; stored user: true" in log2 and states[0] == "credential state: authorized", \
        "relaunch: stored user still authorized"
    assert f"revoked Sign in with Apple for {APP}" in revoke and "credential revoked notification" in log2 and \
        "state revoked" in listed, "isim appleid revoke -> notification"
    assert states[-1] == "credential state: revoked", "state revoked after Stop Using"
    assert "id=siwa-title text=Create an account for Sign In using your Apple ID “taylor@example.com”." in again and \
        "AuthorizationError 1001 (canceled)" in log2, "sign-in again: first-time sheet (iOS 17 wording)"
    assert f"idfa: {idfa} zero=false enabled=true" in log2, "IDFA stable per device"
