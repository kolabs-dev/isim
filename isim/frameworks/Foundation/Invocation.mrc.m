/* isim Foundation (MRC): NSMethodSignature, NSInvocation, NSProxy and the message forwarding handler.
 *
 * Arguments are placed per the x86_64 System V calling convention (Darwin flavour): each Objective-C
 * type encoding is classified into INTEGER / SSE eightbytes or MEMORY; MEMORY arguments and those that
 * do not fit the remaining registers go on the stack; MEMORY results use the hidden result pointer
 * (objc_msgSend_stret). -invoke calls objc_msgSend through isim_objc_call_frame (libobjc) and the
 * forwarding handler unpacks the registers that _objc_msgForward captured into an NSInvocation. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>

/* ================= type encodings ================= */
enum { CLS_NONE = 0, CLS_INT = 1, CLS_SSE = 2 };
typedef struct {
    char *type;              /* this argument's encoding (with qualifiers, without offsets) */
    char code;               /* first character after the qualifiers */
    NSUInteger size, align, offset;
    BOOL memory;             /* passed in memory (on the stack) / returned through the hidden pointer */
    int nwords;              /* eightbytes when passed in registers */
    int cls[2];
} isim_arginfo;

static const char *skip_quals(const char *t) { while (*t && strchr("rnNoORVA", *t)) t++; return t; }
static const char *skip_type(const char *t);
static const char *skip_aggregate(const char *t, char open, char close) {
    int depth = 0;
    for (; *t; t++) {
        if (*t == '"') { t = strchr(t + 1, '"'); if (!t) return ""; continue; }
        if (*t == open) depth++;
        else if (*t == close && --depth == 0) return t + 1;
    }
    return t;
}
static const char *skip_type(const char *t) {
    t = skip_quals(t);
    switch (*t) {
    case 0: return t;
    case '@':
        t++;
        if (*t == '"') { const char *q = strchr(t + 1, '"'); return q ? q + 1 : t + strlen(t); }
        if (*t == '?') { t++; if (*t == '<') { const char *q = skip_aggregate(t, '<', '>'); return q; } }
        return t;
    case '^': return skip_type(t + 1);
    case 'j': return skip_type(t + 1);
    case 'b': t++; while (*t >= '0' && *t <= '9') t++; return t;
    case '[': return skip_aggregate(t, '[', ']');
    case '{': return skip_aggregate(t, '{', '}');
    case '(': return skip_aggregate(t, '(', ')');
    default: return t + 1;
    }
}
static NSUInteger align_up(NSUInteger v, NSUInteger a) { return a > 1 ? (v + a - 1) / a * a : v; }

