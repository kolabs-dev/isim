"""Screen Time (issue #409, HelloScreenTime under `isim boot`): FamilyControls' authorization alert (a child's
authorization is refused: the device's account is not in a family), FamilyActivityPicker with opaque tokens, a shield
from ManagedSettingsStore drawn by the home screen with the app's Shield Configuration extension's look and its Shield
Action extension's answers, DeviceActivityCenter's validation, the Device Activity Monitor extension's interval and
event callbacks on Screen Time's clock (`isim screentime usage` / `clock`), effective settings, and the report
extension's scene."""
import os
import subprocess

from isimtest import ISIM

APP = "dev.isim.samples.HelloScreenTime"
OTHER = "dev.kolabs.isim.HelloCounterSwift"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_screen_time(launch, device_data):
    dev = launch(None, install=["HelloScreenTime", "HelloCounterSwift"])
    dev.send(f"launch {APP}")
    dev.wait_log(r"^st launched status=notDetermined$")
    dev.wait_tap_id("monitor")                                          # not authorized yet
    dev.wait_log(r"^st monitoring failed unauthorized$")
    dev.tap_id("child")
    dev.wait_log(r"^st authorization child failed invalidAccountType status=notDetermined$")
    dev.tap_id("authorize")                                             # the Screen Time alert
    dev.wait_view(r"Continue")
    dev.tap_text("Continue")
    dev.wait_log(r"^st authorized individual status=approved$")

    dev.tap_id("pick")                                                  # the picker: names stay hidden from the app
    dev.wait_tap_id(f"family-app-{OTHER}")
    dev.wait_tap_id("family-done")
    dev.wait_log(r"^st picked 1 app\(s\) 0 category\(ies\) names=0$")

    dev.tap_id("short")
    dev.wait_log(r"^st monitoring failed intervalTooShort$")
    dev.tap_id("monitor")                                               # an interval in progress: it starts
    dev.wait_log(r"^st monitoring \[\"focus\"\] events=1 next=true$")
    dev.wait_log(r"stm intervalDidStart focus")
    isim(device_data, "screentime", "usage", OTHER, "6")                 # within the warning time (5 min) of 10 min
    dev.wait_log(r"stm eventWillReachThresholdWarning limit focus")
    isim(device_data, "screentime", "usage", OTHER, "5")
    dev.wait_log(rf"stm eventDidReachThreshold limit focus: shielding {OTHER}")

    dev.send(f"launch {OTHER}")                                         # the shield instead of the app
    dev.wait_log(rf"SpringBoard: Screen Time shields {OTHER}")
    dev.wait_log(rf"stc configuration for {OTHER} \(HelloCounterSwift\)")
    dev.wait_view(r"id=shield-title.*Time’s up")
    dev.wait_still()
    dev.screenshot("screentime-shield")
    dev.tap_id("shield-secondary")                                      # One More Minute: defer, the shield stays
    dev.wait_log(rf"sta secondary for {OTHER}")
    dev.wait_log(r"SpringBoard: Screen Time shield action 1: defer")
    dev.wait_tap_id("shield-primary")                                   # Close
    dev.wait_log(rf"sta primary for {OTHER}")
    dev.wait_log(r"SpringBoard: Screen Time shield action 0: close")
    dev.wait_view(r"id=shield-title", gone=True)
    assert OTHER in isim(device_data, "screentime", "status")

    isim(device_data, "screentime", "clock", "+26")                     # 5 minutes before the end
    dev.wait_log(r"stm intervalWillEndWarning focus")
    isim(device_data, "screentime", "clock", "+5")                      # the end: the monitor lifts the shields
    dev.wait_log(r"stm intervalDidEnd focus: shields lifted")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("ratings")
    dev.wait_log(r"^st ratings movie=300 tv=1000 explicit=true default=1000 bounds=0...1000$")
    dev.tap_id("report")                                                # the report extension's scene
    dev.wait_log(r"str report HelloCounterSwift: 11 min")
    dev.wait_view(r"id=report-HelloCounterSwift")
    dev.tap_id("clear")
    dev.wait_log(r"^st cleared shields=0 activities=0$")
    dev.tap_id("revoke")
    dev.wait_log(r"^st revoked true status=notDetermined$")
