// isim JavaScriptCore: the Objective-C API (JSVirtualMachine, JSContext, JSValue, JSManagedValue, JSExport) on top of
// the C API, which libisim_jsc.dylib forwards to the host's JavaScriptCore (runtime/host_jsc.c).
//
// Adapted, compared with Apple's implementation:
// - values: JSValue keeps its JavaScript value alive (JSValueProtect) while it exists; JSManagedValue does the same
//   (Apple's is a conditional reference; the difference only shows in when JavaScript collects garbage);
// - blocks become JavaScript functions called through the block's type signature (its parameters typed JSValue,
//   NSString, NSNumber, NSArray, NSDictionary, NSDate, id, BOOL, integers or doubles); JSContext.currentArguments,
//   currentThis and currentCallee work inside them;
// - Objective-C objects are wrapped: the instance methods and properties their classes declare in protocols that
//   conform to JSExport are visible to JavaScript (JSExportAs renames a method); class methods and constructors are not
//   exported.
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/runtime.h>

NSString * const JSPropertyDescriptorWritableKey = @"writable";
NSString * const JSPropertyDescriptorEnumerableKey = @"enumerable";
NSString * const JSPropertyDescriptorConfigurableKey = @"configurable";
NSString * const JSPropertyDescriptorValueKey = @"value";
NSString * const JSPropertyDescriptorGetKey = @"get";
NSString * const JSPropertyDescriptorSetKey = @"set";

static JSStringRef js_string(NSString *s) { return JSStringCreateWithUTF8CString((s ?: @"").UTF8String); }
static NSString *ns_string(JSStringRef s) {
    if (!s) return nil;
    size_t n = JSStringGetMaximumUTF8CStringSize(s);
    char *b = malloc(n);
    JSStringGetUTF8CString(s, b, n);
    NSString *r = [NSString stringWithUTF8String:b];
    free(b);
    return r;
}

/* ---------------- JSVirtualMachine ---------------- */
@interface JSVirtualMachine ()
@property (nonatomic, readonly) JSContextGroupRef group;
@end
@implementation JSVirtualMachine {
    NSMapTable *_managed;                    /* owner (weak) -> objects it keeps (strong) */
}
- (instancetype)init {
    if ((self = [super init])) { _group = JSContextGroupCreate(); _managed = [NSMapTable weakToStrongObjectsMapTable]; }
    return self;
}
- (void)dealloc { if (_group) JSContextGroupRelease(_group); }
- (BOOL)addManagedReference:(id)object withOwner:(id)owner {
    if (!object || !owner) return NO;
    @synchronized (self) {
        NSMutableArray *a = [_managed objectForKey:owner];
        if (!a) { a = [NSMutableArray array]; [_managed setObject:a forKey:owner]; }
        [a addObject:object];
    }
    return YES;
}
- (BOOL)removeManagedReference:(id)object withOwner:(id)owner {
    if (!object || !owner) return NO;
    @synchronized (self) { [[_managed objectForKey:owner] removeObjectIdenticalTo:object]; }
    return YES;
}
@end

/* ---------------- calls in progress (currentContext, currentArguments...) ---------------- */
@interface JSValue ()
- (instancetype)initWithRef:(JSValueRef)ref context:(JSContext *)ctx;
@end
@interface ISIMJSFrame : NSObject
@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) JSValue *callee, *thisValue;
@property (nonatomic, strong) NSArray *arguments;
@end
@implementation ISIMJSFrame
@end
static NSMutableArray<ISIMJSFrame *> *frames(void) {
    NSMutableDictionary *t = NSThread.currentThread.threadDictionary;
    NSMutableArray *a = t[@"ISIMJSFrames"];
    if (!a) { a = [NSMutableArray array]; t[@"ISIMJSFrames"] = a; }
    return a;
}

/* ---------------- JSContext ---------------- */
static NSMapTable *contexts_by_ref;                     /* JSGlobalContextRef (pointer) -> JSContext (weak) */
static NSLock *contexts_lock;

@implementation JSContext {
    JSGlobalContextRef _ctx;
    NSMapTable *_wrappers;                              /* wrapped Objective-C objects (weak) -> their JSValue */
}
@synthesize exception = _exception, exceptionHandler = _exceptionHandler, virtualMachine = _virtualMachine;
+ (void)initialize {
    if (self != [JSContext class]) return;
    contexts_by_ref = [NSMapTable strongToWeakObjectsMapTable];   /* keys: the context pointer as an NSValue */
    contexts_lock = [NSLock new];
}
- (instancetype)init { return [self initWithVirtualMachine:[JSVirtualMachine new]]; }
- (instancetype)initWithVirtualMachine:(JSVirtualMachine *)vm {
    if ((self = [super init])) {
        _virtualMachine = vm;
        _ctx = JSGlobalContextCreateInGroup(vm.group, NULL);
        [self _isim_setUp];
    }
    return self;
}
- (instancetype)initWithISIMGlobalContextRef:(JSGlobalContextRef)ref {
    if ((self = [super init])) {
        _virtualMachine = [JSVirtualMachine new];
        _ctx = JSGlobalContextRetain(ref);
        [self _isim_setUp];
    }
    return self;
}
- (void)_isim_setUp {
    _wrappers = [NSMapTable weakToStrongObjectsMapTable];
    __weak JSContext *weak = self;
    _exceptionHandler = ^(JSContext *c, JSValue *e) { weak.exception = e; };
    [contexts_lock lock];
    [contexts_by_ref setObject:self forKey:[NSValue valueWithPointer:_ctx]];
    [contexts_lock unlock];
}
- (void)dealloc {
    [contexts_lock lock];
    [contexts_by_ref removeObjectForKey:[NSValue valueWithPointer:_ctx]];
    [contexts_lock unlock];
    JSGlobalContextRelease(_ctx);
}
+ (JSContext *)contextWithJSGlobalContextRef:(JSGlobalContextRef)ref {
    [contexts_lock lock];
    JSContext *c = [contexts_by_ref objectForKey:[NSValue valueWithPointer:ref]];
    [contexts_lock unlock];
    return c ?: [[JSContext alloc] initWithISIMGlobalContextRef:ref];
}
+ (JSContext *)_isim_contextFor:(JSContextRef)ctx { return [self contextWithJSGlobalContextRef:JSContextGetGlobalContext(ctx)]; }
- (JSGlobalContextRef)JSGlobalContextRef { return _ctx; }
- (NSMapTable *)_isim_wrappers { return _wrappers; }