/* size/alignment, and (when cls != NULL) the SysV classification of each eightbyte at offset base */
static void layout(const char *t, NSUInteger *size, NSUInteger *align, NSUInteger base, int cls[2], BOOL *memory) {
    t = skip_quals(t);
    NSUInteger s = 0, a = 1; int kind = CLS_NONE;
    switch (*t) {
    case 'c': case 'C': case 'B': s = a = 1; kind = CLS_INT; break;
    case 's': case 'S': s = a = 2; kind = CLS_INT; break;
    case 'i': case 'I': case 'l': case 'L': s = a = 4; kind = CLS_INT; break;
    case 'q': case 'Q': case '@': case '#': case ':': case '*': case '^': case '?': s = a = 8; kind = CLS_INT; break;
    case 'f': s = a = 4; kind = CLS_SSE; break;
    case 'd': s = a = 8; kind = CLS_SSE; break;
    case 'D': s = a = 16; if (memory) *memory = YES; break;
    case 't': case 'T': s = a = 16; kind = CLS_INT; break;
    case 'v': s = 0; a = 1; break;
    case 'b': { long bits = strtol(t + 1, NULL, 10); s = (NSUInteger)(bits + 7) / 8; a = 1; kind = CLS_INT; break; }
    case 'j': { NSUInteger es, ea; layout(t + 1, &es, &ea, base, cls, memory); layout(t + 1, &es, &ea, base + es, cls, memory); s = es * 2; a = ea; break; }
    case '[': {
        const char *p = t + 1; long n = strtol(p, (char **)&p, 10);
        NSUInteger es = 0, ea = 1; layout(p, &es, &ea, base, NULL, NULL);
        for (long i = 0; i < n && cls; i++) layout(p, &es, &ea, base + i * es, cls, memory);
        s = es * n; a = ea; break;
    }
    case '{': case '(': {
        char close = *t == '{' ? '}' : ')';
        const char *p = t + 1;
        while (*p && *p != '=' && *p != close) p++;              /* tag name */
        if (*p != '=') { s = 0; a = 1; break; }                   /* opaque */
        p++;
        NSUInteger off = 0;
        while (*p && *p != close) {
            if (*p == '"') { p = strchr(p + 1, '"'); if (!p) break; p++; continue; }   /* field name */
            NSUInteger fs = 0, fa = 1; layout(p, &fs, &fa, 0, NULL, NULL);
            if (close == '}') off = align_up(off, fa);
            if (cls) layout(p, &fs, &fa, base + (close == '}' ? off : 0), cls, memory);
            if (close == '}') off += fs; else if (fs > off) off = fs;
            if (fa > a) a = fa;
            p = skip_type(p);
        }
        s = align_up(off, a);
        break;
    }
    default: s = a = 8; kind = CLS_INT; break;
    }
    if (size) *size = s;
    if (align) *align = a;
    if (cls && kind != CLS_NONE && s) {
        for (NSUInteger w = base / 8; w <= (base + s - 1) / 8 && w < 2; w++)
            if (cls[w] != CLS_INT) cls[w] = kind;
        if (base + s > 16 && memory) *memory = YES;
    }
}
static void classify(isim_arginfo *ai) {
    NSUInteger size = 0, align = 1;
    int cls[2] = {0, 0}; BOOL mem = NO;
    layout(ai->type, &size, &align, 0, cls, &mem);
    ai->code = *skip_quals(ai->type);
    ai->size = size; ai->align = align;
    if (size > 16) mem = YES;
    ai->memory = mem;
    ai->nwords = (int)((size + 7) / 8);
    for (int w = 0; w < 2; w++) ai->cls[w] = cls[w] == CLS_NONE ? CLS_SSE : cls[w];
}

const char *NSGetSizeAndAlignment(const char *t, NSUInteger *sizep, NSUInteger *alignp) {
    NSUInteger s = 0, a = 1;
    layout(t, &s, &a, 0, NULL, NULL);
    if (sizep) *sizep = s;
    if (alignp) *alignp = a;
    return skip_type(t);
}

