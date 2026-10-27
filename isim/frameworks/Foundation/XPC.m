/* isim Foundation: XPC (<xpc/xpc.h>): objects, connections, sessions, listeners, endpoints and activities (issue #357).
 * Self-authored, Apple's API. Adapted:
 *   - a named service is a Unix socket every process of the booted device can reach: the app, its extensions, other
 *     apps (Apple: a launchd service). Its path is derived from the device's data directory and the service name
 *     (/tmp/isim-xpc-<uid>/<hash of $ISIM_DATA>-<hash of the name>: short enough for a socket address), and
 *     $ISIM_DATA/Library/isim/xpc/<name> records which process listens (for people and agents). An anonymous listener
 *     gets a unique path, which its endpoint carries.
 *   - nothing launches a service on demand: a connection or session to a service nobody listens on is interrupted
 *     (connections retry on the next message) or fails to activate (sessions).
 *   - messages are length-prefixed frames carrying isim's encoding of the XPC objects; file descriptors and shared
 *     memory stay in their process (they arrive as null).
 *   - code-signing, entitlement and team requirements are accepted and not checked (isim does not sign code).
 *   - activities run in their process after their delay, and again every interval when repeating.
 * NSXPCConnection (NSXPC.m) uses the connections below. */
#import <Foundation/Foundation.h>
#include <xpc/xpc.h>
#include <objc/runtime.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <pthread.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include "isim_foundation.h"
#import "isim_xpc.h"

#ifndef SUN_LEN
#define SUN_LEN(su) (sizeof(*(su)) - sizeof((su)->sun_path) + strlen((su)->sun_path))
#endif

/* ================= types ================= */
struct _xpc_type_s { const char *name; };
#define TYPE(n) const struct _xpc_type_s _xpc_type_##n = { #n };
TYPE(connection) TYPE(endpoint) TYPE(null) TYPE(bool) TYPE(int64) TYPE(uint64) TYPE(double) TYPE(date) TYPE(data) TYPE(string)
TYPE(uuid) TYPE(fd) TYPE(shmem) TYPE(array) TYPE(dictionary) TYPE(error) TYPE(activity) TYPE(session) TYPE(rich_error) TYPE(listener)
#undef TYPE

const char *const XPC_ERROR_KEY_DESCRIPTION = "XPCErrorDescription";
const char *const XPC_EVENT_KEY_NAME = "XPCEventName";

/* ================= the objects ================= */
@implementation OS_xpc_object
- (xpc_type_t)_type { return XPC_TYPE_NULL; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<%s: %p>", [self _type]->name, self]; }
- (BOOL)_equal:(OS_xpc_object *)other { return self == other; }
- (NSUInteger)_hash { return (NSUInteger)self; }
- (id)_copy { return self; }
- (NSString *)description { NSMutableString *s = [NSMutableString string]; [self _describe:s indent:0]; return s; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[OS_xpc_object class]] && [self _equal:o]; }
- (NSUInteger)hash { return [self _hash]; }
@end

@interface _XPCNull : OS_xpc_object
@end
@implementation _XPCNull
- (xpc_type_t)_type { return XPC_TYPE_NULL; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCNull class]]; }
- (NSUInteger)_hash { return 0x6e756c6c; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<null: %p>", self]; }
@end

struct _xpc_bool_s { Class isa; bool value; };
struct _xpc_bool_s _xpc_bool_true = { Nil, true }, _xpc_bool_false = { Nil, false };
@interface _XPCBool : _XPCStatic { @public bool _value; }
@end
@implementation _XPCBool
+ (void)load { _xpc_bool_true.isa = self; _xpc_bool_false.isa = self; }
- (xpc_type_t)_type { return XPC_TYPE_BOOL; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCBool class]] && ((_XPCBool *)o)->_value == _value; }
- (NSUInteger)_hash { return _value; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<bool: %p>: %s", self, _value ? "true" : "false"]; }
@end
#define XBOOL(v) ((__bridge xpc_object_t)(void *)((v) ? &_xpc_bool_true : &_xpc_bool_false))

@interface _XPCNumber : OS_xpc_object { @public xpc_type_t _kind; union { int64_t i; uint64_t u; double d; } _v; }
@end
@implementation _XPCNumber
- (xpc_type_t)_type { return _kind; }
- (BOOL)_equal:(OS_xpc_object *)o {
    if (![o isKindOfClass:[_XPCNumber class]] || ((_XPCNumber *)o)->_kind != _kind) return NO;
    return _kind == XPC_TYPE_DOUBLE ? ((_XPCNumber *)o)->_v.d == _v.d : ((_XPCNumber *)o)->_v.u == _v.u;
}
- (NSUInteger)_hash { return (NSUInteger)_v.u ^ (NSUInteger)_kind; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    if (_kind == XPC_TYPE_INT64) [out appendFormat:@"<int64: %p>: %lld", self, (long long)_v.i];
    else if (_kind == XPC_TYPE_UINT64) [out appendFormat:@"<uint64: %p>: %llu", self, (unsigned long long)_v.u];
    else if (_kind == XPC_TYPE_DOUBLE) [out appendFormat:@"<double: %p>: %.17g", self, _v.d];
    else [out appendFormat:@"<date: %p> %lld", self, (long long)_v.i];
}
@end
static xpc_object_t number(xpc_type_t kind, uint64_t bits) {
    _XPCNumber *n = [_XPCNumber new]; n->_kind = kind; n->_v.u = bits; return n;
}

@interface _XPCString : OS_xpc_object { @public char *_s; size_t _len; }
@end
@implementation _XPCString
- (void)dealloc { free(_s); }
- (xpc_type_t)_type { return XPC_TYPE_STRING; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCString class]] && ((_XPCString *)o)->_len == _len && !memcmp(((_XPCString *)o)->_s, _s, _len); }
- (NSUInteger)_hash { NSUInteger h = 5381; for (size_t i = 0; i < _len; i++) h = h * 33 + (unsigned char)_s[i]; return h; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    [out appendFormat:@"<string: %p> { length = %zu, contents = \"%s\" }", self, _len, _s];
}
@end
static xpc_object_t string_n(const char *s, size_t n) {
    _XPCString *o = [_XPCString new]; o->_s = malloc(n + 1); memcpy(o->_s, s, n); o->_s[n] = 0; o->_len = n; return o;
}

@interface _XPCData : OS_xpc_object { @public NSData *_d; }
@end
@implementation _XPCData
- (xpc_type_t)_type { return XPC_TYPE_DATA; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCData class]] && [((_XPCData *)o)->_d isEqualToData:_d]; }
- (NSUInteger)_hash { return _d.hash; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<data: %p> { length = %lu bytes }", self, (unsigned long)_d.length]; }
@end

@interface _XPCUUID : OS_xpc_object { @public uuid_t _u; }
@end
@implementation _XPCUUID
- (xpc_type_t)_type { return XPC_TYPE_UUID; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCUUID class]] && !memcmp(((_XPCUUID *)o)->_u, _u, 16); }
- (NSUInteger)_hash { NSUInteger h; memcpy(&h, _u, sizeof h); return h; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    [out appendFormat:@"<uuid: %p> %@", self, [[[NSUUID alloc] initWithUUIDBytes:_u] UUIDString]];
}
@end

