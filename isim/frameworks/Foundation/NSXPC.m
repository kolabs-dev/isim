/* isim Foundation: NSXPCConnection, NSXPCListener, NSXPCInterface, NSXPCListenerEndpoint and NSXPCCoder over isim's XPC
 * connections (XPC.m; issue #357). Self-authored, Apple's API. Adapted:
 *   - a message to a remote object proxy is an XPC message with the selector and its arguments, archived with
 *     NSKeyedArchiver: objects (NSSecureCoding, including NSXPCListenerEndpoint), numbers and BOOLs, classes and C
 *     strings; the exported object's method runs on the connection's queue with NSXPCConnection.currentConnection set.
 *   - a reply block travels as the reply to that message: the exported object gets a block of the reply's signature
 *     (from the protocol's extended type encodings; without them, one object argument) whose call sends the reply,
 *     and the caller's block runs with the reply's arguments; an interrupted or invalid connection calls the proxy's
 *     error handler instead (NSXPCConnectionInterrupted / NSXPCConnectionInvalid).
 *   - the allowed classes (setClasses:forSelector:...) are recorded and not enforced; proxies passed as arguments
 *     (setInterface:forSelector:...) are not supported.
 *   - serviceListener listens for the app's bundle identifier; nothing launches services on demand (XPC.m). */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "isim_xpc.h"
#include <pthread.h>
#include <stddef.h>
#include <string.h>

extern void _objc_msgForward(void);

/* ================= blocks: signatures, calling them, making forwarding ones ================= */
struct isim_block_desc { unsigned long reserved, size; const void *rest[]; };
struct isim_block { void *isa; int flags; int reserved; void (*invoke)(void); struct isim_block_desc *desc; };
enum { BLOCK_HAS_COPY_DISPOSE = 1 << 25, BLOCK_IS_GLOBAL = 1 << 28, BLOCK_HAS_SIGNATURE = 1 << 30 };

static const char *block_signature(id block) {
    struct isim_block *b = (__bridge struct isim_block *)block;
    if (!b || !(b->flags & BLOCK_HAS_SIGNATURE) || !b->desc) return NULL;
    return b->desc->rest[(b->flags & BLOCK_HAS_COPY_DISPOSE) ? 2 : 0];
}

/* a type encoding without quoted class names and block signatures (what NSMethodSignature reads) */
static NSString *plain_types(const char *t) {
    NSMutableString *s = [NSMutableString string];
    for (; *t; t++) {
        if (*t == '"') { t = strchr(t + 1, '"'); if (!t) break; continue; }
        if (*t == '<') { int depth = 1; while (depth && *++t) { if (*t == '<') depth++; else if (*t == '>') depth--; } if (!*t) break; continue; }
        [s appendFormat:@"%c", *t];
    }
    return s;
}