/* ================= NSMethodSignature ================= */
@implementation NSMethodSignature {
@public
    char *_types;
    NSUInteger _count;               /* arguments */
    isim_arginfo _ret;
    isim_arginfo *_args;
    NSUInteger _frameLength;
}
+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)types {
    if (!types || !*types) [NSException raise:NSInvalidArgumentException format:@"+[NSMethodSignature signatureWithObjCTypes:]: type signature is empty"];
    NSMethodSignature *sig = [[[self alloc] init] autorelease];
    sig->_types = strdup(types);
    isim_arginfo infos[64]; NSUInteger n = 0;
    const char *p = types;
    while (*p && n < 64) {
        const char *end = skip_type(p);
        if (end == p) break;
        infos[n].type = strndup(p, end - p);
        classify(&infos[n]);
        n++;
        p = end;
        while (*p == '-' || *p == '+' || (*p >= '0' && *p <= '9')) p++;   /* frame offsets */
    }
    if (n == 0) return nil;
    sig->_ret = infos[0];
    sig->_count = n - 1;
    sig->_args = calloc(n, sizeof *sig->_args);
    NSUInteger off = 0;
    for (NSUInteger i = 0; i + 1 < n; i++) {
        sig->_args[i] = infos[i + 1];
        NSUInteger a = sig->_args[i].align < 8 ? 8 : sig->_args[i].align;
        off = align_up(off, a);
        sig->_args[i].offset = off;
        off += align_up(sig->_args[i].size, 8);
    }
    sig->_frameLength = off;
    return sig;
}
- (void)dealloc {
    free(_types); free(_ret.type);
    for (NSUInteger i = 0; i < _count; i++) free(_args[i].type);
    free(_args);
    [super dealloc];
}
- (NSUInteger)numberOfArguments { return _count; }
- (const char *)getArgumentTypeAtIndex:(NSUInteger)idx {
    if (idx >= _count) [NSException raise:NSInvalidArgumentException format:@"-[NSMethodSignature getArgumentTypeAtIndex:]: index (%lu) out of bounds [0, %ld]", (unsigned long)idx, (long)_count - 1];
    return _args[idx].type;
}
- (NSUInteger)frameLength { return _frameLength; }
- (BOOL)isOneway { for (const char *p = _ret.type; p < skip_quals(_ret.type); p++) if (*p == 'V') return YES; return NO; }
- (const char *)methodReturnType { return _ret.type; }
- (NSUInteger)methodReturnLength { return _ret.size; }
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSMethodSignature class]] || ((NSMethodSignature *)o)->_count != _count) return NO;
    if (strcmp(((NSMethodSignature *)o)->_ret.type, _ret.type)) return NO;
    for (NSUInteger i = 0; i < _count; i++) if (strcmp(((NSMethodSignature *)o)->_args[i].type, _args[i].type)) return NO;
    return YES;
}
- (NSUInteger)hash { NSUInteger h = _count; for (const char *p = _ret.type; *p; p++) h = h * 31 + (unsigned char)*p; return h; }
- (NSString *)debugDescription {
    NSMutableString *s = [NSMutableString stringWithFormat:@"<NSMethodSignature: %p>\n    number of arguments = %lu\n    frame size = %lu\n    return value: type encoding (%c) '%s', size %lu",
                          self, (unsigned long)_count, (unsigned long)_frameLength, _ret.code, _ret.type, (unsigned long)_ret.size];
    for (NSUInteger i = 0; i < _count; i++)
        [s appendFormat:@"\n    argument %lu: type encoding (%c) '%s', size %lu, offset %lu%@", (unsigned long)i, _args[i].code, _args[i].type,
                        (unsigned long)_args[i].size, (unsigned long)_args[i].offset, _args[i].memory ? @" (memory)" : @""];
    return s;
}
@end

/* small integer scalars are widened (Darwin: callers sign/zero-extend to 32 bits; we extend to 64) */
static uint64_t scalar_word(const isim_arginfo *ai, const uint8_t *src, NSUInteger n) {
    uint64_t w = 0; memcpy(&w, src, n);
    if (ai->nwords != 1 || (ai->code != 'c' && ai->code != 's' && ai->code != 'i' && ai->code != 'l' &&
                            ai->code != 'C' && ai->code != 'S' && ai->code != 'B' && ai->code != 'I' && ai->code != 'L')) return w;
    switch (ai->code) {
    case 'c': return (uint64_t)(int64_t)(int8_t)w;
    case 's': return (uint64_t)(int64_t)(int16_t)w;
    case 'i': case 'l': return (uint64_t)(int64_t)(int32_t)w;
    case 'C': case 'B': return (uint8_t)w;
    case 'S': return (uint16_t)w;
    default: return (uint32_t)w;
    }
}
/* register / stack placement cursor */
typedef struct { int ng, nx; NSUInteger ns; } place_t;
static BOOL in_registers(const isim_arginfo *ai, place_t *pc) {
    if (ai->memory || !ai->size) return NO;
    int g = 0, x = 0;
    for (int w = 0; w < ai->nwords; w++) { if (ai->cls[w] == CLS_SSE) x++; else g++; }
    return pc->ng + g <= 6 && pc->nx + x <= 8;
}
static NSUInteger stack_slot(const isim_arginfo *ai, place_t *pc) {
    if (ai->align > 8) pc->ns = align_up(pc->ns, 2);
    NSUInteger at = pc->ns;
    pc->ns += (ai->size + 7) / 8;
    return at;
}

