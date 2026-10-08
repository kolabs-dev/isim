"""HelloSafari: SFSafariViewController (redirect + initial load + Done), ASWebAuthenticationSession (consent alert ->
sign-in page from the local server -> tap Allow -> 302 to hellosafari://auth?code=... ends the session; ephemeral
session without the alert, cancelled; SwiftUI webAuthenticationSession), MessageUI (like the Simulator: no accounts;
ISIM_MAIL=1/ISIM_MESSAGES=1: composers, sent mail/message files, saved draft, cancel), universal links via the
`openurl` script command and a custom URL scheme. Local server only (samples/HelloWeb/server.py).
Port of tests/ui/safari.sh."""
import re

import pytest
from isimtest import ISIM, ROOT, count_px, local_server, near, rgb

pytestmark = pytest.mark.skipif(not (ISIM.parent / "isim-webkit").exists(),
                                reason="no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)")

BLUE = lambda c: c[2] > 0.75 * 255 and c[0] < 0.3 * 255 and c[1] < 0.65 * 255      # noqa: E731
ALLOW = (170, 301)                                                                  # the sign-in page's Allow button


def allow_shown(s):
    """The web sign-in page is up: its Allow button where the app's own (also blue) buttons were covered."""
    return near(rgb(s, *ALLOW), (0, 122, 255), 40) and not near(rgb(s, 200, 102), (0, 122, 255), 40)


def sign_in_page(app, requests, n):
    """Wait for the n-th sign-in page request to the local server, the sheet to settle, the page to render."""
    app.wait_until(lambda: requests.exists() and requests.read_text().count("GET /oauth/authorize") >= n,
                   what="the sign-in page is requested from the local server")
    app.wait_still()
    app.wait_shot(allow_shown, "the sign-in page from the local server", timeout=20)