@interface _XPCFD : OS_xpc_object { @public int _fd; }
@end
@implementation _XPCFD
- (void)dealloc { if (_fd >= 0) close(_fd); }
- (xpc_type_t)_type { return XPC_TYPE_FD; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<fd: %p> { fd = %d }", self, _fd]; }
@end

@interface _XPCShmem : OS_xpc_object { @public void *_region; size_t _length; }
@end
@implementation _XPCShmem
- (xpc_type_t)_type { return XPC_TYPE_SHMEM; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<shmem: %p> { length = %zu }", self, _length]; }
@end

@interface _XPCArray : OS_xpc_object { @public NSMutableArray *_a; }
@end
@implementation _XPCArray
- (instancetype)init { if ((self = [super init])) _a = [NSMutableArray array]; return self; }
- (xpc_type_t)_type { return XPC_TYPE_ARRAY; }
- (BOOL)_equal:(OS_xpc_object *)o {
    if (![o isKindOfClass:[_XPCArray class]] || ((_XPCArray *)o)->_a.count != _a.count) return NO;
    for (NSUInteger i = 0; i < _a.count; i++) if (![_a[i] _equal:((_XPCArray *)o)->_a[i]]) return NO;
    return YES;
}
- (NSUInteger)_hash { return _a.count; }
- (id)_copy { _XPCArray *c = [_XPCArray new]; for (OS_xpc_object *v in _a) [c->_a addObject:[v _copy]]; return c; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    [out appendFormat:@"<array: %p> { count = %lu, capacity = %lu, contents =\n", self, (unsigned long)_a.count, (unsigned long)_a.count];
    for (NSUInteger i = 0; i < _a.count; i++) {
        [out appendFormat:@"%*s%lu: ", (indent + 1) * 4, "", (unsigned long)i];
        [_a[i] _describe:out indent:indent + 1];
        [out appendString:@"\n"];
    }
    [out appendFormat:@"%*s}", indent * 4, ""];
}
@end

@class _XPCLink;
@interface _XPCDictionary : OS_xpc_object {
@public
    NSMutableArray<NSString *> *_keys;
    NSMutableDictionary<NSString *, OS_xpc_object *> *_values;
    _XPCLink *_from;            /* the connection or session the message came in on */
    uint64_t _serial;           /* its serial there */
    BOOL _wantsReply;           /* sent with a reply handler */
    BOOL _sync;                 /* by a sender waiting for the reply */
    _XPCLink *_replyTo;         /* a reply (xpc_dictionary_create_reply): goes back on this link */
    uint64_t _replySerial;
}
@end
@implementation _XPCDictionary
- (instancetype)init { if ((self = [super init])) { _keys = [NSMutableArray array]; _values = [NSMutableDictionary dictionary]; } return self; }
- (xpc_type_t)_type { return XPC_TYPE_DICTIONARY; }
- (void)_set:(NSString *)k value:(OS_xpc_object *)v {
    if (!v) { if (_values[k]) { [_values removeObjectForKey:k]; [_keys removeObject:k]; } return; }
    if (!_values[k]) [_keys addObject:k];
    _values[k] = v;
}
- (BOOL)_equal:(OS_xpc_object *)o {
    if (![o isKindOfClass:[_XPCDictionary class]] || ((_XPCDictionary *)o)->_values.count != _values.count) return NO;
    for (NSString *k in _keys) { OS_xpc_object *ov = ((_XPCDictionary *)o)->_values[k]; if (!ov || ![_values[k] _equal:ov]) return NO; }
    return YES;
}
- (NSUInteger)_hash { return _values.count; }
- (id)_copy { _XPCDictionary *c = [_XPCDictionary new]; for (NSString *k in _keys) [c _set:k value:[_values[k] _copy]]; return c; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    [out appendFormat:@"<dictionary: %p> { count = %lu, transaction: 0, voucher = 0x0, contents =\n", self, (unsigned long)_keys.count];
    for (NSString *k in _keys) {
        [out appendFormat:@"%*s\"%@\" => ", (indent + 1) * 4, "", k];
        [_values[k] _describe:out indent:indent + 1];
        [out appendString:@"\n"];
    }
    [out appendFormat:@"%*s}", indent * 4, ""];
}
@end

/* the errors (dictionaries with XPC_ERROR_KEY_DESCRIPTION) and XPC_ACTIVITY_CHECK_IN */
struct _xpc_dictionary_s { Class isa; const char *desc; };
struct _xpc_dictionary_s _xpc_error_connection_interrupted = { Nil, "Connection interrupted" };
struct _xpc_dictionary_s _xpc_error_connection_invalid = { Nil, "Connection invalid" };
struct _xpc_dictionary_s _xpc_error_termination_imminent = { Nil, "Process termination imminent" };
struct _xpc_dictionary_s _xpc_error_peer_code_signing_requirement = { Nil, "Peer forbidden by code signing requirement" };
struct _xpc_dictionary_s _xpc_activity_check_in = { Nil, NULL };
@interface _XPCError : _XPCStatic { @public const char *_desc; }
@end
@implementation _XPCError
+ (void)load {
    _xpc_error_connection_interrupted.isa = _xpc_error_connection_invalid.isa = _xpc_error_termination_imminent.isa = self;
    _xpc_error_peer_code_signing_requirement.isa = _xpc_activity_check_in.isa = self;
}
- (xpc_type_t)_type { return _desc ? XPC_TYPE_ERROR : XPC_TYPE_DICTIONARY; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    if (_desc) [out appendFormat:@"<error: %p> { count = 1, transaction: 0, voucher = 0x0, contents =\n%*s\"XPCErrorDescription\" => <string: 0x0> { length = %zu, contents = \"%s\" }\n%*s}",
                self, (indent + 1) * 4, "", strlen(_desc), _desc, indent * 4, ""];
    else [out appendFormat:@"<dictionary: %p> { count = 0 }", self];
}
@end
#define XERR(e) ((__bridge xpc_object_t)(void *)&(e))

@interface _XPCRichError : OS_xpc_object { @public NSString *_desc; BOOL _retry; }
@end
@implementation _XPCRichError
- (xpc_type_t)_type { return XPC_TYPE_RICH_ERROR; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<rich error: %p> { %@ }", self, _desc]; }
@end
static xpc_rich_error_t rich_error(NSString *desc, BOOL retry) {
    _XPCRichError *e = [_XPCRichError new]; e->_desc = desc; e->_retry = retry; return (xpc_rich_error_t)e;
}

@interface _XPCEndpoint : OS_xpc_object { @public NSString *_path; NSString *_name; }
@end
@implementation _XPCEndpoint
- (xpc_type_t)_type { return XPC_TYPE_ENDPOINT; }
- (BOOL)_equal:(OS_xpc_object *)o { return [o isKindOfClass:[_XPCEndpoint class]] && [((_XPCEndpoint *)o)->_path isEqual:_path]; }
- (NSUInteger)_hash { return _path.hash; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<endpoint: %p> { name = %@ }", self, _name ?: @"(anonymous)"]; }
@end

/* ================= object functions ================= */
#define O(x) ((__bridge OS_xpc_object *)(__bridge void *)(x))
xpc_object_t xpc_retain(xpc_object_t o) { return (__bridge xpc_object_t)(__bridge_retained void *)o; }
void xpc_release(xpc_object_t o) { if (o) CFBridgingRelease((__bridge CFTypeRef)o); }
xpc_type_t xpc_get_type(xpc_object_t o) { return [O(o) _type]; }
const char *xpc_type_get_name(xpc_type_t t) { return t ? t->name : "unknown"; }
xpc_object_t xpc_copy(xpc_object_t o) { return o ? [O(o) _copy] : nil; }
bool xpc_equal(xpc_object_t a, xpc_object_t b) { return a == b || (a && b && [O(a) _equal:O(b)]); }
size_t xpc_hash(xpc_object_t o) { return [O(o) _hash]; }
char *xpc_copy_description(xpc_object_t o) { return strdup(O(o).description.UTF8String ?: ""); }
const char *xpc_debugger_api_misuse_info(void) { return NULL; }
xpc_type_t _isim_xpc_type(const char *name) {
    static const struct _xpc_type_s *all[] = { &_xpc_type_connection, &_xpc_type_endpoint, &_xpc_type_null, &_xpc_type_bool,
        &_xpc_type_int64, &_xpc_type_uint64, &_xpc_type_double, &_xpc_type_date, &_xpc_type_data, &_xpc_type_string, &_xpc_type_uuid,
        &_xpc_type_fd, &_xpc_type_shmem, &_xpc_type_array, &_xpc_type_dictionary, &_xpc_type_error, &_xpc_type_activity,
        &_xpc_type_session, &_xpc_type_rich_error, &_xpc_type_listener };
    for (size_t i = 0; i < sizeof all / sizeof *all; i++) if (!strcmp(all[i]->name, name)) return all[i];
    return NULL;
}
xpc_object_t _isim_xpc_constant(const char *name) {
    if (!strcmp(name, "true")) return XBOOL(1);
    if (!strcmp(name, "false")) return XBOOL(0);
    if (!strcmp(name, "interrupted")) return XERR(_xpc_error_connection_interrupted);
    if (!strcmp(name, "invalid")) return XERR(_xpc_error_connection_invalid);
    if (!strcmp(name, "termination")) return XERR(_xpc_error_termination_imminent);
    if (!strcmp(name, "codesigning")) return XERR(_xpc_error_peer_code_signing_requirement);
    if (!strcmp(name, "checkin")) return XERR(_xpc_activity_check_in);
    return nil;
}

xpc_object_t xpc_null_create(void) { return [_XPCNull new]; }
xpc_object_t xpc_bool_create(bool v) { return XBOOL(v); }
bool xpc_bool_get_value(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCBool class]] && ((_XPCBool *)O(o))->_value; }
xpc_object_t xpc_int64_create(int64_t v) { return number(XPC_TYPE_INT64, (uint64_t)v); }
xpc_object_t xpc_uint64_create(uint64_t v) { return number(XPC_TYPE_UINT64, v); }
xpc_object_t xpc_double_create(double v) { uint64_t b; memcpy(&b, &v, 8); return number(XPC_TYPE_DOUBLE, b); }
xpc_object_t xpc_date_create(int64_t v) { return number(XPC_TYPE_DATE, (uint64_t)v); }
xpc_object_t xpc_date_create_from_current(void) { return xpc_date_create((int64_t)([NSDate date].timeIntervalSince1970 * 1e9)); }
static _XPCNumber *num_of(xpc_object_t o, xpc_type_t t) {
    return [O(o) isKindOfClass:[_XPCNumber class]] && ((_XPCNumber *)O(o))->_kind == t ? (_XPCNumber *)O(o) : nil;
}
int64_t xpc_int64_get_value(xpc_object_t o) { _XPCNumber *n = num_of(o, XPC_TYPE_INT64); return n ? n->_v.i : 0; }
uint64_t xpc_uint64_get_value(xpc_object_t o) { _XPCNumber *n = num_of(o, XPC_TYPE_UINT64); return n ? n->_v.u : 0; }
double xpc_double_get_value(xpc_object_t o) { _XPCNumber *n = num_of(o, XPC_TYPE_DOUBLE); return n ? n->_v.d : NAN; }
int64_t xpc_date_get_value(xpc_object_t o) { _XPCNumber *n = num_of(o, XPC_TYPE_DATE); return n ? n->_v.i : 0; }

xpc_object_t xpc_data_create(const void *bytes, size_t len) { _XPCData *d = [_XPCData new]; d->_d = [NSData dataWithBytes:bytes length:len]; return d; }
xpc_object_t xpc_data_create_with_dispatch_data(dispatch_data_t dd) {
    NSMutableData *m = [NSMutableData data];
    dispatch_data_apply(dd, ^bool(dispatch_data_t r, size_t off, const void *buf, size_t size) { [m appendBytes:buf length:size]; return true; });
    _XPCData *d = [_XPCData new]; d->_d = m; return d;
}
static _XPCData *data_of(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCData class]] ? (_XPCData *)O(o) : nil; }
size_t xpc_data_get_length(xpc_object_t o) { return data_of(o)->_d.length; }
const void *xpc_data_get_bytes_ptr(xpc_object_t o) { return data_of(o)->_d.bytes; }
size_t xpc_data_get_bytes(xpc_object_t o, void *buf, size_t off, size_t len) {
    NSData *d = data_of(o)->_d;
    if (off >= d.length) return 0;
    size_t n = MIN(len, d.length - off);
    memcpy(buf, (const char *)d.bytes + off, n);
    return n;
}
xpc_object_t xpc_string_create(const char *s) { return string_n(s, strlen(s)); }
xpc_object_t xpc_string_create_with_format_and_arguments(const char *fmt, va_list ap) {
    char *s = NULL; int n = vasprintf(&s, fmt, ap);
    xpc_object_t o = string_n(s ?: "", n > 0 ? (size_t)n : 0); free(s); return o;
}
xpc_object_t xpc_string_create_with_format(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt); xpc_object_t o = xpc_string_create_with_format_and_arguments(fmt, ap); va_end(ap); return o;
}
static _XPCString *str_of(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCString class]] ? (_XPCString *)O(o) : nil; }
size_t xpc_string_get_length(xpc_object_t o) { return str_of(o)->_len; }
const char *xpc_string_get_string_ptr(xpc_object_t o) { return str_of(o)->_s; }
xpc_object_t xpc_uuid_create(const uuid_t u) { _XPCUUID *o = [_XPCUUID new]; memcpy(o->_u, u, 16); return o; }
const uint8_t *xpc_uuid_get_bytes(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCUUID class]] ? ((_XPCUUID *)O(o))->_u : NULL; }
xpc_object_t xpc_fd_create(int fd) { int d = dup(fd); if (d < 0) return nil; _XPCFD *o = [_XPCFD new]; o->_fd = d; return o; }
int xpc_fd_dup(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCFD class]] ? dup(((_XPCFD *)O(o))->_fd) : -1; }
xpc_object_t xpc_shmem_create(void *region, size_t len) { _XPCShmem *o = [_XPCShmem new]; o->_region = region; o->_length = len; return o; }
size_t xpc_shmem_map(xpc_object_t o, void **region) {
    if (![O(o) isKindOfClass:[_XPCShmem class]]) { *region = NULL; return 0; }
    *region = ((_XPCShmem *)O(o))->_region; return ((_XPCShmem *)O(o))->_length;
}