- (JSValue *)evaluateScript:(NSString *)script { return [self evaluateScript:script withSourceURL:nil]; }
- (JSValue *)evaluateScript:(NSString *)script withSourceURL:(NSURL *)url {
    JSStringRef s = js_string(script), u = url ? js_string(url.absoluteString) : NULL;
    JSValueRef exc = NULL;
    JSValueRef r = JSEvaluateScript(_ctx, s, NULL, u, 1, &exc);
    JSStringRelease(s);
    if (u) JSStringRelease(u);
    if (exc) { [self _isim_notifyException:exc]; return [JSValue valueWithUndefinedInContext:self]; }
    return [[JSValue alloc] initWithRef:r context:self];
}
- (void)_isim_notifyException:(JSValueRef)exc {
    JSValue *e = [[JSValue alloc] initWithRef:exc context:self];
    void (^h)(JSContext *, JSValue *) = self.exceptionHandler;
    if (h) h(self, e); else self.exception = e;
}
- (JSValue *)globalObject { return [[JSValue alloc] initWithRef:JSContextGetGlobalObject(_ctx) context:self]; }
- (NSString *)name { JSStringRef n = JSGlobalContextCopyName(_ctx); NSString *s = ns_string(n); if (n) JSStringRelease(n); return s; }
- (void)setName:(NSString *)name { JSStringRef n = name ? js_string(name) : NULL; JSGlobalContextSetName(_ctx, n); if (n) JSStringRelease(n); }
- (BOOL)isInspectable { return JSGlobalContextIsInspectable(_ctx); }
- (void)setInspectable:(BOOL)i { JSGlobalContextSetInspectable(_ctx, i); }
+ (JSContext *)currentContext { return frames().lastObject.context; }
+ (JSValue *)currentCallee { return frames().lastObject.callee; }
+ (JSValue *)currentThis { return frames().lastObject.thisValue; }
+ (NSArray *)currentArguments { return frames().lastObject.arguments; }
- (JSValue *)objectForKeyedSubscript:(id)key { return [self.globalObject valueForProperty:key]; }
- (void)setObject:(id)object forKeyedSubscript:(NSObject<NSCopying> *)key { [self.globalObject setValue:object forProperty:key]; }
@end

/* ---------------- Objective-C <-> JavaScript conversion ---------------- */
static JSValueRef ref_of(id obj, JSContext *ctx);
static id object_of(JSValueRef v, JSContext *ctx, int depth);

static JSClassRef block_class, wrapper_class, method_class;
static Class block_base;

/* a block's Objective-C type signature (Block ABI: descriptor after copy/dispose helpers) */
struct block_layout { void *isa; int flags, reserved; void (*invoke)(void); struct { unsigned long reserved, size; void *rest[]; } *descriptor; };
static const char *block_signature(id block) {
    struct block_layout *b = (__bridge void *)block;
    if (!(b->flags & (1 << 30))) return NULL;                        /* BLOCK_HAS_SIGNATURE */
    int i = (b->flags & (1 << 25)) ? 2 : 0;                           /* BLOCK_HAS_COPY_DISPOSE */
    return b->descriptor->rest[i];
}
/* the class names of an extended type encoding's object types ("@\"JSValue\""), and the plain encoding */
static NSString *plain_types(const char *types, NSMutableArray<NSString *> *classes) {
    NSMutableString *out = [NSMutableString string];
    for (const char *p = types; *p; p++) {
        if (*p == '@' && p[1] == '"') {
            const char *e = strchr(p + 2, '"');
            if (!e) break;
            [classes addObject:[[NSString alloc] initWithBytes:p + 2 length:(NSUInteger)(e - p - 2) encoding:NSUTF8StringEncoding]];
            [out appendString:@"@"];
            p = e;
        } else {
            if (*p == '@' && p[1] != '?') [classes addObject:@""];
            [out appendFormat:@"%c", *p];
        }
    }
    return out;
}
static const char *skip_qualifiers(const char *t) { while (*t && strchr("rnNoORV", *t)) t++; return t; }

