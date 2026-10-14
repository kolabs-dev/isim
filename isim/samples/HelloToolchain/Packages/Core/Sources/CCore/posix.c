/* The Darwin C headers a package's C target compiles against (issue #220): regex, kqueue, sysctl, uname, wide
 * characters, the user database. */
#include "ccore.h"
#include <pwd.h>
#include <regex.h>
#include <string.h>
#include <sys/event.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <syslog.h>
#include <termios.h>
#include <unistd.h>
#include <wchar.h>

int ccore_matches(const char *pattern, const char *text) {
    regex_t re;
    if (regcomp(&re, pattern, REG_EXTENDED | REG_NOSUB) != 0) return -1;
    int r = regexec(&re, text, 0, NULL, 0) == 0;
    regfree(&re);
    return r;
}

int ccore_platform_ok(void) {
    struct utsname u;
    char machine[32]; size_t len = sizeof machine;
    struct kevent ev; EV_SET(&ev, 0, EVFILT_READ, EV_ADD, 0, 0, NULL);
    return uname(&u) == 0 && sysctlbyname("hw.machine", machine, &len, NULL, 0) == 0 && wcslen(L"ok") == 2 && ev.filter == EVFILT_READ;
}