/* arrays */
static _XPCArray *arr_of(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCArray class]] ? (_XPCArray *)O(o) : nil; }
xpc_object_t xpc_array_create(const xpc_object_t *objects, size_t count) {
    _XPCArray *a = [_XPCArray new];
    for (size_t i = 0; i < count; i++) [a->_a addObject:O(objects[i])];
    return a;
}
xpc_object_t xpc_array_create_empty(void) { return [_XPCArray new]; }
void xpc_array_set_value(xpc_object_t xa, size_t i, xpc_object_t v) {
    _XPCArray *a = arr_of(xa);
    if (i == XPC_ARRAY_APPEND || i == a->_a.count) [a->_a addObject:O(v)];
    else if (i < a->_a.count) a->_a[i] = O(v);
}
void xpc_array_append_value(xpc_object_t xa, xpc_object_t v) { [arr_of(xa)->_a addObject:O(v)]; }
size_t xpc_array_get_count(xpc_object_t xa) { return arr_of(xa)->_a.count; }
xpc_object_t xpc_array_get_value(xpc_object_t xa, size_t i) { _XPCArray *a = arr_of(xa); return i < a->_a.count ? a->_a[i] : nil; }
bool xpc_array_apply(xpc_object_t xa, xpc_array_applier_t f) {
    NSArray *items = [arr_of(xa)->_a copy];
    for (NSUInteger i = 0; i < items.count; i++) if (!f(i, items[i])) return false;
    return true;
}
void xpc_array_set_bool(xpc_object_t a, size_t i, bool v) { xpc_array_set_value(a, i, XBOOL(v)); }
void xpc_array_set_int64(xpc_object_t a, size_t i, int64_t v) { xpc_array_set_value(a, i, xpc_int64_create(v)); }
void xpc_array_set_uint64(xpc_object_t a, size_t i, uint64_t v) { xpc_array_set_value(a, i, xpc_uint64_create(v)); }
void xpc_array_set_double(xpc_object_t a, size_t i, double v) { xpc_array_set_value(a, i, xpc_double_create(v)); }
void xpc_array_set_date(xpc_object_t a, size_t i, int64_t v) { xpc_array_set_value(a, i, xpc_date_create(v)); }
void xpc_array_set_data(xpc_object_t a, size_t i, const void *b, size_t n) { xpc_array_set_value(a, i, xpc_data_create(b, n)); }
void xpc_array_set_string(xpc_object_t a, size_t i, const char *s) { xpc_array_set_value(a, i, xpc_string_create(s)); }
void xpc_array_set_uuid(xpc_object_t a, size_t i, const uuid_t u) { xpc_array_set_value(a, i, xpc_uuid_create(u)); }
void xpc_array_set_fd(xpc_object_t a, size_t i, int fd) { xpc_object_t o = xpc_fd_create(fd); if (o) xpc_array_set_value(a, i, o); }
void xpc_array_set_connection(xpc_object_t a, size_t i, xpc_connection_t c) { xpc_array_set_value(a, i, xpc_endpoint_create(c)); }
bool xpc_array_get_bool(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v && xpc_bool_get_value(v); }
int64_t xpc_array_get_int64(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_int64_get_value(v) : 0; }
uint64_t xpc_array_get_uint64(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_uint64_get_value(v) : 0; }
double xpc_array_get_double(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_double_get_value(v) : NAN; }
int64_t xpc_array_get_date(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_date_get_value(v) : 0; }
const void *xpc_array_get_data(xpc_object_t a, size_t i, size_t *len) {
    _XPCData *d = data_of(xpc_array_get_value(a, i));
    if (len) *len = d ? d->_d.length : 0;
    return d ? d->_d.bytes : NULL;
}
const char *xpc_array_get_string(xpc_object_t a, size_t i) { _XPCString *s = str_of(xpc_array_get_value(a, i)); return s ? s->_s : NULL; }
const uint8_t *xpc_array_get_uuid(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_uuid_get_bytes(v) : NULL; }
int xpc_array_dup_fd(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v ? xpc_fd_dup(v) : -1; }
xpc_connection_t xpc_array_create_connection(xpc_object_t a, size_t i) {
    xpc_object_t v = xpc_array_get_value(a, i);
    return v && xpc_get_type(v) == XPC_TYPE_ENDPOINT ? xpc_connection_create_from_endpoint((xpc_endpoint_t)v) : nil;
}
xpc_object_t xpc_array_get_dictionary(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v && xpc_get_type(v) == XPC_TYPE_DICTIONARY ? v : nil; }
xpc_object_t xpc_array_get_array(xpc_object_t a, size_t i) { xpc_object_t v = xpc_array_get_value(a, i); return v && xpc_get_type(v) == XPC_TYPE_ARRAY ? v : nil; }

/* dictionaries */
static _XPCDictionary *dict_of(xpc_object_t o) { return [O(o) isKindOfClass:[_XPCDictionary class]] ? (_XPCDictionary *)O(o) : nil; }
xpc_object_t xpc_dictionary_create(const char *const *keys, const xpc_object_t *values, size_t count) {
    _XPCDictionary *d = [_XPCDictionary new];
    for (size_t i = 0; i < count; i++) if (values[i]) [d _set:@(keys[i]) value:O(values[i])];
    return d;
}
xpc_object_t xpc_dictionary_create_empty(void) { return [_XPCDictionary new]; }
xpc_object_t xpc_dictionary_create_reply(xpc_object_t original) {
    _XPCDictionary *o = dict_of(original);
    if (!o || !o->_from || !o->_wantsReply) return nil;
    _XPCDictionary *r = [_XPCDictionary new];
    r->_replyTo = o->_from; r->_replySerial = o->_serial;
    o->_wantsReply = NO;                          /* one reply per message */
    return r;
}
void xpc_dictionary_set_value(xpc_object_t xd, const char *key, xpc_object_t v) { [dict_of(xd) _set:@(key) value:O(v)]; }
xpc_object_t xpc_dictionary_get_value(xpc_object_t xd, const char *key) {
    if ([O(xd) isKindOfClass:[_XPCError class]]) {
        const char *desc = ((_XPCError *)O(xd))->_desc;
        return desc && !strcmp(key, XPC_ERROR_KEY_DESCRIPTION) ? xpc_string_create(desc) : nil;
    }
    return dict_of(xd)->_values[@(key)];
}
size_t xpc_dictionary_get_count(xpc_object_t xd) {
    if ([O(xd) isKindOfClass:[_XPCError class]]) return ((_XPCError *)O(xd))->_desc ? 1 : 0;
    return dict_of(xd)->_values.count;
}
bool xpc_dictionary_apply(xpc_object_t xd, xpc_dictionary_applier_t f) {
    if ([O(xd) isKindOfClass:[_XPCError class]]) {
        const char *desc = ((_XPCError *)O(xd))->_desc;
        return !desc || f(XPC_ERROR_KEY_DESCRIPTION, xpc_string_create(desc));
    }
    _XPCDictionary *d = dict_of(xd);
    for (NSString *k in [d->_keys copy]) if (!f(k.UTF8String, d->_values[k])) return false;
    return true;
}
void xpc_dictionary_set_bool(xpc_object_t d, const char *k, bool v) { xpc_dictionary_set_value(d, k, XBOOL(v)); }
void xpc_dictionary_set_int64(xpc_object_t d, const char *k, int64_t v) { xpc_dictionary_set_value(d, k, xpc_int64_create(v)); }
void xpc_dictionary_set_uint64(xpc_object_t d, const char *k, uint64_t v) { xpc_dictionary_set_value(d, k, xpc_uint64_create(v)); }
void xpc_dictionary_set_double(xpc_object_t d, const char *k, double v) { xpc_dictionary_set_value(d, k, xpc_double_create(v)); }
void xpc_dictionary_set_date(xpc_object_t d, const char *k, int64_t v) { xpc_dictionary_set_value(d, k, xpc_date_create(v)); }
void xpc_dictionary_set_data(xpc_object_t d, const char *k, const void *b, size_t n) { xpc_dictionary_set_value(d, k, xpc_data_create(b, n)); }
void xpc_dictionary_set_string(xpc_object_t d, const char *k, const char *s) { xpc_dictionary_set_value(d, k, xpc_string_create(s)); }
void xpc_dictionary_set_uuid(xpc_object_t d, const char *k, const uuid_t u) { xpc_dictionary_set_value(d, k, xpc_uuid_create(u)); }
void xpc_dictionary_set_fd(xpc_object_t d, const char *k, int fd) { xpc_object_t o = xpc_fd_create(fd); if (o) xpc_dictionary_set_value(d, k, o); }
void xpc_dictionary_set_connection(xpc_object_t d, const char *k, xpc_connection_t c) { xpc_dictionary_set_value(d, k, xpc_endpoint_create(c)); }
bool xpc_dictionary_get_bool(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v && xpc_bool_get_value(v); }
int64_t xpc_dictionary_get_int64(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_int64_get_value(v) : 0; }
uint64_t xpc_dictionary_get_uint64(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_uint64_get_value(v) : 0; }
double xpc_dictionary_get_double(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_double_get_value(v) : NAN; }
int64_t xpc_dictionary_get_date(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_date_get_value(v) : 0; }
const void *xpc_dictionary_get_data(xpc_object_t d, const char *k, size_t *len) {
    _XPCData *x = data_of(xpc_dictionary_get_value(d, k));
    if (len) *len = x ? x->_d.length : 0;
    return x ? x->_d.bytes : NULL;
}
const char *xpc_dictionary_get_string(xpc_object_t d, const char *k) {
    xpc_object_t v = xpc_dictionary_get_value(d, k);
    _XPCString *s = str_of(v);
    if (s && [O(d) isKindOfClass:[_XPCError class]]) objc_setAssociatedObject(O(d), k, v, OBJC_ASSOCIATION_RETAIN);   /* keep it alive */
    return s ? s->_s : NULL;
}
const uint8_t *xpc_dictionary_get_uuid(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_uuid_get_bytes(v) : NULL; }
int xpc_dictionary_dup_fd(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v ? xpc_fd_dup(v) : -1; }
xpc_connection_t xpc_dictionary_create_connection(xpc_object_t d, const char *k) {
    xpc_object_t v = xpc_dictionary_get_value(d, k);
    return v && xpc_get_type(v) == XPC_TYPE_ENDPOINT ? xpc_connection_create_from_endpoint((xpc_endpoint_t)v) : nil;
}
xpc_object_t xpc_dictionary_get_dictionary(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v && xpc_get_type(v) == XPC_TYPE_DICTIONARY ? v : nil; }
xpc_object_t xpc_dictionary_get_array(xpc_object_t d, const char *k) { xpc_object_t v = xpc_dictionary_get_value(d, k); return v && xpc_get_type(v) == XPC_TYPE_ARRAY ? v : nil; }

