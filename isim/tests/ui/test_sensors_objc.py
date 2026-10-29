"""Sensors and health from Objective-C (HelloSensorsObjC, issue #315): HealthKit (units and quantities, authorization
answered by ISIM_HEALTH_PERMISSION, saving a sample, a sample query, a statistics sum), Core Motion's pedometer, motion
activity and altimeter (unavailable like the Simulator), Core Bluetooth (unsupported central and peripheral managers with
Objective-C delegates, a mutable service) and Core NFC (an NDEF reader session invalidated through its Objective-C
delegate, payloads, an APDU)."""

ENV = {"ISIM_HEALTH_PERMISSION": "allow"}


def test_sensors_objc(launch):
    app = launch("HelloSensorsObjC", env=ENV)
    app.wait_log(r"^po health available 1")
    app.wait_log(r"^po health units km/hr mile 1609 m compatible 1")
    app.wait_log(r"^po health authorized 1 status 2 error nil")
    app.wait_log(r"^po health saved 1 error nil")
    app.wait_log(r"^po health query 1 first 1200 source dev\.isim\.samples\.HelloSensorsObjC")
    app.wait_log(r"^po health sum 1200")
    app.wait_log(r"^po health anchored added 1 deleted 0 archived 1")
    app.wait_log(r"^po health sources 1 dev\.isim\.samples\.HelloSensorsObjC")
    app.wait_log(r"^po health background 1 error nil")
    app.wait_log(r"^po motion steps 0 floors 0 activity 0 altimeter 0 status 0")
    app.wait_log(r"^po motion pedometer \(null\) error CMErrorDomain/104")
    app.wait_log(r"^po motion altimeter \(null\) error CMErrorDomain/109")
    app.wait_log(r"^po motion extras headphones 0 connection 1 batched 0 0 recorder 0 data \(null\) water 0$")   # issue #414
    app.wait_log(r"^po motion batched \(null\) error CMErrorDomain/109$")
    app.wait_log(r"^po motion absolute altitude \(null\) error CMErrorDomain/109$")
    app.wait_log(r"^po motion water error CMErrorDomain/109$")
    app.wait_log(r"^po bluetooth service 180D primary 1 characteristic 2A37 properties 18 linked 1")
    app.wait_log(r"^po bluetooth central state 2 authorization 3")
    app.wait_log(r"API MISUSE: <CBCentralManager")
    app.wait_log(r"^po bluetooth peripheral state 2 advertising 0")
    app.wait_log(r"API MISUSE: <CBPeripheralManager")
    app.wait_log(r"^po nfc available 0 records 1 format 1 apdu ins A4 le 256")
    app.wait_log(r"^po nfc invalidated NFCError/1")
