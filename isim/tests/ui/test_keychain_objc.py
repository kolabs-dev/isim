"""The keychain from Objective-C and C (HelloKeychainObjC, issue #228): SecItemAdd / CopyMatching / Update / Delete on
generic passwords (data, attributes, arrays, duplicates, missing items, SecCopyErrorMessageString), and an item with
SecAccessControl (biometryCurrentSet): no user interaction refuses or skips it, its attributes need no authentication,
and reading its data asks for Face ID (a matching face opens it, cancelling refuses with errSecUserCanceled)."""


def test_keychain_objc(launch):
    app = launch("HelloKeychainObjC")
    app.wait_log(r"^kc ready$")
    log = app.log
    assert "kc add 0 duplicate -25299" in log, "errSecDuplicateItem"
    assert "kc read 0 hunter2" in log
    assert "kc all 0 alice,bob label=Alice's password created=1" in log
    assert "kc update 0 correct horse" in log
    assert 'kc delete 0 then -25300 "The specified item could not be found in the keychain."' in log
    assert "kc constants 1 1" in log, "the C constants have the Swift overlay's values"
    assert "kc protected add 0 typeid=1" in log
    assert "kc protected noui fail=-25308 skip=-25300 attributes=0" in log, \
        "kSecUseAuthenticationUIFail: errSecInteractionNotAllowed; Skip: not found; attributes without authentication"

    # reading the data asks for Face ID: permission first, then the scan
    app.wait_tap_id("open-vault")
    app.wait_view(r"text=Do you want to allow “HelloKeychainObjC” to use Face ID\?")
    app.tap_text("OK")
    app.wait_view(r"text=Matching Face")
    app.tap_text("Matching Face")
    app.wait_log(r"^kc vault 0 open sesame$")

    app.wait_tap_id("open-vault")                                       # each read asks again
    app.wait_view(r"text=Matching Face")
    app.tap_text("Cancel")
    app.wait_log(r"^kc vault -128 -$")                                 # errSecUserCanceled