/* ================= NSInvocation ================= */
@interface NSInvocation (IsimPrivate)
+ (instancetype)_isim_newWithSignature:(NSMethodSignature *)sig;
- (void)_isim_invokeIMP:(nullable IMP)imp;
- (void)_isim_loadFrame:(isim_objc_frame *)f;
- (void)_isim_storeReturnInFrame:(isim_objc_frame *)f;
@end
@implementation NSInvocation {
    NSMethodSignature *_sig;
    uint8_t *_args, *_ret;
    BOOL _retained;
}
+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig {
    if (!sig) [NSException raise:NSInvalidArgumentException format:@"+[NSInvocation invocationWithMethodSignature:]: method signature argument cannot be nil"];
    return [[self _isim_newWithSignature:sig] autorelease];
}
+ (instancetype)_isim_newWithSignature:(NSMethodSignature *)sig {
    NSInvocation *inv = [[self alloc] init];
    inv->_sig = [sig retain];
    inv->_args = calloc(1, sig->_frameLength + 16);
    inv->_ret = calloc(1, sig->_ret.size + 16);
    return inv;
}
static BOOL retainable(const isim_arginfo *ai) { return ai->code == '@' || ai->code == '#'; }
static BOOL is_block(const isim_arginfo *ai) { const char *t = skip_quals(ai->type); return t[0] == '@' && t[1] == '?'; }
static void retain_value(const isim_arginfo *ai, void *slot) {
    if (retainable(ai)) { id o = *(id *)slot; *(id *)slot = is_block(ai) ? [o copy] : [o retain]; }
    else if (ai->code == '*' && *(char **)slot) *(char **)slot = strdup(*(char **)slot);
}
static void release_value(const isim_arginfo *ai, void *slot) {
    if (retainable(ai)) [*(id *)slot release];
    else if (ai->code == '*') free(*(char **)slot);
}
- (void)dealloc {
    if (_retained) {
        for (NSUInteger i = 0; i < _sig->_count; i++) release_value(&_sig->_args[i], _args + _sig->_args[i].offset);
        release_value(&_sig->_ret, _ret);
    }
    free(_args); free(_ret);
    [_sig release];
    [super dealloc];
}
- (NSMethodSignature *)methodSignature { return _sig; }
- (void)retainArguments {
    if (_retained) return;
    _retained = YES;
    for (NSUInteger i = 0; i < _sig->_count; i++) retain_value(&_sig->_args[i], _args + _sig->_args[i].offset);
    retain_value(&_sig->_ret, _ret);
}
- (BOOL)argumentsRetained { return _retained; }
- (void)setArgument:(void *)loc atIndex:(NSInteger)idx {
    if (idx < 0 || (NSUInteger)idx >= _sig->_count)
        [NSException raise:NSInvalidArgumentException format:@"-[NSInvocation setArgument:atIndex:]: index (%ld) out of bounds [-1, %ld]", (long)idx, (long)_sig->_count - 1];
    isim_arginfo *ai = &_sig->_args[idx];
    void *slot = _args + ai->offset;
    if (_retained) {
        uint8_t old[16] = {0}; memcpy(old, slot, ai->size <= 16 ? ai->size : 0);
        memcpy(slot, loc, ai->size);
        retain_value(ai, slot);
        if (ai->size <= 16) release_value(ai, old);
    } else memcpy(slot, loc, ai->size);
}
- (void)getArgument:(void *)loc atIndex:(NSInteger)idx {
    if (idx < 0 || (NSUInteger)idx >= _sig->_count)
        [NSException raise:NSInvalidArgumentException format:@"-[NSInvocation getArgument:atIndex:]: index (%ld) out of bounds [-1, %ld]", (long)idx, (long)_sig->_count - 1];
    memcpy(loc, _args + _sig->_args[idx].offset, _sig->_args[idx].size);
}
- (void)setReturnValue:(void *)loc {
    if (_retained) { uint8_t old[16] = {0}; memcpy(old, _ret, _sig->_ret.size <= 16 ? _sig->_ret.size : 0); memcpy(_ret, loc, _sig->_ret.size); retain_value(&_sig->_ret, _ret); if (_sig->_ret.size <= 16) release_value(&_sig->_ret, old); }
    else memcpy(_ret, loc, _sig->_ret.size);
}
- (void)getReturnValue:(void *)loc { memcpy(loc, _ret, _sig->_ret.size); }
- (id)target { return _sig->_count > 0 ? *(id *)_args : nil; }
- (void)setTarget:(id)t { if (_sig->_count > 0) [self setArgument:&t atIndex:0]; }
- (SEL)selector { return _sig->_count > 1 ? *(SEL *)(_args + _sig->_args[1].offset) : NULL; }
- (void)setSelector:(SEL)s { if (_sig->_count > 1) [self setArgument:&s atIndex:1]; }