/* a JavaScript argument as the Objective-C value a parameter of this type expects */
static void store_arg(NSInvocation *inv, NSInteger idx, const char *type, NSString *cls, JSValueRef v, JSContext *ctx) {
    type = skip_qualifiers(type);
    JSContextRef c = ctx.JSGlobalContextRef;
    switch (*type) {
    case '@': {
        id o;
        if ([cls isEqualToString:@"JSValue"]) o = [[JSValue alloc] initWithRef:v context:ctx];
        else if ([cls isEqualToString:@"NSString"]) o = JSValueIsUndefined(c, v) || JSValueIsNull(c, v) ? nil : [[JSValue alloc] initWithRef:v context:ctx].toString;
        else if ([cls isEqualToString:@"NSNumber"]) o = [[JSValue alloc] initWithRef:v context:ctx].toNumber;
        else o = object_of(v, ctx, 0);
        [inv retainArguments];
        [inv setArgument:&o atIndex:idx];
        break;
    }
    case 'c': case 'B': { BOOL b = JSValueToBoolean(c, v); [inv setArgument:&b atIndex:idx]; break; }
    case 'i': case 's': case 'l': { int32_t i = JSValueToInt32(c, v, NULL); if (*type == 's') { short s = (short)i; [inv setArgument:&s atIndex:idx]; } else [inv setArgument:&i atIndex:idx]; break; }
    case 'I': case 'S': case 'L': { uint32_t u = JSValueToUInt32(c, v, NULL); [inv setArgument:&u atIndex:idx]; break; }
    case 'q': { long long q = (long long)JSValueToNumber(c, v, NULL); [inv setArgument:&q atIndex:idx]; break; }
    case 'Q': { unsigned long long q = (unsigned long long)JSValueToNumber(c, v, NULL); [inv setArgument:&q atIndex:idx]; break; }
    case 'f': { float f = (float)JSValueToNumber(c, v, NULL); [inv setArgument:&f atIndex:idx]; break; }
    case 'd': { double d = JSValueToNumber(c, v, NULL); [inv setArgument:&d atIndex:idx]; break; }
    default: break;                                                  /* other types are left zero */
    }
}
static JSValueRef return_value(NSInvocation *inv, JSContext *ctx) {
    const char *t = skip_qualifiers(inv.methodSignature.methodReturnType);
    JSContextRef c = ctx.JSGlobalContextRef;
    switch (*t) {
    case 'v': return JSValueMakeUndefined(c);
    case '@': { __unsafe_unretained id o = nil; [inv getReturnValue:&o]; return ref_of(o, ctx); }
    case 'c': case 'B': { BOOL b = NO; [inv getReturnValue:&b]; return JSValueMakeBoolean(c, b); }
    case 'i': { int i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, i); }
    case 's': { short i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, i); }
    case 'l': case 'q': { long long i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, (double)i); }
    case 'I': { unsigned i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, i); }
    case 'S': { unsigned short i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, i); }
    case 'L': case 'Q': { unsigned long long i = 0; [inv getReturnValue:&i]; return JSValueMakeNumber(c, (double)i); }
    case 'f': { float f = 0; [inv getReturnValue:&f]; return JSValueMakeNumber(c, f); }
    case 'd': { double d = 0; [inv getReturnValue:&d]; return JSValueMakeNumber(c, d); }
    default: return JSValueMakeUndefined(c);
    }
}
static JSValueRef with_frame(JSContextRef jctx, JSObjectRef callee, JSObjectRef thisObj, size_t argc, const JSValueRef argv[],
                             JSValueRef (^body)(JSContext *ctx)) {
    JSContext *ctx = [JSContext _isim_contextFor:jctx];
    ISIMJSFrame *f = [ISIMJSFrame new];
    f.context = ctx;
    f.callee = [[JSValue alloc] initWithRef:callee context:ctx];
    f.thisValue = thisObj ? [[JSValue alloc] initWithRef:thisObj context:ctx] : [JSValue valueWithUndefinedInContext:ctx];
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argc];
    for (size_t i = 0; i < argc; i++) [args addObject:[[JSValue alloc] initWithRef:argv[i] context:ctx]];
    f.arguments = args;
    [frames() addObject:f];
    JSValueRef r = body(ctx);
    [frames() removeLastObject];
    return r;
}

/* blocks as functions */
static JSValueRef block_call(JSContextRef jctx, JSObjectRef fn, JSObjectRef thisObj, size_t argc, const JSValueRef argv[], JSValueRef *exc) {
    id block = (__bridge id)JSObjectGetPrivate(fn);
    const char *sig = block ? block_signature(block) : NULL;
    if (!sig) return JSValueMakeUndefined(jctx);
    return with_frame(jctx, fn, thisObj, argc, argv, ^JSValueRef(JSContext *ctx) {
        NSMutableArray *classes = [NSMutableArray array];
        NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:plain_types(sig, classes).UTF8String];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
        id target = block;
        [inv setArgument:&target atIndex:0];
        NSUInteger objIndex = 0;
        if (*skip_qualifiers(ms.methodReturnType) == '@') objIndex = 1;   /* the return type's class name came first */
        for (NSUInteger i = 1; i < ms.numberOfArguments; i++) {
            const char *t = skip_qualifiers([ms getArgumentTypeAtIndex:i]);
            NSString *cls = @"";
            if (*t == '@') cls = objIndex < classes.count ? classes[objIndex++] : @"";
            JSValueRef v = i - 1 < argc ? argv[i - 1] : JSValueMakeUndefined(jctx);
            store_arg(inv, (NSInteger)i, t, cls, v, ctx);
        }
        struct block_layout *b = (__bridge void *)block;
        [inv invokeUsingIMP:(IMP)b->invoke];
        return return_value(inv, ctx);
    });
}
static void retained_finalize(JSObjectRef o) { void *p = JSObjectGetPrivate(o); if (p) CFBridgingRelease(p); }

