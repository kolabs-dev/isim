/* isim Foundation: Darwin notifications (<notify.h>): notify_post and the check, dispatch, signal and file-descriptor
 * clients, suspension and the per-name state. Adapted: a post reaches the clients of every process on the device
 * (the app, its extensions, other apps): each post is appended to $ISIM_DATA/Library/isim/notify.log, and a process
 * with clients watches the log (a vnode dispatch source) and delivers the other processes' posts to them. The state
 * (notify_set_state) stays in its process; Mach port registrations are not supported. */
#import <Foundation/Foundation.h>
#include <notify.h>
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "isim_foundation.h"

@interface _ISIMNotifyClient : NSObject {
@public
    int token, kind, sig, writeFD;              /* kind: 0 check, 1 dispatch, 2 signal, 3 file descriptor */
    BOOL changed, suspended, pending;
    NSString *name;
    dispatch_queue_t queue;
    notify_handler_t handler;
}
@end
@implementation _ISIMNotifyClient
@end

static pthread_mutex_t notify_lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary<NSNumber *, _ISIMNotifyClient *> *clients;
static NSMutableDictionary<NSString *, NSNumber *> *states;
static int next_token = 1;

static void deliver(_ISIMNotifyClient *c) {                     /* called without the lock */
    switch (c->kind) {
    case 0: c->changed = YES; break;
    case 1: { notify_handler_t h = c->handler; int t = c->token; dispatch_async(c->queue, ^{ h(t); }); break; }
    case 2: kill(getpid(), c->sig); break;
    case 3: { int32_t be = (int32_t)htonl((uint32_t)c->token); if (write(c->writeFD, &be, sizeof be) < 0) {} break; }
    }
}