- (void)invoke { [self _isim_invokeIMP:NULL]; }
- (void)invokeWithTarget:(id)target { [self setTarget:target]; [self _isim_invokeIMP:NULL]; }
- (void)invokeUsingIMP:(IMP)imp { [self _isim_invokeIMP:imp]; }
- (void)_isim_invokeIMP:(IMP)imp {
    isim_arginfo *ri = &_sig->_ret;
    BOOL stret = ri->memory && ri->size;
    if (!self.target && !imp) { memset(_ret, 0, ri->size); return; }
    isim_objc_call c; memset(&c, 0, sizeof c);
    NSUInteger maxstack = _sig->_frameLength / 8 + 2 * _sig->_count + 2;
    uint64_t *stack = calloc(maxstack, 8);
    place_t pc = {0, 0, 0};
    if (stret) c.gpr[pc.ng++] = (uint64_t)(uintptr_t)_ret;
    for (NSUInteger i = 0; i < _sig->_count; i++) {
        isim_arginfo *ai = &_sig->_args[i];
        const uint8_t *src = _args + ai->offset;
        if (!ai->size) continue;
        if (in_registers(ai, &pc)) {
            for (int w = 0; w < ai->nwords; w++) {
                NSUInteger n = ai->size - w * 8 < 8 ? ai->size - w * 8 : 8;
                uint64_t v = scalar_word(ai, src + w * 8, n);
                if (ai->cls[w] == CLS_SSE) c.xmm[pc.nx++][0] = v; else c.gpr[pc.ng++] = v;
            }
        } else {
            NSUInteger at = stack_slot(ai, &pc);
            if (ai->nwords == 1 && !ai->memory) stack[at] = scalar_word(ai, src, ai->size);
            else memcpy(stack + at, src, ai->size);
        }
    }
    c.fn = imp ? (void *)imp : stret ? (void *)objc_msgSend_stret : (void *)objc_msgSend;
    c.stack = stack; c.nstack = pc.ns; c.nvec = pc.nx;
    @try { isim_objc_call_frame(&c); }
    @finally { free(stack); }
    if (!stret && ri->size) {
        int g = 0, x = 0;
        for (int w = 0; w < ri->nwords; w++) {
            uint64_t v = ri->cls[w] == CLS_SSE ? c.ret_xmm[x++][0] : c.ret_gpr[g++];
            NSUInteger n = ri->size - w * 8 < 8 ? ri->size - w * 8 : 8;
            memcpy(_ret + w * 8, &v, n);
        }
    }
    if (_retained) retain_value(ri, _ret);
}

