"""Age assurance and parental permission (issue #397, HelloAgeRange): DeclaredAgeRange's share sheet answering with
the range between the app's age gates (`isim agerange set`), declining, and no age set; PermissionKit's Ask sheet, the
question answered by the simulated parent (`isim permission`), the response in AskCenter.responses(for:) and the
approved handle becoming known; AskError.communicationLimitsNotEnabled for an adult; ATT's expanded prompt (iOS 27.2)
with its Learn More action."""
import os
import subprocess

from isimtest import ISIM, need_apps

APP = "HelloAgeRange"
BID = "dev.isim.samples.HelloAgeRange"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_agerange(launch, device_data):
    need_apps(APP)
    assert "age 14 (guardianDeclared, communicationLimits, regulated)" in \
        isim(device_data, "agerange", "set", "14", "--controls", "communicationLimits", "--regulated")
    app = launch(APP, os_version="26")
    app.wait_log(r"age features eligible true")
    # the share sheet: declined, then shared (14 falls between the gates 13 and 16)
    app.tap_id("age")
    app.wait_view("agerange-share")
    app.tap_id("agerange-decline")
    app.wait_log(r"age range: declined")
    app.tap_id("age")
    app.wait_view("agerange-share")
    app.tap_id("agerange-share")
    app.wait_log(r"age range: 13-15 declaration guardianDeclared controls \[communicationLimits\]")
    # a parent's permission: asked, approved by the simulated parent, delivered, then known
    app.tap_id("known")
    app.wait_log(r"known: false")
    app.tap_id("ask")
    app.wait_view("permission-ask")
    app.tap_id("permission-ask")
    app.wait_log(r"ask: sent ")
    assert "pending communication: communicate with sam@example.com" in isim(device_data, "permission", BID, "list")
    assert "approved" in isim(device_data, "permission", BID, "approve")
    app.wait_log(r"response: approval for sam@example\.com")
    app.tap_id("known")
    app.wait_log(r"known: true")
    assert app.quit() == 0


def test_agerange_adult_and_tracking(launch, device_data):
    """an adult (no Communication Limits) cannot ask; no age: notAvailable; the expanded tracking prompt"""
    need_apps(APP)
    isim(device_data, "agerange", "set", "30")
    app = launch(APP, os_version="27.2")
    app.wait_log(r"age features eligible false")
    app.tap_id("age")
    app.wait_view("agerange-share")
    app.tap_id("agerange-share")
    app.wait_log(r"age range: 18-nil declaration selfDeclared controls \[\]")
    app.tap_id("ask")
    app.wait_log(r"ask: error communicationLimitsNotEnabled")
    app.tap_id("track")
    app.wait_view("att-learn-more")
    app.tap_id("att-learn-more")
    app.wait_log(r"tracking: learn more")
    app.tap_id("att-allow")
    app.wait_log(r"tracking: status 3")
    assert app.quit() == 0
    isim(device_data, "agerange", "set", "none")
    app = launch(APP, os_version="26")
    app.tap_id("age")
    app.wait_log(r"age range: error notAvailable")
    assert app.quit() == 0
