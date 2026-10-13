"""Privacy and ad attribution with Apple's frameworks (HelloPrivacy): the app's privacy manifest checked by
`isim privacy-report` (and its ITMS-91053 / reason checks on a broken copy), its tracking domain blocked until App
Tracking Transparency allows tracking, AdServices' attribution token, SKAdNetwork and AdAttributionKit conversion
values (checked, shared, locking closes a conversion window), AdAttributionKit impressions (a click-through through a
UIEventAttributionView, a view-through of two seconds, a tap without the attribution view refused) and development
postbacks created, filled and transmitted with `isim adattribution`."""
import base64
import http.server
import json
import os
import plistlib
import re
import shutil
import subprocess
import threading

import pytest
from isimtest import APPS, ISIM, ROOT, local_server

APP = APPS / "HelloPrivacy.app"


def report(app, *args):
    return subprocess.run([str(ISIM), "privacy-report", str(app), *args], capture_output=True, text=True)


def test_privacy_report(tmp_path):
    r = report(APP)
    assert r.returncode == 0, r.stderr
    out = r.stdout
    assert "- Manifest: PrivacyInfo.xcprivacy" in out and "- Tracking: yes (domains: localhost)" in out, out
    assert "| AdvertisingData | no | yes | ThirdPartyAdvertising |" in out, out
    assert "| UserDefaults | CA92.1 |" in out and "Problems:" not in out, out
    j = json.loads(report(APP, "--json").stdout)
    assert j[0]["usedAPIs"] == ["UserDefaults"] and j[0]["trackingDomains"] == ["localhost"]

    broken = tmp_path / "Broken.app"                         # no UserDefaults reason, a bad reason, an unknown key
    shutil.copytree(APP, broken)
    with open(broken / "PrivacyInfo.xcprivacy", "rb") as f:
        m = plistlib.load(f)
    m["NSPrivacyAccessedAPITypes"] = [{"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryDiskSpace",
                                       "NSPrivacyAccessedAPITypeReasons": ["XXXX.1"]}]
    m["NSPrivacyFoo"] = True
    with open(broken / "PrivacyInfo.xcprivacy", "wb") as f:
        plistlib.dump(m, f)
    r = report(broken, "--strict")
    assert r.returncode == 1
    assert "ITMS-91053: Missing API declaration - Broken.app references UserDefaults APIs" in r.stdout, r.stdout
    assert "'XXXX.1' is not an approved reason for DiskSpace" in r.stdout and "unknown key NSPrivacyFoo" in r.stdout, r.stdout


def test_privacy_tracking_domain(launch, tmp_path):
    """the manifest's tracking domain (localhost) is blocked until tracking is allowed"""
    with local_server(ROOT / "samples/HelloWeb/server.py", tmp_path / "server.log") as port:
        app = launch("HelloPrivacy", args=["-tracker", f"http://localhost:{port}"])
        app.wait_log(r"HelloPrivacy: tracking=0 idfa=00000000-0000-0000-0000-000000000000")
        app.wait_tap_id("track")
        app.wait_log(r"isim: localhost is a tracking domain of this app's privacy manifest \(localhost\) and tracking is not authorized")
        app.wait_log(r"HelloPrivacy: tracker ping: status=0 error=-1003")
        assert "GET /" not in (tmp_path / "server.log").read_text(), "the blocked request never reached the server"
        app.tap_id("att")
        app.wait_view(r"text=Allow")
        app.tap_text("Allow")
        m = app.wait_log(r"HelloPrivacy: tracking authorization: 3 idfa=(\S+)")
        assert m.group(1) != "00000000-0000-0000-0000-000000000000"
        app.tap_id("track")
        app.wait_log(r"HelloPrivacy: tracker ping: status=\d+ error=none")
        assert app.quit() == 0


@pytest.fixture
def postback_server():
    got = []

    class H(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            got.append((self.path, json.loads(self.rfile.read(int(self.headers["Content-Length"])))))
            self.send_response(200)
            self.end_headers()

        def log_message(self, *a):
            pass
    s = http.server.HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    yield s.server_address[1], got
    s.shutdown()


def test_ad_attribution(launch, device_data, postback_server):
    port, got = postback_server
    env = {"ISIM_DATA": str(device_data)}
    adattr = lambda *a: subprocess.run([str(ISIM), "adattribution", *a], capture_output=True, text=True, env={**os.environ, **env})
    r = adattr("add", "dev.isim.samples.HelloPrivacy", f"http://127.0.0.1:{port}/postback", "--source-id", "5239")
    assert r.returncode == 0 and "development postback" in r.stdout, r.stderr

    app = launch("HelloPrivacy")
    app.wait_tap_id("token")
    app.wait_log(r"HelloPrivacy: attribution token failed: AAAttributionErrorDomain 3")       # no Apple Ads attribution
    app.tap_id("skan")
    app.wait_log(r"HelloPrivacy: SKAdNetwork update 12/medium: error=none")
    app.wait_log(r"HelloPrivacy: SKAdNetwork update 99: error=SKANErrorDomain 5")             # invalidConversionValue
    app.tap_id("postback")
    app.wait_log(r"HelloPrivacy: postback update 42/high ok")
    app.tap_id("impression")
    app.wait_log(r"HelloPrivacy: impression: network=example.adattributionkit advertised=1108187390 source=5239 kid=example.adattributionkit")
    app.wait_log(r"HelloPrivacy: bad impression: The attribution failed due to an invalid JWS header\.")
    app.tap_id("ad")                                                    # through the UIEventAttributionView
    app.wait_log(r"HelloPrivacy: click-through recorded")
    app.tap_id("viewAd")
    app.wait_log(r"HelloPrivacy: view-through recorded")
    app.wait_log(r"HelloPrivacy: tap without attribution view: The attribution failed due to a missing attribution view\.")
    app.tap_id("lock")
    app.wait_log(r"HelloPrivacy: postback locked at 50/high")
    app.tap_id("postback")                                              # the next conversion window
    app.wait_log(r"HelloPrivacy: postback update 42/high ok", count=2)
    assert app.quit() == 0

    state = json.loads((device_data / "Library/isim/AdAttribution/dev.isim.samples.HelloPrivacy.json").read_text())
    assert [i["type"] for i in state["impressions"]] == ["click", "view"]
    assert [(u["api"], u["fine"], u["window"]) for u in state["updates"]] == \
        [("SKAdNetwork", 12, 0), ("AdAttributionKit", 42, 0), ("AdAttributionKit", 50, 0), ("AdAttributionKit", 42, 1)]

    assert re.search(r"\[0: fine=50 coarse=high locked, 1: fine=42 coarse=high, 2: fine=None coarse=None\]", adattr("list").stdout)
    r = adattr("transmit")
    assert "2 postback(s) transmitted" in r.stdout, r.stdout + r.stderr
    assert [p for p, _ in got] == ["/postback", "/postback"]
    first, second = got[0][1], got[1][1]
    assert first["conversion-value"] == 50 and first["coarse-conversion-value"] == "high" and first["ad-interaction-type"] == "click"
    assert "conversion-value" not in second and second["coarse-conversion-value"] == "high", "fine values only in the first postback"

    payload = json.loads(base64.urlsafe_b64decode(first["jws-string"].split(".")[1] + "=="))
    assert payload["ad-network-identifier"] == "development.adattributionkit" and payload["source-identifier"] == "5239"
    assert payload["postback-sequence-index"] == 0 and payload["did-win"] is True
    assert "0 postback(s) transmitted" in adattr("transmit").stdout, "sent postbacks are not sent twice"
