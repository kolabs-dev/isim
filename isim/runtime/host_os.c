/* isim libSystem: os_unfair_lock (libsystem_platform on iOS) on a Linux futex. The 32-bit lock word holds the
 * owner's thread id (bit 31 = waiters), so ownership assertions work and unlocking from another thread aborts
 * like on iOS. */
#define _GNU_SOURCE
#include <linux/futex.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>
#include "runtime.h"

#define WAITERS 0x80000000u
static uint32_t self_id(void) { static __thread uint32_t tid; if (!tid) tid = (uint32_t)syscall(SYS_gettid) & 0x7fffffff; return tid; }
static void ul_crash(const char *what) { fflush(NULL); fprintf(stderr, "isim: BUG IN CLIENT OF LIBPLATFORM: %s\n", what); abort(); }

static void ul_lock(uint32_t *l) {
    uint32_t me = self_id(), v = 0;
    if (__atomic_compare_exchange_n(l, &v, me, 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) return;
    for (;;) {
        v = __atomic_load_n(l, __ATOMIC_RELAXED);
        if ((v & ~WAITERS) == me) ul_crash("Trying to recursively lock an os_unfair_lock");
        if (v == 0) {
            if (__atomic_compare_exchange_n(l, &v, me | WAITERS, 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) return;
            continue;
        }
        if (!(v & WAITERS) && !__atomic_compare_exchange_n(l, &v, v | WAITERS, 0, __ATOMIC_RELAXED, __ATOMIC_RELAXED)) continue;
        syscall(SYS_futex, l, FUTEX_WAIT_PRIVATE, v | WAITERS, NULL, NULL, 0);
    }
}
static _Bool ul_trylock(uint32_t *l) {
    uint32_t v = 0;
    return __atomic_compare_exchange_n(l, &v, self_id(), 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED);
}
static void ul_unlock(uint32_t *l) {
    uint32_t v = __atomic_load_n(l, __ATOMIC_RELAXED);
    if ((v & ~WAITERS) != self_id()) ul_crash("Unlock of an os_unfair_lock not owned by current thread");
    v = __atomic_exchange_n(l, 0, __ATOMIC_RELEASE);
    if (v & WAITERS) syscall(SYS_futex, l, FUTEX_WAKE_PRIVATE, 1, NULL, NULL, 0);
}
static void ul_assert_owner(const uint32_t *l) {
    if ((__atomic_load_n(l, __ATOMIC_RELAXED) & ~WAITERS) != self_id()) ul_crash("os_unfair_lock is not owned by current thread");
}
static void ul_assert_not_owner(const uint32_t *l) {
    if ((__atomic_load_n(l, __ATOMIC_RELAXED) & ~WAITERS) == self_id()) ul_crash("os_unfair_lock is owned by current thread");
}

static const struct shim os_table[] = {
    { "_os_unfair_lock_lock", (void *)ul_lock, "isim" }, { "_os_unfair_lock_trylock", (void *)ul_trylock, "isim" },
    { "_os_unfair_lock_unlock", (void *)ul_unlock, "isim" }, { "_os_unfair_lock_assert_owner", (void *)ul_assert_owner, "isim" },
    { "_os_unfair_lock_assert_not_owner", (void *)ul_assert_not_owner, "isim" },
};
const struct host_lib host_libsystem_os = { "/usr/lib/system/libsystem_platform.dylib", os_table, sizeof os_table / sizeof *os_table };