/* ---- across processes: the device's post log ---- */
enum { LOG_LIMIT = 4 << 20 };                 /* a post at this size starts the log again (posts are not kept) */
static NSString *log_path(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/notify.log"]; }
static int log_fd = -1;
static off_t log_offset;
static dispatch_source_t log_source;          /* kept for the life of the process */
static void post_local(NSString *n);
/* the posts of other processes since the last read: "<pid> <name>" lines */
static void read_log(void) {
    struct stat st;
    if (fstat(log_fd, &st) != 0) return;
    if (st.st_size < log_offset) log_offset = 0;                        /* started again */
    if (st.st_size == log_offset) return;
    size_t len = (size_t)(st.st_size - log_offset);
    char *buf = malloc(len);
    ssize_t n = pread(log_fd, buf, len, log_offset);
    ssize_t end = n;
    while (end > 0 && buf[end - 1] != '\n') end--;                      /* whole lines only */
    if (end > 0) {
        log_offset += end;
        NSString *text = [[NSString alloc] initWithBytes:buf length:(NSUInteger)end encoding:NSUTF8StringEncoding];
        int me = getpid();
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            NSRange sp = [line rangeOfString:@" "];
            if (sp.location == NSNotFound || [line substringToIndex:sp.location].intValue == me) continue;
            post_local([line substringFromIndex:sp.location + 1]);
        }
    }
    free(buf);
}
static void watch_log(void) {                  /* once, when the process registers its first client */
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = log_path();
        [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
        log_fd = open(path.fileSystemRepresentation, O_RDONLY | O_CREAT | O_CLOEXEC, 0644);
        if (log_fd < 0) return;
        struct stat st;
        log_offset = fstat(log_fd, &st) == 0 ? st.st_size : 0;           /* posts from now on */
        dispatch_queue_t q = dispatch_queue_create("isim.notify", DISPATCH_QUEUE_SERIAL);
        dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)log_fd,
                                                       DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND, q);
        dispatch_source_set_event_handler(src, ^{ read_log(); });
        dispatch_resume(src);
        log_source = src;
    });
}
static void append_log(const char *name) {
    if (strchr(name, '\n')) return;
    NSString *path = log_path();
    int fd = open(path.fileSystemRepresentation, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0644);
    if (fd < 0) {
        [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
        if ((fd = open(path.fileSystemRepresentation, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0644)) < 0) return;
    }
    struct stat st;
    if (fstat(fd, &st) == 0 && st.st_size > LOG_LIMIT && ftruncate(fd, 0) != 0) {}
    char line[1100];
    int len = snprintf(line, sizeof line, "%d %s\n", getpid(), name);
    if (len > 0 && len < (int)sizeof line && write(fd, line, (size_t)len) < 0) {}      /* one append: whole */
    close(fd);
}

/* the clients of this process */
static void post_local(NSString *n) {
    NSMutableArray *ready = [NSMutableArray array];
    pthread_mutex_lock(&notify_lock);
    for (_ISIMNotifyClient *c in clients.allValues) {
        if (![c->name isEqualToString:n]) continue;
        if (c->suspended) c->pending = YES;
        else [ready addObject:c];
    }
    pthread_mutex_unlock(&notify_lock);
    for (_ISIMNotifyClient *c in ready) deliver(c);
}
uint32_t notify_post(const char *name) {
    if (!name) return NOTIFY_STATUS_INVALID_NAME;
    post_local(@(name));
    append_log(name);
    return NOTIFY_STATUS_OK;
}

static uint32_t add_client(const char *name, int kind, int *out_token, void (^setup)(_ISIMNotifyClient *)) {
    if (!name) return NOTIFY_STATUS_INVALID_NAME;
    if (!out_token) return NOTIFY_STATUS_NULL_INPUT;
    _ISIMNotifyClient *c = [_ISIMNotifyClient new];
    c->kind = kind; c->name = @(name); c->changed = YES;         /* the first notify_check reports a change */
    c->writeFD = -1;
    if (setup) setup(c);
    pthread_mutex_lock(&notify_lock);
    if (!clients) { clients = [NSMutableDictionary dictionary]; states = [NSMutableDictionary dictionary]; }
    c->token = next_token++;
    clients[@(c->token)] = c;
    pthread_mutex_unlock(&notify_lock);
    watch_log();
    *out_token = c->token;
    return NOTIFY_STATUS_OK;
}
static _ISIMNotifyClient *client(int token) {
    pthread_mutex_lock(&notify_lock);
    _ISIMNotifyClient *c = clients[@(token)];
    pthread_mutex_unlock(&notify_lock);
    return c;
}

uint32_t notify_register_check(const char *name, int *out_token) { return add_client(name, 0, out_token, nil); }
uint32_t notify_register_dispatch(const char *name, int *out_token, dispatch_queue_t queue, notify_handler_t handler) {
    if (!queue || !handler) return NOTIFY_STATUS_NULL_INPUT;
    return add_client(name, 1, out_token, ^(_ISIMNotifyClient *c) { c->queue = queue; c->handler = [handler copy]; });
}
uint32_t notify_register_signal(const char *name, int sig, int *out_token) {
    if (sig <= 0 || sig >= 32) return NOTIFY_STATUS_INVALID_SIGNAL;
    return add_client(name, 2, out_token, ^(_ISIMNotifyClient *c) { c->sig = sig; });
}
/* the read end gets each notification as the token in network byte order; NOTIFY_REUSE shares *notify_fd's pipe */
uint32_t notify_register_file_descriptor(const char *name, int *notify_fd, int flags, int *out_token) {
    if (!notify_fd) return NOTIFY_STATUS_NULL_INPUT;
    int writeFD = -1;
    if (flags & NOTIFY_REUSE) {
        pthread_mutex_lock(&notify_lock);
        for (_ISIMNotifyClient *c in clients.allValues) if (c->kind == 3 && c->sig == *notify_fd) writeFD = c->writeFD;
        pthread_mutex_unlock(&notify_lock);
        if (writeFD < 0) return NOTIFY_STATUS_INVALID_FILE;
    } else {
        int p[2];
        if (pipe(p) != 0) return NOTIFY_STATUS_FAILED;
        *notify_fd = p[0]; writeFD = p[1];
    }
    int readFD = *notify_fd;
    return add_client(name, 3, out_token, ^(_ISIMNotifyClient *c) { c->writeFD = writeFD; c->sig = readFD; });
}
uint32_t notify_check(int token, int *check) {
    _ISIMNotifyClient *c = client(token);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    if (c->kind != 0) return NOTIFY_STATUS_INVALID_REQUEST;
    pthread_mutex_lock(&notify_lock);
    if (check) *check = c->changed;
    c->changed = NO;
    pthread_mutex_unlock(&notify_lock);
    return NOTIFY_STATUS_OK;
}
uint32_t notify_cancel(int token) {
    pthread_mutex_lock(&notify_lock);
    _ISIMNotifyClient *c = clients[@(token)];
    if (c) [clients removeObjectForKey:@(token)];
    BOOL shared = NO;
    for (_ISIMNotifyClient *o in clients.allValues) if (c && o->kind == 3 && o->writeFD == c->writeFD) shared = YES;
    pthread_mutex_unlock(&notify_lock);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    if (c->kind == 3 && !shared) close(c->writeFD);
    return NOTIFY_STATUS_OK;
}
uint32_t notify_suspend(int token) {
    _ISIMNotifyClient *c = client(token);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    c->suspended = YES;
    return NOTIFY_STATUS_OK;
}
/* posts that arrived while suspended are delivered once */
uint32_t notify_resume(int token) {
    _ISIMNotifyClient *c = client(token);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    c->suspended = NO;
    if (c->pending) { c->pending = NO; deliver(c); }
    return NOTIFY_STATUS_OK;
}
uint32_t notify_set_state(int token, uint64_t state64) {
    _ISIMNotifyClient *c = client(token);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    pthread_mutex_lock(&notify_lock);
    states[c->name] = @(state64);
    pthread_mutex_unlock(&notify_lock);
    return NOTIFY_STATUS_OK;
}
uint32_t notify_get_state(int token, uint64_t *state64) {
    _ISIMNotifyClient *c = client(token);
    if (!c) return NOTIFY_STATUS_INVALID_TOKEN;
    if (!state64) return NOTIFY_STATUS_NULL_INPUT;
    pthread_mutex_lock(&notify_lock);
    *state64 = states[c->name].unsignedLongLongValue;
    pthread_mutex_unlock(&notify_lock);
    return NOTIFY_STATUS_OK;
}
bool notify_is_valid_token(int val) { return client(val) != nil; }
/* isim has no Mach ports */
uint32_t notify_register_mach_port(const char *name, mach_port_t *notify_port, int flags, int *out_token) {
    return name ? NOTIFY_STATUS_FAILED : NOTIFY_STATUS_INVALID_NAME;
}
