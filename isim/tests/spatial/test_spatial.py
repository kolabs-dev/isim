"""Spatial (issue #370): SpatialTest.app checks the 3D geometry types (points, vectors, sizes, rotations, boxes, rays,
affine and projective transforms, poses) and the double-precision simd types under them, against hand-worked values."""
from isimtest import need_apps, run_app, selftest


def test_spatial(device_data):
    need_apps("SpatialTest")
    selftest("SpatialTest", data=device_data)


def lines(name, device_data):
    r = run_app(name, data=device_data)
    out = [l for l in r.output.splitlines() if l and l[0].islower() and " " in l and not l.startswith("isim")]
    assert out, r.output
    return out



def split(line):
    """"slerp longest 45.0000" -> ("slerp longest", [45.0])"""
    words = line.split()
    n = next(i for i, w in enumerate(words) if w.lstrip("-").replace(".", "", 1).isdigit())
    return " ".join(words[:n]), [float(w) for w in words[n:]]


def test_spatial_c_matches_swift(device_data):
    """The C interface (issue #692): SpatialCTest computes points, vectors, rotations, boxes, rays, transforms, poses and
    spherical coordinates with <Spatial/Spatial.h>; every double line must equal SpatialSwiftTest's, which computes the
    same with Swift's Spatial, and every …Float line the double one to float precision."""
    need_apps("SpatialCTest", "SpatialSwiftTest")
    c, swift = lines("SpatialCTest", device_data), lines("SpatialSwiftTest", device_data)
    double = [l for l in c if not l.startswith("float ")]
    floats = [l[len("float "):] for l in c if l.startswith("float ")]
    assert len(double) == 53, double
    assert double == swift
    assert "rotate 0.0000 1.0000 0.0000" in double and "length 5.0000" in double
    reference = dict(split(l) for l in double)
    assert len(floats) == 51, floats                         # Apple has no float rect distance or perspective
    for l in floats:
        name, got = split(l)
        assert len(got) == len(reference[name]) and all(abs(a - b) <= 1e-3 for a, b in zip(got, reference[name])), (l, reference[name])