def test_safari(launch, device_data):
    log_file = device_data / "server.log"
    with local_server(ROOT / "samples/HelloWeb/server.py", log_file) as port:
        server = ["-server", f"http://127.0.0.1:{port}"]
        app = launch("HelloSafari", args=server, env={"ISIM_MAIL": "1", "ISIM_MESSAGES": "1"})
        app.wait_tap_id("safari")
        app.wait_log(r"safari initial load success", timeout=20)
        safari = app.wait_view(lambda d: "id=safari-domain text=127.0.0.1" in d and "id=safari-done text=Done" in d,
                               what="SFSafariViewController shows the page with Safari chrome")
        shot = app.wait_shot(lambda s: count_px(s, (10, 70, 60, 30), BLUE) > 20 and
                             count_px(s, (0, 795, 402, 40), BLUE) > 20, "Safari chrome drawn")
        app.tap_id("safari-done")
        app.wait_log(r"safari done")
        app.wait_view(r"id=safari-done", gone=True)
        app.wait_still()
        app.tap_id("signin")
        consent = app.wait_view(r"text=Continue")
        app.screenshot("consent")
        app.tap_text("Continue")
        sign_in_page(app, log_file, 1)
        app.tap(*ALLOW)
        app.wait_log(r"auth callback ")
        app.wait_view(r"id=safari-done", gone=True)
        app.wait_still()
        app.tap_id("signin-eph")
        app.wait_log(r"auth start=true ephemeral=true")
        app.wait_view(r"id=safari-done")
        app.wait_still()
        app.tap_id("safari-done")
        app.wait_log(r"auth error code=")
        app.wait_view(r"id=safari-done", gone=True)
        app.wait_still()
        app.tap_id("signin-swiftui")
        sign_in_page(app, log_file, 3)
        app.tap(*ALLOW)
        app.wait_log(r"swiftui callback ")
        app.wait_view(r"id=safari-done", gone=True)
        app.wait_still()

        app.tap_id("mail")
        app.wait_view(r"id=mail-send")
        app.wait_still()
        app.screenshot("mail")
        app.tap_id("mail-send")
        app.wait_log(r"mail result=2")
        app.wait_view(r"id=mail-send", gone=True)
        app.wait_still()
        app.tap_id("message")
        app.wait_view(r"id=message-cancel")
        app.wait_still()
        app.screenshot("message")
        app.tap_id("message-cancel")
        app.wait_log(r"message result=0")
        app.wait_view(r"id=message-cancel", gone=True)
        app.wait_still()
        app.tap_id("message")
        app.wait_view(r"id=message-send")
        app.wait_still()
        app.tap_id("message-send")
        app.wait_log(r"message result=1")
        app.wait_view(r"id=message-send", gone=True)
        app.wait_still()
        app.tap_id("mail")
        app.wait_view(r"id=mail-cancel")
        app.wait_still()
        app.tap_id("mail-cancel")
        app.wait_view(r"text=Save Draft")
        app.tap_text("Save Draft")
        app.wait_log(r"mail result=1")
        app.send("openurl https://links.isim.example/items/42")
        app.wait_log(r"universal link links.isim.example")
        app.send("openurl hellosafari://open/x")
        app.wait_log(r"open url hellosafari://open/x")
        app.send("openurl https://www.apple.com/")
        app.wait_log(r"is not a universal link of this app")
        app.send("openurl https://a.shop.isim.example/cart")
        app.wait_log(r"universal link a.shop.isim.example")
        assert app.quit() == 0, "exits cleanly"
        log = app.log

        plain = launch("HelloSafari", args=server)                     # like the Simulator: no mail account, no texts
        plain.wait_tap_id("mail")
        plain.wait_log(r"mail unavailable")
        plain.tap_id("message")
        plain.wait_log(r"messages unavailable")
        plain.quit()
        log2 = plain.log
    requests = log_file.read_text()

    def has(p):
        return re.search(p, log, re.M)
    assert count_px(shot, (10, 70, 60, 30), BLUE) > 20 and count_px(shot, (0, 795, 402, 40), BLUE) > 20 and safari, \
        "SFSafariViewController shows the page with Safari chrome"
    assert has(r"^HelloSafari: safari redirected to /page3") and has(r"^HelloSafari: safari initial load success=true") \
        and has(r"^HelloSafari: safari done"), "delegate: initial redirect + successful load + finish"
    assert "text=“HelloSafari” Wants to Use “127.0.0.1” to Sign In" in consent and "text=Continue" in consent, \
        "ASWebAuthenticationSession consent alert"
    assert has(r"^HelloSafari: auth callback hellosafari://auth\?code=abc123&state=xyz code=abc123") and \
        "GET /oauth/approve" in requests, "sign-in page, Allow -> callback URL with code"
    assert has(r"^HelloSafari: auth start=true ephemeral=true") and has(r"^HelloSafari: auth error code=1 canceled=true"), \
        "ephemeral session: no alert, Cancel -> canceledLogin"
    assert has(r"^HelloSafari: swiftui callback hellosafari://swiftui\?code=abc123&state=s1"), \
        "SwiftUI webAuthenticationSession.authenticate"
    eml = device_data / "Library/Mail/Outbox/1.eml"
    assert has(r"^HelloSafari: mail result=2") and re.search(r"^Subject: Hello from isim", eml.read_text(), re.M) and \
        'filename="data.csv"' in eml.read_text(), "mail composer (ISIM_MAIL=1) prefilled, sent -> .eml"
    assert has(r"^HelloSafari: mail result=1") and (device_data / "Library/Mail/Drafts/1.eml").is_file(), \
        "mail cancel -> Save Draft -> .saved"
    assert has(r"^HelloSafari: message result=0") and has(r"^HelloSafari: message result=1") and \
        "On my way" in (device_data / "Library/SMS/Outbox/1.json").read_text(), "message composer: cancel, then send -> JSON"
    assert has(r"^HelloSafari: universal link links.isim.example path=/items/42") and \
        has(r"^HelloSafari: universal link a.shop.isim.example path=/cart"), "universal link -> continue userActivity"
    assert has(r"https://www.apple.com/ is not a universal link of this app: opened in Safari"), \
        "non-app https link goes to Safari"
    assert has(r"^HelloSafari: open url hellosafari://open/x"), "custom scheme -> application(_:open:options:)"
    assert re.search(r"^HelloSafari: canSendMail=false canSendText=false", log2, re.M) and \
        "HelloSafari: mail unavailable" in log2 and "HelloSafari: messages unavailable" in log2, \
        "like the Simulator: no mail account, no texts"
