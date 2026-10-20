"""Accelerate (issue #279): AccelerateCTest.app checks BLAS, LAPACK, vDSP (the FFTs and the DFT included) and vForce
from C against references computed in the app; AccelerateTest.app the Swift overlay (vDSP, vForce, FFT, DFT)."""
from isimtest import need_apps, selftest


def test_accelerate_c(device_data):
    need_apps("AccelerateCTest")
    selftest("AccelerateCTest", data=device_data)


def test_accelerate_swift(device_data):
    need_apps("AccelerateTest")
    selftest("AccelerateTest", data=device_data)
