"""VideoToolbox (issue #284): VideoToolboxTest.app encodes H.264 and HEVC with compression sessions (the host's
libx264 / libx265), decodes them back with decompression sessions (the host's libavcodec), and checks pixel transfer
sessions and VTCreateCGImageFromCVPixelBuffer."""
from isimtest import need_apps, selftest


def test_videotoolbox(device_data):
    need_apps("VideoToolboxTest")
    selftest("VideoToolboxTest", data=device_data)