/* wrapped Objective-C objects and their JSExport members */
@interface ISIMJSExportInfo : NSObject
@property (nonatomic) SEL selector;                    /* a method */
@property (nonatomic) SEL getter, setter;              /* a property */
@end
@implementation ISIMJSExportInfo
@end
static NSMutableDictionary<NSString *, NSDictionary<NSString *, ISIMJSExportInfo *> *> *export_cache;
static NSString *js_name_of(SEL sel) {
    NSArray<NSString *> *parts = [NSStringFromSelector(sel) componentsSeparatedByString:@":"];
    NSMutableString *n = [NSMutableString stringWithString:parts.firstObject];
    for (NSUInteger i = 1; i < parts.count; i++) {
        NSString *p = parts[i];
        if (p.length) [n appendFormat:@"%@%@", [p substringToIndex:1].uppercaseString, [p substringFromIndex:1]];
    }
    return n;
}
static void collect_protocol(Protocol *p, NSMutableDictionary<NSString *, ISIMJSExportInfo *> *out, NSMutableSet *seen) {
    if ([seen containsObject:NSStringFromProtocol(p)]) return;
    [seen addObject:NSStringFromProtocol(p)];
    unsigned n = 0;
    objc_property_t *props = protocol_copyPropertyList(p, &n);
    NSMutableSet<NSString *> *accessors = [NSMutableSet set];
    for (unsigned i = 0; i < n; i++) {
        NSString *name = @(property_getName(props[i]));
        ISIMJSExportInfo *info = [ISIMJSExportInfo new];
        char *g = property_copyAttributeValue(props[i], "G"), *s = property_copyAttributeValue(props[i], "S"), *ro = property_copyAttributeValue(props[i], "R");
        info.getter = g ? sel_registerName(g) : NSSelectorFromString(name);
        if (!ro) info.setter = s ? sel_registerName(s) : NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [name substringToIndex:1].uppercaseString, [name substringFromIndex:1]]);
        free(g); free(s); free(ro);
        out[name] = info;
        [accessors addObject:NSStringFromSelector(info.getter)];
        if (info.setter) [accessors addObject:NSStringFromSelector(info.setter)];
    }
    free(props);
    for (int required = 0; required < 2; required++) {
        unsigned m = 0;
        struct objc_method_description *ms = protocol_copyMethodDescriptionList(p, required, YES, &m);
        NSMutableDictionary<NSString *, NSString *> *renames = [NSMutableDictionary dictionary];   /* JSExportAs */
        for (unsigned i = 0; i < m; i++) {
            NSString *s = NSStringFromSelector(ms[i].name);
            NSRange r = [s rangeOfString:@"__JS_EXPORT_AS__"];
            if (r.location != NSNotFound) renames[[s substringToIndex:r.location]] = [[s substringFromIndex:NSMaxRange(r)] stringByReplacingOccurrencesOfString:@":" withString:@""];
        }
        for (unsigned i = 0; i < m; i++) {
            NSString *s = NSStringFromSelector(ms[i].name);
            if ([s containsString:@"__JS_EXPORT_AS__"] || [accessors containsObject:s]) continue;
            ISIMJSExportInfo *info = [ISIMJSExportInfo new];
            info.selector = ms[i].name;
            out[renames[s] ?: js_name_of(ms[i].name)] = info;
        }
        free(ms);
    }
    unsigned k = 0;
    Protocol * __unsafe_unretained *inherited = protocol_copyProtocolList(p, &k);
    for (unsigned i = 0; i < k; i++) if (inherited[i] != @protocol(JSExport)) collect_protocol(inherited[i], out, seen);
    free(inherited);
}
static NSDictionary<NSString *, ISIMJSExportInfo *> *exports_of(Class cls) {
    NSString *key = NSStringFromClass(cls);
    @synchronized (export_cache) {
        NSDictionary *d = export_cache[key];
        if (d) return d;
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        NSMutableSet *seen = [NSMutableSet set];
        for (Class c = cls; c; c = class_getSuperclass(c)) {
            unsigned n = 0;
            Protocol * __unsafe_unretained *ps = class_copyProtocolList(c, &n);
            for (unsigned i = 0; i < n; i++) if (protocol_conformsToProtocol(ps[i], @protocol(JSExport))) collect_protocol(ps[i], out, seen);
            free(ps);
        }
        export_cache[key] = out;
        return out;
    }
}
static JSValueRef invoke_selector(id target, SEL sel, size_t argc, const JSValueRef argv[], JSContext *ctx) {
    NSMethodSignature *ms = [target methodSignatureForSelector:sel];
    if (!ms) return JSValueMakeUndefined(ctx.JSGlobalContextRef);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
    inv.target = target;
    inv.selector = sel;
    for (NSUInteger i = 2; i < ms.numberOfArguments; i++) {
        JSValueRef v = i - 2 < argc ? argv[i - 2] : JSValueMakeUndefined(ctx.JSGlobalContextRef);
        store_arg(inv, (NSInteger)i, [ms getArgumentTypeAtIndex:i], @"", v, ctx);
    }
    [inv invoke];
    return return_value(inv, ctx);
}
static JSValueRef method_call(JSContextRef jctx, JSObjectRef fn, JSObjectRef thisObj, size_t argc, const JSValueRef argv[], JSValueRef *exc) {
    SEL sel = (SEL)JSObjectGetPrivate(fn);
    id target = thisObj && JSValueIsObjectOfClass(jctx, thisObj, wrapper_class) ? (__bridge id)JSObjectGetPrivate(thisObj) : nil;
    if (!target || !sel) return JSValueMakeUndefined(jctx);
    return with_frame(jctx, fn, thisObj, argc, argv, ^JSValueRef(JSContext *ctx) { return invoke_selector(target, sel, argc, argv, ctx); });
}
static JSValueRef wrapper_get(JSContextRef jctx, JSObjectRef obj, JSStringRef name, JSValueRef *exc) {
    id target = (__bridge id)JSObjectGetPrivate(obj);
    ISIMJSExportInfo *info = target ? exports_of([target class])[ns_string(name)] : nil;
    if (!info) return NULL;                                          /* not exported: ordinary property lookup */
    JSContext *ctx = [JSContext _isim_contextFor:jctx];
    if (info.getter) return invoke_selector(target, info.getter, 0, NULL, ctx);
    return JSObjectMake(jctx, method_class, (void *)info.selector);
}
static bool wrapper_set(JSContextRef jctx, JSObjectRef obj, JSStringRef name, JSValueRef value, JSValueRef *exc) {
    id target = (__bridge id)JSObjectGetPrivate(obj);
    ISIMJSExportInfo *info = target ? exports_of([target class])[ns_string(name)] : nil;
    if (!info.setter) return false;
    invoke_selector(target, info.setter, 1, &value, [JSContext _isim_contextFor:jctx]);
    return true;
}
static void wrapper_names(JSContextRef jctx, JSObjectRef obj, JSPropertyNameAccumulatorRef acc) {
    id target = (__bridge id)JSObjectGetPrivate(obj);
    for (NSString *n in exports_of([target class])) { JSStringRef s = js_string(n); JSPropertyNameAccumulatorAddName(acc, s); JSStringRelease(s); }
}