bool xpc_rich_error_can_retry(xpc_rich_error_t e) { return [O(e) isKindOfClass:[_XPCRichError class]] && ((_XPCRichError *)O(e))->_retry; }
char *xpc_rich_error_copy_description(xpc_rich_error_t e) {
    return [O(e) isKindOfClass:[_XPCRichError class]] ? strdup(((_XPCRichError *)O(e))->_desc.UTF8String ?: "") : NULL;
}

/* ================= the wire encoding ================= */
static void put(NSMutableData *m, const void *p, size_t n) { [m appendBytes:p length:n]; }
static void put_u32(NSMutableData *m, uint32_t v) { put(m, &v, 4); }
static void encode(NSMutableData *m, OS_xpc_object *o) {
    xpc_type_t t = [o _type];
    uint8_t tag;
    if ([o isKindOfClass:[_XPCDictionary class]]) {
        _XPCDictionary *d = (_XPCDictionary *)o; tag = 'D'; put(m, &tag, 1); put_u32(m, (uint32_t)d->_keys.count);
        for (NSString *k in d->_keys) { const char *s = k.UTF8String; put_u32(m, (uint32_t)strlen(s)); put(m, s, strlen(s)); encode(m, d->_values[k]); }
    } else if ([o isKindOfClass:[_XPCArray class]]) {
        _XPCArray *a = (_XPCArray *)o; tag = 'A'; put(m, &tag, 1); put_u32(m, (uint32_t)a->_a.count);
        for (OS_xpc_object *v in a->_a) encode(m, v);
    } else if ([o isKindOfClass:[_XPCString class]]) {
        tag = 'S'; put(m, &tag, 1); put_u32(m, (uint32_t)((_XPCString *)o)->_len); put(m, ((_XPCString *)o)->_s, ((_XPCString *)o)->_len);
    } else if ([o isKindOfClass:[_XPCNumber class]]) {
        tag = t == XPC_TYPE_INT64 ? 'i' : t == XPC_TYPE_UINT64 ? 'u' : t == XPC_TYPE_DOUBLE ? 'd' : 't';
        put(m, &tag, 1); put(m, &((_XPCNumber *)o)->_v.u, 8);
    } else if ([o isKindOfClass:[_XPCBool class]]) {
        tag = ((_XPCBool *)o)->_value ? 'T' : 'F'; put(m, &tag, 1);
    } else if ([o isKindOfClass:[_XPCData class]]) {
        NSData *d = ((_XPCData *)o)->_d; tag = 'x'; put(m, &tag, 1); put_u32(m, (uint32_t)d.length); put(m, d.bytes, d.length);
    } else if ([o isKindOfClass:[_XPCUUID class]]) {
        tag = 'U'; put(m, &tag, 1); put(m, ((_XPCUUID *)o)->_u, 16);
    } else if ([o isKindOfClass:[_XPCEndpoint class]]) {
        const char *p = ((_XPCEndpoint *)o)->_path.UTF8String, *n = ((_XPCEndpoint *)o)->_name.UTF8String ?: "";
        tag = 'E'; put(m, &tag, 1); put_u32(m, (uint32_t)strlen(p)); put(m, p, strlen(p)); put_u32(m, (uint32_t)strlen(n)); put(m, n, strlen(n));
    } else if ([o isKindOfClass:[_XPCError class]] && ((_XPCError *)o)->_desc) {
        tag = 'e'; put(m, &tag, 1); put_u32(m, (uint32_t)strlen(((_XPCError *)o)->_desc)); put(m, ((_XPCError *)o)->_desc, strlen(((_XPCError *)o)->_desc));
    } else {
        tag = 'n'; put(m, &tag, 1);                   /* null; fds and shared memory stay in their process */
    }
}
static BOOL take(const uint8_t **p, const uint8_t *end, void *out, size_t n) {
    if ((size_t)(end - *p) < n) return NO;
    memcpy(out, *p, n); *p += n; return YES;
}
static id decode(const uint8_t **p, const uint8_t *end, int depth) {
    uint8_t tag; uint32_t n;
    if (depth > 64 || !take(p, end, &tag, 1)) return nil;
    switch (tag) {
    case 'D': {
        if (!take(p, end, &n, 4)) return nil;
        _XPCDictionary *d = [_XPCDictionary new];
        for (uint32_t i = 0; i < n; i++) {
            uint32_t kl; if (!take(p, end, &kl, 4) || (size_t)(end - *p) < kl) return nil;
            NSString *k = [[NSString alloc] initWithBytes:*p length:kl encoding:NSUTF8StringEncoding]; *p += kl;
            id v = decode(p, end, depth + 1); if (!v || !k) return nil;
            [d _set:k value:v];
        }
        return d;
    }
    case 'A': {
        if (!take(p, end, &n, 4)) return nil;
        _XPCArray *a = [_XPCArray new];
        for (uint32_t i = 0; i < n; i++) { id v = decode(p, end, depth + 1); if (!v) return nil; [a->_a addObject:v]; }
        return a;
    }
    case 'S': case 'x': case 'e': {
        if (!take(p, end, &n, 4) || (size_t)(end - *p) < n) return nil;
        id o = tag == 'S' ? string_n((const char *)*p, n) : tag == 'x' ? xpc_data_create(*p, n) : nil;
        if (tag == 'e') {
            o = !strncmp((const char *)*p, _xpc_error_connection_interrupted.desc, n) ? XERR(_xpc_error_connection_interrupted)
              : !strncmp((const char *)*p, _xpc_error_termination_imminent.desc, n) ? XERR(_xpc_error_termination_imminent)
              : XERR(_xpc_error_connection_invalid);
        }
        *p += n; return o;
    }
    case 'i': case 'u': case 'd': case 't': {
        uint64_t b; if (!take(p, end, &b, 8)) return nil;
        return number(tag == 'i' ? XPC_TYPE_INT64 : tag == 'u' ? XPC_TYPE_UINT64 : tag == 'd' ? XPC_TYPE_DOUBLE : XPC_TYPE_DATE, b);
    }
    case 'T': return XBOOL(1);
    case 'F': return XBOOL(0);
    case 'U': { uuid_t u; if (!take(p, end, u, 16)) return nil; return xpc_uuid_create(u); }
    case 'E': {
        uint32_t nl;
        if (!take(p, end, &n, 4) || (size_t)(end - *p) < n) return nil;
        _XPCEndpoint *e = [_XPCEndpoint new];
        e->_path = [[NSString alloc] initWithBytes:*p length:n encoding:NSUTF8StringEncoding]; *p += n;
        if (!take(p, end, &nl, 4) || (size_t)(end - *p) < nl) return nil;
        if (nl) e->_name = [[NSString alloc] initWithBytes:*p length:nl encoding:NSUTF8StringEncoding];
        *p += nl; return e;
    }
    case 'n': return [_XPCNull new];
    default: return nil;
    }
}

/* ================= rendezvous: where a service's socket lives ================= */
static uint64_t fnv(const char *s) { uint64_t h = 1469598103934665603ULL; for (; *s; s++) { h ^= (unsigned char)*s; h *= 1099511628211ULL; } return h; }
static NSString *socket_dir(void) {
    NSString *d = [NSString stringWithFormat:@"/tmp/isim-xpc-%u", (unsigned)getuid()];
    mkdir(d.fileSystemRepresentation, 0700);
    return d;
}
static NSString *service_socket(const char *name) {
    return [socket_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%016llx-%016llx",
            (unsigned long long)fnv(isim_data_dir().UTF8String), (unsigned long long)fnv(name)]];
}
static NSString *anonymous_socket(void) {
    static uint64_t counter;
    return [socket_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"anon-%d-%llu-%llx", (int)getpid(),
            (unsigned long long)__atomic_add_fetch(&counter, 1, __ATOMIC_RELAXED), (unsigned long long)arc4random()]];
}
static NSString *registry_path(const char *name) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/xpc"];
    [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:@(name)];
}
static BOOL fill_addr(struct sockaddr_un *a, NSString *path) {
    memset(a, 0, sizeof *a);
    a->sun_family = AF_UNIX;
    const char *p = path.fileSystemRepresentation;
    if (strlen(p) >= sizeof a->sun_path) return NO;
    strcpy(a->sun_path, p);
    a->sun_len = (unsigned char)SUN_LEN(a);
    return YES;
}
static int connect_path(NSString *path) {
    struct sockaddr_un a;
    if (!fill_addr(&a, path)) return -1;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    if (connect(fd, (struct sockaddr *)&a, sizeof a) < 0) { close(fd); return -1; }
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    return fd;
}
static int listen_path(NSString *path) {
    struct sockaddr_un a;
    if (!fill_addr(&a, path)) return -1;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    if (bind(fd, (struct sockaddr *)&a, sizeof a) < 0) {
        /* a socket left behind by a process that has gone: take it over */
        int probe = connect_path(path);
        if (probe >= 0) { close(probe); close(fd); errno = EADDRINUSE; return -1; }
        unlink(path.fileSystemRepresentation);
        if (bind(fd, (struct sockaddr *)&a, sizeof a) < 0) { close(fd); return -1; }
    }
    if (listen(fd, 64) < 0) { close(fd); return -1; }
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    return fd;
}

