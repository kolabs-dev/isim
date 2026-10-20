"""UniformTypeIdentifiers and CoreTransferable (issue #278): UTTypesTest.app checks the app's Info.plist type
declarations, the system types, the Objective-C bridge and Transferable's Codable representation and modifiers from
Swift; UTTypesObjCTest.app the Objective-C interface (the UTType class, UTCoreTypes.h, the tag classes)."""
from isimtest import need_apps, selftest


def test_uttypes(device_data):
    need_apps("UTTypesTest")
    selftest("UTTypesTest", data=device_data)


def test_uttypes_objc(device_data):
    need_apps("UTTypesObjCTest")
    selftest("UTTypesObjCTest", data=device_data)