/* forwarding: arguments from the registers/stack captured by _objc_msgForward */
- (void)_isim_loadFrame:(isim_objc_frame *)f {
    isim_arginfo *ri = &_sig->_ret;
    place_t pc = {0, 0, 0};
    if (ri->memory && ri->size) pc.ng = 1;
    for (NSUInteger i = 0; i < _sig->_count; i++) {
        isim_arginfo *ai = &_sig->_args[i];
        uint8_t *dst = _args + ai->offset;
        if (!ai->size) continue;
        if (in_registers(ai, &pc)) {
            for (int w = 0; w < ai->nwords; w++) {
                NSUInteger n = ai->size - w * 8 < 8 ? ai->size - w * 8 : 8;
                uint64_t v = ai->cls[w] == CLS_SSE ? f->xmm[pc.nx++][0] : f->gpr[pc.ng++];
                memcpy(dst + w * 8, &v, n);
            }
        } else {
            NSUInteger at = stack_slot(ai, &pc);
            memcpy(dst, f->stack + at, ai->size);
        }
    }
}
- (void)_isim_storeReturnInFrame:(isim_objc_frame *)f {
    isim_arginfo *ri = &_sig->_ret;
    if (!ri->size) return;
    if (ri->memory) {
        void *buf = (void *)(uintptr_t)f->gpr[0];
        if (buf) memcpy(buf, _ret, ri->size);
        f->ret_gpr[0] = f->gpr[0];
        return;
    }
    int g = 0, x = 0;
    for (int w = 0; w < ri->nwords; w++) {
        NSUInteger n = ri->size - w * 8 < 8 ? ri->size - w * 8 : 8;
        uint64_t v = scalar_word(ri, _ret + w * 8, n);
        if (ri->cls[w] == CLS_SSE) f->ret_xmm[x++][0] = v; else f->ret_gpr[g++] = v;
    }
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSInvocation: %p> -[%s %s] (%lu arguments)", self, self.target ? object_getClassName(self.target) : "nil",
            self.selector ? sel_getName(self.selector) : "(null)", (unsigned long)_sig->_count];
}
@end

/* ================= NSObject forwarding support ================= */
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation NSObject (NSObjectForwarding)
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    Method m = sel ? class_getInstanceMethod(object_getClass(self), sel) : NULL;
    const char *t = m ? method_getTypeEncoding(m) : NULL;
    return t ? [NSMethodSignature signatureWithObjCTypes:t] : nil;
}
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    Method m = sel ? class_getInstanceMethod(object_getClass(self), sel) : NULL;
    const char *t = m ? method_getTypeEncoding(m) : NULL;
    return t ? [NSMethodSignature signatureWithObjCTypes:t] : nil;
}
+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)sel {
    Method m = sel ? class_getInstanceMethod(self, sel) : NULL;
    const char *t = m ? method_getTypeEncoding(m) : NULL;
    return t ? [NSMethodSignature signatureWithObjCTypes:t] : nil;
}
- (void)forwardInvocation:(NSInvocation *)inv { [self doesNotRecognizeSelector:inv.selector]; }
+ (void)forwardInvocation:(NSInvocation *)inv { [self doesNotRecognizeSelector:inv.selector]; }
+ (id)forwardingTargetForSelector:(SEL)sel { return nil; }
+ (void)doesNotRecognizeSelector:(SEL)sel {
    [NSException raise:NSInvalidArgumentException format:@"+[%s %s]: unrecognized selector sent to class %p", class_getName(self), sel_getName(sel), self];
}
+ (IMP)instanceMethodForSelector:(SEL)sel { return class_getMethodImplementation(self, sel); }
@end

