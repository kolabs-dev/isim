#pragma once
/* isim SDK (self-authored, Apple's declarations): the deprecated OSAtomic and OSSpinLock functions, implemented by
 * isim's libSystem with the compiler's atomics (full barriers). New code uses <stdatomic.h> and os_unfair_lock. */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
#define __OSATOMIC_DEPRECATED(r) __attribute__((deprecated("Use " r " from <stdatomic.h> instead")))
int32_t OSAtomicAdd32(int32_t, volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add_explicit(memory_order_relaxed)");
int32_t OSAtomicAdd32Barrier(int32_t, volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add()");
int32_t OSAtomicIncrement32(volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add_explicit(memory_order_relaxed)");
int32_t OSAtomicIncrement32Barrier(volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add()");
int32_t OSAtomicDecrement32(volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_sub_explicit(memory_order_relaxed)");
int32_t OSAtomicDecrement32Barrier(volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_sub()");
int64_t OSAtomicAdd64(int64_t, volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add_explicit(memory_order_relaxed)");
int64_t OSAtomicAdd64Barrier(int64_t, volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add()");
int64_t OSAtomicIncrement64(volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add_explicit(memory_order_relaxed)");
int64_t OSAtomicIncrement64Barrier(volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_add()");
int64_t OSAtomicDecrement64(volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_sub_explicit(memory_order_relaxed)");
int64_t OSAtomicDecrement64Barrier(volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_fetch_sub()");
int32_t OSAtomicOr32(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_or_explicit(memory_order_relaxed)");
int32_t OSAtomicOr32Barrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_or()");
int32_t OSAtomicOr32Orig(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_or_explicit(memory_order_relaxed)");
int32_t OSAtomicOr32OrigBarrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_or()");
int32_t OSAtomicAnd32(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_and_explicit(memory_order_relaxed)");
int32_t OSAtomicAnd32Barrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_and()");
int32_t OSAtomicAnd32Orig(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_and_explicit(memory_order_relaxed)");
int32_t OSAtomicAnd32OrigBarrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_and()");
int32_t OSAtomicXor32(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_xor_explicit(memory_order_relaxed)");
int32_t OSAtomicXor32Barrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_xor()");
int32_t OSAtomicXor32Orig(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_xor_explicit(memory_order_relaxed)");
int32_t OSAtomicXor32OrigBarrier(uint32_t, volatile uint32_t *) __OSATOMIC_DEPRECATED("atomic_fetch_xor()");
bool OSAtomicCompareAndSwap32(int32_t, int32_t, volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong_explicit(memory_order_relaxed)");
bool OSAtomicCompareAndSwap32Barrier(int32_t, int32_t, volatile int32_t *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong()");
bool OSAtomicCompareAndSwap64(int64_t, int64_t, volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong_explicit(memory_order_relaxed)");
bool OSAtomicCompareAndSwap64Barrier(int64_t, int64_t, volatile int64_t *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong()");
bool OSAtomicCompareAndSwapInt(int, int, volatile int *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong_explicit(memory_order_relaxed)");
bool OSAtomicCompareAndSwapIntBarrier(int, int, volatile int *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong()");
bool OSAtomicCompareAndSwapLong(long, long, volatile long *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong_explicit(memory_order_relaxed)");
bool OSAtomicCompareAndSwapLongBarrier(long, long, volatile long *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong()");
bool OSAtomicCompareAndSwapPtr(void *, void *, void *volatile *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong_explicit(memory_order_relaxed)");
bool OSAtomicCompareAndSwapPtrBarrier(void *, void *, void *volatile *) __OSATOMIC_DEPRECATED("atomic_compare_exchange_strong()");
bool OSAtomicTestAndSet(uint32_t, volatile void *) __OSATOMIC_DEPRECATED("atomic_fetch_or()");
bool OSAtomicTestAndSetBarrier(uint32_t, volatile void *) __OSATOMIC_DEPRECATED("atomic_fetch_or()");
bool OSAtomicTestAndClear(uint32_t, volatile void *) __OSATOMIC_DEPRECATED("atomic_fetch_and()");
bool OSAtomicTestAndClearBarrier(uint32_t, volatile void *) __OSATOMIC_DEPRECATED("atomic_fetch_and()");
void OSMemoryBarrier(void) __OSATOMIC_DEPRECATED("atomic_thread_fence()");
typedef int32_t OSSpinLock;
#define OS_SPINLOCK_INIT 0
bool OSSpinLockTry(volatile OSSpinLock *) __attribute__((deprecated("Use os_unfair_lock_trylock() from <os/lock.h> instead")));
void OSSpinLockLock(volatile OSSpinLock *) __attribute__((deprecated("Use os_unfair_lock_lock() from <os/lock.h> instead")));
void OSSpinLockUnlock(volatile OSSpinLock *) __attribute__((deprecated("Use os_unfair_lock_unlock() from <os/lock.h> instead")));
typedef volatile struct { void *opaque1; long opaque2; } __attribute__((aligned(16))) OSQueueHead;
#define OS_ATOMIC_QUEUE_INIT { NULL, 0 }
void OSAtomicEnqueue(OSQueueHead *, void *, size_t);
void *OSAtomicDequeue(OSQueueHead *, size_t);
__END_DECLS
