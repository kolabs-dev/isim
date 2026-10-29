"""Device sensors and health (HelloSensors): Core Motion (simulated device upright at rest: accelerometer / device
motion / gyro updates; pedometer, activity and altimeter unavailable like the Simulator; ISIM_MOTION=unavailable),
Core Bluetooth (.unsupported + API MISUSE log), Core NFC (no reader), HealthKit (the Health Access sheet: Turn On All +
Allow, saving with unit conversion, statistics sum, sample query, answers remembered after a relaunch,
ISIM_HEALTH_PERMISSION=deny makes saving fail with errorAuthorizationDenied). Port of tests/ui/sensors.sh."""
import pytest


@pytest.mark.os_matrix
def test_sensors_and_health(launch):
    app = launch("HelloSensors")
    app.wait_tap_id("motion")
    app.wait_log(r"^motion available accel true gyro true magnetometer true deviceMotion true")
    app.wait_log(r"^motion frames 15$")
    app.wait_log(r"^accel 0\.00 -1\.00 0\.00 pull 0\.00 -1\.00 0\.00 after 3 updates")
    app.wait_log(r"^deviceMotion gravity 0\.00 -1\.00 0\.00 user 0\.00 pitch 1\.57 roll 0\.00 pull -1\.00 heading -1")
    app.wait_log(r"^gyro 0\.00 0\.00 0\.00 active yes")                             # gyro pull mode at rest
    app.wait_log(r"^magnetometer 18\.4 -9\.2 -41\.7 pull 18\.4 -9\.2 -41\.7")
    app.wait_log(r"^pedometer steps false distance false floors false pace false cadence false events false activity false altimeter false")
    app.wait_log(r"^pedometer query error 104")                                     # pedometer/activity/altimeter n/a
    app.wait_log(r"^activity query error 104")
    app.wait_log(r"^altimeter update error 109")
    # issue #414: headphone motion, batched sensors, the sensor recorder, absolute altitude, water submersion
    app.wait_log(r"^absolute altitude nil error 109 available false$")
    app.wait_log(r"^headphones motion false connection true status 0$")
    app.wait_log(r"^batched accelerometer false deviceMotion false recorder false data nil water false depth nil$")
    app.wait_log(r"^batched device motion nil error 109$")
    app.wait_log(r"^batched accelerometer updates error 109$")
    app.wait_log(r"^water submersion error 109$")
    app.tap_id("bluetooth")
    app.wait_log(r"^bluetooth state unsupported")
    app.wait_log(r"API MISUSE: <CBCentralManager")
    app.wait_view(r"text=Bluetooth: unsupported")                                    # Bluetooth unsupported
    app.tap_id("nfc")
    app.wait_log(r"^nfc readingAvailable false")
    app.wait_log(r"^nfc invalidated 1")                                              # NFC: no reader
    app.tap_id("peripheral")                                                         # the peripheral role
    app.wait_log(r"^peripheral state unsupported service 180D primary true characteristics 1 descriptor Heart rate linked true")
    app.wait_log(r"^peripheral advertising false sent false attError 2 CBATTErrorDomain")
    app.wait_log(r"API MISUSE: <CBPeripheralManager")
    app.tap_id("nfcTags")                                                            # tag and Wallet pass readers
    app.wait_log(r"^nfc tags readingAvailable false vas false")
    app.wait_log(r"^nfc apdu ins A4 data 2 le 256")
    app.wait_log(r"^nfc tag session invalidated 1")
    app.wait_log(r"^nfc vas session invalidated 1")
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
    app.tap_id("healthChanges")                                                      # anchored object queries
    app.wait_log(r"^health anchored added 3 deleted 0 error none")
    app.wait_log(r"^health anchor archived equal true")
    app.wait_log(r"^health sources Sensors$")
    app.wait_log(r"^health source descriptor Sensors$")
    app.wait_log(r"^health descriptor 2 1200 800$")                                   # newest first, limit 2
    app.wait_log(r"^health background true")
    app.wait_log(r"isim HealthKit: Sensors background delivery for Steps \(hourly\)")
    app.wait_log(r"^health anchored update added 1 deleted 0")                        # saved, then deleted
    app.wait_log(r"^health deleted true")
    app.wait_log(r"^health anchored update added 0 deleted 1")
    app.wait_log(r"^health descriptor since added 0 deleted 1 newer true")
    app.wait_log(r"^health sequence added 3 deleted 0")
    app.wait_view(r"text=2450 steps")                                                # statistics sum + sample query
    assert app.quit() == 0

    # relaunch on the same device data, motion unavailable (Simulator-exact)
    app = launch("HelloSensors", env={"ISIM_MOTION": "unavailable"})
    app.wait_tap_id("motion")
    app.wait_log(r"^motion available accel false gyro false magnetometer false deviceMotion false")
    app.wait_log(r"^motion frames 0$")
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
