"""Swift networking self-test: sockets, URLSession, cookies, cache, NWPathMonitor (in-process server)."""
from isimtest import need_apps, selftest


def test_swift_network(device_data):
    need_apps("SwiftNetworkTest")
    selftest("SwiftNetworkTest", data=device_data, executable=True, timeout=90)
