"""Automatic grammar agreement (issue #351): ^[…](inflect: true), number and gender agreement in en / es / fr / it / pt,
terms of address, Morphology, InflectionRule, LocalizationOptions, and NSMorphology / inflecting() from Swift."""
from isimtest import need_apps, selftest


def test_swift_inflection(device_data):
    need_apps("SwiftInflectionTest")
    selftest("SwiftInflectionTest", data=device_data, executable=True)
