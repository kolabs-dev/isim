// XPC on isim (XPCTest.app, issue #357): the C API and NSXPCConnection between two processes of one device. The
// test runs this app twice on one ISIM_DATA: XPC_ROLE=server listens (a connection listener, a session listener, a
// listener that rejects its peers and an NSXPCListener) and XPC_ROLE=client talks to it; each prints "N/M passed".
#import <Foundation/Foundation.h>
#include <xpc/xpc.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; int ok_ = (cond); char what_[300]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (ok_) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } fflush(stdout); } while (0)

#define SVC_CONN "dev.isim.xpctest.connection"
#define SVC_SESSION "dev.isim.xpctest.session"
#define SVC_REJECT "dev.isim.xpctest.reject"
#define SVC_NSXPC "dev.isim.xpctest.nsxpc"

@protocol XPCTestService
- (void)add:(NSInteger)a to:(NSInteger)b reply:(void (^)(NSInteger sum, NSString *text))reply;
- (void)reverse:(NSArray<NSString *> *)items flag:(BOOL)flag reply:(void (^)(NSArray<NSString *> *reversed, BOOL flag, double half))reply;
- (void)note:(NSString *)text;
- (void)lastNote:(void (^)(NSString *text, pid_t pid))reply;
@end

@interface Service : NSObject <XPCTestService>
@property (copy) NSString *last;
@end
@implementation Service
- (void)add:(NSInteger)a to:(NSInteger)b reply:(void (^)(NSInteger, NSString *))reply {
    reply(a + b, [NSString stringWithFormat:@"%ld+%ld", (long)a, (long)b]);
}
- (void)reverse:(NSArray<NSString *> *)items flag:(BOOL)flag reply:(void (^)(NSArray<NSString *> *, BOOL, double))reply {
    reply(items.reverseObjectEnumerator.allObjects, !flag, items.count / 2.0);
}
- (void)note:(NSString *)text { self.last = text; }
- (void)lastNote:(void (^)(NSString *, pid_t))reply { reply(self.last ?: @"(none)", NSXPCConnection.currentConnection.processIdentifier); }
@end

@interface Delegate : NSObject <NSXPCListenerDelegate>
@property (strong) Service *service;
@end
@implementation Delegate
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)c {
    c.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCTestService)];
    c.exportedObject = self.service;
    [c resume];
    return YES;
}
@end

static int wait_for(dispatch_semaphore_t s, double seconds) {
    return dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC))) == 0;
}

