"""GameSave from Objective-C (issue #393): GameSaveObjCTest.app opens a GSSyncedDirectory, observes its state, uploads,
closes, and resolves a conflict with a version another device put in the simulated iCloud."""
from isimtest import need_apps, selftest


def test_gamesave_objc(device_data):
    need_apps("GameSaveObjCTest")
    selftest("GameSaveObjCTest", data=device_data)
