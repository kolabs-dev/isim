"""Core Image's iOS 18/26 filters and HDR (issue #380): CoreImageHDRTest.app renders CIAreaBoundsRed,
CIAreaAverageMaximumRed, CIAreaAlphaWeightedHistogram, CIMaximumScaleTransform, CIBlurredRoundedRectangleGenerator,
CIRoundedQRCodeGenerator (decoded back when the host has zbar or zxing-cpp), CISystemToneMap and smoothness, and checks
content headroom / average light level, calculateHDRStats, Lab conversion, CIImage(depthData:) and the new constants."""
from isimtest import need_apps, selftest


def test_coreimage_hdr(device_data):
    need_apps("CoreImageHDRTest")
    selftest("CoreImageHDRTest", data=device_data, os_version="26")
