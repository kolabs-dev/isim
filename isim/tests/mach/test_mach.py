"""Mach self-test (MachTest.app): time, task_info, task_threads / thread_info, host_info / host_statistics /
host_processor_info, vm_allocate / vm_protect / vm_read_overwrite, ports and mach_msg between threads, semaphores,
clocks, error strings, from Objective-C and Swift."""
from isimtest import need_apps, selftest


def test_selftest(device_data):
    need_apps("MachTest")
    r = selftest("MachTest", data=device_data, timeout=60)
    assert not r.lines(r"^FAIL"), r.lines(r"^FAIL")
