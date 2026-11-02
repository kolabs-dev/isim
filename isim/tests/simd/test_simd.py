"""The C simd interface (issue #800): SimdCTest computes vectors, geometry, common functions, logic, matrices and
quaternions with <simd/simd.h>; every result line must equal SimdSwiftTest's, which computes the same with Swift's simd."""
from isimtest import need_apps, run_app


def lines(name, device_data):
    r = run_app(name, data=device_data)
    out = [l for l in r.output.splitlines() if l and l[0].islower() and " " in l]
    assert out, r.output
    return out


def test_simd_c_matches_swift(device_data):
    need_apps("SimdCTest", "SimdSwiftTest")
    c, swift = lines("SimdCTest", device_data), lines("SimdSwiftTest", device_data)
    assert len(c) == 44, c
    assert c == swift
    assert "cross 27.0000 6.0000 -13.0000" in c
    assert "act 0.0000 1.0000 0.0000" in c
