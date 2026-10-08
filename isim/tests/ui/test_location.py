"""Core Location (HelloLocation): the location permission alert (tapped), CLLocationManager updates from the simulated
location (Apple Park by default), the `location LAT LON` script command, offline reverse and forward geocoding, circular
region enter events, the Always upgrade alert, the answer remembered after a relaunch, ISIM_LOCATION (custom location +
route) with CLLocationUpdate.liveUpdates, "Allow Once" lasting one launch, ISIM_LOCATION_PERMISSION=deny,
`location none`, and a missing usage description (request ignored and logged). Port of tests/ui/location.sh."""
import plistlib
import shutil

from isimtest import APPS


def test_permission_updates_geocoding_regions(launch):
    app = launch("HelloLocation")
    app.wait_log(r"^auth notDetermined")                                 # the delegate hears notDetermined at launch
    app.wait_tap_id("start")
    app.tap_id("requestWhenInUse")
    alert = app.wait_view(r"text=Allow “Location” to use your location\?")
    for t in ("Allow Once", "Don’t Allow", "Shows where you are and what is nearby."):
        assert f"text={t}" in alert, f"permission alert shows {t!r}"
    app.tap_text("Allow While Using App")
    app.wait_log(r"^auth authorizedWhenInUse accuracy full")
    app.wait_log(r"^location 37\.3349 -122\.0090 accuracy 5 simulated yes fromApplePark 0\.0km")   # queued updates
    app.send("location 37.787994 -122.407437")
    app.wait_log(r"^location 37\.7880 -122\.4074 .* fromApplePark 61\.[0-9]km")  # the location command moves the device
    app.tap_id("geocode")
    app.wait_log(r"^placemark Union Square, San Francisco 94108 US tz America/Los_Angeles main true")
    app.tap_id("forward")
    app.wait_log(r"^forward Eiffel Tower 48\.8584 2\.2945")
    app.wait_log(r"^forward error 8")                                    # forward geocoding + no-result error
    app.tap_id("region")
    app.wait_log(r"^monitoring ApplePark")
    app.wait_log(r"^region state outside ApplePark")
    app.send("location 37.3349 -122.00902")
    app.wait_log(r"^region enter ApplePark")                             # region monitoring: start, state, enter
    app.tap_id("requestAlways")
    app.wait_view(r"text=Allow “Location” to also use your location even when you are not using the app\?")
    app.tap_text("Change to Always Allow")
    app.wait_log(r"^auth authorizedAlways")
    assert app.quit() == 0

    app = launch("HelloLocation")                                       # the same device data
    app.wait_log(r"^auth authorizedAlways")                              # the answer is remembered
    app.wait_tap_id("once")
    app.wait_log(r"^location 37\.3349 -122\.0090")                       # the persisted location
    assert "text=Allow Once" not in app.view_dump(), "no permission alert after the answer"
    assert app.quit() == 0


def test_route_live_updates_allow_once(launch):
    app = launch("HelloLocation", env={"ISIM_LOCATION": "38.707751,-9.136592;38.7100,-9.1366@40"})
    app.wait_tap_id("live")
    app.wait_view(r"text=Allow Once")
    app.tap_text("Allow Once")
    app.wait_log(r"^live 1 38\.70[78][0-9] -9\.1366 speed 40")           # ISIM_LOCATION route + liveUpdates
    app.wait_log(r"^live 3 38\.7")
    app.wait_log(r"^live done", timeout=15)
    assert app.has(r"authorization authorizedWhenInUse"), "Allow Once authorizes for this launch"
    app.quit()

    app = launch("HelloLocation")                                       # the same device data, a new launch
    app.wait_log(r"^auth notDetermined")                                 # Allow Once lasts one launch
    app.wait_tap_id("start")
    app.sleep(0.8)                                                       # no update may arrive
    assert not app.has(r"^location"), "no location without a new answer"
    app.quit()


def test_denied(launch):
    app = launch("HelloLocation", env={"ISIM_LOCATION_PERMISSION": "deny"})
    app.wait_tap_id("requestWhenInUse")
    app.wait_log(r"^auth denied")
    app.tap_id("start")
    app.wait_log(r"^error 1 kCLErrorDomain")                             # ISIM_LOCATION_PERMISSION=deny -> denied + error
    app.quit()


def test_location_none_and_offline_geocoder(launch):
    app = launch("HelloLocation", env={"ISIM_LOCATION": "none", "ISIM_LOCATION_PERMISSION": "wheninuse",
                                       "ISIM_GEOCODER": "offline"})
    app.wait_tap_id("requestWhenInUse")
    app.tap_id("start")
    app.sleep(0.8)
    app.send("location 51.508039 -0.128069")
    app.wait_log(r"^location 51\.5080 -0\.1281")
    app.tap_id("geocode")
    app.wait_log(r"^geocode error 2")                                    # the geocoder is offline
    app.send("location none")
    app.sleep(0.3)
    app.tap_id("once")
    app.wait_log(r"^error 0 kCLErrorDomain")                             # Location None -> locationUnknown
    app.quit()


def test_missing_usage_description(launch, tmp_path):
    nokey = tmp_path / "HelloLocation.app"
    shutil.copytree(APPS / "HelloLocation.app", nokey, symlinks=True)
    info = nokey / "Info.plist"
    d = plistlib.loads(info.read_bytes())
    d.pop("NSLocationWhenInUseUsageDescription")
    info.write_bytes(plistlib.dumps(d))
    app = launch(nokey)
    app.wait_tap_id("requestWhenInUse")
    app.wait_log(r"NSLocationWhenInUseUsageDescription key")             # iOS ignores the request and logs
    app.sleep(0.8)                                                       # no alert may come
    assert "text=Allow Once" not in app.view_dump(), "missing usage description: no alert"
    app.quit()