/* ================= the forwarding handler (installed into libobjc at load) ================= */
static SEL s_fwdTarget, s_sigFor, s_fwdInv, s_dnr;
static id isim_forward(id self, SEL sel, isim_objc_frame *f) {
    Class cls = object_getClass(self);
    if (sel != s_fwdTarget && class_respondsToSelector(cls, s_fwdTarget)) {
        id t = ((id (*)(id, SEL, SEL))objc_msgSend)(self, s_fwdTarget, sel);
        if (t && t != self) return t;
    }
    if (sel != s_sigFor && class_respondsToSelector(cls, s_sigFor)) {
        NSMethodSignature *sig = ((id (*)(id, SEL, SEL))objc_msgSend)(self, s_sigFor, sel);
        if (sig && class_respondsToSelector(cls, s_fwdInv)) {
            NSInvocation *inv = [NSInvocation _isim_newWithSignature:sig];
            [inv _isim_loadFrame:f];
            @try {
                ((void (*)(id, SEL, id))objc_msgSend)(self, s_fwdInv, inv);
                [inv _isim_storeReturnInFrame:f];
            } @finally {
                [inv release];
            }
            return nil;
        }
    }
    if (sel != s_dnr && class_respondsToSelector(cls, s_dnr)) {
        ((void (*)(id, SEL, SEL))objc_msgSend)(self, s_dnr, sel);
        return nil;
    }
    fflush(NULL);
    fprintf(stderr, "isim objc: FATAL: %c[%s %s]: unrecognized selector sent to %s %p (no forwarding methods)\n",
            class_isMetaClass(cls) ? '+' : '-', class_getName(cls), sel_getName(sel), class_isMetaClass(cls) ? "class" : "instance", self);
    signal(SIGABRT, SIG_DFL);
    abort();
}
__attribute__((constructor)) static void isim_install_forwarding(void) {
    s_fwdTarget = @selector(forwardingTargetForSelector:); s_sigFor = @selector(methodSignatureForSelector:);
    s_fwdInv = @selector(forwardInvocation:); s_dnr = @selector(doesNotRecognizeSelector:);
    isim_objc_set_forward_handler(isim_forward);
}

/* ================= NSProxy ================= */
@implementation NSProxy
+ (id)alloc { return [self allocWithZone:NULL]; }
+ (id)allocWithZone:(NSZone *)zone { return class_createInstance(self, 0); }
+ (Class)class { return self; }
+ (Class)superclass { return class_getSuperclass(self); }
+ (id)self { return self; }
+ (BOOL)respondsToSelector:(SEL)sel { return class_respondsToSelector(object_getClass(self), sel); }
+ (BOOL)instancesRespondToSelector:(SEL)sel { return class_respondsToSelector(self, sel); }
+ (BOOL)conformsToProtocol:(Protocol *)p { for (Class c = self; c; c = class_getSuperclass(c)) if (class_conformsToProtocol(c, p)) return YES; return NO; }
+ (BOOL)isKindOfClass:(Class)cls { for (Class c = object_getClass(self); c; c = class_getSuperclass(c)) if (c == cls) return YES; return NO; }
+ (BOOL)isSubclassOfClass:(Class)cls { for (Class c = self; c; c = class_getSuperclass(c)) if (c == cls) return YES; return NO; }
+ (NSString *)description { return [NSString stringWithUTF8String:class_getName(self)]; }
+ (NSString *)debugDescription { return [self description]; }
+ (id)retain { return self; }
+ (oneway void)release {}
+ (id)autorelease { return self; }
+ (NSUInteger)retainCount { return NSUIntegerMax; }
+ (NSUInteger)hash { return (NSUInteger)self; }
+ (BOOL)isEqual:(id)o { return self == o; }
+ (id)copyWithZone:(NSZone *)z { return self; }
+ (BOOL)resolveInstanceMethod:(SEL)sel { return NO; }
+ (BOOL)resolveClassMethod:(SEL)sel { return NO; }
+ (id)forwardingTargetForSelector:(SEL)sel { return nil; }
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    Method m = sel ? class_getInstanceMethod(object_getClass(self), sel) : NULL;
    return m && method_getTypeEncoding(m) ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)] : nil;
}
+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)sel {
    Method m = sel ? class_getInstanceMethod(self, sel) : NULL;
    return m && method_getTypeEncoding(m) ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)] : nil;
}
+ (void)forwardInvocation:(NSInvocation *)inv { [self doesNotRecognizeSelector:inv.selector]; }
+ (void)doesNotRecognizeSelector:(SEL)sel {
    [NSException raise:NSInvalidArgumentException format:@"+[%s %s]: unrecognized selector sent to class %p", class_getName(self), sel_getName(sel), self];
}