__attribute__((constructor)) static void make_classes(void) {
    JSClassDefinition d = kJSClassDefinitionEmpty;
    d.className = "ObjCBlockFunction"; d.callAsFunction = block_call; d.finalize = retained_finalize;
    block_class = JSClassCreate(&d);
    d = kJSClassDefinitionEmpty;
    d.className = "ObjCObject"; d.getProperty = wrapper_get; d.setProperty = wrapper_set; d.getPropertyNames = wrapper_names;
    d.finalize = retained_finalize;
    wrapper_class = JSClassCreate(&d);
    d = kJSClassDefinitionEmpty;
    d.className = "ObjCMethod"; d.callAsFunction = method_call;
    method_class = JSClassCreate(&d);
    export_cache = [NSMutableDictionary dictionary];
    block_base = objc_getClass("__NSBlockBase") ?: objc_getClass("NSBlock");
}

static JSValueRef ref_of(id obj, JSContext *ctx) {
    JSContextRef c = ctx.JSGlobalContextRef;
    if (!obj) return JSValueMakeUndefined(c);
    if ([obj isKindOfClass:[JSValue class]]) return ((JSValue *)obj).JSValueRef;
    if ([obj isKindOfClass:[NSNull class]]) return JSValueMakeNull(c);
    if ([obj isKindOfClass:[NSString class]]) { JSStringRef s = js_string(obj); JSValueRef v = JSValueMakeString(c, s); JSStringRelease(s); return v; }
    if ([obj isKindOfClass:[NSNumber class]]) {
        const char *t = [obj objCType];
        if (!strcmp(t, "c") || !strcmp(t, "B")) return JSValueMakeBoolean(c, [obj boolValue]);
        return JSValueMakeNumber(c, [obj doubleValue]);
    }
    if ([obj isKindOfClass:[NSDate class]]) {
        JSValueRef ms = JSValueMakeNumber(c, [obj timeIntervalSince1970] * 1000);
        return JSObjectMakeDate(c, 1, &ms, NULL);
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *a = obj;
        JSValueRef *vs = calloc(a.count ?: 1, sizeof *vs);
        for (NSUInteger i = 0; i < a.count; i++) { vs[i] = ref_of(a[i], ctx); JSValueProtect(c, vs[i]); }
        JSObjectRef arr = JSObjectMakeArray(c, a.count, vs, NULL);
        for (NSUInteger i = 0; i < a.count; i++) JSValueUnprotect(c, vs[i]);
        free(vs);
        return arr;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        JSObjectRef o = JSObjectMake(c, NULL, NULL);
        JSValueProtect(c, o);
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
            JSStringRef s = js_string([k description]);
            JSObjectSetProperty(c, o, s, ref_of(v, ctx), kJSPropertyAttributeNone, NULL);
            JSStringRelease(s);
        }];
        JSValueUnprotect(c, o);
        return o;
    }
    if (block_base && [obj isKindOfClass:block_base]) return JSObjectMake(c, block_class, (void *)CFBridgingRetain([obj copy]));
    JSValue *existing = [[ctx _isim_wrappers] objectForKey:obj];
    if (existing) return existing.JSValueRef;
    JSObjectRef w = JSObjectMake(c, wrapper_class, (void *)CFBridgingRetain(obj));
    [[ctx _isim_wrappers] setObject:[[JSValue alloc] initWithRef:w context:ctx] forKey:obj];
    return w;
}

