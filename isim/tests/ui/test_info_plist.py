"""The Info.plist keys iOS checks (HelloInfoPlist, issue #233), run as the sample and as copies with Info.plist
variants: LSApplicationQueriesSchemes (canOpenURL answers only for declared, system and the app's own schemes; openURL
is not limited), UIRequiresFullScreen (an iPad app opts out of multitasking before iPadOS 26), the usage descriptions
of Core Bluetooth, Core Motion and Core NFC (without them the access is denied; iOS would terminate the app), and
NSBonjourServices (browsing or advertising an undeclared type fails with NoAuth). UIRequiredDeviceCapabilities is
checked by `isim install` / `isim run` against the device's hardware."""
import os
import plistlib
import shutil
import subprocess

import pytest

from isimtest import APPS, ISIM


def variant(tmp_path, **changes):
    """a copy of HelloInfoPlist.app with Info.plist keys set (None removes one)"""
    app = tmp_path / "HelloInfoPlist.app"
    shutil.copytree(APPS / "HelloInfoPlist.app", app)
    p = app / "Info.plist"
    info = plistlib.loads(p.read_bytes())
    for k, v in changes.items():
        if v is None:
            info.pop(k, None)
        else:
            info[k] = v
    p.write_bytes(plistlib.dumps(info))
    return app


def test_queries_schemes_and_usage(launch):
    app = launch("HelloInfoPlist")
    app.wait_log(r"^ip can open helloinfoplist://self true$")
    log = app.log
    assert "ip can open fb://profile false" in log, "declared, but no app handles it"
    assert "ip can open twitter://user false" in log
    assert '-canOpenURL: failed for URL: "twitter://user" - error: "This app is not allowed to query for scheme twitter"' in log
    assert "not allowed to query for scheme fb" not in log, "a declared scheme may be queried"
    assert "ip can open https://example.com true" in log and "ip can open tel:5550100 true" in log
    # no usage descriptions: Bluetooth unauthorized, motion and NFC denied
    app.wait_log(r"^ip bluetooth state 3$")                              # CBManagerState.unauthorized
    assert "ip bluetooth authorization 2" in app.log                     # CBManagerAuthorization.denied
    app.wait_log(r"^ip pedometer status 2 error 105$")                   # denied, CMErrorMotionActivityNotAuthorized
    app.wait_log(r"^ip nfc invalidated 2$")                              # readerErrorSecurityViolation
    for key in ("NSBluetoothAlwaysUsageDescription", "NSMotionUsageDescription", "NFCReaderUsageDescription"):
        assert f"must contain an {key} key" in app.log, key
    # Bonjour: the declared type browses, the undeclared one fails to browse and to advertise
    app.wait_log(r"^ip browse _isim-declared\._tcp ready$")
    app.wait_log(r"^ip browse _isim-undeclared\._tcp failed .*-65555")
    app.wait_log(r"^ip advertise _isim-undeclared\._tcp failed .*-65555")


def test_usage_descriptions_declared(launch, tmp_path):
    app = launch(variant(tmp_path, NSBluetoothAlwaysUsageDescription="Finds accessories.", NSMotionUsageDescription="Counts steps.",
                         NFCReaderUsageDescription="Reads tags."))
    app.wait_log(r"^ip bluetooth state 2$")                              # unsupported: no Bluetooth radio, like the Simulator
    assert "ip bluetooth authorization 3" in app.log                     # allowedAlways
    app.wait_log(r"^ip pedometer status 0 error 104$")                   # not available (no motion coprocessor)
    app.wait_log(r"^ip nfc invalidated 1$")                              # readerErrorUnsupportedFeature
    assert "privacy-sensitive data without a usage description" not in app.log


@pytest.mark.os_matrix
def test_requires_full_screen(launch, tmp_path, ios):
    os_version = ios[0] or "18"
    app = launch(variant(tmp_path, UIRequiresFullScreen=True), device="ipadmini")        # runs iOS 17.0 too
    ignored = int(str(os_version).split(".")[0]) >= 26                  # iPadOS 26's windowing ignores it
    app.wait_log(rf"^ip multiple scenes {'true' if ignored else 'false'}$")


def test_required_device_capabilities(tmp_path):
    def install(app, device):
        env = dict(os.environ, ISIM_DATA=str(tmp_path / f"data-{device}"), ISIM_DEVICE=device)
        return subprocess.run([str(ISIM), "install", str(app)], env=env, capture_output=True, text=True)
    phone = variant(tmp_path / "a", UIRequiredDeviceCapabilities=["arm64", "telephony", "nfc"])
    r = install(phone, "ipadair11")
    assert r.returncode != 0 and "UIRequiredDeviceCapabilities (requires telephony, requires nfc)" in r.stderr, r.stderr
    assert install(phone, "iphone15").returncode == 0
    no_phone = variant(tmp_path / "b", UIRequiredDeviceCapabilities={"telephony": False, "metal": True})
    r = install(no_phone, "iphone15")
    assert r.returncode != 0 and "must not have telephony" in r.stderr, r.stderr
    assert install(no_phone, "ipadair11").returncode == 0
    gaming = variant(tmp_path / "c", UIRequiredDeviceCapabilities=["iphone-performance-gaming-tier", "made-up-sensor"])
    r = install(gaming, "iphonese")
    assert r.returncode != 0 and "requires iphone-performance-gaming-tier" in r.stderr, r.stderr
    r = install(gaming, "iphone16pro")
    assert r.returncode == 0 and "unknown capability 'made-up-sensor'" in r.stderr, r.stderr
