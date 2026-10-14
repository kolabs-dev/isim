/* isim Foundation: Darwin notifications (<notify.h>): notify_post and the check, dispatch, signal and file-descriptor
 * clients, suspension and the per-name state. Adapted: delivered within the app's process; Mach port registrations
 * are not supported. */
#import <Foundation/Foundation.h>
#include <notify.h>
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <netinet/in.h>

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

uint32_t notify_post(const char *name) {
    if (!name) return NOTIFY_STATUS_INVALID_NAME;
    NSString *n = @(name);
    NSMutableArray *ready = [NSMutableArray array];
    pthread_mutex_lock(&notify_lock);
    for (_ISIMNotifyClient *c in clients.allValues) {
        if (![c->name isEqualToString:n]) continue;
        if (c->suspended) c->pending = YES;
        else [ready addObject:c];
    }
    pthread_mutex_unlock(&notify_lock);
    for (_ISIMNotifyClient *c in ready) deliver(c);
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
