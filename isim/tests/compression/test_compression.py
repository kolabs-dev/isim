"""libcompression and Compression (issue #264): every algorithm through the buffer and stream APIs and NSData from C
and Objective-C (CompressionTest.app), the Swift Compression module's filters and NSData.compressed(using:)
(SwiftCompressionTest.app)."""
from isimtest import need_apps, selftest


def test_compression_c(device_data):
    need_apps("CompressionTest")
    selftest("CompressionTest", data=device_data)


def test_compression_swift(device_data):
    need_apps("SwiftCompressionTest")
    selftest("SwiftCompressionTest", data=device_data, executable=True)
