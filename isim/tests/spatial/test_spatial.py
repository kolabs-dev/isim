"""Spatial (issue #370): SpatialTest.app checks the 3D geometry types (points, vectors, sizes, rotations, boxes, rays,
affine and projective transforms, poses) and the double-precision simd types under them, against hand-worked values."""
from isimtest import need_apps, selftest


def test_spatial(device_data):
    need_apps("SpatialTest")
    selftest("SpatialTest", data=device_data)