/* ================= links: one socket to a peer (connections and sessions) ================= */
enum { F_MESSAGE = 0, F_WANTS_REPLY = 1, F_REPLY = 2, F_HELLO = 3, F_REJECT = 4, F_WANTS_REPLY_SYNC = 5 };
typedef void (^reply_block)(xpc_object_t reply);
enum { L_CLIENT, L_PEER, L_LISTENER };

@interface _XPCLink : OS_xpc_object {
@public
    int _role;                      /* L_CLIENT (to a service or endpoint), L_PEER (accepted), L_LISTENER (connection API) */
    NSString *_name, *_path;        /* the service's name; its socket */
    dispatch_queue_t _target, _io;
    int _fd;
    dispatch_source_t _src;
    NSMutableData *_in;
    pthread_mutex_t _wlock;
    uint64_t _serial;
    NSMutableDictionary<NSNumber *, reply_block> *_pending;
    NSMutableArray *_held;          /* messages received while suspended / inactive */
    int _suspend;                   /* suspension count (connections start suspended) */
    BOOL _connected, _cancelled, _invalidated, _helloSent;
    pid_t _peerPid;
    void *_context;
    xpc_finalizer_t _finalizer;
    NSString *_reason;              /* invalidation reason */
    id _owner;                      /* a listener keeps its peers alive until they close */
}
- (void)_received:(OS_xpc_object *)msg;                 /* subclasses deliver */
- (void)_closed:(BOOL)byPeer;
- (BOOL)_ensureConnected;
- (BOOL)_sendFrame:(int)kind serial:(uint64_t)serial replyTo:(uint64_t)replyTo payload:(NSData *)payload;
@end

@implementation _XPCLink
- (instancetype)init {
    if ((self = [super init])) {
        _fd = -1; _in = [NSMutableData data]; pthread_mutex_init(&_wlock, NULL);
        _pending = [NSMutableDictionary dictionary]; _held = [NSMutableArray array];
        _io = dispatch_queue_create("isim.xpc.io", DISPATCH_QUEUE_SERIAL);
        _target = dispatch_queue_create("isim.xpc.target", DISPATCH_QUEUE_SERIAL);   /* messages arrive in order */
    }
    return self;
}
- (void)dealloc {
    if (_src) dispatch_source_cancel(_src);
    else if (_fd >= 0) close(_fd);
    if (_finalizer && _context) _finalizer(_context);
}
- (xpc_type_t)_type { return XPC_TYPE_CONNECTION; }
- (void)_describe:(NSMutableString *)out indent:(int)indent {
    [out appendFormat:@"<%s: %p> { name = %@, listener = %s, pid = %d }", [self _type]->name, self, _name ?: @"(anonymous)",
     _role == L_LISTENER ? "true" : "false", (int)_peerPid];
}
/* frames: u32 length (of what follows), u8 kind, u64 serial, u64 reply-to, payload */
- (BOOL)_sendFrame:(int)kind serial:(uint64_t)serial replyTo:(uint64_t)replyTo payload:(NSData *)payload {
    NSMutableData *f = [NSMutableData dataWithCapacity:21 + payload.length];
    uint32_t len = (uint32_t)(17 + payload.length); uint8_t k = (uint8_t)kind;
    put(f, &len, 4); put(f, &k, 1); put(f, &serial, 8); put(f, &replyTo, 8); [f appendData:payload];
    pthread_mutex_lock(&_wlock);
    BOOL ok = _fd >= 0;
    const uint8_t *p = f.bytes; size_t left = f.length;
    while (ok && left) {
        ssize_t w = send(_fd, p, left, MSG_NOSIGNAL);   /* a peer that closed is an error here, never SIGPIPE */
        if (w < 0 && errno == EINTR) continue;
        if (w <= 0) { ok = NO; break; }
        p += w; left -= (size_t)w;
    }
    pthread_mutex_unlock(&_wlock);
    return ok;
}
- (void)_startReading {
    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)_fd, 0, _io);
    int fd = _fd;
    __weak _XPCLink *weakSelf = self;
    dispatch_source_set_event_handler(s, ^{
        _XPCLink *me = weakSelf;
        if (!me) return;
        char buf[16384];
        for (;;) {                  /* everything that is there: the source may report a socket only when more arrives */
            ssize_t n = recv(fd, buf, sizeof buf, MSG_DONTWAIT);
            if (n < 0 && errno == EINTR) continue;
            if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) break;
            if (n <= 0) { [me _drain]; [me _closed:YES]; return; }
            [me->_in appendBytes:buf length:(NSUInteger)n];
        }
        [me _drain];
    });
    dispatch_source_set_cancel_handler(s, ^{ close(fd); });
    _src = s;
    dispatch_resume(s);
}
- (void)_drain {
    while (_in.length >= 4) {
        uint32_t len; memcpy(&len, _in.bytes, 4);
        if (_in.length < 4 + (NSUInteger)len) return;
        const uint8_t *f = (const uint8_t *)_in.bytes + 4;
        uint8_t kind = f[0]; uint64_t serial, replyTo;
        memcpy(&serial, f + 1, 8); memcpy(&replyTo, f + 9, 8);
        const uint8_t *p = f + 17, *end = f + len;
        if (kind == F_HELLO) {
            int64_t pid = 0; if (end - p >= 8) memcpy(&pid, p, 8);
            _peerPid = (pid_t)pid;
            if (_role == L_PEER && !_helloSent) { _helloSent = YES; int64_t me = getpid(); [self _sendFrame:F_HELLO serial:0 replyTo:0 payload:[NSData dataWithBytes:&me length:8]]; }
        } else if (kind == F_REJECT) {
            _reason = [[NSString alloc] initWithBytes:p length:(NSUInteger)(end - p) encoding:NSUTF8StringEncoding];
        } else {
            id msg = decode(&p, end, 0);
            if (kind == F_REPLY) {
                reply_block cb = _pending[@(replyTo)];
                [_pending removeObjectForKey:@(replyTo)];
                if (cb) cb(msg ?: [_XPCDictionary new]);
            } else if (msg) {
                if ([msg isKindOfClass:[_XPCDictionary class]]) {
                    _XPCDictionary *d = (_XPCDictionary *)msg;
                    d->_from = self; d->_serial = serial; d->_wantsReply = kind == F_WANTS_REPLY || kind == F_WANTS_REPLY_SYNC;
                    d->_sync = kind == F_WANTS_REPLY_SYNC;
                }
                [self _received:msg];
            }
        }
        [_in replaceBytesInRange:NSMakeRange(0, 4 + len) withBytes:NULL length:0];
    }
}
- (BOOL)_attach:(int)fd {
    _fd = fd; _connected = YES;
    [self _startReading];
    if (_role == L_CLIENT) { _helloSent = YES; int64_t me = getpid(); [self _sendFrame:F_HELLO serial:0 replyTo:0 payload:[NSData dataWithBytes:&me length:8]]; }
    return YES;
}
- (BOOL)_ensureConnected {
    if (_connected) return YES;
    if (_cancelled || _role != L_CLIENT || !_path) return NO;
    int fd = connect_path(_path);
    if (fd < 0) return NO;
    return [self _attach:fd];
}
/* the peer went away or the link was cancelled: fail the pending replies, then tell the owner */
- (void)_closed:(BOOL)byPeer {
    if (!_connected && !_cancelled && byPeer) return;
    if (_src) { dispatch_source_cancel(_src); _src = nil; } else if (_fd >= 0) close(_fd);
    _fd = -1; _connected = NO; _helloSent = NO; [_in setLength:0];
    NSDictionary *pending = [_pending copy]; [_pending removeAllObjects];
    xpc_object_t err = (_role == L_CLIENT && byPeer && !_reason) ? XERR(_xpc_error_connection_interrupted) : XERR(_xpc_error_connection_invalid);
    for (NSNumber *k in pending) ((reply_block)pending[k])(err);
    [self _lost:byPeer];
}
- (void)_lost:(BOOL)byPeer {}
- (void)_received:(OS_xpc_object *)msg {}
- (uint64_t)_nextSerial { return __atomic_add_fetch(&_serial, 1, __ATOMIC_RELAXED); }
/* sends a message (a reply when it was made with xpc_dictionary_create_reply); NO when there is no peer */
- (BOOL)_send:(OS_xpc_object *)msg wantsReply:(reply_block)reply { return [self _send:msg wantsReply:reply sync:NO]; }
- (BOOL)_send:(OS_xpc_object *)msg wantsReply:(reply_block)reply sync:(BOOL)sync {
    NSMutableData *payload = [NSMutableData data];
    encode(payload, msg);
    __block BOOL ok = NO;
    _XPCDictionary *d = [msg isKindOfClass:[_XPCDictionary class]] ? (_XPCDictionary *)msg : nil;
    dispatch_sync(_io, ^{
        if (d && d->_replyTo) {
            _XPCLink *back = d->_replyTo;
            ok = back->_connected && [back _sendFrame:F_REPLY serial:[back _nextSerial] replyTo:d->_replySerial payload:payload];
            return;
        }
        if (![self _ensureConnected]) return;
        uint64_t s = [self _nextSerial];
        if (reply) self->_pending[@(s)] = reply;
        ok = [self _sendFrame:!reply ? F_MESSAGE : sync ? F_WANTS_REPLY_SYNC : F_WANTS_REPLY serial:s replyTo:0 payload:payload];
        if (!ok && reply) [self->_pending removeObjectForKey:@(s)];
    });
    return ok;
}
- (void)_cancelLink {
    dispatch_sync(_io, ^{
        if (self->_cancelled) return;
        self->_cancelled = YES;
        if (self->_connected) [self _closed:NO];
        else [self _lost:NO];
    });
}
@end

