// isim Foundation: NSLock, NSRecursiveLock, NSCondition over pthreads.
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <time.h>
#include <errno.h>

static struct timespec deadline_of(NSDate *limit) {
    NSTimeInterval t = [limit timeIntervalSince1970];
    struct timespec ts = { (time_t)t, (long)((t - (double)(time_t)t) * 1e9) };
    return ts;
}
/* timed lock by polling (pthread_mutex_timedlock is not in every libc the host may use) */
static BOOL lock_before(pthread_mutex_t *m, NSDate *limit) {
    while (pthread_mutex_trylock(m) != 0) {
        if ([limit timeIntervalSinceNow] <= 0) return NO;
        struct timespec ts = { 0, 1000000 };
        nanosleep(&ts, NULL);
    }
    return YES;
}

@implementation NSLock { pthread_mutex_t _m; }
@synthesize name = _name;
- (instancetype)init { if ((self = [super init])) pthread_mutex_init(&_m, NULL); return self; }
- (void)dealloc { pthread_mutex_destroy(&_m); }
- (void)lock { pthread_mutex_lock(&_m); }
- (void)unlock { pthread_mutex_unlock(&_m); }
- (BOOL)tryLock { return pthread_mutex_trylock(&_m) == 0; }
- (BOOL)lockBeforeDate:(NSDate *)limit { return lock_before(&_m, limit); }
@end

@implementation NSRecursiveLock { pthread_mutex_t _m; }
@synthesize name = _name;
- (instancetype)init {
    if ((self = [super init])) {
        pthread_mutexattr_t a; pthread_mutexattr_init(&a); pthread_mutexattr_settype(&a, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_m, &a); pthread_mutexattr_destroy(&a);
    }
    return self;
}
- (void)dealloc { pthread_mutex_destroy(&_m); }
- (void)lock { pthread_mutex_lock(&_m); }
- (void)unlock { pthread_mutex_unlock(&_m); }
- (BOOL)tryLock { return pthread_mutex_trylock(&_m) == 0; }
- (BOOL)lockBeforeDate:(NSDate *)limit { return lock_before(&_m, limit); }
@end

@implementation NSCondition { pthread_mutex_t _m; pthread_cond_t _c; }
@synthesize name = _name;
- (instancetype)init { if ((self = [super init])) { pthread_mutex_init(&_m, NULL); pthread_cond_init(&_c, NULL); } return self; }
- (void)dealloc { pthread_cond_destroy(&_c); pthread_mutex_destroy(&_m); }
- (void)lock { pthread_mutex_lock(&_m); }
- (void)unlock { pthread_mutex_unlock(&_m); }
- (void)wait { pthread_cond_wait(&_c, &_m); }
- (BOOL)waitUntilDate:(NSDate *)limit { struct timespec ts = deadline_of(limit); return pthread_cond_timedwait(&_c, &_m, &ts) != ETIMEDOUT; }
- (void)signal { pthread_cond_signal(&_c); }
- (void)broadcast { pthread_cond_broadcast(&_c); }
@end
