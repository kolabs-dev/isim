"""Core Graphics from C (issue #363): CGExtrasTest.app checks ICC color spaces (profiles it builds), Lab and indexed
spaces (colors and images), extended / linearized / standard-range variants, direct and sequential data providers,
CGFont tables, layers and conic gradients, on pixels it draws."""
from isimtest import need_apps, selftest


def test_cgextras(device_data):
    need_apps("CGExtrasTest")
    selftest("CGExtrasTest", data=device_data)