static id object_of(JSValueRef v, JSContext *ctx, int depth) {
    JSContextRef c = ctx.JSGlobalContextRef;
    switch (JSValueGetType(c, v)) {
    case kJSTypeUndefined: return nil;
    case kJSTypeNull: return [NSNull null];
    case kJSTypeBoolean: return @(JSValueToBoolean(c, v));
    case kJSTypeNumber: return @(JSValueToNumber(c, v, NULL));
    case kJSTypeString: case kJSTypeSymbol: case kJSTypeBigInt: {
        JSStringRef s = JSValueToStringCopy(c, v, NULL);
        NSString *r = ns_string(s);
        if (s) JSStringRelease(s);
        return r;
    }
    case kJSTypeObject: break;
    }
    JSObjectRef o = JSValueToObject(c, v, NULL);
    if (JSValueIsObjectOfClass(c, o, wrapper_class) || JSValueIsObjectOfClass(c, o, block_class)) return (__bridge id)JSObjectGetPrivate(o);
    if (JSValueIsDate(c, v)) {
        JSStringRef n = JSStringCreateWithUTF8CString("getTime");
        JSValueRef fn = JSObjectGetProperty(c, o, n, NULL);
        JSStringRelease(n);
        JSValueRef ms = JSValueIsObject(c, fn) ? JSObjectCallAsFunction(c, (JSObjectRef)fn, o, 0, NULL, NULL) : NULL;
        return ms ? [NSDate dateWithTimeIntervalSince1970:JSValueToNumber(c, ms, NULL) / 1000] : nil;
    }
    if (depth > 32) return @{};
    if (JSValueIsArray(c, v)) {
        JSStringRef n = JSStringCreateWithUTF8CString("length");
        unsigned len = (unsigned)JSValueToNumber(c, JSObjectGetProperty(c, o, n, NULL), NULL);
        JSStringRelease(n);
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:len];
        for (unsigned i = 0; i < len; i++) [a addObject:object_of(JSObjectGetPropertyAtIndex(c, o, i, NULL), ctx, depth + 1) ?: [NSNull null]];
        return a;
    }
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    JSPropertyNameArrayRef names = JSObjectCopyPropertyNames(c, o);
    size_t count = JSPropertyNameArrayGetCount(names);
    for (size_t i = 0; i < count; i++) {
        JSStringRef n = JSPropertyNameArrayGetNameAtIndex(names, i);
        id val = object_of(JSObjectGetProperty(c, o, n, NULL), ctx, depth + 1);
        if (val) d[ns_string(n)] = val;
    }
    JSPropertyNameArrayRelease(names);
    return d;
}

/* ---------------- JSValue ---------------- */
@implementation JSValue {
    JSValueRef _ref;
    JSContext *_context;
}
- (instancetype)initWithRef:(JSValueRef)ref context:(JSContext *)ctx {
    if ((self = [super init])) {
        _context = ctx;
        _ref = ref ? ref : JSValueMakeUndefined(ctx.JSGlobalContextRef);
        JSValueProtect(ctx.JSGlobalContextRef, _ref);
    }
    return self;
}
- (void)dealloc { JSValueUnprotect(_context.JSGlobalContextRef, _ref); }
- (JSContext *)context { return _context; }
- (JSValueRef)JSValueRef { return _ref; }
- (JSContextRef)c { return _context.JSGlobalContextRef; }
+ (JSValue *)valueWithJSValueRef:(JSValueRef)v inContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:v context:ctx]; }
+ (JSValue *)valueWithObject:(id)value inContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:ref_of(value, ctx) context:ctx]; }
+ (JSValue *)valueWithBool:(BOOL)b inContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSValueMakeBoolean(ctx.JSGlobalContextRef, b) context:ctx]; }
+ (JSValue *)valueWithDouble:(double)d inContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSValueMakeNumber(ctx.JSGlobalContextRef, d) context:ctx]; }
+ (JSValue *)valueWithInt32:(int32_t)i inContext:(JSContext *)ctx { return [self valueWithDouble:i inContext:ctx]; }
+ (JSValue *)valueWithUInt32:(uint32_t)i inContext:(JSContext *)ctx { return [self valueWithDouble:i inContext:ctx]; }
+ (JSValue *)valueWithNewObjectInContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSObjectMake(ctx.JSGlobalContextRef, NULL, NULL) context:ctx]; }
+ (JSValue *)valueWithNewArrayInContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSObjectMakeArray(ctx.JSGlobalContextRef, 0, NULL, NULL) context:ctx]; }
+ (JSValue *)valueWithNewRegularExpressionFromPattern:(NSString *)pattern flags:(NSString *)flags inContext:(JSContext *)ctx {
    JSValueRef args[2] = { ref_of(pattern, ctx), ref_of(flags, ctx) };
    return [[JSValue alloc] initWithRef:JSObjectMakeRegExp(ctx.JSGlobalContextRef, 2, args, NULL) context:ctx];
}
+ (JSValue *)valueWithNewErrorFromMessage:(NSString *)message inContext:(JSContext *)ctx {
    JSValueRef arg = ref_of(message, ctx);
    return [[JSValue alloc] initWithRef:JSObjectMakeError(ctx.JSGlobalContextRef, 1, &arg, NULL) context:ctx];
}
+ (JSValue *)valueWithNewSymbolFromDescription:(NSString *)description inContext:(JSContext *)ctx {
    JSStringRef s = js_string(description);
    JSValue *v = [[JSValue alloc] initWithRef:JSValueMakeSymbol(ctx.JSGlobalContextRef, s) context:ctx];
    JSStringRelease(s);
    return v;
}
+ (JSValue *)valueWithNewPromiseInContext:(JSContext *)ctx fromExecutor:(void (^)(JSValue *, JSValue *))callback {
    JSObjectRef resolve = NULL, reject = NULL;
    JSObjectRef p = JSObjectMakeDeferredPromise(ctx.JSGlobalContextRef, &resolve, &reject, NULL);
    JSValue *v = [[JSValue alloc] initWithRef:p context:ctx];
    if (callback) callback([[JSValue alloc] initWithRef:resolve context:ctx], [[JSValue alloc] initWithRef:reject context:ctx]);
    return v;
}
+ (JSValue *)valueWithNewPromiseResolvedWithResult:(id)result inContext:(JSContext *)ctx {
    return [self valueWithNewPromiseInContext:ctx fromExecutor:^(JSValue *resolve, JSValue *reject) { [resolve callWithArguments:@[result ?: [NSNull null]]]; }];
}
+ (JSValue *)valueWithNewPromiseRejectedWithReason:(id)reason inContext:(JSContext *)ctx {
    return [self valueWithNewPromiseInContext:ctx fromExecutor:^(JSValue *resolve, JSValue *reject) { [reject callWithArguments:@[reason ?: [NSNull null]]]; }];
}
+ (JSValue *)valueWithNullInContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSValueMakeNull(ctx.JSGlobalContextRef) context:ctx]; }
+ (JSValue *)valueWithUndefinedInContext:(JSContext *)ctx { return [[JSValue alloc] initWithRef:JSValueMakeUndefined(ctx.JSGlobalContextRef) context:ctx]; }