/* ================= connections ================= */
@interface _XPCConnection : _XPCLink {
@public
    xpc_handler_t _handler;
    int _listenFD;
    dispatch_source_t _accept;
    BOOL _activated;
}
@end
@interface _XPCListener : OS_xpc_object
@end

static void deliver_conn(_XPCConnection *c, id msg) {
    xpc_handler_t h = c->_handler;
    if (h) dispatch_async(c->_target, ^{ h((xpc_object_t)msg); });
}
@implementation _XPCConnection
- (instancetype)init { if ((self = [super init])) { _suspend = 1; _listenFD = -1; } return self; }
- (void)dealloc { if (_accept) dispatch_source_cancel(_accept); else if (_listenFD >= 0) close(_listenFD); }
- (void)_received:(OS_xpc_object *)msg {
    if (_suspend > 0) { [_held addObject:msg]; return; }
    deliver_conn(self, msg);
}
- (void)_lost:(BOOL)byPeer {
    if (_cancelled) {
        if (!_invalidated) { _invalidated = YES; deliver_conn(self, XERR(_xpc_error_connection_invalid)); _owner = nil; }
    } else if (_role == L_CLIENT && !_reason) {
        deliver_conn(self, XERR(_xpc_error_connection_interrupted));   /* the next message reconnects */
    } else {
        _invalidated = YES; _cancelled = YES; deliver_conn(self, XERR(_xpc_error_connection_invalid)); _owner = nil;
    }
}
- (void)_resumed {
    if (_role == L_LISTENER) { [self _listen]; return; }
    NSArray *held = [_held copy]; [_held removeAllObjects];
    for (OS_xpc_object *m in held) deliver_conn(self, m);
    if (_role == L_CLIENT) [self _ensureConnected];
}
- (void)_listen {
    if (_listenFD >= 0 || _cancelled) return;
    _listenFD = listen_path(_path);
    if (_listenFD < 0) { _cancelled = YES; deliver_conn(self, XERR(_xpc_error_connection_invalid)); return; }
    if (_name) [[NSString stringWithFormat:@"%d\n%@\n", (int)getpid(), _path] writeToFile:registry_path(_name.UTF8String) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    int lfd = _listenFD;
    _accept = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)lfd, 0, _io);
    __weak _XPCConnection *weakSelf = self;
    dispatch_source_set_event_handler(_accept, ^{
        int fd = accept(lfd, NULL, NULL);
        _XPCConnection *me = weakSelf;
        if (fd < 0 || !me) { if (fd >= 0) close(fd); return; }
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        _XPCConnection *peer = [_XPCConnection new];
        peer->_role = L_PEER; peer->_name = me->_name; peer->_target = me->_target; peer->_owner = peer;
        [peer _attach:fd];
        deliver_conn(me, peer);                      /* the handler sets the peer's handler and resumes it */
    });
    NSString *path = _path;
    dispatch_source_set_cancel_handler(_accept, ^{ close(lfd); unlink(path.fileSystemRepresentation); });
    dispatch_resume(_accept);
}
@end
static _XPCConnection *conn_of(xpc_connection_t c) { return [O(c) isKindOfClass:[_XPCConnection class]] ? (_XPCConnection *)O(c) : nil; }

xpc_connection_t xpc_connection_create(const char *name, dispatch_queue_t q) {
    _XPCConnection *c = [_XPCConnection new];
    if (q) c->_target = q;
    if (name) { c->_role = L_CLIENT; c->_name = @(name); c->_path = service_socket(name); }
    else { c->_role = L_LISTENER; c->_path = anonymous_socket(); }   /* Apple: NULL makes an anonymous listener */
    return (xpc_connection_t)c;
}
xpc_connection_t xpc_connection_create_mach_service(const char *name, dispatch_queue_t q, uint64_t flags) {
    _XPCConnection *c = [_XPCConnection new];
    if (q) c->_target = q;
    c->_name = @(name); c->_path = service_socket(name);
    c->_role = (flags & XPC_CONNECTION_MACH_SERVICE_LISTENER) ? L_LISTENER : L_CLIENT;
    return (xpc_connection_t)c;
}
xpc_connection_t xpc_connection_create_from_endpoint(xpc_endpoint_t e) {
    _XPCConnection *c = [_XPCConnection new];
    c->_role = L_CLIENT; c->_path = ((_XPCEndpoint *)O(e))->_path; c->_name = ((_XPCEndpoint *)O(e))->_name;
    return (xpc_connection_t)c;
}
void xpc_connection_set_target_queue(xpc_connection_t c, dispatch_queue_t q) { if (q) conn_of(c)->_target = q; }
void xpc_connection_set_event_handler(xpc_connection_t c, xpc_handler_t h) { conn_of(c)->_handler = [h copy]; }
void xpc_connection_activate(xpc_connection_t xc) {
    _XPCConnection *c = conn_of(xc);
    if (c->_activated) return;
    c->_activated = YES;
    dispatch_async(c->_io, ^{ if (c->_suspend > 0) c->_suspend--; if (c->_suspend == 0) [c _resumed]; });
}
void xpc_connection_resume(xpc_connection_t xc) {
    _XPCConnection *c = conn_of(xc);
    c->_activated = YES;
    dispatch_async(c->_io, ^{ if (c->_suspend > 0 && --c->_suspend == 0) [c _resumed]; });
}
void xpc_connection_suspend(xpc_connection_t xc) { _XPCConnection *c = conn_of(xc); dispatch_async(c->_io, ^{ c->_suspend++; }); }
void xpc_connection_cancel(xpc_connection_t xc) {
    _XPCConnection *c = conn_of(xc);
    if (c->_accept) { dispatch_source_cancel(c->_accept); c->_accept = nil; c->_listenFD = -1; }
    [c _cancelLink];
}
void xpc_connection_send_message(xpc_connection_t xc, xpc_object_t m) { [conn_of(xc) _send:O(m) wantsReply:nil]; }
void xpc_connection_send_barrier(xpc_connection_t xc, dispatch_block_t b) {
    _XPCConnection *c = conn_of(xc);
    dispatch_async(c->_io, ^{ dispatch_async(c->_target, b); });
}
void xpc_connection_send_message_with_reply(xpc_connection_t xc, xpc_object_t m, dispatch_queue_t q, xpc_handler_t h) {
    _XPCConnection *c = conn_of(xc);
    dispatch_queue_t rq = q ?: c->_target;
    xpc_handler_t handler = [h copy];
    reply_block cb = ^(xpc_object_t r) { dispatch_async(rq, ^{ handler(r); }); };
    if (![c _send:O(m) wantsReply:cb])
        cb(c->_cancelled ? XERR(_xpc_error_connection_invalid) : XERR(_xpc_error_connection_interrupted));
}
xpc_object_t xpc_connection_send_message_with_reply_sync(xpc_connection_t xc, xpc_object_t m) {
    _XPCConnection *c = conn_of(xc);
    __block xpc_object_t reply = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    reply_block cb = ^(xpc_object_t r) { reply = r; dispatch_semaphore_signal(sem); };
    if (![c _send:O(m) wantsReply:cb sync:YES])
        return c->_cancelled ? XERR(_xpc_error_connection_invalid) : XERR(_xpc_error_connection_interrupted);
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return reply;
}
const char *xpc_connection_get_name(xpc_connection_t c) { return conn_of(c)->_name.UTF8String; }
uid_t xpc_connection_get_euid(xpc_connection_t c) { return getuid(); }
gid_t xpc_connection_get_egid(xpc_connection_t c) { return getgid(); }
pid_t xpc_connection_get_pid(xpc_connection_t c) { return conn_of(c)->_peerPid; }
au_asid_t xpc_connection_get_asid(xpc_connection_t c) { return 0; }
void xpc_connection_set_context(xpc_connection_t c, void *ctx) { conn_of(c)->_context = ctx; }
void *xpc_connection_get_context(xpc_connection_t c) { return conn_of(c)->_context; }
void xpc_connection_set_finalizer_f(xpc_connection_t c, xpc_finalizer_t f) { conn_of(c)->_finalizer = f; }
char *xpc_connection_copy_invalidation_reason(xpc_connection_t c) {
    _XPCConnection *x = conn_of(c);
    return x->_invalidated ? strdup((x->_reason ?: (x->_cancelled ? @"Connection cancelled" : @"Peer closed the connection")).UTF8String) : NULL;
}
int xpc_connection_set_peer_code_signing_requirement(xpc_connection_t c, const char *r) { return 0; }
int xpc_connection_set_peer_entitlement_exists_requirement(xpc_connection_t c, const char *e) { return 0; }
int xpc_connection_set_peer_entitlement_matches_value_requirement(xpc_connection_t c, const char *e, xpc_object_t v) { return 0; }
int xpc_connection_set_peer_team_identity_requirement(xpc_connection_t c, const char *s) { return 0; }
int xpc_connection_set_peer_platform_identity_requirement(xpc_connection_t c, const char *s) { return 0; }
int xpc_connection_set_peer_lightweight_code_requirement(xpc_connection_t c, xpc_object_t l) { return 0; }

xpc_endpoint_t xpc_endpoint_create(xpc_connection_t xc) {
    _XPCLink *c = (_XPCLink *)O(xc);
    _XPCEndpoint *e = [_XPCEndpoint new];
    e->_path = c->_path; e->_name = c->_name;
    if (c->_role == L_LISTENER && [c isKindOfClass:[_XPCConnection class]]) dispatch_sync(c->_io, ^{ [(_XPCConnection *)c _listen]; });
    return (xpc_endpoint_t)e;
}

