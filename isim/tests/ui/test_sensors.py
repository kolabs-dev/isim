"""Device sensors and health (HelloSensors): Core Motion (simulated device upright at rest: accelerometer / device
motion / gyro updates; pedometer, activity and altimeter unavailable like the Simulator; ISIM_MOTION=unavailable),
Core Bluetooth (.unsupported + API MISUSE log), Core NFC (no reader), HealthKit (the Health Access sheet: Turn On All +
Allow, saving with unit conversion, statistics sum, sample query, answers remembered after a relaunch,
ISIM_HEALTH_PERMISSION=deny makes saving fail with errorAuthorizationDenied). Port of tests/ui/sensors.sh."""


def test_sensors_and_health(launch):
    app = launch("HelloSensors")
    app.wait_tap_id("motion")
    app.wait_log(r"^motion available accel true gyro true deviceMotion true")       # motion sensors (simulated)
    app.wait_log(r"^accel 0\.00 -1\.00 0\.00 after 3 updates")                      # accelerometer reads gravity
    app.wait_log(r"^deviceMotion gravity 0\.00 -1\.00 0\.00 user 0\.00 pitch 1\.57 roll 0\.00")
    app.wait_log(r"^gyro 0\.00 0\.00 0\.00 active yes")                             # gyro pull mode at rest
    app.wait_log(r"^pedometer steps false activity false altimeter false")
    app.wait_log(r"^pedometer query error 104")                                     # pedometer/activity/altimeter n/a
    app.tap_id("bluetooth")
    app.wait_log(r"^bluetooth state unsupported")
    app.wait_log(r"API MISUSE: <CBCentralManager")
    app.wait_view(r"text=Bluetooth: unsupported")                                    # Bluetooth unsupported
    app.tap_id("nfc")
    app.wait_log(r"^nfc readingAvailable false")
    app.wait_log(r"^nfc invalidated 1")                                              # NFC: no reader
    app.tap_id("healthAuth")
    app.wait_log(r"^health available true")
    sheet = app.wait_view(r"text=Health Access")
    for t in ("Turn On All", "App Explanation: Saves your walks and weight.", "Heart Rate"):
        assert f"text={t}" in sheet, f"Health Access sheet shows {t!r}"
    app.tap_text("Turn On All")
    app.wait_view(r"text=Turn Off All")
    app.tap_id("health-write-Weight")
    app.tap_text("Allow")
    app.wait_log(r"^health auth true steps 2 weight 1 error none")                  # Turn On All, Weight off, Allow
    app.wait_tap_id("healthSave")
    app.wait_log(r"^health save steps true 0")
    app.wait_log(r"^health save weight false 4")                                    # allowed type ok, denied refused
    app.tap_id("healthQuery")
    app.wait_log(r"^health steps sum 2450")
    app.wait_log(r"^health weight none")
    app.wait_view(r"text=2450 steps")                                                # statistics sum + sample query
    assert app.quit() == 0

    # relaunch on the same device data, motion unavailable (Simulator-exact)
    app = launch("HelloSensors", env={"ISIM_MOTION": "unavailable"})
    app.wait_tap_id("motion")
    app.wait_log(r"^motion available accel false gyro false deviceMotion false")
    app.tap_id("healthAuth")
    app.wait_log(r"^health auth true steps 2 weight 1")                             # answers remembered (no sheet)
    app.tap_id("healthSave")
    app.wait_log(r"^health save steps")
    app.tap_id("healthQuery")
    app.wait_log(r"^health steps sum 4900")                                          # data persists
    assert "text=Health Access" not in app.view_dump(), "no Health Access sheet the second time"
    assert app.quit() == 0


def test_health_denied(launch):
    app = launch("HelloSensors", env={"ISIM_HEALTH_PERMISSION": "deny"})
    app.wait_tap_id("healthAuth")
    app.wait_log(r"^health auth true steps 1 weight 1")
    app.tap_id("healthSave")
    app.wait_log(r"^health save steps false 4")
    app.tap_id("healthQuery")
    app.wait_log(r"^health steps sum -1")
    app.quit()
