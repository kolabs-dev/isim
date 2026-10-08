"""Settings > General > Date & Time (isim boot): the 24-Hour Time and Time Zone switches write the system preferences
(which the status bar clock and apps apply live). Port of tests/ui/datetime.sh."""
import re


def test_datetime(launch, device_data):
    prefs = device_data / "Library" / "Preferences" / ".GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True)
    prefs.write_text('<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>AppleICUForce24HourTime</key>'
                     '<true/><key>TimeZone</key><string>America/New_York</string></dict></plist>')
    dev = launch(None)
    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-general")
    dev.wait_view(r"text=Date & Time")
    dev.wait_still()
    dev.tap_text("Date & Time")
    page = dev.wait_view(r"id=settings-24h")
    dev.wait_still()
    assert "id=settings-24h text=on" in page and "text=America/New_York" in page, "page reflects the preferences"
    dev.tap_id("settings-24h")
    dev.wait_until(lambda: "<key>AppleICUForce24HourTime</key><false/>" in re.sub(r"[\n\t ]", "", prefs.read_text()),
                   what="24-Hour Time switch writes the pref")
    dev.tap_id("settings-auto-tz")
    dev.wait_view(r"id=settings-auto-tz text=on")
    dev.wait_until(lambda: "<key>TimeZone</key>" not in re.sub(r"[\n\t ]", "", prefs.read_text()),
                   what="Set Automatically clears the zone")
    assert dev.quit() == 0, "exits cleanly"
    flat = re.sub(r"[\n\t ]", "", prefs.read_text())
    assert "<key>AppleICUForce24HourTime</key><false/>" in flat, "24-Hour Time switch writes the pref"
    assert "<key>TimeZone</key>" not in flat, "Set Automatically clears the zone"