/* objects in one process */
static void objects(void) {
    uuid_t u = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    xpc_object_t d = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(d, "name", "isim");
    xpc_dictionary_set_int64(d, "i", -42);
    xpc_dictionary_set_uint64(d, "u", 42);
    xpc_dictionary_set_double(d, "d", 2.5);
    xpc_dictionary_set_bool(d, "b", true);
    xpc_dictionary_set_data(d, "data", "abc", 3);
    xpc_dictionary_set_uuid(d, "uuid", u);
    xpc_dictionary_set_date(d, "date", 1000);
    xpc_object_t a = xpc_array_create_empty();
    xpc_array_append_value(a, xpc_string_create("x"));
    xpc_array_set_int64(a, XPC_ARRAY_APPEND, 7);
    xpc_dictionary_set_value(d, "array", a);
    size_t n = 0;
    const void *bytes = xpc_dictionary_get_data(d, "data", &n);
    CHECK(xpc_get_type(d) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_count(d) == 9 && !strcmp(xpc_dictionary_get_string(d, "name"), "isim")
          && xpc_dictionary_get_int64(d, "i") == -42 && xpc_dictionary_get_uint64(d, "u") == 42 && xpc_dictionary_get_double(d, "d") == 2.5
          && xpc_dictionary_get_bool(d, "b") && n == 3 && !memcmp(bytes, "abc", 3) && !memcmp(xpc_dictionary_get_uuid(d, "uuid"), u, 16)
          && xpc_dictionary_get_date(d, "date") == 1000, "dictionary setters and getters");
    CHECK(xpc_array_get_count(a) == 2 && !strcmp(xpc_array_get_string(a, 0), "x") && xpc_array_get_int64(a, 1) == 7
          && xpc_get_type(xpc_dictionary_get_array(d, "array")) == XPC_TYPE_ARRAY, "arrays (append, XPC_ARRAY_APPEND)");
    xpc_object_t c = xpc_copy(d);
    CHECK(xpc_equal(c, d) && xpc_hash(c) == xpc_hash(d) && c != d, "xpc_copy, xpc_equal, xpc_hash");
    xpc_dictionary_set_value(c, "name", NULL);
    CHECK(!xpc_equal(c, d) && xpc_dictionary_get_count(c) == 8, "removing a key with a NULL value");
    __block int keys = 0;
    xpc_dictionary_apply(d, ^bool(const char *k, xpc_object_t v) { keys++; return true; });
    __block int elems = 0;
    xpc_array_apply(a, ^bool(size_t i, xpc_object_t v) { elems++; return i < 0; });
    CHECK(keys == 9 && elems == 1, "xpc_dictionary_apply, xpc_array_apply (stops)");
    char *desc = xpc_copy_description(d);
    CHECK(strstr(desc, "<dictionary: ") && strstr(desc, "\"name\" => <string: ") && strstr(desc, "contents = \"isim\""), "xpc_copy_description");
    free(desc);
    CHECK(xpc_bool_create(true) == XPC_BOOL_TRUE && xpc_bool_get_value(XPC_BOOL_TRUE) && !xpc_bool_get_value(XPC_BOOL_FALSE)
          && !strcmp(xpc_type_get_name(xpc_get_type(XPC_BOOL_TRUE)), "bool"), "XPC_BOOL_TRUE / FALSE");
    CHECK(xpc_get_type(XPC_ERROR_CONNECTION_INVALID) == XPC_TYPE_ERROR
          && !strcmp(xpc_dictionary_get_string(XPC_ERROR_CONNECTION_INTERRUPTED, XPC_ERROR_KEY_DESCRIPTION), "Connection interrupted"),
          "XPC_ERROR_* and XPC_ERROR_KEY_DESCRIPTION");
    xpc_object_t s = xpc_string_create_with_format("%d-%s", 5, "five");
    CHECK(!strcmp(xpc_string_get_string_ptr(s), "5-five") && xpc_string_get_length(s) == 6, "xpc_string_create_with_format");
    xpc_object_t dd = xpc_data_create("hello", 5);
    char buf[3] = {0};
    CHECK(xpc_data_get_bytes(dd, buf, 1, 3) == 3 && !memcmp(buf, "ell", 3) && xpc_data_get_length(dd) == 5, "xpc_data_get_bytes");
    int fds[2]; pipe(fds);
    xpc_object_t fd = xpc_fd_create(fds[1]);
    int dup = xpc_fd_dup(fd);
    CHECK(fd && dup >= 0 && write(dup, "z", 1) == 1, "xpc_fd_create / dup");
    close(dup); close(fds[0]); close(fds[1]);
    CHECK(xpc_dictionary_create_reply(d) == NULL, "no reply to a message nobody sent");
}

static void activities(void) {
    dispatch_semaphore_t ran = dispatch_semaphore_create(0);
    __block NSMutableArray *states = [NSMutableArray array];
    xpc_object_t criteria = xpc_dictionary_create_empty();
    xpc_dictionary_set_int64(criteria, XPC_ACTIVITY_DELAY, 0);
    xpc_dictionary_set_bool(criteria, XPC_ACTIVITY_REPEATING, false);
    xpc_activity_register("dev.isim.xpctest.activity", criteria, ^(xpc_activity_t act) {
        xpc_activity_state_t st = xpc_activity_get_state(act);
        [states addObject:@(st)];
        if (st == XPC_ACTIVITY_STATE_RUN) { xpc_activity_set_state(act, XPC_ACTIVITY_STATE_DONE); dispatch_semaphore_signal(ran); }
    });
    CHECK(wait_for(ran, 5) && [states isEqual:(@[ @(XPC_ACTIVITY_STATE_CHECK_IN), @(XPC_ACTIVITY_STATE_RUN) ])],
          "xpc_activity_register: checked in, then run (%s)", states.description.UTF8String);
    xpc_activity_unregister("dev.isim.xpctest.activity");
}