/* ================= sessions ================= */
@interface _XPCSession : _XPCLink {
@public
    xpc_session_incoming_message_handler_t _incoming;
    xpc_session_cancel_handler_t _cancelHandler;
    BOOL _active, _rejected;
    NSString *_rejectReason;
}
@end
@implementation _XPCSession
- (xpc_type_t)_type { return XPC_TYPE_SESSION; }
- (void)_received:(OS_xpc_object *)msg {
    if (!_active) { [_held addObject:msg]; return; }
    xpc_session_incoming_message_handler_t h = _incoming;
    if (h) dispatch_async(_target, ^{ h((xpc_object_t)msg); });
}
- (void)_lost:(BOOL)byPeer {
    if (_invalidated) return;
    _invalidated = YES; _cancelled = YES;
    xpc_session_cancel_handler_t h = _cancelHandler;
    NSString *why = _reason ? [NSString stringWithFormat:@"Peer rejected the session: %@", _reason]
                  : byPeer ? @"Connection interrupted: the peer closed the session" : @"Session cancelled";
    xpc_rich_error_t err = rich_error(why, byPeer && !_reason);
    if (h) dispatch_async(_target, ^{ h(err); });
    _owner = nil;
}
@end
static _XPCSession *sess_of(xpc_session_t s) { return [O(s) isKindOfClass:[_XPCSession class]] ? (_XPCSession *)O(s) : nil; }

static xpc_session_t session_to(NSString *path, NSString *name, dispatch_queue_t q, xpc_session_create_flags_t flags, xpc_rich_error_t *err) {
    _XPCSession *s = [_XPCSession new];
    s->_role = L_CLIENT; s->_path = path; s->_name = name;
    if (q) s->_target = q;
    if (!(flags & XPC_SESSION_CREATE_INACTIVE) && !xpc_session_activate((xpc_session_t)s, err)) return nil;
    return (xpc_session_t)s;
}
xpc_session_t xpc_session_create_xpc_service(const char *name, dispatch_queue_t q, xpc_session_create_flags_t f, xpc_rich_error_t *err) {
    return session_to(service_socket(name), @(name), q, f, err);
}
xpc_session_t xpc_session_create_mach_service(const char *name, dispatch_queue_t q, xpc_session_create_flags_t f, xpc_rich_error_t *err) {
    return session_to(service_socket(name), @(name), q, f, err);
}
xpc_session_t _xpc_session_create_endpoint(xpc_endpoint_t e, dispatch_queue_t q, xpc_session_create_flags_t f, xpc_rich_error_t *err) {
    return session_to(((_XPCEndpoint *)O(e))->_path, ((_XPCEndpoint *)O(e))->_name, q, f, err);
}
void xpc_session_set_target_queue(xpc_session_t s, dispatch_queue_t q) { if (q) sess_of(s)->_target = q; }
void xpc_session_set_cancel_handler(xpc_session_t s, xpc_session_cancel_handler_t h) { sess_of(s)->_cancelHandler = [h copy]; }
void xpc_session_set_incoming_message_handler(xpc_session_t s, xpc_session_incoming_message_handler_t h) { sess_of(s)->_incoming = [h copy]; }
bool xpc_session_activate(xpc_session_t xs, xpc_rich_error_t *err) {
    _XPCSession *s = sess_of(xs);
    __block BOOL ok = YES;
    dispatch_sync(s->_io, ^{
        if (s->_active) return;
        if (s->_cancelled) { ok = NO; return; }
        if (s->_role == L_CLIENT && ![s _ensureConnected]) { ok = NO; return; }
        s->_active = YES;
        NSArray *held = [s->_held copy]; [s->_held removeAllObjects];
        for (OS_xpc_object *m in held) [s _received:m];
    });
    if (!ok && err) *err = rich_error(s->_cancelled ? @"Session cancelled"
                                      : [NSString stringWithFormat:@"No listener for the service %@", s->_name ?: @"(endpoint)"], !s->_cancelled);
    return ok;
}
void xpc_session_cancel(xpc_session_t s) { [sess_of(s) _cancelLink]; }
char *xpc_session_copy_description(xpc_session_t s) { return xpc_copy_description((xpc_object_t)s); }
xpc_rich_error_t xpc_session_send_message(xpc_session_t xs, xpc_object_t m) {
    _XPCSession *s = sess_of(xs);
    if (!s->_active && !(dict_of(m) && dict_of(m)->_replyTo)) return rich_error(@"Session is not active", NO);
    return [s _send:O(m) wantsReply:nil] ? nil : rich_error(@"Connection interrupted", YES);
}
static xpc_rich_error_t error_of_reply(xpc_object_t r) {
    if (r && [O(r) isKindOfClass:[_XPCError class]] && ((_XPCError *)O(r))->_desc)
        return rich_error(@(((_XPCError *)O(r))->_desc), r == XERR(_xpc_error_connection_interrupted));
    return nil;
}
xpc_object_t xpc_session_send_message_with_reply_sync(xpc_session_t xs, xpc_object_t m, xpc_rich_error_t *err) {
    _XPCSession *s = sess_of(xs);
    if (!s->_active) { if (err) *err = rich_error(@"Session is not active", NO); return nil; }
    __block xpc_object_t reply = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if (![s _send:O(m) wantsReply:^(xpc_object_t r) { reply = r; dispatch_semaphore_signal(sem); } sync:YES]) {
        if (err) *err = rich_error(@"Connection interrupted", YES);
        return nil;
    }
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    xpc_rich_error_t e = error_of_reply(reply);
    if (e) { if (err) *err = e; return nil; }
    return reply;
}
void xpc_session_send_message_with_reply_async(xpc_session_t xs, xpc_object_t m, xpc_session_reply_handler_t h) {
    _XPCSession *s = sess_of(xs);
    xpc_session_reply_handler_t handler = [h copy];
    dispatch_queue_t q = s->_target;
    if (!s->_active) { xpc_rich_error_t e = rich_error(@"Session is not active", NO); dispatch_async(q, ^{ handler(nil, e); }); return; }
    if (![s _send:O(m) wantsReply:^(xpc_object_t r) {
            xpc_rich_error_t e = error_of_reply(r);
            dispatch_async(q, ^{ handler(e ? nil : r, e); });
        }]) {
        xpc_rich_error_t e = rich_error(@"Connection interrupted", YES);
        dispatch_async(q, ^{ handler(nil, e); });
    }
}
int xpc_session_set_peer_code_signing_requirement(xpc_session_t s, const char *r) { return 0; }

/* ================= listeners ================= */
@interface _XPCListenerImpl : OS_xpc_object {
@public
    NSString *_name, *_path;
    dispatch_queue_t _target, _io;
    xpc_listener_incoming_session_handler_t _handler;
    int _fd;
    dispatch_source_t _src;
    BOOL _active, _cancelled;
}
@end
@implementation _XPCListenerImpl
- (xpc_type_t)_type { return XPC_TYPE_LISTENER; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<listener: %p> { name = %@ }", self, _name ?: @"(anonymous)"]; }
- (void)dealloc { if (_src) dispatch_source_cancel(_src); }
@end
static _XPCListenerImpl *lis_of(xpc_listener_t l) { return [O(l) isKindOfClass:[_XPCListenerImpl class]] ? (_XPCListenerImpl *)O(l) : nil; }

xpc_listener_t xpc_listener_create(const char *service, dispatch_queue_t q, xpc_listener_create_flags_t flags,
                                   xpc_listener_incoming_session_handler_t handler, xpc_rich_error_t *err) {
    _XPCListenerImpl *l = [_XPCListenerImpl new];
    l->_name = service ? @(service) : nil;
    l->_path = service ? service_socket(service) : anonymous_socket();
    l->_target = q ?: dispatch_queue_create("isim.xpc.listener.target", DISPATCH_QUEUE_SERIAL);
    l->_io = dispatch_queue_create("isim.xpc.listener", DISPATCH_QUEUE_SERIAL);
    l->_handler = [handler copy];
    l->_fd = -1;
    if (!(flags & XPC_LISTENER_CREATE_INACTIVE) && !xpc_listener_activate((xpc_listener_t)l, err)) return nil;
    return (xpc_listener_t)l;
}
bool xpc_listener_activate(xpc_listener_t xl, xpc_rich_error_t *err) {
    _XPCListenerImpl *l = lis_of(xl);
    if (l->_active) return true;
    if (l->_cancelled) { if (err) *err = rich_error(@"Listener cancelled", NO); return false; }
    int lfd = listen_path(l->_path);
    if (lfd < 0) {
        if (err) *err = rich_error([NSString stringWithFormat:@"Cannot listen for %@: %s", l->_name ?: @"(anonymous)", strerror(errno)], NO);
        return false;
    }
    l->_fd = lfd; l->_active = YES;
    if (l->_name) [[NSString stringWithFormat:@"%d\n%@\n", (int)getpid(), l->_path] writeToFile:registry_path(l->_name.UTF8String) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    l->_src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)lfd, 0, l->_io);
    __weak _XPCListenerImpl *weakL = l;
    dispatch_source_set_event_handler(l->_src, ^{
        int fd = accept(lfd, NULL, NULL);
        _XPCListenerImpl *me = weakL;
        if (fd < 0 || !me) { if (fd >= 0) close(fd); return; }
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        _XPCSession *peer = [_XPCSession new];
        peer->_role = L_PEER; peer->_name = me->_name; peer->_target = me->_target; peer->_owner = peer;
        [peer _attach:fd];
        xpc_listener_incoming_session_handler_t h = me->_handler;
        dispatch_async(me->_target, ^{
            if (h) h((xpc_session_t)peer);
            dispatch_async(peer->_io, ^{
                if (peer->_rejected) {
                    const char *why = (peer->_rejectReason ?: @"rejected").UTF8String;
                    [peer _sendFrame:F_REJECT serial:0 replyTo:0 payload:[NSData dataWithBytes:why length:strlen(why)]];
                    peer->_cancelled = YES; peer->_invalidated = YES;
                    [peer _closed:NO];
                    peer->_owner = nil;
                    return;
                }
                peer->_active = YES;                /* accepted: messages flow to its incoming handler */
                NSArray *held = [peer->_held copy]; [peer->_held removeAllObjects];
                for (OS_xpc_object *m in held) [peer _received:m];
            });
        });
    });
    NSString *path = l->_path;
    dispatch_source_set_cancel_handler(l->_src, ^{ close(lfd); unlink(path.fileSystemRepresentation); });
    dispatch_resume(l->_src);
    return true;
}
void xpc_listener_cancel(xpc_listener_t xl) {
    _XPCListenerImpl *l = lis_of(xl);
    l->_cancelled = YES;
    if (l->_src) { dispatch_source_cancel(l->_src); l->_src = nil; }
    if (l->_name) unlink(registry_path(l->_name.UTF8String).fileSystemRepresentation);
}
void xpc_listener_reject_peer(xpc_session_t peer, const char *reason) {
    _XPCSession *s = sess_of(peer);
    s->_rejected = YES; s->_rejectReason = reason ? @(reason) : nil;
}
xpc_endpoint_t xpc_listener_copy_endpoint(xpc_listener_t xl) {
    _XPCListenerImpl *l = lis_of(xl);
    _XPCEndpoint *e = [_XPCEndpoint new]; e->_path = l->_path; e->_name = l->_name;
    return (xpc_endpoint_t)e;
}
char *xpc_listener_copy_description(xpc_listener_t l) { return xpc_copy_description((xpc_object_t)l); }
int xpc_listener_set_peer_code_signing_requirement(xpc_listener_t l, const char *r) { return 0; }

