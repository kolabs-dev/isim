#pragma once
/* isim SDK (self-authored): unified logging. In Swift, `import os` / `import os.log` provide Logger, OSLog,
 * os_log and OSSignposter (isim's Swift os module, which prints to stderr). The C/Objective-C os_log macros
 * are not provided by isim yet. */
#include <_isim_cdefs.h>
#include <stdint.h>
