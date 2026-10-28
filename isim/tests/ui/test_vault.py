"""A password manager's extensions (issue #400, HelloVault): the credential provider is off until ASSettingsHelper's
"Turn On AutoFill?" alert turns it on; its ASCredentialIdentityStore identities then appear in the QuickType bar of
the app's sign-in form (a password filled without the provider's UI, a locked one after its unlock screen, a one-time
code), registering a passkey goes to the provider (its save screen) and the passkey chooser offers its passkey, whose
assertion verifies. The SSO extension answers for https://idp.isim.dev once `isim sso add` maps it (tokens without UI,
an Authorization header after its approval screen). The account modification extension changes a saved password to a
strong one and moves another account to Sign in with Apple (the Passwords store follows). On iOS 26, passkey account
creation with the Apple Account's email and name."""
import datetime
import os
import plistlib
import re
import subprocess

from isimtest import ISIM, APPS

APP = "HelloVault"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def passwords(data):
    p = data / "Library/Passwords/passwords.plist"
    return plistlib.load(open(p, "rb")) if p.exists() else []


def test_credential_provider(launch, device_data):
    app = launch(APP, data=device_data)
    app.wait_log(r"vault store enabled=false incremental=true")
    app.wait_tap_id("save")                                              # off: the store refuses
    app.wait_log(r"vault saved identities ok=false error=ASCredentialIdentityStoreErrorDomain 1")
    app.wait_tap_id("turn-on")
    app.wait_view(r"text=Turn On AutoFill\?")
    app.tap_text("Turn On")
    app.wait_log(r"vault autofill on=true")
    app.wait_tap_id("save")
    app.wait_log(r"vault saved identities ok=true error=none")
    app.wait_log(r'vault identities: 3 total, \["ana", "bo"\] passwords for vault\.isim\.dev')
    out = isim(device_data, "autofill", "providers")
    assert "Vault (dev.isim.samples.HelloVault.Provider): on" in out, out
    assert "password ana @ vault.isim.dev [ana]" in out, out

    # the QuickType bar offers the provider's passwords (highest rank first); ana fills without the provider's UI
    app.wait_tap_id("user")
    app.wait_for(id="isim-kb-autofill-0", label="ana")
    app.wait_still()
    app.screenshot("vault-quicktype")
    app.wait_tap_id("isim-kb-autofill-0")
    app.wait_log(r"vault provider: password for ana without UI")
    app.wait_log(r"AutoFill: filled 2 field\(s\) with the password of ana \(Vault\)")
    # bo is locked: the provider shows its UI
    app.wait_for(id="isim-kb-autofill-1", label="bo")
    app.wait_tap_id("isim-kb-autofill-1")
    app.wait_log(r"vault provider: bo is locked: needs the user")
    app.wait_view(r"id=vault-unlock")
    app.tap_id("vault-unlock")
    app.wait_log(r"AutoFill: filled 2 field\(s\) with the password of bo \(Vault\)")
    # one-time codes
    app.wait_tap_id("code")
    app.wait_for(id="isim-kb-autofill-0", label=r"ana \(Vault\)")
    app.wait_tap_id("isim-kb-autofill-0")
    app.wait_log(r"AutoFill: one-time code from Vault")
    app.wait_log(r"vault code = 424242")

    # a new passkey goes to the provider (its save screen); the chooser then offers it, and the assertion verifies
    app.wait_tap_id("register")
    app.wait_view(r"id=vault-save-passkey")
    app.tap_id("vault-save-passkey")
    app.wait_log(r"vault provider: passkey created for ana")
    app.wait_log(r"vault passkey registered id=16 bytes attestation=\d+ bytes")
    app.wait_tap_id("sign-in")
    app.wait_view(r"id=signin-choice-0")
    app.wait_view(r"text=Passkey · Vault")
    app.tap_id("signin-continue")
    app.wait_log(r"vault provider: passkey assertion for ana without UI")
    app.wait_log(r"vault passkey signed in user=user-ana verified=true clientData=webauthn\.get")
    assert app.quit() == 0

    # turned off (Settings > Passwords > Password Options, or the CLI): the store reports it
    isim(device_data, "autofill", "disable", str(APPS / f"{APP}.app"))
    app = launch(APP, data=device_data)
    app.wait_log(r"vault store enabled=false")
    assert app.quit() == 0


