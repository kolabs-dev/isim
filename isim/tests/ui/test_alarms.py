"""AlarmKit (issue #405, HelloAlarms, under `isim boot`): the authorization alert; a tea timer counts down as the app's
Live Activity, pauses and resumes, goes off in the shell's alarm banner, Repeat starts its post-alert countdown and
Done stops it; an alarm goes off on the Lock Screen (the full-screen alert) and its Stop runs the app's intent; a weekly
alarm is listed (also by `isim alarms list`) and cancelled. System UI: os_matrix; AlarmKit is iOS 26."""
import os
import subprocess

import pytest

from isimtest import ISIM

APP = "dev.isim.samples.HelloAlarms"

pytestmark = pytest.mark.os_matrix


def test_alarms(launch, ios, tmp_path):
    dev = launch(None, install=["HelloAlarms"])
    dev.send(f"launch {APP}")
    version = ios[0] or "18"
    if int(version.split(".")[0]) < 26:
        dev.wait_log(r"^ak needs iOS 26$")
        return
    dev.wait_log(r"^ak authorization notDetermined$")
    dev.wait_log(r"^ak update \[\]$")

    dev.wait_tap_id("authorize")
    dev.wait_view(r"Would Like to Schedule Alarms and Timers")
    dev.tap_text("Allow")
    dev.wait_log(r"^ak authorization authorized$")

    dev.wait_tap_id("tea")                                          # a timer: counting down at once
    dev.wait_log(r"^ak scheduled tea countdown pre=3 post=2$")
    dev.wait_log(r"isim shell: timer Tea is ready of Wake goes off at")
    dev.wait_log(r"isim ActivityKit: requested Live Activity .* \(AlarmAttributes<TeaData>\)")
    dev.tap_id("pause")
    dev.wait_log(r"^ak update \[tea=paused\]$")
    dev.wait_log(r"isim shell: alarm Tea is ready cleared")
    dev.tap_id("resume")
    dev.wait_log(r"^ak update \[tea=countdown\]$")
    dev.wait_log(r"isim shell: timer Tea is ready of Wake is alerting")
    dev.wait_log(r"^ak update \[tea=alerting\]$")
    dev.wait_dump(r"id=alarm-banner text=Tea is ready")
    dev.wait_still()
    dev.screenshot("alarm-banner")
    dev.tap_id("alarm-secondary")                                   # Repeat: the post-alert countdown
    dev.wait_log(r"isim shell: secondary action on Tea is ready \(Repeat\)")
    dev.wait_log(r"^ak update \[tea=countdown\]$")
    dev.wait_log(r"isim shell: timer Tea is ready of Wake is alerting")
    dev.wait_dump(r"id=alarm-stop text=Done")
    dev.tap_id("alarm-stop")
    dev.wait_log(r"isim shell: stopped Tea is ready \(Done\)")
    dev.wait_log(r"^ak update \[\]$")

    dev.wait_tap_id("wake")                                         # an alarm, on the Lock Screen
    dev.wait_log(r"^ak scheduled wake scheduled fixed$")
    dev.send("lock")
    dev.wait_log(r"isim shell: alarm Wake up of Wake is alerting")
    dev.wait_dump(r"IsimAlarmAlert")
    dev.wait_dump(r"id=alarm-title text=Wake up")                  # (the app is suspended: no wait_still)
    dev.screenshot("alarm-lock-screen")
    dev.tap_id("alarm-stop")
    dev.wait_log(r"^ak intent stop$")
    dev.wait_log(r"^ak update \[\]$")
    dev.send("unlock")

    dev.wait_tap_id("weekly")                                       # a weekly alarm: listed, then cancelled
    dev.wait_log(r"^ak scheduled weekly scheduled 7:30 days=5$")
    dev.wait_log(r"isim shell: alarm Weekday alarm of Wake goes off at 07:30:00")
    dev.tap_id("list")
    dev.wait_log(r"^ak list weekly$")
    out = subprocess.run([str(ISIM), "alarms", "list"], env=dict(os.environ, ISIM_DATA=str(dev.data)), stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True, timeout=60).stdout
    assert f'{APP}: alarm A1A2A3A4-0000-4000-8000-000000000003 "Weekday alarm" scheduled at ' in out, out
    dev.tap_id("cancel")
    dev.wait_log(r"^ak cancelled weekly$")
    dev.wait_log(r"^ak update \[\]$")


def test_alarms_denied(launch, ios):
    """ISIM_ALARMKIT_PERMISSION=deny: no alert; scheduling fails"""
    version = ios[0] or "18"
    if int(version.split(".")[0]) < 26:
        pytest.skip("AlarmKit is iOS 26")
    dev = launch(None, install=["HelloAlarms"], env={"ISIM_ALARMKIT_PERMISSION": "deny"})
    dev.send(f"launch {APP}")
    dev.wait_log(r"^ak update \[\]$")
    dev.wait_tap_id("tea")
    dev.wait_log(r"^ak tea failed: the user has not allowed this app to schedule alarms and timers$")