- (void)dealloc { object_dispose(self); }
- (void)finalize {}
- (id)retain { return _objc_rootRetain(self); }
- (oneway void)release { _objc_rootRelease(self); }
- (id)autorelease { return _objc_rootAutorelease(self); }
- (NSUInteger)retainCount { return _objc_rootRetainCount(self); }
- (NSZone *)zone { return NULL; }
- (Class)class { return object_getClass(self); }
- (Class)superclass { return class_getSuperclass(object_getClass(self)); }
- (id)self { return self; }
- (BOOL)isProxy { return YES; }
- (NSUInteger)hash { return (NSUInteger)self; }
- (BOOL)isEqual:(id)o { return self == o; }
- (BOOL)allowsWeakReference { return !_objc_rootIsDeallocating(self); }
- (BOOL)retainWeakReference { return !_objc_rootIsDeallocating(self); }
- (NSString *)description { return [NSString stringWithFormat:@"<%s: %p>", object_getClassName(self), self]; }
- (NSString *)debugDescription { return [self description]; }
- (id)performSelector:(SEL)sel { return ((id (*)(id, SEL))objc_msgSend)(self, sel); }
- (id)performSelector:(SEL)sel withObject:(id)o { return ((id (*)(id, SEL, id))objc_msgSend)(self, sel, o); }
- (id)performSelector:(SEL)sel withObject:(id)a withObject:(id)b { return ((id (*)(id, SEL, id, id))objc_msgSend)(self, sel, a, b); }
- (void)forwardInvocation:(NSInvocation *)inv {
    [NSException raise:NSInvalidArgumentException format:@"*** -[NSProxy forwardInvocation:] called!"];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    [NSException raise:NSInvalidArgumentException format:@"*** -[NSProxy methodSignatureForSelector:] called!"];
    return nil;
}
- (void)doesNotRecognizeSelector:(SEL)sel {
    [NSException raise:NSInvalidArgumentException format:@"-[%s %s]: unrecognized selector sent to instance %p", object_getClassName(self), sel_getName(sel), self];
}
/* NSObject-protocol queries are answered by the proxied object: sent through -forwardInvocation: */
static BOOL forward_bool(id self, SEL cmd, const void *arg) {
    NSMethodSignature *sig = [self methodSignatureForSelector:cmd];
    if (!sig) [NSException raise:NSInvalidArgumentException format:@"*** -[NSProxy %s] called!", sel_getName(cmd)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:self];
    [inv setSelector:cmd];
    [inv setArgument:(void *)arg atIndex:2];
    [self forwardInvocation:inv];
    BOOL r = NO;
    if ([sig methodReturnLength] == sizeof r) [inv getReturnValue:&r];
    return r;
}
- (BOOL)isKindOfClass:(Class)c { return forward_bool(self, _cmd, &c); }
- (BOOL)isMemberOfClass:(Class)c { return forward_bool(self, _cmd, &c); }
- (BOOL)respondsToSelector:(SEL)s { return forward_bool(self, _cmd, &s); }
- (BOOL)conformsToProtocol:(Protocol *)p { return forward_bool(self, _cmd, &p); }
@end
