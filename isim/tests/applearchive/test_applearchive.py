"""AppleArchive (issue #348): the C API (AppleArchiveTest.app: byte streams, compression, headers, key sets, XAT blobs,
encoding, decoding, extraction, conversion, custom streams) and the Swift API (SwiftAppleArchiveTest.app: a directory
archived, compressed, decoded and extracted, entry filters, custom streams, random access, the shared buffer pipe)."""
from isimtest import need_apps, selftest


def test_applearchive_c(device_data):
    need_apps("AppleArchiveTest")
    selftest("AppleArchiveTest", data=device_data)


def test_applearchive_swift(device_data):
    need_apps("SwiftAppleArchiveTest")
    selftest("SwiftAppleArchiveTest", data=device_data, executable=True)
