"""The C library and POSIX headers apps and packages compile against (LibcTest.app, issue #220): sys/mman.h,
sys/sysctl.h, sys/utsname.h, sys/event.h (kqueue on epoll), sys/resource.h, sys/xattr.h, execinfo.h, wchar.h,
regex.h, notify.h, syslog.h, pwd.h, termios.h, libkern/OSAtomic.h, os/activity.h, os/proc.h and the added
unistd / stdlib / string / signal functions."""
import re

from isimtest import need_apps, selftest


def test_libc(device_data):
    need_apps("LibcTest")
    r = selftest("LibcTest", data=device_data)
    # syslog with LOG_PERROR | LOG_PID: the message on stderr, %m expanded
    assert re.search(r"^libctest\[\d+\]: hello from syslog 7$", r.output, re.M), r.output[-2000:]
    assert re.search(r"^libctest\[\d+\]: failed: No such file or directory$", r.output, re.M), r.output[-2000:]