/* ================= activities ================= */
const char *const XPC_ACTIVITY_INTERVAL = "Interval";
const char *const XPC_ACTIVITY_REPEATING = "Repeating";
const char *const XPC_ACTIVITY_DELAY = "Delay";
const char *const XPC_ACTIVITY_GRACE_PERIOD = "GracePeriod";
const char *const XPC_ACTIVITY_PRIORITY = "Priority";
const char *const XPC_ACTIVITY_PRIORITY_MAINTENANCE = "Maintenance";
const char *const XPC_ACTIVITY_PRIORITY_UTILITY = "Utility";
const char *const XPC_ACTIVITY_ALLOW_BATTERY = "AllowBattery";
const char *const XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP = "RequireScreenSleep";
const char *const XPC_ACTIVITY_PREVENT_DEVICE_SLEEP = "PreventDeviceSleep";
const char *const XPC_ACTIVITY_REQUIRE_BATTERY_LEVEL = "RequireBatteryLevel";
const char *const XPC_ACTIVITY_REQUIRE_HDD_SPINNING = "RequireHDDSpinning";
const int64_t XPC_ACTIVITY_INTERVAL_1_MIN = 60, XPC_ACTIVITY_INTERVAL_5_MIN = 300, XPC_ACTIVITY_INTERVAL_15_MIN = 900,
    XPC_ACTIVITY_INTERVAL_30_MIN = 1800, XPC_ACTIVITY_INTERVAL_1_HOUR = 3600, XPC_ACTIVITY_INTERVAL_4_HOURS = 14400,
    XPC_ACTIVITY_INTERVAL_8_HOURS = 28800, XPC_ACTIVITY_INTERVAL_1_DAY = 86400, XPC_ACTIVITY_INTERVAL_7_DAYS = 604800;

@interface _XPCActivity : OS_xpc_object {
@public
    NSString *_ident;
    xpc_object_t _criteria;
    xpc_activity_handler_t _handler;
    xpc_activity_state_t _state;
    uint64_t _generation;
}
@end
@implementation _XPCActivity
- (xpc_type_t)_type { return XPC_TYPE_ACTIVITY; }
- (void)_describe:(NSMutableString *)out indent:(int)indent { [out appendFormat:@"<activity: %p> { name = %@, state = %ld }", self, _ident, _state]; }
@end
static NSMutableDictionary<NSString *, _XPCActivity *> *activities(void) {
    static NSMutableDictionary *d; static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}
static dispatch_queue_t activity_queue(void) {
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("isim.xpc.activity", DISPATCH_QUEUE_SERIAL); });
    return q;
}
static void activity_schedule(_XPCActivity *a, int64_t delay) {
    uint64_t gen = a->_generation;
    a->_state = XPC_ACTIVITY_STATE_WAIT;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, MAX(delay, 0) * NSEC_PER_SEC), activity_queue(), ^{
        if (a->_generation != gen || !activities()[a->_ident]) return;
        a->_state = XPC_ACTIVITY_STATE_RUN;
        a->_handler((xpc_activity_t)a);
        if (a->_state == XPC_ACTIVITY_STATE_RUN) a->_state = XPC_ACTIVITY_STATE_DONE;   /* returned without saying */
        if (a->_state == XPC_ACTIVITY_STATE_DEFER) { activity_schedule(a, 1); return; }
        if (a->_state == XPC_ACTIVITY_STATE_DONE && xpc_dictionary_get_bool(a->_criteria, XPC_ACTIVITY_REPEATING))
            activity_schedule(a, MAX(xpc_dictionary_get_int64(a->_criteria, XPC_ACTIVITY_INTERVAL), 1));
    });
}
void xpc_activity_register(const char *identifier, xpc_object_t criteria, xpc_activity_handler_t handler) {
    NSString *ident = @(identifier);
    xpc_activity_handler_t h = [handler copy];
    dispatch_async(activity_queue(), ^{
        _XPCActivity *a = activities()[ident];
        if (criteria == XERR(_xpc_activity_check_in)) {      /* check in: only an activity registered earlier runs */
            if (!a) return;
            a->_handler = h;
            a->_state = XPC_ACTIVITY_STATE_CHECK_IN;
            h((xpc_activity_t)a);
            return;
        }
        if (!a) { a = [_XPCActivity new]; a->_ident = ident; activities()[ident] = a; }
        a->_criteria = xpc_copy(criteria); a->_handler = h; a->_generation++;
        a->_state = XPC_ACTIVITY_STATE_CHECK_IN;
        h((xpc_activity_t)a);
        activity_schedule(a, xpc_dictionary_get_int64(a->_criteria, XPC_ACTIVITY_DELAY));
    });
}
void xpc_activity_unregister(const char *identifier) {
    NSString *ident = @(identifier);
    dispatch_async(activity_queue(), ^{ [activities() removeObjectForKey:ident]; });
}
static _XPCActivity *act_of(xpc_activity_t a) { return [O(a) isKindOfClass:[_XPCActivity class]] ? (_XPCActivity *)O(a) : nil; }
xpc_object_t xpc_activity_copy_criteria(xpc_activity_t a) { _XPCActivity *x = act_of(a); return x->_criteria ? xpc_copy(x->_criteria) : nil; }
void xpc_activity_set_criteria(xpc_activity_t a, xpc_object_t c) {
    _XPCActivity *x = act_of(a);
    x->_criteria = xpc_copy(c); x->_generation++;
    activity_schedule(x, xpc_dictionary_get_int64(c, XPC_ACTIVITY_DELAY));
}
xpc_activity_state_t xpc_activity_get_state(xpc_activity_t a) { return act_of(a)->_state; }
bool xpc_activity_set_state(xpc_activity_t a, xpc_activity_state_t s) {
    _XPCActivity *x = act_of(a);
    if (s != XPC_ACTIVITY_STATE_CONTINUE && s != XPC_ACTIVITY_STATE_DONE && s != XPC_ACTIVITY_STATE_DEFER) return false;
    BOOL wasContinuing = x->_state == XPC_ACTIVITY_STATE_CONTINUE;
    x->_state = s;
    if (wasContinuing && s == XPC_ACTIVITY_STATE_DONE && xpc_dictionary_get_bool(x->_criteria, XPC_ACTIVITY_REPEATING))
        dispatch_async(activity_queue(), ^{ activity_schedule(x, MAX(xpc_dictionary_get_int64(x->_criteria, XPC_ACTIVITY_INTERVAL), 1)); });
    return true;
}
bool xpc_activity_should_defer(xpc_activity_t a) { return false; }

/* ================= event streams, xpc_main, transactions ================= */
void xpc_set_event_stream_handler(const char *stream, dispatch_queue_t q, xpc_handler_t handler) {
    /* isim's devices deliver no launchd events (IOKit matching, distributed notifications) */
}
void xpc_main(xpc_connection_handler_t handler) {
    const char *name = [NSBundle mainBundle].bundleIdentifier.UTF8String ?: getprogname();
    xpc_connection_t listener = xpc_connection_create_mach_service(name, dispatch_get_main_queue(), XPC_CONNECTION_MACH_SERVICE_LISTENER);
    xpc_connection_set_event_handler(listener, ^(xpc_object_t peer) {
        if (xpc_get_type(peer) == XPC_TYPE_CONNECTION) handler((xpc_connection_t)peer);
    });
    xpc_connection_resume(listener);
    objc_setAssociatedObject([NSBundle mainBundle], "isim.xpc_main", listener, OBJC_ASSOCIATION_RETAIN);
    dispatch_main();
}
void xpc_transaction_begin(void) {}
void xpc_transaction_end(void) {}

/* ================= for NSXPCConnection (NSXPC.m) ================= */
xpc_connection_t _isim_xpc_remote_connection(xpc_object_t message) {
    _XPCDictionary *d = dict_of(message);
    return d && [d->_from isKindOfClass:[_XPCConnection class]] ? (xpc_connection_t)d->_from : nil;
}
xpc_connection_t xpc_dictionary_get_remote_connection(xpc_object_t message) { return _isim_xpc_remote_connection(message); }
NSString *_isim_xpc_endpoint_path(xpc_endpoint_t e) { return [O(e) isKindOfClass:[_XPCEndpoint class]] ? ((_XPCEndpoint *)O(e))->_path : nil; }
NSString *_isim_xpc_endpoint_name(xpc_endpoint_t e) { return [O(e) isKindOfClass:[_XPCEndpoint class]] ? ((_XPCEndpoint *)O(e))->_name : nil; }
xpc_endpoint_t _isim_xpc_endpoint_with_path(NSString *path, NSString *name) {
    _XPCEndpoint *e = [_XPCEndpoint new]; e->_path = path; e->_name = name; return (xpc_endpoint_t)e;
}
bool _isim_xpc_message_expects_reply(xpc_object_t m) { _XPCDictionary *d = dict_of(m); return d && d->_from && d->_wantsReply; }
bool _isim_xpc_message_is_sync(xpc_object_t m) { _XPCDictionary *d = dict_of(m); return d && d->_sync; }
bool _isim_xpc_reply(xpc_object_t m, xpc_object_t contents) {
    _XPCDictionary *r = (_XPCDictionary *)O(xpc_dictionary_create_reply(m)), *c = dict_of(contents);
    if (!r) return false;
    for (NSString *k in c->_keys) [r _set:k value:c->_values[k]];
    return [r->_replyTo _send:r wantsReply:nil];
}
