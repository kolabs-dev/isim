"""Core Graphics paths (issue #273): CGPathTest.app works arcs to a point, stroked and dashed copies, transformed
copies, CGPathIsRect and the boolean operations from C, measuring areas by sampling CGPathContainsPoint."""
from isimtest import need_apps, selftest


def test_cgpath(device_data):
    need_apps("CGPathTest")
    selftest("CGPathTest", data=device_data)