/* the protocol's extended method type encodings (clang emits them after the protocol's flags) */
struct isim_method { SEL name; const char *types; IMP imp; };
struct isim_mlist { uint32_t entsizeAndFlags, count; };
struct isim_proto {
    Class isa; const char *name; void *protocols;
    struct isim_mlist *inst, *cls, *opt_inst, *opt_cls; void *props;
    uint32_t size, flags; const char **extended;
};
static const char *extended_types(Protocol *p, SEL sel, int depth) {
    if (!p || depth > 8) return NULL;
    struct isim_proto *pr = (__bridge struct isim_proto *)p;
    if (pr->size >= offsetof(struct isim_proto, extended) + sizeof(void *) && pr->extended) {
        struct isim_mlist *lists[4] = { pr->inst, pr->cls, pr->opt_inst, pr->opt_cls };
        uint32_t index = 0;
        for (int l = 0; l < 4; l++) {
            struct isim_mlist *ml = lists[l];
            if (!ml) continue;
            if (ml->entsizeAndFlags & 0x80000000u) return NULL;            /* small method lists: no extended types here */
            uint32_t entsize = ml->entsizeAndFlags & 0xfffc;
            for (uint32_t i = 0; i < ml->count; i++, index++) {
                const struct isim_method *m = (const void *)((const char *)(ml + 1) + i * entsize);
                if (m->name == sel && (l == 0 || l == 2)) return pr->extended[index];
            }
        }
    }
    unsigned n = 0;
    Protocol * __unsafe_unretained *parents = protocol_copyProtocolList(p, &n);
    const char *t = NULL;
    for (unsigned i = 0; !t && i < n; i++) t = extended_types(parents[i], sel, depth + 1);
    free(parents);
    return t;
}
static const char *method_types(Protocol *p, SEL sel) {
    struct objc_method_description d = protocol_getMethodDescription(p, sel, YES, YES);
    if (!d.types) d = protocol_getMethodDescription(p, sel, NO, YES);
    return d.types;
}
/* the signature of the reply block argument at `index` (counting self and _cmd), from the extended types */
static NSString *reply_block_types(Protocol *p, SEL sel, NSUInteger index) {
    const char *ext = extended_types(p, sel, 0);
    if (!ext) return nil;
    const char *t = ext;
    /* walk the encoding: return type, then each argument (each followed by its offset digits) */
    for (NSUInteger arg = 0; *t; arg++) {
        while (*t && strchr("rnNoORV", *t)) t++;
        const char *start = t;
        if (t[0] == '@' && t[1] == '?') {
            t += 2;
            if (*t == '<') {
                const char *open = t; int depth = 1;
                while (depth && *++t) { if (*t == '<') depth++; else if (*t == '>') depth--; }
                if (arg == index + 1) return plain_types([[NSString alloc] initWithBytes:open + 1 length:(NSUInteger)(t - open - 1) encoding:NSUTF8StringEncoding].UTF8String);
                if (*t) t++;
            }
        } else if (*t == '@') {
            t++; if (*t == '"') { t = strchr(t + 1, '"'); t = t ? t + 1 : start + 1; }
        } else if (*t == '{' || *t == '(' || *t == '[') {
            char open = *t, close = open == '{' ? '}' : open == '(' ? ')' : ']'; int depth = 1;
            while (depth && *++t) { if (*t == open) depth++; else if (*t == close) depth--; }
            if (*t) t++;
        } else if (*t == '^') {
            t++; if (*t) t++;
        } else if (*t) t++;
        while (*t >= '0' && *t <= '9') t++;
        (void)start;
    }
    return nil;
}

