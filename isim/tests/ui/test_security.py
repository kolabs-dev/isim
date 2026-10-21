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


def test_local_authentication(launch):
    """LocalAuthentication beyond evaluatePolicy (issue #307), on HelloSecurity's LocalAuthentication section: three failed
    scans end an evaluation (authenticationFailed), five in a row lock biometry out (biometryLockout, LAEnvironment
    observers hear it) until the passcode is entered; the `biometry` script command (nomatch / match / enrolled);
    LADomainState; rights saved with a key and a secret (signing and the secret need the right authorized); a
    .biometryCurrentSet right refused after re-enrolling; evaluateAccessControl; LocalAuthenticationView."""
    app = launch("HelloSecurity")

    def scan(answer):
        """the scan alert is up: answer it (a `biometry` script command, or a tap on its button)"""
        app.wait_view(r"text=Matching Face")
        app.wait_still()
        if answer in ("match", "nomatch"):
            app.send(f"biometry {answer}")
        else:
            app.tap_text(answer)
        app.wait_view(r"text=Matching Face", gone=True)

    def retry():
        app.wait_view(r"text=Try Face ID Again")
        app.wait_still()
        app.tap_text("Try Face ID Again")

    # three failures end the evaluation
    app.wait_tap_id("la-biometrics")
    app.wait_log(r"^la environment biometry=Face ID enrolled=true locked=false passcode=true mechanisms=2$")
    app.wait_view(r"text=OK")                      # the Face ID permission alert
    app.tap_text("OK")
    scan("nomatch")
    retry()
    scan("Non-matching Face")
    retry()
    scan("nomatch")
    app.wait_log(r"^la biometrics ok=false code=-1$")
    # two more: biometry locks out
    app.wait_still()
    app.tap_id("la-biometrics")
    scan("nomatch")
    retry()
    scan("nomatch")
    app.wait_log(r"^la biometrics ok=false code=-8$")
    app.wait_log(r"biometry locked out after 5 failed attempts")
    app.wait_log(r"^la environment changed enrolled=true locked=true was=false$")
    app.wait_still()
    app.tap_id("la-biometrics")
    app.wait_log(r"^la biometrics unavailable code=-8$")
    # the passcode ends the lockout
    app.tap_id("la-passcode")
    app.wait_view(r"text=Enter Passcode")
    app.screenshot("passcode-after-lockout")
    app.wait_still()
    app.tap_text("Enter Passcode")
    app.wait_log(r"^la passcode ok=true biometrics=true$")
    app.wait_log(r"^la environment changed enrolled=true locked=false was=true$")

    # domain state, rights
    app.wait_still()
    app.tap_id("la-domain")
    first = app.wait_log(r"^la domain state biometry=faceID hash=(\S+) same=true companions=0$")
    app.tap_id("la-rights")
    app.wait_log(r"^la right saved state=0 loaded=true$")
    app.wait_log(r"^la right sign before authorize code=-1$")
    scan("match")
    app.wait_log(r"^la right authorized state=2 signed=true verified=true secret=s3cret public=65$")
    app.wait_log(r"^la right deauthorized state=3 secret refused$")
    app.wait_still()
    app.tap_id("la-current-set")
    app.wait_log(r"^la current set can authorize$")
    # enrolling again: a new domain state, and the .biometryCurrentSet right no longer authorizes
    app.send("biometry enrolled off")
    app.wait_log(r"^la environment changed enrolled=false locked=false was=false$")
    app.send("biometry enrolled on")
    app.wait_log(r"^la environment changed enrolled=true locked=false was=false$")
    app.tap_id("la-current-set")
    app.wait_log(r"^la current set refused code=-10$")
    app.tap_id("la-domain")
    app.wait_log(r"^la domain state biometry=faceID hash=", count=2)

    # access control and LocalAuthenticationView
    app.tap_id("la-access")
    scan("Matching Face")
    app.wait_log(r"^la access control ok=true code=0$")
    app.wait_still()
    app.tap_id("la-authentication-view")
    scan("match")
    app.wait_log(r"^la view authenticated$")
    app.send("biometry")
    app.wait_log(r"isim: biometry enrolled=1 failures=0 lockedout=0 enrollment=2")
    assert app.quit() == 0, "exits cleanly"
    hashes = re.findall(r"^la domain state biometry=faceID hash=(\S+)", app.log, re.M)
    assert len(hashes) == 2 and hashes[0] != hashes[1] and hashes[0] == first.group(1), "re-enrolling changes the domain state"

    # iOS 17: no LAEnvironment
    app = launch("HelloSecurity", device="iphone15", os_version="17.0")
    app.wait_tap_id("la-domain")
    app.wait_log(r"^la domain state hash=")
    app.tap_id("la-biometrics")
    app.wait_log(r"^la environment needs iOS 18$")
    app.quit()

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
    dev.wait_dump(r"IsimNotificationBanner .*id=isim-notification-banner notification=backup text=Security demo body=\S")
    dev.tap_id("isim-notification-banner")                              # the shell's banner
    dev.wait_log(r"isim shell: opened notification backup")
    dev.wait_log(r"opened backup action default")
    dev.wait_view(r"text=Opened backup", what="tapping the shell banner reopens the app (didReceive)")
    assert dev.quit() == 0, "exits cleanly"
    assert re.search(r"delivered “backup” in the background", dev.log), \
        "background delivery: shell banner over the home screen"