/* ================= server ================= */
static int server(void) {
    __block int dones = 0;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    /* the connection API: echo with a reply; "endpoint" answers an anonymous listener's endpoint; "done" ends */
    xpc_connection_t anon = xpc_connection_create(NULL, NULL);
    xpc_connection_set_event_handler(anon, ^(xpc_object_t peer) {
        if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
        xpc_connection_set_event_handler(peer, ^(xpc_object_t m) {
            if (xpc_get_type(m) != XPC_TYPE_DICTIONARY) return;
            xpc_object_t r = xpc_dictionary_create_reply(m);
            xpc_dictionary_set_string(r, "via", "anonymous");
            xpc_connection_send_message(peer, r);
        });
        xpc_connection_resume(peer);
    });
    xpc_connection_resume(anon);
    xpc_connection_t listener = xpc_connection_create_mach_service(SVC_CONN, NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);
    xpc_connection_set_event_handler(listener, ^(xpc_object_t peer) {
        if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
        xpc_connection_set_event_handler(peer, ^(xpc_object_t m) {
            if (xpc_get_type(m) != XPC_TYPE_DICTIONARY) return;
            const char *op = xpc_dictionary_get_string(m, "op");
            if (op && !strcmp(op, "done")) { if (++dones == 3) dispatch_semaphore_signal(finished); return; }
            xpc_object_t r = xpc_dictionary_create_reply(m);
            if (!r) { printf("server: one-way message %s\n", op ?: "?"); fflush(stdout); return; }
            if (op && !strcmp(op, "endpoint")) xpc_dictionary_set_value(r, "endpoint", xpc_endpoint_create(anon));
            else {
                xpc_dictionary_set_value(r, "echo", m);
                xpc_dictionary_set_int64(r, "sum", xpc_dictionary_get_int64(m, "a") + xpc_dictionary_get_int64(m, "b"));
                xpc_dictionary_set_int64(r, "pid", getpid());
                xpc_dictionary_set_int64(r, "peer", xpc_connection_get_pid(peer));
            }
            xpc_connection_send_message(peer, r);
        });
        xpc_connection_resume(peer);
    });
    xpc_connection_resume(listener);
    /* the session API */
    xpc_rich_error_t err = NULL;
    xpc_listener_t sl = xpc_listener_create(SVC_SESSION, NULL, XPC_LISTENER_CREATE_NONE, ^(xpc_session_t peer) {
        xpc_session_set_incoming_message_handler(peer, ^(xpc_object_t m) {
            const char *op = xpc_dictionary_get_string(m, "op");
            if (op && !strcmp(op, "done")) { if (++dones == 3) dispatch_semaphore_signal(finished); return; }
            xpc_object_t r = xpc_dictionary_create_reply(m);
            if (!r) return;
            xpc_dictionary_set_string(r, "upper", [[@(xpc_dictionary_get_string(m, "text") ?: "") uppercaseString] UTF8String]);
            xpc_session_send_message(peer, r);
        });
    }, &err);
    CHECK(sl && !err, "xpc_listener_create (a named service)");
    xpc_listener_t rl = xpc_listener_create(SVC_REJECT, NULL, XPC_LISTENER_CREATE_NONE, ^(xpc_session_t peer) {
        xpc_listener_reject_peer(peer, "not today");
    }, &err);
    CHECK(rl != NULL, "a listener that rejects its peers");
    /* NSXPCListener */
    Delegate *delegate = [Delegate new];
    delegate.service = [Service new];
    NSXPCListener *nl = [[NSXPCListener alloc] initWithMachServiceName:@SVC_NSXPC];
    nl.delegate = delegate;
    [nl resume];
    printf("xpc server ready\n"); fflush(stdout);
    /* the client sends "done" on the connection and the session; the NSXPC note counts as the third */
    __block BOOL noted = NO;
    for (int i = 0; i < 600 && dones < 3; i++) {
        usleep(50000);
        if (!noted && [delegate.service.last isEqual:@"done"]) { noted = YES; if (++dones == 3) break; }
    }
    CHECK(dones >= 3, "the client finished on all three listeners");
    xpc_listener_cancel(sl); xpc_listener_cancel(rl); xpc_connection_cancel(listener); [nl invalidate];
    (void)finished;
    return 0;
}

