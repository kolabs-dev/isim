"""Foundation's newer format styles (issue #352): URL.FormatStyle / ParseStrategy, URL.Template, Date.HTTPFormatStyle,
Calendar.RecurrenceRule."""
from isimtest import need_apps, selftest


def test_swift_formatstyles(device_data):
    need_apps("SwiftFormatStylesTest")
    selftest("SwiftFormatStylesTest", data=device_data, executable=True)
