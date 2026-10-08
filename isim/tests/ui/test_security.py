"""Security & system services (HelloSecurity): CryptoKit, keychain save/load/delete, SQLite3 notes, os.Logger
privacy, Face ID (permission alert, simulated scan, ISIM_BIOMETRY hook, Touch ID on iPhone SE), and a local
notification (permission alert, foreground banner via willPresent, tap -> didReceive; under `isim boot` the shell's
banner over the home screen). Relaunches check that keychain items, the database, and both permission answers
persist. Port of tests/ui/security.sh."""
import re


def test_security_app(launch):
    app = launch("HelloSecurity")
    app.wait_tap_id("runCrypto")
    app.wait_log(r"^crypto ")
    app.tap_id("save")
    app.wait_log(r"keychain save ")
    app.tap_id("load")
    app.wait_log(r"keychain load ")
    app.tap_id("addNote")
    app.wait_log(r"sqlite 1 notes")
    app.tap_id("addNote")
    app.wait_log(r"sqlite 2 notes")
    app.tap_id("unlock")
    app.wait_view(r"text=OK")
    app.screenshot("faceid-permission")
    app.tap_text("OK")
    app.wait_view(r"text=Matching Face")
    app.screenshot("faceid-scan")
    app.tap_text("Matching Face")
    app.wait_log(r"auth ")
    app.wait_tap_id("notify")
    app.wait_view(r"text=Allow")
    app.screenshot("notification-permission")
    app.tap_text("Allow")
    app.wait_log(r"willPresent backup")
    banner = app.wait_view(lambda d: "id=isim-notification-banner" in d and "text=Your notes were backed up." in d,
                           what="notification: willPresent + foreground banner")
    app.screenshot("banner")
    app.tap_id("isim-notification-banner")
    app.wait_log(r"opened backup action default")
    app.wait_view(r"text=Opened backup", what="notification: tapping the banner -> didReceive")
    first = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log + "\n" + first + "\n" + banner

    assert "crypto 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 hmac=true aes=secret message" in log, \
        "CryptoKit: SHA-256, HMAC, AES-GCM round trip"
    assert "keychain save 0" in log and "keychain load 0 token" in log, "keychain: SecItemAdd + SecItemCopyMatching"
    assert "sqlite 2 notes" in log and "text=2 notes: note 1, note 2" in log, "SQLite3: insert + query in the app container"
    assert "[dev.isim.samples.HelloSecurity:demo] crypto done, digest 2cf24dba" in log and \
        "saved a token <private>" in log and "saved a token tok-" not in log, \
        "os.Logger: public values shown, private redacted"
    assert "biometry faceID" in log and "Face ID matched" in log and "auth Unlocked" in log, \
        "Face ID: permission alert, then simulated scan"
    assert "notifications allowed for Security" in log and 'notify scheduled ["backup"]' in log, \
        "notifications: permission alert"
    assert re.search(r"calendar next 9:30 in ([0-9]|1[0-9]|2[0-3])h repeats true hour 9", log), \
        "UNCalendarNotificationTrigger next date (daily 9:30)"

    # relaunch: what persisted, and ISIM_BIOMETRY=nomatch
    app = launch("HelloSecurity", env={"ISIM_BIOMETRY": "nomatch"})
    app.wait_tap_id("load")
    app.wait_log(r"keychain load ")
    app.tap_id("unlock")
    app.wait_log(r"auth ")
    app.tap_id("notify")
    app.wait_log(r"notify scheduled")
    relaunched = app.wait_view(r"text=2 notes: note 1, note 2", what="SQLite data survives a relaunch")
    app.tap_id("delete")
    app.wait_log(r"keychain delete ")
    app.tap_id("load")
    app.wait_log(r"keychain load ", count=2)
    assert app.quit() == 0, "exits cleanly"
    log2 = app.log + "\n" + relaunched
    assert "keychain load 0 token" in log2 and "keychain delete 0" in log2 and \
        "keychain load -25300 not found" in log2, "keychain item survives a relaunch, then deletes"
    assert "Face ID did not match" in log2 and "auth Failed" in log2, \
        "ISIM_BIOMETRY=nomatch fails (permission remembered)"
    assert "notify scheduled" in log2 and "notifications allowed" not in log2, "notification permission remembered"

    # Touch ID on iPhone SE (same device data)
    app = launch("HelloSecurity", device="iphonese", env={"ISIM_BIOMETRY": "match"})
    app.wait_tap_id("unlock")
    app.wait_log(r"auth ")
    app.view_dump()
    app.quit()
    assert "biometry touchID" in app.log and "auth Unlocked" in app.log, "Touch ID on iPhone SE"


def test_security_boot(launch, tmp_path):
    """Under the device shell: the app goes home, the shell shows its banner over the home screen, tapping it reopens
    the app."""
    dev = launch(None, install=["HelloSecurity"], data=tmp_path / "boot",
                 env={"ISIM_NOTIFICATION_PERMISSION": "allow"})
    dev.send("launch dev.isim.samples.HelloSecurity")
    dev.wait_tap_id("notify")
    dev.wait_log(r"notify scheduled")
    dev.send("home")
    dev.wait_log(r"isim shell: notification banner from .*HelloSecurity.app: Security demo")
    dev.screenshot("banner-home")
    dev.tap_id("isim-notification-banner")                              # the shell's banner (not in view dumps)
    dev.wait_log(r"isim shell: opened notification backup")
    dev.wait_log(r"opened backup action default")
    dev.wait_view(r"text=Opened backup", what="tapping the shell banner reopens the app (didReceive)")
    assert dev.quit() == 0, "exits cleanly"
    assert re.search(r"delivered “backup” in the background", dev.log), \
        "background delivery: shell banner over the home screen"
