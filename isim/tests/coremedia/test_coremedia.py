"""Core Media (issue #383): CoreMediaTest.app checks the Swift time range and time mapping functions, CMSimpleQueue,
CMBufferQueue (callbacks, handlers, triggers, validation, the iOS 13 Swift API), sample buffer copies and the video
format description functions (clean aperture, presentation size, image buffer matching, QuickTime image
descriptions); CoreMediaCTest.app the C interface of the time ranges, mappings and queues."""
from isimtest import need_apps, selftest


def test_coremedia_swift(device_data):
    need_apps("CoreMediaTest")
    selftest("CoreMediaTest", data=device_data)


def test_coremedia_c(device_data):
    need_apps("CoreMediaCTest")
    selftest("CoreMediaCTest", data=device_data)
