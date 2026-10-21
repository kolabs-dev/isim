"""Frameworks that talk to other devices (HelloAccessories), each like Apple's Simulator: CoreLocationUI (SwiftUI's
LocationButton and UIKit's CLLocationButton grant when-in-use location access for the run, not remembered),
WatchConnectivity (supported, activated, no paired watch: messages, application contexts and transfers fail),
ExternalAccessory (no accessories; the picker finds none), NearbyInteraction (no Ultra Wideband: the session is
invalidated with unsupportedPlatform), WorkoutKit (no watch to schedule on) and AccessorySetupKit (activated; the
picker finds nothing)."""
import pytest

APP = "HelloAccessories"


@pytest.mark.os_matrix
def test_location_button(launch):
    app = launch(APP)
    app.wait_log(r"^location authorization 0")                                   # not determined
    app.wait_view(r"text=Current Location")
    app.screenshot("buttons")
    app.tap_text("Current Location")
    app.wait_log(r"isim CoreLocation: authorization authorizedWhenInUse")
    app.wait_log(r"^LocationButton tapped authorization 4 location true")       # granted before the action
    app.wait_view(r"text=Location shared")
    app.tap_id("clLocationButton")
    app.wait_log(r"^CLLocationButton tapped authorization 4")
    assert app.quit() == 0, "exits cleanly"
    app = launch(APP)                                                            # temporary: not remembered
    app.wait_log(r"^location authorization 0")
    app.wait_tap_id("clLocationButton")
    app.wait_log(r"^CLLocationButton tapped authorization 4")


def test_devices(launch):
    app = launch(APP)
    app.wait_tap_id("watch")
    app.wait_log(r"^watch supported true")
    app.wait_log(r"^watch activated 2 paired false installed false reachable false")
    app.wait_log(r"^watch message error 7007")                                   # not reachable
    app.wait_log(r"^watch context error 7005")                                   # not paired
    app.wait_log(r"^watch user info 1 error 7005")
    app.tap_id("accessories")
    app.wait_log(r"^accessories connected 0 session false")
    app.wait_log(r"^accessory picker EABluetoothAccessoryPickerErrorDomain 1")    # result not found
    app.tap_id("nearby")
    app.wait_log(r"^nearby distance false direction false camera false")
    app.wait_log(r"^nearby token false")
    app.wait_log(r"^nearby invalidated -5889")                                  # unsupported platform
    app.tap_id("workout")
    app.wait_log(r"^workout supported false authorization notDetermined blocks 1 steps 2 scheduled 0")
    app.tap_id("setup")
    app.wait_log(r"^setup event 10")                                           # activated
    app.wait_log(r"^setup picker 200 accessories 0 service 180D")              # discovery timeout
