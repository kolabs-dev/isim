"""Metal Performance Shaders, MPSGraph and MetalFX from Objective-C (issue #365): MPSTest.app checks image kernels,
MPSImage, matrix kernels and N-dimensional arrays on isim's CPU Metal device, against values computed by hand."""
from isimtest import need_apps, selftest


def test_mps(device_data):
    need_apps("MPSTest")
    selftest("MPSTest", data=device_data)
