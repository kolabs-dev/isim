"""Accelerate (issue #279): AccelerateCTest.app checks BLAS, LAPACK, vDSP (the FFTs and the DFT included) and vForce
from C against references computed in the app; AccelerateTest.app the Swift overlay (vDSP, vForce, FFT, DFT).
Issue #543 adds complex BLAS, SVD / geev / banded / complex LAPACK, the new LAPACK interface (newlapack.c), the 2D,
multiple-signal, radix 3 / 5 and interleaved transforms, biquads, the DCT, more vector functions and Quadrature, from C
and from Swift (vDSP.Biquad, vDSP.DCT, vDSP.FFT2D, Quadrature, ...)."""
from isimtest import need_apps, selftest


def test_accelerate_c(device_data):
    need_apps("AccelerateCTest")
    selftest("AccelerateCTest", data=device_data)


def test_accelerate_swift(device_data):
    need_apps("AccelerateTest")
    selftest("AccelerateTest", data=device_data)


def test_vimage_c(device_data):
    """vImage from C (issue #371): VImageCTest.app checks buffers, conversions, Y'CbCr, geometry, filters, alpha,
    colour matrices, lookup tables and Core Graphics interoperation."""
    need_apps("VImageCTest")
    selftest("VImageCTest", data=device_data)


def test_vimage_swift(device_data):
    """vImage from Swift (issue #371): VImageTest.app checks vImage_Buffer, vImage_CGImageFormat, vImageConverter and
    vImage.PixelBuffer."""
    need_apps("VImageTest")
    selftest("VImageTest", data=device_data)