/* values <-> archivable boxes */
static id box_argument(NSInvocation *inv, NSUInteger i, const char *type) {
    while (*type && strchr("rnNoORV", *type)) type++;
    switch (*type) {
    case '@': { __unsafe_unretained id o = nil; [inv getArgument:&o atIndex:(NSInteger)i]; return o ?: [NSNull null]; }
    case '#': { __unsafe_unretained Class c = Nil; [inv getArgument:&c atIndex:(NSInteger)i]; return c ? @{ @"$class": NSStringFromClass(c) } : [NSNull null]; }
    case '*': { char *s = NULL; [inv getArgument:&s atIndex:(NSInteger)i]; return s ? @{ @"$cstring": @(s) } : [NSNull null]; }
    case 'c': { char v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'B': { bool v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'C': { unsigned char v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 's': { short v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'S': { unsigned short v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'i': { int v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'I': { unsigned v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'l': case 'q': { long long v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'L': case 'Q': { unsigned long long v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'f': { float v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    case 'd': { double v; [inv getArgument:&v atIndex:(NSInteger)i]; return @(v); }
    default:
        [NSException raise:NSInvalidArgumentException format:@"NSXPCConnection: argument type %s cannot be sent (isim sends objects and numbers)", type];
        return nil;
    }
}
static void unbox_argument(NSInvocation *inv, NSUInteger i, const char *type, id v) {
    while (*type && strchr("rnNoORV", *type)) type++;
    if (v == [NSNull null]) v = nil;
    switch (*type) {
    case '@': { __unsafe_unretained id o = v; [inv setArgument:&o atIndex:(NSInteger)i]; break; }
    case '#': { __unsafe_unretained Class c = v ? NSClassFromString(v[@"$class"]) : Nil; [inv setArgument:&c atIndex:(NSInteger)i]; break; }
    case '*': { const char *s = v ? [v[@"$cstring"] UTF8String] : NULL; [inv setArgument:&s atIndex:(NSInteger)i]; break; }
    case 'c': { char x = [v charValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'B': { bool x = [v boolValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'C': { unsigned char x = [v unsignedCharValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 's': { short x = [v shortValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'S': { unsigned short x = (unsigned short)[v unsignedIntValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'i': { int x = [v intValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'I': { unsigned x = [v unsignedIntValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'l': case 'q': { long long x = [v longLongValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'L': case 'Q': { unsigned long long x = [v unsignedLongLongValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'f': { float x = [v floatValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    case 'd': { double x = [v doubleValue]; [inv setArgument:&x atIndex:(NSInteger)i]; break; }
    default: break;
    }
}
static NSData *archive(NSArray *values) { return [NSKeyedArchiver archivedDataWithRootObject:values requiringSecureCoding:NO error:NULL]; }
static NSArray *unarchive(const void *bytes, size_t len) {
    if (!bytes) return @[];
    id v = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithBytes:bytes length:len]];
    return [v isKindOfClass:[NSArray class]] ? v : @[];
}

/* the block the exported object gets for a reply: calling it (through _objc_msgForward) sends the reply.
   Its layout after the isa is a block's (flags, reserved, invoke, descriptor). */
@interface _NSXPCReplyBlock : NSObject {
@public
    int _flags, _reserved;
    void (*_invoke)(void);
    struct isim_block_desc *_desc;
    NSString *_types;               /* the block's signature: return type, the block, the arguments */
    void (^_send)(NSArray *values);
    BOOL _sent;
}
@end
static struct isim_block_desc s_replyDesc = { 0, sizeof(struct isim_block) };
@implementation _NSXPCReplyBlock
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    /* called with the block's first argument where the selector would be: answer the block's own signature */
    return [NSMethodSignature signatureWithObjCTypes:_types.UTF8String];
}
- (id)forwardingTargetForSelector:(SEL)sel { return nil; }
- (void)forwardInvocation:(NSInvocation *)inv {
    if (_sent) return;
    _sent = YES;
    NSMethodSignature *sig = inv.methodSignature;
    NSMutableArray *values = [NSMutableArray array];
    for (NSUInteger i = 1; i < sig.numberOfArguments; i++) [values addObject:box_argument(inv, i, [sig getArgumentTypeAtIndex:i])];
    _send(values);
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
static id make_reply_block(NSString *types, void (^send)(NSArray *)) {
    _NSXPCReplyBlock *b = [_NSXPCReplyBlock new];
    b->_flags = BLOCK_IS_GLOBAL; b->_invoke = _objc_msgForward; b->_desc = &s_replyDesc;
    b->_types = types; b->_send = [send copy];
    return b;
}
static void call_block(id block, NSArray *values) {
    const char *sig = block_signature(block);
    NSString *types = sig ? plain_types(sig) : @"v@?@";
    NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:types.UTF8String];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
    [inv setTarget:block];
    for (NSUInteger i = 1; i < ms.numberOfArguments; i++)
        unbox_argument(inv, i, [ms getArgumentTypeAtIndex:i], i - 1 < values.count ? values[i - 1] : nil);
    [inv retainArguments];
    [inv invokeUsingIMP:(IMP)((__bridge struct isim_block *)block)->invoke];
}

/* ================= NSXPCInterface ================= */
@implementation NSXPCInterface {
    NSMutableDictionary *_classes, *_interfaces, *_types;
}
+ (NSXPCInterface *)interfaceWithProtocol:(Protocol *)protocol { NSXPCInterface *i = [self new]; i.protocol = protocol; return i; }
- (instancetype)init {
    if ((self = [super init])) { _classes = [NSMutableDictionary dictionary]; _interfaces = [NSMutableDictionary dictionary]; _types = [NSMutableDictionary dictionary]; }
    return self;
}
static NSString *slot(SEL sel, NSUInteger arg, BOOL reply) { return [NSString stringWithFormat:@"%@#%lu#%d", NSStringFromSelector(sel), (unsigned long)arg, reply]; }
- (void)setClasses:(NSSet<Class> *)classes forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply { _classes[slot(sel, arg, ofReply)] = classes; }
- (NSSet<Class> *)classesForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply {
    return _classes[slot(sel, arg, ofReply)] ?: [NSSet setWithObjects:[NSString class], [NSNumber class], [NSData class], [NSDate class],
                                                [NSArray class], [NSDictionary class], [NSError class], [NSNull class], [NSUUID class], nil];
}
- (void)setInterface:(NSXPCInterface *)ifc forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply { _interfaces[slot(sel, arg, ofReply)] = ifc; }
- (NSXPCInterface *)interfaceForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply { return _interfaces[slot(sel, arg, ofReply)]; }
- (void)setXPCType:(xpc_type_t)type forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply {
    _types[slot(sel, arg, ofReply)] = [NSValue valueWithPointer:type];
}
- (xpc_type_t)XPCTypeForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply { return [_types[slot(sel, arg, ofReply)] pointerValue]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSXPCInterface: %p> Protocol: %s", self, self.protocol ? protocol_getName(self.protocol) : "(none)"]; }
@end

/* ================= NSXPCListenerEndpoint ================= */
@interface NSXPCListenerEndpoint () { @public xpc_endpoint_t _endpoint; NSString *_path, *_name; }
@end
@implementation NSXPCListenerEndpoint
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_path forKey:@"path"]; [c encodeObject:_name forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { _path = [c decodeObjectOfClass:[NSString class] forKey:@"path"]; _name = [c decodeObjectOfClass:[NSString class] forKey:@"name"]; }
    return self;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSXPCListenerEndpoint class]] && [((NSXPCListenerEndpoint *)o)->_path isEqual:_path]; }
- (NSUInteger)hash { return _path.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSXPCListenerEndpoint: %p> { name = %@ }", self, _name ?: @"(anonymous)"]; }
@end
static NSXPCListenerEndpoint *endpoint_of(xpc_endpoint_t e) {
    NSXPCListenerEndpoint *n = [NSXPCListenerEndpoint new];
    n->_endpoint = e; n->_path = _isim_xpc_endpoint_path(e); n->_name = _isim_xpc_endpoint_name(e);
    return n;
}

/* ================= NSXPCConnection ================= */
static __thread void *s_current;

@interface _NSXPCRemoteProxy : NSProxy {
@public
    __weak NSXPCConnection *_conn;
    void (^_errorHandler)(NSError *);
    BOOL _sync;
}
@end

@interface NSXPCConnection () {
@public
    xpc_connection_t _xpc;
    dispatch_queue_t _queue;
    NSString *_serviceName;
    NSXPCListenerEndpoint *_endpoint;
    BOOL _invalidated, _resumed;
    id _keepAlive;                  /* an accepted connection stays alive until it is invalidated */
}
- (instancetype)_initWithXPC:(xpc_connection_t)c;
@end

static NSError *xpc_nserror(xpc_object_t e) {
    BOOL interrupted = e == XPC_ERROR_CONNECTION_INTERRUPTED;
    NSString *desc = interrupted ? @"Couldn't communicate with a helper application." : @"The connection was invalidated.";
    return [NSError errorWithDomain:NSCocoaErrorDomain code:interrupted ? NSXPCConnectionInterrupted : NSXPCConnectionInvalid
                           userInfo:@{ NSDebugDescriptionErrorKey: desc }];
}

@implementation NSXPCConnection
- (instancetype)_initWithXPC:(xpc_connection_t)c {
    if ((self = [super init])) {
        _xpc = c;
        _queue = dispatch_queue_create("isim.NSXPCConnection", DISPATCH_QUEUE_SERIAL);
        xpc_connection_set_target_queue(_xpc, _queue);
        __weak NSXPCConnection *weakSelf = self;
        xpc_connection_set_event_handler(_xpc, ^(xpc_object_t event) { [weakSelf _event:event]; });
    }
    return self;
}
- (instancetype)initWithServiceName:(NSString *)serviceName {
    if ((self = [self _initWithXPC:xpc_connection_create(serviceName.UTF8String, NULL)])) _serviceName = [serviceName copy];
    return self;
}
- (instancetype)initWithMachServiceName:(NSString *)name options:(NSXPCConnectionOptions)options {
    if ((self = [self _initWithXPC:xpc_connection_create_mach_service(name.UTF8String, NULL, 0)])) _serviceName = [name copy];
    return self;
}
- (instancetype)initWithListenerEndpoint:(NSXPCListenerEndpoint *)endpoint {
    xpc_endpoint_t e = endpoint->_endpoint;
    if (!e) e = _isim_xpc_endpoint_with_path(endpoint->_path, endpoint->_name);   /* one that arrived in a message */
    if ((self = [self _initWithXPC:xpc_connection_create_from_endpoint(e)])) _endpoint = endpoint;
    return self;
}
- (NSString *)serviceName { return _serviceName; }
- (NSXPCListenerEndpoint *)endpoint { return _endpoint ?: endpoint_of(xpc_endpoint_create(_xpc)); }
- (id)remoteObjectProxy { return [self remoteObjectProxyWithErrorHandler:^(NSError *e) {}]; }
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *))handler {
    _NSXPCRemoteProxy *p = [_NSXPCRemoteProxy alloc];
    p->_conn = self; p->_errorHandler = [handler copy];
    return p;
}
- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *))handler {
    _NSXPCRemoteProxy *p = [self remoteObjectProxyWithErrorHandler:handler];
    p->_sync = YES;
    return p;
}
- (void)resume { _resumed = YES; xpc_connection_resume(_xpc); }
- (void)activate { if (!_resumed) { _resumed = YES; xpc_connection_activate(_xpc); } }
- (void)suspend { xpc_connection_suspend(_xpc); }
- (void)invalidate { xpc_connection_cancel(_xpc); }
- (au_asid_t)auditSessionIdentifier { return 0; }
- (pid_t)processIdentifier { return xpc_connection_get_pid(_xpc); }
- (uid_t)effectiveUserIdentifier { return xpc_connection_get_euid(_xpc); }
- (gid_t)effectiveGroupIdentifier { return xpc_connection_get_egid(_xpc); }
+ (NSXPCConnection *)currentConnection { return (__bridge NSXPCConnection *)s_current; }
- (void)scheduleSendBarrierBlock:(void (^)(void))block { xpc_connection_send_barrier(_xpc, block); }
- (void)setCodeSigningRequirement:(NSString *)requirement {}
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSXPCConnection: %p> connection from pid %d on %@", self, (int)self.processIdentifier,
            _serviceName ? [NSString stringWithFormat:@"mach service named %@", _serviceName] : @"anonymousListener or serviceListener"];
}

- (void)_event:(xpc_object_t)event {
    xpc_type_t t = xpc_get_type(event);
    if (t == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INTERRUPTED) { void (^h)(void) = self.interruptionHandler; if (h) h(); return; }
        if (_invalidated) return;
        _invalidated = YES;
        void (^h)(void) = self.invalidationHandler;
        self.invalidationHandler = nil; self.interruptionHandler = nil;
        if (h) h();
        _keepAlive = nil;
        return;
    }
    if (t != XPC_TYPE_DICTIONARY) return;
    [self _invoke:event];
}
/* a message for the exported object */
- (void)_invoke:(xpc_object_t)msg {
    const char *selName = xpc_dictionary_get_string(msg, "sel");
    id target = self.exportedObject;
    Protocol *proto = self.exportedInterface.protocol;
    SEL sel = selName ? sel_registerName(selName) : NULL;
    const char *types = sel && proto ? method_types(proto, sel) : NULL;
    if (!target || !types || ![target respondsToSelector:sel]) {
        NSLog(@"NSXPCConnection: the exported object does not handle %s (exported interface %@)", selName ?: "?", self.exportedInterface);
        return;
    }
    size_t len = 0;
    const void *bytes = xpc_dictionary_get_data(msg, "args", &len);
    NSArray *values = unarchive(bytes, len);
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:types];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target; inv.selector = sel;
    NSUInteger v = 0;
    xpc_connection_t xpc = _xpc;
    for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
        const char *at = [sig getArgumentTypeAtIndex:i];
        if (at[0] == '@' && at[1] == '?') {
            NSString *btypes = reply_block_types(proto, sel, i) ?: @"v@?@";
            id block = make_reply_block(btypes, ^(NSArray *replyValues) {
                xpc_object_t reply = xpc_dictionary_create_reply(msg);
                if (!reply) return;
                NSData *d = archive(replyValues);
                xpc_dictionary_set_data(reply, "args", d.bytes, d.length);
                xpc_connection_send_message(xpc, reply);
            });
            __unsafe_unretained id b = block;
            [inv setArgument:&b atIndex:(NSInteger)i];
            objc_setAssociatedObject(inv, "isim.reply", block, OBJC_ASSOCIATION_RETAIN);
        } else {
            unbox_argument(inv, i, at, v < values.count ? values[v] : nil);
            v++;
        }
    }
    [inv retainArguments];
    void *saved = s_current;
    s_current = (__bridge void *)self;
    @try { [inv invoke]; }
    @catch (NSException *e) { NSLog(@"NSXPCConnection: exception in %s: %@", selName, e); }
    s_current = saved;
}
@end

@implementation _NSXPCRemoteProxy
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSXPCConnection *c = _conn;
    const char *types = c.remoteObjectInterface.protocol ? method_types(c.remoteObjectInterface.protocol, sel) : NULL;
    if (!types) [NSException raise:NSInvalidArgumentException format:@"NSXPCConnection: %@ is not in the remote object interface %@", NSStringFromSelector(sel), c.remoteObjectInterface];
    return [NSMethodSignature signatureWithObjCTypes:types];
}
- (BOOL)respondsToSelector:(SEL)sel {
    NSXPCConnection *c = _conn;
    return c.remoteObjectInterface.protocol && method_types(c.remoteObjectInterface.protocol, sel);
}
- (void)forwardInvocation:(NSInvocation *)inv {
    NSXPCConnection *c = _conn;
    void (^errorHandler)(NSError *) = _errorHandler;
    if (!c) return;
    NSMethodSignature *sig = inv.methodSignature;
    NSMutableArray *values = [NSMutableArray array];
    id replyBlock = nil;
    for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
        const char *at = [sig getArgumentTypeAtIndex:i];
        if (at[0] == '@' && at[1] == '?') { __unsafe_unretained id b = nil; [inv getArgument:&b atIndex:(NSInteger)i]; replyBlock = b; }
        else [values addObject:box_argument(inv, i, at)];
    }
    xpc_object_t msg = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(msg, "sel", NSStringFromSelector(inv.selector).UTF8String);
    NSData *d = archive(values);
    xpc_dictionary_set_data(msg, "args", d.bytes, d.length);
    if (!replyBlock) { xpc_connection_send_message(c->_xpc, msg); return; }
    id block = [replyBlock copy];
    void (^handle)(xpc_object_t) = ^(xpc_object_t reply) {
        if (xpc_get_type(reply) == XPC_TYPE_ERROR) { if (errorHandler) errorHandler(xpc_nserror(reply)); return; }
        size_t len = 0;
        const void *bytes = xpc_dictionary_get_data(reply, "args", &len);
        call_block(block, unarchive(bytes, len));
    };
    if (_sync) handle(xpc_connection_send_message_with_reply_sync(c->_xpc, msg));
    else xpc_connection_send_message_with_reply(c->_xpc, msg, c->_queue, handle);
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSXPCConnection remote object proxy %p>", self]; }
@end

/* ================= NSXPCListener ================= */
@implementation NSXPCListener {
    xpc_connection_t _xpc;
    BOOL _service, _resumed;
    dispatch_queue_t _queue;
}
+ (NSXPCListener *)serviceListener {
    static NSXPCListener *l; static dispatch_once_t once;
    dispatch_once(&once, ^{
        l = [[NSXPCListener alloc] initWithMachServiceName:[NSBundle mainBundle].bundleIdentifier ?: @(getprogname())];
        l->_service = YES;
    });
    return l;
}
+ (NSXPCListener *)anonymousListener { return [[self alloc] _initWithXPC:xpc_connection_create(NULL, NULL)]; }
- (instancetype)initWithMachServiceName:(NSString *)name {
    return [self _initWithXPC:xpc_connection_create_mach_service(name.UTF8String, NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER)];
}
- (instancetype)init { return [self initWithMachServiceName:@"(isim anonymous)"]; }
- (instancetype)_initWithXPC:(xpc_connection_t)c {
    if ((self = [super init])) {
        _xpc = c;
        _queue = dispatch_queue_create("isim.NSXPCListener", DISPATCH_QUEUE_SERIAL);
        xpc_connection_set_target_queue(_xpc, _queue);
        __weak NSXPCListener *weakSelf = self;
        xpc_connection_set_event_handler(_xpc, ^(xpc_object_t event) {
            NSXPCListener *me = weakSelf;
            if (!me || xpc_get_type(event) != XPC_TYPE_CONNECTION) return;
            NSXPCConnection *conn = [[NSXPCConnection alloc] _initWithXPC:(xpc_connection_t)event];
            id<NSXPCListenerDelegate> delegate = me.delegate;
            BOOL accept = [delegate respondsToSelector:@selector(listener:shouldAcceptNewConnection:)] && [delegate listener:me shouldAcceptNewConnection:conn];
            if (accept) { conn->_keepAlive = conn; if (!conn->_resumed) [conn resume]; }
            else [conn invalidate];
        });
    }
    return self;
}
- (NSXPCListenerEndpoint *)endpoint { return endpoint_of(xpc_endpoint_create(_xpc)); }
- (void)resume {
    if (!_resumed) { _resumed = YES; xpc_connection_resume(_xpc); }
    if (_service) dispatch_main();                  /* an XPC service's listener runs for the life of the process */
}
- (void)activate { if (!_resumed) { _resumed = YES; xpc_connection_activate(_xpc); } }
- (void)suspend { xpc_connection_suspend(_xpc); }
- (void)invalidate { xpc_connection_cancel(_xpc); }
- (void)setConnectionCodeSigningRequirement:(NSString *)requirement {}
@end

/* ================= NSXPCCoder ================= */
@implementation NSXPCCoder {
    NSMutableDictionary *_objects;
}
- (instancetype)init { if ((self = [super init])) _objects = [NSMutableDictionary dictionary]; return self; }
- (NSXPCConnection *)connection { return [NSXPCConnection currentConnection]; }
- (BOOL)allowsKeyedCoding { return YES; }
- (void)encodeXPCObject:(xpc_object_t)xpcObject forKey:(NSString *)key { _objects[key] = xpcObject; }
- (xpc_object_t)decodeXPCObjectOfType:(xpc_type_t)type forKey:(NSString *)key {
    xpc_object_t o = _objects[key];
    return o && xpc_get_type(o) == type ? o : nil;
}
@end
