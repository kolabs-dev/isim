"""Core Data self-test (CoreDataTest.app: models, stores, contexts, fetching, FRC, migration) on scratch device data
(the stores live in its container)."""
from isimtest import need_apps, selftest


def test_coredata(device_data):
    need_apps("CoreDataTest")
    selftest("CoreDataTest", data=device_data, timeout=120)