- (id)toObject { return object_of(_ref, _context, 0); }
- (id)toObjectOfClass:(Class)cls { id o = [self toObject]; return [o isKindOfClass:cls] ? o : nil; }
- (BOOL)toBool { return JSValueToBoolean(self.c, _ref); }
- (double)toDouble {
    JSValueRef exc = NULL;
    double d = JSValueToNumber(self.c, _ref, &exc);
    if (exc) { [_context _isim_notifyException:exc]; return NAN; }
    return d;
}
- (int32_t)toInt32 { return JSValueToInt32(self.c, _ref, NULL); }
- (uint32_t)toUInt32 { return JSValueToUInt32(self.c, _ref, NULL); }
- (NSNumber *)toNumber { return self.isBoolean ? @(self.toBool) : @(self.toDouble); }
- (NSString *)toString {
    JSValueRef exc = NULL;
    JSStringRef s = JSValueToStringCopy(self.c, _ref, &exc);
    if (exc) { [_context _isim_notifyException:exc]; return nil; }
    NSString *r = ns_string(s);
    JSStringRelease(s);
    return r;
}
- (NSDate *)toDate {
    if (self.isDate) return object_of(_ref, _context, 0);
    double d = self.toDouble;
    return isnan(d) ? nil : [NSDate dateWithTimeIntervalSince1970:d / 1000];
}
- (NSArray *)toArray { id o = [self toObject]; return [o isKindOfClass:[NSArray class]] ? o : (self.isObject ? @[] : nil); }
- (NSDictionary *)toDictionary { id o = [self toObject]; return [o isKindOfClass:[NSDictionary class]] ? o : nil; }
- (CGPoint)toPoint { return CGPointMake([self[@"x"] toDouble], [self[@"y"] toDouble]); }
- (CGSize)toSize { return CGSizeMake([self[@"width"] toDouble], [self[@"height"] toDouble]); }
- (CGRect)toRect { return CGRectMake([self[@"x"] toDouble], [self[@"y"] toDouble], [self[@"width"] toDouble], [self[@"height"] toDouble]); }
- (BOOL)isUndefined { return JSValueIsUndefined(self.c, _ref); }
- (BOOL)isNull { return JSValueIsNull(self.c, _ref); }
- (BOOL)isBoolean { return JSValueIsBoolean(self.c, _ref); }
- (BOOL)isNumber { return JSValueIsNumber(self.c, _ref); }
- (BOOL)isString { return JSValueIsString(self.c, _ref); }
- (BOOL)isObject { return JSValueIsObject(self.c, _ref); }
- (BOOL)isArray { return JSValueIsArray(self.c, _ref); }
- (BOOL)isDate { return JSValueIsDate(self.c, _ref); }
- (BOOL)isSymbol { return JSValueIsSymbol(self.c, _ref); }
- (BOOL)isEqualToObject:(id)value { return JSValueIsStrictEqual(self.c, _ref, ref_of(value, _context)); }
- (BOOL)isEqualWithTypeCoercionToObject:(id)value { return JSValueIsEqual(self.c, _ref, ref_of(value, _context), NULL); }
- (BOOL)isInstanceOf:(id)value {
    JSValueRef c = ref_of(value, _context);
    return JSValueIsObject(self.c, c) && JSValueIsInstanceOfConstructor(self.c, _ref, (JSObjectRef)c, NULL);
}
- (JSValueRef *)_isim_args:(NSArray *)args {
    JSValueRef *a = calloc(args.count ?: 1, sizeof *a);
    for (NSUInteger i = 0; i < args.count; i++) { a[i] = ref_of(args[i], _context); JSValueProtect(self.c, a[i]); }
    return a;
}
- (void)_isim_free:(JSValueRef *)a count:(NSUInteger)n { for (NSUInteger i = 0; i < n; i++) JSValueUnprotect(self.c, a[i]); free(a); }
- (JSValue *)_isim_result:(JSValueRef)r exception:(JSValueRef)exc {
    if (exc) { [_context _isim_notifyException:exc]; return [JSValue valueWithUndefinedInContext:_context]; }
    return [[JSValue alloc] initWithRef:r context:_context];
}
- (JSValue *)callWithArguments:(NSArray *)arguments {
    if (!self.isObject || !JSObjectIsFunction(self.c, (JSObjectRef)_ref)) return [JSValue valueWithUndefinedInContext:_context];
    JSValueRef *a = [self _isim_args:arguments], exc = NULL;
    JSValueRef r = JSObjectCallAsFunction(self.c, (JSObjectRef)_ref, NULL, arguments.count, a, &exc);
    [self _isim_free:a count:arguments.count];
    return [self _isim_result:r exception:exc];
}
- (JSValue *)constructWithArguments:(NSArray *)arguments {
    if (!self.isObject || !JSObjectIsConstructor(self.c, (JSObjectRef)_ref)) return [JSValue valueWithUndefinedInContext:_context];
    JSValueRef *a = [self _isim_args:arguments], exc = NULL;
    JSValueRef r = JSObjectCallAsConstructor(self.c, (JSObjectRef)_ref, arguments.count, a, &exc);
    [self _isim_free:a count:arguments.count];
    return [self _isim_result:r exception:exc];
}
- (JSValue *)invokeMethod:(NSString *)method withArguments:(NSArray *)arguments {
    JSValue *fn = [self valueForProperty:method];
    if (!fn.isObject || !JSObjectIsFunction(self.c, (JSObjectRef)fn.JSValueRef)) return [JSValue valueWithUndefinedInContext:_context];
    JSValueRef *a = [self _isim_args:arguments], exc = NULL;
    JSObjectRef thisObj = JSValueToObject(self.c, _ref, NULL);
    JSValueRef r = JSObjectCallAsFunction(self.c, (JSObjectRef)fn.JSValueRef, thisObj, arguments.count, a, &exc);
    [self _isim_free:a count:arguments.count];
    return [self _isim_result:r exception:exc];
}
- (JSObjectRef)_isim_object { return self.isObject ? (JSObjectRef)_ref : JSValueToObject(self.c, _ref, NULL); }
- (JSValue *)valueForProperty:(id)property {
    JSObjectRef o = [self _isim_object];
    if (!o) return [JSValue valueWithUndefinedInContext:_context];
    JSValueRef exc = NULL;
    JSValueRef r = JSObjectGetPropertyForKey(self.c, o, ref_of(property, _context), &exc);
    return [self _isim_result:r exception:exc];
}
- (void)setValue:(id)value forProperty:(id)property {
    JSObjectRef o = [self _isim_object];
    if (!o) return;
    JSValueRef exc = NULL;
    JSObjectSetPropertyForKey(self.c, o, ref_of(property, _context), ref_of(value, _context), kJSPropertyAttributeNone, &exc);
    if (exc) [_context _isim_notifyException:exc];
}
- (BOOL)deleteProperty:(id)property {
    JSObjectRef o = [self _isim_object];
    return o && JSObjectDeletePropertyForKey(self.c, o, ref_of(property, _context), NULL);
}
- (BOOL)hasProperty:(id)property {
    JSObjectRef o = [self _isim_object];
    return o && JSObjectHasPropertyForKey(self.c, o, ref_of(property, _context), NULL);
}
- (void)defineProperty:(id)property descriptor:(id)descriptor {
    JSValue *define = [_context evaluateScript:@"Object.defineProperty"];
    JSObjectRef o = [self _isim_object];
    if (!o) return;
    JSValueRef args[3] = { o, ref_of(property, _context), ref_of(descriptor, _context) }, exc = NULL;
    JSObjectCallAsFunction(self.c, (JSObjectRef)define.JSValueRef, NULL, 3, args, &exc);
    if (exc) [_context _isim_notifyException:exc];
}
- (JSValue *)valueAtIndex:(NSUInteger)index {
    JSObjectRef o = [self _isim_object];
    if (!o || index > UINT32_MAX) return [JSValue valueWithUndefinedInContext:_context];
    return [[JSValue alloc] initWithRef:JSObjectGetPropertyAtIndex(self.c, o, (unsigned)index, NULL) context:_context];
}
- (void)setValue:(id)value atIndex:(NSUInteger)index {
    JSObjectRef o = [self _isim_object];
    if (o && index <= UINT32_MAX) JSObjectSetPropertyAtIndex(self.c, o, (unsigned)index, ref_of(value, _context), NULL);
}
- (JSValue *)objectForKeyedSubscript:(id)key { return [self valueForProperty:key]; }
- (JSValue *)objectAtIndexedSubscript:(NSUInteger)index { return [self valueAtIndex:index]; }
- (void)setObject:(id)object forKeyedSubscript:(id)key { [self setValue:object forProperty:key]; }
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index { [self setValue:object atIndex:index]; }
- (NSString *)description { return self.toString ?: @"undefined"; }
@end

/* ---------------- JSManagedValue ---------------- */
@implementation JSManagedValue { JSValue *_value; }
+ (JSManagedValue *)managedValueWithValue:(JSValue *)value { return [[self alloc] initWithValue:value]; }
+ (JSManagedValue *)managedValueWithValue:(JSValue *)value andOwner:(id)owner {
    JSManagedValue *m = [[self alloc] initWithValue:value];
    [value.context.virtualMachine addManagedReference:m withOwner:owner];
    return m;
}
- (instancetype)initWithValue:(JSValue *)value { if ((self = [super init])) _value = value; return self; }
- (JSValue *)value { return _value; }
@end