def test_sso(launch, device_data):
    app = launch(APP, data=device_data)
    app.wait_tap_id("sso")                                               # no profile maps the identity provider
    app.wait_log(r"vault sso canPerform=false")
    app.wait_log(r"vault authorization failed: 1003")
    assert app.quit() == 0
    isim(device_data, "sso", "add", "dev.isim.samples.HelloVault.SSO", "https://idp.isim.dev", "--realm", "VAULT.ISIM.DEV")
    assert "https://idp.isim.dev" in isim(device_data, "sso", "list")
    app = launch(APP, data=device_data)
    app.wait_tap_id("sso")
    app.wait_log(r"vault sso canPerform=true")
    app.wait_log(r"vault sso: begin idp\.isim\.dev caller=dev\.isim\.samples\.HelloVault realm=VAULT\.ISIM\.DEV ui=true")
    app.wait_log(r"vault sso signed in state=s1 status=200 token=at-123 id=it-456 authorization=-")
    app.wait_tap_id("sso-login")                                         # prompt=login: the extension's approval screen
    app.wait_view(r"id=sso-approve")
    app.tap_id("sso-approve")
    app.wait_log(r"vault sso signed in state=s1 status=200 token=- id=- authorization=Bearer sso-1")
    assert app.quit() == 0


def test_account_modification(launch, device_data):
    now = datetime.datetime(2026, 10, 1)
    p = device_data / "Library/Passwords/passwords.plist"
    p.parent.mkdir(parents=True, exist_ok=True)
    plistlib.dump([{"site": "vault.isim.dev", "user": "ana", "password": "weak1", "created": now},
                   {"site": "vault.isim.dev", "user": "bo", "password": "weak2", "created": now}], open(p, "wb"))
    app = launch(APP, data=device_data)
    app.wait_tap_id("strong")
    app.wait_log(r"vault upgrade: change ana on vault\.isim\.dev from weak1 \(strong: 20 chars\)")
    app.wait_log(r"vault modified \(strong password\) userInfo=1")
    ana = [e["password"] for e in passwords(device_data) if e["user"] == "ana"]
    assert len(ana) == 1 and re.fullmatch(r"[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}", ana[0]), ana
    app.wait_tap_id("siwa")                                              # the extension asks for Sign in with Apple
    app.wait_log(r"vault upgrade: convert bo to Sign in with Apple")
    app.wait_view(r"id=siwa-continue")
    app.tap_id("siwa-continue")
    app.wait_log(r"vault upgrade: authorized state=up-1 email=\S+")
    app.wait_log(r"vault modified \(Sign in with Apple\) userInfo=1")
    assert [e["user"] for e in passwords(device_data)] == ["ana"], "bo's password is gone"
    assert app.quit() == 0


def test_account_creation(launch, device_data):
    app = launch(APP, data=device_data, os_version="26.0")
    app.wait_tap_id("create")
    app.wait_view(r"id=create-continue")
    app.wait_view(r"id=create-contact text=taylor@example\.com")
    app.wait_still()
    app.screenshot("vault-create-account")
    app.tap_id("create-continue")
    app.wait_log(r"vault account created email taylor@example\.com name=Taylor Appleseed passkey=\d+ bytes")
    assert app.quit() == 0
    app = launch(APP, data=device_data, os_version="18.4")
    app.wait_tap_id("create")
    app.wait_log(r"vault account creation needs iOS 26")
    assert app.quit() == 0