/* ================= client ================= */
static int client(void) {
    objects();
    activities();
    /* the connection API */
    xpc_connection_t c = xpc_connection_create_mach_service(SVC_CONN, NULL, 0);
    __block int errors = 0;
    xpc_connection_set_event_handler(c, ^(xpc_object_t e) { if (xpc_get_type(e) == XPC_TYPE_ERROR) errors++; });
    xpc_connection_resume(c);
    xpc_object_t m = xpc_dictionary_create_empty();
    xpc_dictionary_set_int64(m, "a", 40); xpc_dictionary_set_int64(m, "b", 2);
    xpc_dictionary_set_string(m, "s", "héllo");
    xpc_dictionary_set_double(m, "d", -1.25);
    xpc_dictionary_set_data(m, "data", "\0\1\2", 3);
    uuid_t u = { 0xaa, 0xbb };
    xpc_dictionary_set_uuid(m, "uuid", u);
    xpc_object_t arr = xpc_array_create_empty();
    xpc_array_set_bool(arr, XPC_ARRAY_APPEND, true); xpc_array_set_uint64(arr, XPC_ARRAY_APPEND, UINT64_MAX);
    xpc_dictionary_set_value(m, "arr", arr);
    xpc_object_t r = xpc_connection_send_message_with_reply_sync(c, m);
    xpc_object_t echo = xpc_get_type(r) == XPC_TYPE_DICTIONARY ? xpc_dictionary_get_value(r, "echo") : NULL;
    CHECK(xpc_get_type(r) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_int64(r, "sum") == 42, "send_message_with_reply_sync across processes");
    CHECK(echo && xpc_equal(echo, m), "every object type survives the trip (dictionary, string, numbers, data, uuid, array, bool)");
    CHECK(xpc_dictionary_get_int64(r, "pid") == xpc_connection_get_pid(c) && xpc_dictionary_get_int64(r, "pid") != getpid()
          && xpc_dictionary_get_int64(r, "peer") == getpid(), "xpc_connection_get_pid on both sides (%lld, me %d)",
          (long long)xpc_dictionary_get_int64(r, "pid"), (int)getpid());
    dispatch_semaphore_t got = dispatch_semaphore_create(0);
    __block int64_t asyncSum = 0;
    xpc_object_t m2 = xpc_dictionary_create_empty();
    xpc_dictionary_set_int64(m2, "a", 1); xpc_dictionary_set_int64(m2, "b", 2);
    xpc_connection_send_message_with_reply(c, m2, NULL, ^(xpc_object_t reply) {
        asyncSum = xpc_dictionary_get_int64(reply, "sum"); dispatch_semaphore_signal(got);
    });
    CHECK(wait_for(got, 5) && asyncSum == 3, "send_message_with_reply (async)");
    xpc_object_t one = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(one, "op", "one-way");
    xpc_connection_send_message(c, one);
    /* an endpoint in a message: a connection to the server's anonymous listener */
    xpc_object_t q = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(q, "op", "endpoint");
    xpc_object_t er = xpc_connection_send_message_with_reply_sync(c, q);
    xpc_connection_t ac = xpc_dictionary_create_connection(er, "endpoint");
    BOOL viaAnon = NO;
    if (ac) {
        xpc_connection_set_event_handler(ac, ^(xpc_object_t e) {});
        xpc_connection_resume(ac);
        xpc_object_t ar = xpc_connection_send_message_with_reply_sync(ac, xpc_dictionary_create_empty());
        viaAnon = xpc_get_type(ar) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_string(ar, "via") && !strcmp(xpc_dictionary_get_string(ar, "via"), "anonymous");
        xpc_connection_cancel(ac);
    }
    CHECK(ac && viaAnon, "an endpoint sent in a message reaches the anonymous listener");
    /* nobody listens: interrupted */
    xpc_connection_t none = xpc_connection_create_mach_service("dev.isim.xpctest.nobody", NULL, 0);
    xpc_connection_set_event_handler(none, ^(xpc_object_t e) {});
    xpc_connection_resume(none);
    CHECK(xpc_connection_send_message_with_reply_sync(none, xpc_dictionary_create_empty()) == XPC_ERROR_CONNECTION_INTERRUPTED,
          "a service nobody listens on: XPC_ERROR_CONNECTION_INTERRUPTED");
    xpc_connection_cancel(none);

    /* the session API */
    xpc_rich_error_t err = NULL;
    xpc_session_t s = xpc_session_create_mach_service(SVC_SESSION, NULL, XPC_SESSION_CREATE_NONE, &err);
    CHECK(s && !err, "xpc_session_create_mach_service");
    xpc_object_t sm = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(sm, "text", "quiet");
    xpc_object_t sr = s ? xpc_session_send_message_with_reply_sync(s, sm, &err) : NULL;
    CHECK(sr && !strcmp(xpc_dictionary_get_string(sr, "upper") ?: "", "QUIET"), "xpc_session_send_message_with_reply_sync");
    __block BOOL asyncOK = NO;
    if (s) xpc_session_send_message_with_reply_async(s, sm, ^(xpc_object_t reply, xpc_rich_error_t e) {
        asyncOK = reply && !e && !strcmp(xpc_dictionary_get_string(reply, "upper") ?: "", "QUIET"); dispatch_semaphore_signal(got);
    });
    CHECK(wait_for(got, 5) && asyncOK, "xpc_session_send_message_with_reply_async");
    xpc_rich_error_t missing = NULL;
    xpc_session_t ns = xpc_session_create_mach_service("dev.isim.xpctest.nobody", NULL, XPC_SESSION_CREATE_NONE, &missing);
    char *md = missing ? xpc_rich_error_copy_description(missing) : NULL;
    CHECK(!ns && missing && xpc_rich_error_can_retry(missing) && md && strstr(md, "No listener"), "a session to nobody fails to activate (%s)", md ?: "-");
    free(md);
    /* a listener that rejects: the session is cancelled with the reason */
    __block NSString *reasonText = @"";
    xpc_session_t rj = xpc_session_create_mach_service(SVC_REJECT, NULL, XPC_SESSION_CREATE_INACTIVE, NULL);
    xpc_session_set_cancel_handler(rj, ^(xpc_rich_error_t e) {
        char *d = xpc_rich_error_copy_description(e); reasonText = @(d ?: ""); free(d); dispatch_semaphore_signal(got);
    });
    xpc_session_activate(rj, NULL);
    xpc_session_send_message_with_reply_async(rj, sm, ^(xpc_object_t reply, xpc_rich_error_t e) {});
    CHECK(wait_for(got, 5) && [reasonText containsString:@"not today"], "a rejected session is cancelled (%s)", reasonText.UTF8String);

    /* NSXPCConnection */
    NSXPCConnection *nc = [[NSXPCConnection alloc] initWithMachServiceName:@SVC_NSXPC options:0];
    nc.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCTestService)];
    [nc resume];
    __block NSInteger sum = 0; __block NSString *text = nil;
    [[nc remoteObjectProxyWithErrorHandler:^(NSError *e) { dispatch_semaphore_signal(got); }] add:40 to:2 reply:^(NSInteger s, NSString *t) {
        sum = s; text = t; dispatch_semaphore_signal(got);
    }];
    CHECK(wait_for(got, 5) && sum == 42 && [text isEqual:@"40+2"], "NSXPCConnection: a reply block with an integer and a string (%ld %s)",
          (long)sum, text.UTF8String ?: "nil");
    __block NSArray *rev = nil; __block BOOL flag = YES; __block double half = 0;
    [[nc synchronousRemoteObjectProxyWithErrorHandler:^(NSError *e) {}] reverse:@[ @"a", @"b", @"c" ] flag:YES reply:^(NSArray *r, BOOL f, double h) {
        rev = r; flag = f; half = h;
    }];
    CHECK([rev isEqual:(@[ @"c", @"b", @"a" ])] && !flag && half == 1.5, "synchronousRemoteObjectProxy: an array, a BOOL and a double");
    [nc.remoteObjectProxy note:@"hello"];
    __block NSString *last = nil; __block pid_t serverSeen = 0;
    [nc.remoteObjectProxy lastNote:^(NSString *t, pid_t pid) { last = t; serverSeen = pid; dispatch_semaphore_signal(got); }];
    CHECK(wait_for(got, 5) && [last isEqual:@"hello"] && serverSeen == getpid(), "a one-way message, then currentConnection.processIdentifier");
    NSXPCConnection *bad = [[NSXPCConnection alloc] initWithMachServiceName:@"dev.isim.xpctest.nobody" options:0];
    bad.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCTestService)];
    [bad resume];
    __block NSError *badError = nil;
    [[bad remoteObjectProxyWithErrorHandler:^(NSError *e) { badError = e; dispatch_semaphore_signal(got); }] add:1 to:1 reply:^(NSInteger s, NSString *t) {}];
    CHECK(wait_for(got, 5) && badError.code == NSXPCConnectionInterrupted && [badError.domain isEqual:NSCocoaErrorDomain],
          "the error handler: NSXPCConnectionInterrupted (%ld)", (long)badError.code);
    [bad invalidate];

    CHECK(errors == 0, "no errors on the connection before the end (%d)", errors);
    /* done: tell the server on all three (it exits then: the connection is interrupted) */
    xpc_object_t done = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(done, "op", "done");
    xpc_connection_send_message(c, done);
    if (s) xpc_session_send_message(s, done);
    [nc.remoteObjectProxy note:@"done"];
    usleep(300000);
    xpc_connection_cancel(c);
    if (s) xpc_session_cancel(s);
    [nc invalidate];
    return 0;
}

int main(void) {
    @autoreleasepool {
        const char *role = getenv("XPC_ROLE") ?: "client";
        if (!strcmp(role, "server")) server(); else client();
        printf("xpc %s: %d/%d passed\n", role, checks - failures, checks);
        return failures ? 1 : 0;
    }
}
