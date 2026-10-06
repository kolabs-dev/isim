// Objective-C runtime self-test for isim: exceptions (@try/@catch/@finally/@throw, @synchronized),
// message forwarding (forwardingTargetForSelector:, forwardInvocation:, doesNotRecognizeSelector:),
// NSMethodSignature, NSInvocation and NSProxy. Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

// ---------------------------------------------------------------- exceptions
@interface MyError : NSObject @property int code; @end
@implementation MyError @end
@interface MyException : NSException @end
@implementation MyException @end

static int deallocs;
@interface Tracked : NSObject @end
@implementation Tracked - (void)dealloc { deallocs++; } @end

__attribute__((noinline)) static void thrower(int kind) {
    Tracked *t = [Tracked new];        // released by the cleanup landing pad while unwinding (-fobjc-arc-exceptions)
    (void)t;
    if (kind == 1) [NSException raise:NSInvalidArgumentException format:@"bad value %d", 42];
    if (kind == 2) { MyError *e = [MyError new]; e.code = 7; @throw e; }
    if (kind == 3) @throw [MyException exceptionWithName:@"MyName" reason:@"mine" userInfo:@{@"k": @1}];
    if (kind == 4) @throw @"a string";
}
__attribute__((noinline)) static int nested_frames(int depth, int kind) {
    if (depth == 0) { thrower(kind); return 0; }
    return nested_frames(depth - 1, kind) + 1;
}

static NSString *catchKind(int kind) {
    @try { nested_frames(5, kind); return @"none"; }
    @catch (MyException *e) { return [NSString stringWithFormat:@"MyException %@ %@ %@", e.name, e.reason, e.userInfo[@"k"]]; }
    @catch (NSException *e) { return [NSString stringWithFormat:@"NSException %@ %@", e.name, e.reason]; }
    @catch (MyError *e) { return [NSString stringWithFormat:@"MyError %d", e.code]; }
    @catch (id e) { return [NSString stringWithFormat:@"id %@", e]; }
}

static void testExceptions(void) {
    CHECK([catchKind(0) isEqualToString:@"none"]);
    CHECK([catchKind(1) isEqualToString:@"NSException NSInvalidArgumentException bad value 42"]);
    CHECK([catchKind(2) isEqualToString:@"MyError 7"]);
    CHECK([catchKind(3) isEqualToString:@"MyException MyName mine 1"]);
    CHECK([catchKind(4) isEqualToString:@"id a string"]);

    // @finally runs on normal exit, on exception, and the exception continues to the outer handler
    NSMutableArray *log = [NSMutableArray array];
    @try {
        @try { [log addObject:@"try"]; } @finally { [log addObject:@"finally1"]; }
        @try { [log addObject:@"try2"]; thrower(1); [log addObject:@"not reached"]; }
        @finally { [log addObject:@"finally2"]; }
    } @catch (NSException *e) { [log addObject:[@"outer " stringByAppendingString:e.name]]; }
    CHECK([[log componentsJoinedByString:@","] isEqualToString:@"try,finally1,try2,finally2,outer NSInvalidArgumentException"]);

    // rethrow with @throw; inside a @catch, caught again by an outer handler; @finally ordering
    [log removeAllObjects];
    @try {
        @try { thrower(2); }
        @catch (MyError *e) { [log addObject:@"inner"]; @throw; }
        @finally { [log addObject:@"finally"]; }
    } @catch (MyError *e) { [log addObject:[NSString stringWithFormat:@"outer %d", e.code]]; }
    CHECK([[log componentsJoinedByString:@","] isEqualToString:@"inner,finally,outer 7"]);

    // throwing a new exception from a @catch block
    NSString *got = nil;
    @try {
        @try { thrower(1); }
        @catch (NSException *e) { @throw [MyError new]; }
    } @catch (MyError *e) { got = @"replaced"; }
    @catch (NSException *e) { got = @"original"; }
    CHECK([got isEqualToString:@"replaced"]);

    // nested @try inside a @catch handling a different exception
    [log removeAllObjects];
    @try { thrower(1); }
    @catch (NSException *outer) {
        @try { thrower(2); } @catch (MyError *inner) { [log addObject:@"inner"]; }
        [log addObject:outer.name];
    }
    CHECK([[log componentsJoinedByString:@","] isEqualToString:@"inner,NSInvalidArgumentException"]);

    // ARC locals in unwound frames are released (the frames' cleanup landing pads run)
    deallocs = 0;
    @try { nested_frames(3, 1); } @catch (NSException *e) {}
    CHECK(deallocs == 1);

    // @synchronized releases its lock when an exception leaves the block
    NSObject *lock = [NSObject new];
    @try { @synchronized (lock) { thrower(1); } } @catch (NSException *e) {}
    __block BOOL acquired = NO;
    [NSThread detachNewThreadWithBlock:^{ @synchronized (lock) { acquired = YES; } }];
    for (int i = 0; i < 200 && !acquired; i++) [NSThread sleepForTimeInterval:0.01];
    CHECK(acquired);

    // exceptions raised by Foundation itself
    NSString *reason = nil;
    @try { [@[@1, @2] objectAtIndex:5]; } @catch (NSException *e) { reason = e.name; }
    CHECK([reason isEqualToString:NSRangeException]);
    reason = nil;
    id nothing = nil;
    @try { [NSMutableDictionary.dictionary setObject:nothing forKey:@"k"]; } @catch (NSException *e) { reason = e.name; }
    CHECK([reason isEqualToString:NSInvalidArgumentException]);

    // exceptions on another thread
    __block NSString *threadResult = nil;
    [NSThread detachNewThreadWithBlock:^{
        @try { thrower(3); } @catch (NSException *e) { threadResult = e.reason; }
    }];
    for (int i = 0; i < 200 && !threadResult; i++) [NSThread sleepForTimeInterval:0.01];
    CHECK([threadResult isEqualToString:@"mine"]);

    // many throws (no leaks of handler state)
    int caught = 0;
    for (int i = 0; i < 1000; i++) { @try { thrower(i % 2 ? 1 : 2); } @catch (id e) { caught++; } }
    CHECK(caught == 1000);
}

// ---------------------------------------------------------------- forwarding & NSInvocation
#include <objc/runtime.h>
#include <objc/message.h>
typedef struct { int a; float b; } Mixed;           // one INTEGER eightbyte
typedef struct { double d; long l; } DL;           // SSE + INTEGER
typedef struct { long a, b, c; } Big;              // MEMORY
typedef struct { float x, y, z; } F3;              // SSE + SSE (12 bytes)

@interface Target : NSObject
@property (nonatomic) int calls;
- (int)addInt:(int)a long:(long long)b char:(char)c short:(short)d bool:(BOOL)e;
- (double)sumD:(double)a f:(float)b i:(int)c d:(double)d;
- (double)many:(double)a1 :(double)a2 :(double)a3 :(double)a4 :(double)a5 :(double)a6 :(double)a7 :(double)a8 :(double)a9 :(double)a10
          ints:(long)i1 :(long)i2 :(long)i3 :(long)i4 :(long)i5 :(long)i6;
- (CGPoint)movePoint:(CGPoint)p by:(CGSize)s;
- (NSRange)shift:(NSRange)r by:(NSUInteger)n;
- (CGRect)inset:(CGRect)r by:(CGFloat)d;
- (Mixed)mixed:(Mixed)m;
- (DL)dl:(DL)x;
- (Big)big:(Big)b extra:(long)e;
- (F3)f3:(F3)v;
- (NSString *)join:(NSString *)a with:(id)b;
- (float)half:(float)f;
- (char)neg:(char)c;
- (unsigned short)ushort:(unsigned short)u;
- (BOOL)isEven:(long)n;
- (void)raiseIt;
+ (NSString *)classGreeting:(NSString *)name;
@end
@implementation Target
- (int)addInt:(int)a long:(long long)b char:(char)c short:(short)d bool:(BOOL)e { _calls++; return a + (int)b + c + d + (e ? 1000 : 0); }
- (double)sumD:(double)a f:(float)b i:(int)c d:(double)d { _calls++; return a + b + c + d; }
- (double)many:(double)a1 :(double)a2 :(double)a3 :(double)a4 :(double)a5 :(double)a6 :(double)a7 :(double)a8 :(double)a9 :(double)a10
          ints:(long)i1 :(long)i2 :(long)i3 :(long)i4 :(long)i5 :(long)i6 {
    _calls++;
    return a1 + 2 * a2 + 3 * a3 + 4 * a4 + 5 * a5 + 6 * a6 + 7 * a7 + 8 * a8 + 9 * a9 + 10 * a10 + 100 * (i1 + 2 * i2 + 3 * i3 + 4 * i4 + 5 * i5 + 6 * i6);
}
- (CGPoint)movePoint:(CGPoint)p by:(CGSize)s { _calls++; return CGPointMake(p.x + s.width, p.y + s.height); }
- (NSRange)shift:(NSRange)r by:(NSUInteger)n { _calls++; return NSMakeRange(r.location + n, r.length * 2); }
- (CGRect)inset:(CGRect)r by:(CGFloat)d { _calls++; return CGRectMake(r.origin.x + d, r.origin.y + d, r.size.width - 2 * d, r.size.height - 2 * d); }
- (Mixed)mixed:(Mixed)m { _calls++; return (Mixed){ m.a * 2, m.b * 2 }; }
- (DL)dl:(DL)x { _calls++; return (DL){ x.d + 0.5, x.l - 1 }; }
- (Big)big:(Big)b extra:(long)e { _calls++; return (Big){ b.a + e, b.b + e, b.c + e }; }
- (F3)f3:(F3)v { _calls++; return (F3){ v.z, v.y, v.x }; }
- (NSString *)join:(NSString *)a with:(id)b { _calls++; return [NSString stringWithFormat:@"%@+%@", a, b]; }
- (float)half:(float)f { _calls++; return f / 2; }
- (char)neg:(char)c { _calls++; return (char)-c; }
- (unsigned short)ushort:(unsigned short)u { _calls++; return (unsigned short)(u + 1); }
- (BOOL)isEven:(long)n { _calls++; return n % 2 == 0; }
- (void)raiseIt { [NSException raise:@"TargetException" format:@"raised by target"]; }
+ (NSString *)classGreeting:(NSString *)name { return [@"hello " stringByAppendingString:name]; }
@end

// forwardingTargetForSelector: (fast path)
@interface FastForwarder : NSObject @property (strong) Target *target; @end
@implementation FastForwarder
- (id)forwardingTargetForSelector:(SEL)sel { return [_target respondsToSelector:sel] ? _target : [super forwardingTargetForSelector:sel]; }
+ (id)forwardingTargetForSelector:(SEL)sel { return sel == @selector(classGreeting:) ? [Target class] : nil; }
@end

// methodSignatureForSelector: + forwardInvocation: (slow path), recording selectors
@interface Recorder : NSObject
@property (strong) Target *target;
@property (strong) NSMutableArray<NSString *> *log;
@end
@implementation Recorder
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [super methodSignatureForSelector:sel] ?: [_target methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)inv {
    if (!_log) _log = [NSMutableArray array];
    [_log addObject:NSStringFromSelector(inv.selector)];
    if ([_target respondsToSelector:inv.selector]) [inv invokeWithTarget:_target];
    else [super forwardInvocation:inv];
}
@end

// rewrites arguments and the return value
@interface Rewriter : NSObject @property (strong) Target *target; @end
@implementation Rewriter
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [Target instanceMethodSignatureForSelector:sel]; }
- (void)forwardInvocation:(NSInvocation *)inv {
    if (inv.selector == @selector(addInt:long:char:short:bool:)) {
        int a; [inv getArgument:&a atIndex:2]; a *= 10; [inv setArgument:&a atIndex:2];
        [inv invokeWithTarget:_target];
        int r; [inv getReturnValue:&r]; r += 1; [inv setReturnValue:&r];
    } else if (inv.selector == @selector(inset:by:)) {       // answered without a target (stret return)
        CGRect r; [inv getArgument:&r atIndex:2];
        CGRect out = CGRectMake(r.size.width, r.size.height, r.origin.x, r.origin.y);
        [inv setReturnValue:&out];
    } else if (inv.selector == @selector(movePoint:by:)) {
        CGPoint p = CGPointMake(-1, -2); [inv setReturnValue:&p];
    } else [inv invokeWithTarget:_target];
}
@end

// NSProxy forwarding to a real target
@interface TargetProxy : NSProxy
@property (strong) id target;
@property (nonatomic) int forwarded;
+ (instancetype)proxyWithTarget:(id)t;
@end
@implementation TargetProxy
+ (instancetype)proxyWithTarget:(id)t { TargetProxy *p = [TargetProxy alloc]; p.target = t; return p; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [_target methodSignatureForSelector:sel]; }
- (void)forwardInvocation:(NSInvocation *)inv { _forwarded++; [inv invokeWithTarget:_target]; }
@end

// dynamic method resolution wins over forwarding
static int dynamicIMP(id self, SEL _cmd, int x) { return x * 3; }
@interface Resolver : NSObject @property (nonatomic) int forwardedCount; @end
@implementation Resolver
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == NSSelectorFromString(@"tripled:")) { class_addMethod(self, sel, (IMP)dynamicIMP, "i20@0:8i16"); return YES; }
    return [super resolveInstanceMethod:sel];
}
- (id)forwardingTargetForSelector:(SEL)sel { _forwardedCount++; return nil; }
@end

@protocol Unknown - (void)fooBar; @end
@interface Unrelated : NSObject @end
@implementation Unrelated @end
@protocol Tripler - (int)tripled:(int)x; @end

static void testForwarding(void) {
    Target *target = [Target new];
    CGRect rr = CGRectMake(10, 20, 100, 50);

    // --- forwardingTargetForSelector:
    FastForwarder *ff = [FastForwarder new]; ff.target = target;
    Target *asT = (Target *)ff;
    CHECK([asT addInt:1 long:2 char:3 short:4 bool:YES] == 1010);
    CHECK([asT sumD:1.5 f:2.25f i:3 d:4.0] == 10.75);
    CGRect r1 = [asT inset:rr by:5];
    CHECK(CGRectEqualToRect(r1, CGRectMake(15, 25, 90, 40)));            // stret re-sent to the new target
    CHECK([[asT join:@"a" with:@1] isEqualToString:@"a+1"]);
    CHECK(target.calls == 4);
    CHECK([[(id)[FastForwarder class] classGreeting:@"you"] isEqualToString:@"hello you"]);
    CHECK(![ff respondsToSelector:@selector(addInt:long:char:short:bool:)]);   // forwarding does not imply respondsToSelector:

    // --- forwardInvocation: with every argument / return class
    Recorder *rec = [Recorder new]; rec.target = target;
    Target *t = (Target *)rec;
    CHECK([t addInt:-5 long:10000000000LL char:-3 short:-300 bool:NO] == (int)(-5 + 10000000000LL - 3 - 300));
    CHECK([t sumD:0.25 f:-1.5f i:-7 d:1e10] == 0.25 - 1.5 - 7 + 1e10);
    CHECK([t many:1 :2 :3 :4 :5 :6 :7 :8 :9 :10 ints:1 :2 :3 :4 :5 :6] == 385 + 100 * 91);   // stack-passed doubles and longs
    CGPoint mp = [t movePoint:CGPointMake(1.5, 2.5) by:CGSizeMake(10, 20)];
    CHECK(mp.x == 11.5 && mp.y == 22.5);
    NSRange sr = [t shift:NSMakeRange(3, 4) by:10];
    CHECK(sr.location == 13 && sr.length == 8);
    CGRect ir = [t inset:rr by:2];
    CHECK(CGRectEqualToRect(ir, CGRectMake(12, 22, 96, 46)));
    Mixed mx = [t mixed:(Mixed){ 21, 1.25f }];
    CHECK(mx.a == 42 && mx.b == 2.5f);
    DL dl = [t dl:(DL){ 1.0, 100 }];
    CHECK(dl.d == 1.5 && dl.l == 99);
    Big bg = [t big:(Big){ 1, 2, 3 } extra:10];
    CHECK(bg.a == 11 && bg.b == 12 && bg.c == 13);
    F3 f3 = [t f3:(F3){ 1, 2, 3 }];
    CHECK(f3.x == 3 && f3.y == 2 && f3.z == 1);
    CHECK([[t join:@"x" with:@"y"] isEqualToString:@"x+y"]);
    CHECK([t half:5.0f] == 2.5f);
    CHECK([t neg:5] == -5);
    CHECK([t ushort:65534] == 65535);
    CHECK([t isEven:4] == YES && [t isEven:3] == NO);
    CHECK(rec.log.count == 16 && [rec.log[0] isEqualToString:NSStringFromSelector(@selector(addInt:long:char:short:bool:))] && [rec.log[5] isEqualToString:@"inset:by:"]);

    // --- the forwarder rewrites arguments and results
    Rewriter *rw = [Rewriter new]; rw.target = target;
    CHECK([(Target *)rw addInt:2 long:0 char:0 short:0 bool:NO] == 21);
    CGRect swapped = [(Target *)rw inset:rr by:0];
    CHECK(CGRectEqualToRect(swapped, CGRectMake(100, 50, 10, 20)));
    CGPoint pp = [(Target *)rw movePoint:CGPointZero by:CGSizeZero];
    CHECK(pp.x == -1 && pp.y == -2);

    // --- exceptions thrown by the forwarded-to method propagate through the forwarding frames
    NSString *thrown = nil;
    @try { [t raiseIt]; } @catch (NSException *e) { thrown = e.name; }
    CHECK([thrown isEqualToString:@"TargetException"]);

    // --- unrecognized selectors raise NSInvalidArgumentException
    NSString *reason = nil;
    @try { [(Target *)[Unrelated new] half:1]; } @catch (NSException *e) { reason = e.reason; }
    CHECK([reason hasPrefix:@"-[Unrelated half:]: unrecognized selector sent to instance 0x"]);
    reason = nil;
    @try { [(id)[Unrelated class] classGreeting:@"x"]; } @catch (NSException *e) { reason = e.reason; }
    CHECK([reason hasPrefix:@"+[Unrelated classGreeting:]: unrecognized selector sent to class 0x"]);
    reason = nil;
    @try { [(Target *)rec neg:1]; [(id<Unknown>)rec fooBar]; } @catch (NSException *e) { reason = e.reason; }   // Recorder -> super forwardInvocation:
    CHECK([reason hasPrefix:@"-[Recorder fooBar]: unrecognized selector"]);
    reason = nil;
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [@"str" performSelector:NSSelectorFromString(@"noSuchMethod")];
#pragma clang diagnostic pop
    } @catch (NSException *e) { reason = e.reason; }
    CHECK([reason hasPrefix:@"-[__NSCFConstantString noSuchMethod]"] || [reason containsString:@" noSuchMethod]: unrecognized selector"]);

    // --- runtime functions
    CHECK(class_getMethodImplementation([Unrelated class], @selector(half:)) == (IMP)_objc_msgForward);
    CHECK([target methodForSelector:@selector(fooBar)] == (IMP)_objc_msgForward);
    CHECK(((int (*)(id, SEL, int))[rec methodForSelector:@selector(addInt:long:char:short:bool:)]) != NULL);
    Resolver *res = [Resolver new];
    CHECK([(id<Tripler>)res tripled:7] == 21 && res.forwardedCount == 0);
    CHECK([res respondsToSelector:NSSelectorFromString(@"tripled:")]);
    struct objc_method_description md = protocol_getMethodDescription(@protocol(Tripler), @selector(tripled:), YES, YES);
    CHECK(md.name == @selector(tripled:) && md.types && md.types[0] == 'i');

    // --- NSProxy
    TargetProxy *proxy = [TargetProxy proxyWithTarget:target];
    Target *pt = (Target *)proxy;
    CHECK([pt addInt:1 long:1 char:1 short:1 bool:NO] == 4);
    CGRect pr = [pt inset:rr by:1];
    CHECK(CGRectEqualToRect(pr, CGRectMake(11, 21, 98, 48)));
    CHECK([pt many:1 :1 :1 :1 :1 :1 :1 :1 :1 :1 ints:1 :1 :1 :1 :1 :1] == 55 + 2100);
    CHECK([proxy isKindOfClass:[Target class]] && [proxy isKindOfClass:[NSObject class]] && ![proxy isKindOfClass:[NSString class]]);
    CHECK([proxy isMemberOfClass:[Target class]]);
    CHECK([proxy respondsToSelector:@selector(raiseIt)] && ![proxy respondsToSelector:@selector(fooBar)]);
    CHECK([proxy conformsToProtocol:@protocol(NSObject)]);
    CHECK([proxy isProxy] && ![target isProxy] && [proxy class] == [TargetProxy class]);
    CHECK([[proxy description] hasPrefix:@"<TargetProxy: 0x"]);
    CHECK(proxy.forwarded >= 7);
    NSMutableString *ms = [NSMutableString stringWithString:@"ab"];
    id sp = [TargetProxy proxyWithTarget:ms];
    [sp appendString:@"cd"];
    CHECK([ms isEqualToString:@"abcd"] && [sp length] == 4 && [[sp uppercaseString] isEqualToString:@"ABCD"]);
    CHECK([sp characterAtIndex:2] == 'c' && NSEqualRanges([sp rangeOfString:@"cd"], NSMakeRange(2, 2)));
    __weak id weakProxy = proxy;
    CHECK(weakProxy == proxy);
    reason = nil;
    @try { [(id<Unknown>)[TargetProxy alloc] fooBar]; } @catch (NSException *e) { reason = e.reason; }   // no target: signature nil
    CHECK([reason containsString:@"fooBar]: unrecognized selector"]);
}

static void testInvocation(void) {
    // NSMethodSignature
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"{CGRect={CGPoint=dd}{CGSize=dd}}48@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16d48"];
    CHECK(sig.numberOfArguments == 4 && sig.methodReturnLength == 32);
    CHECK(!strcmp([sig getArgumentTypeAtIndex:0], "@") && !strcmp([sig getArgumentTypeAtIndex:1], ":") && !strcmp([sig getArgumentTypeAtIndex:3], "d"));
    CHECK(!strcmp(sig.methodReturnType, "{CGRect={CGPoint=dd}{CGSize=dd}}"));
    CHECK(sig.frameLength >= 56 && !sig.isOneway);
    CHECK([[NSMethodSignature signatureWithObjCTypes:"Vv16@0:8"] isOneway]);
    CHECK([sig isEqual:[Target instanceMethodSignatureForSelector:@selector(inset:by:)]]);
    NSUInteger sz = 0, al = 0;
    NSGetSizeAndAlignment("{_NSRange=QQ}", &sz, &al); CHECK(sz == 16 && al == 8);
    NSGetSizeAndAlignment("{?=cid}", &sz, &al); CHECK(sz == 16 && al == 8);
    NSGetSizeAndAlignment("[10s]", &sz, &al); CHECK(sz == 20 && al == 2);
    NSGetSizeAndAlignment("@\"NSString\"", &sz, &al); CHECK(sz == 8);
    const char *rest = NSGetSizeAndAlignment("^{CGPoint=dd}i", &sz, &al); CHECK(sz == 8 && !strcmp(rest, "i"));
    {
        NSString *r = nil;
        @try { [sig getArgumentTypeAtIndex:9]; } @catch (NSException *e) { r = e.name; }
        CHECK([r isEqualToString:NSInvalidArgumentException]);
    }

    // NSInvocation built by hand
    Target *target = [Target new];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:@selector(inset:by:)]];
    inv.target = target; inv.selector = @selector(inset:by:);
    CGRect r = CGRectMake(0, 0, 10, 10); CGFloat d = 1;
    [inv setArgument:&r atIndex:2]; [inv setArgument:&d atIndex:3];
    [inv invoke];
    CGRect out; [inv getReturnValue:&out];
    CHECK(CGRectEqualToRect(out, CGRectMake(1, 1, 8, 8)));
    CHECK(inv.target == target && inv.selector == @selector(inset:by:) && inv.methodSignature.numberOfArguments == 4);
    CGRect back; [inv getArgument:&back atIndex:2]; CHECK(CGRectEqualToRect(back, r));

    NSInvocation *sub = [NSInvocation invocationWithMethodSignature:[@"" methodSignatureForSelector:@selector(substringWithRange:)]];
    NSRange range = NSMakeRange(2, 3);
    [sub setSelector:@selector(substringWithRange:)];
    [sub setArgument:&range atIndex:2];
    [sub invokeWithTarget:@"abcdefg"];
    __unsafe_unretained NSString *subResult = nil; [sub getReturnValue:&subResult];
    CHECK([subResult isEqualToString:@"cde"]);

    NSInvocation *many = [NSInvocation invocationWithMethodSignature:[Target instanceMethodSignatureForSelector:@selector(many::::::::::ints::::::)]];
    many.selector = @selector(many::::::::::ints::::::);
    for (int i = 2; i < 12; i++) { double v = i - 1; [many setArgument:&v atIndex:i]; }
    for (int i = 12; i < 18; i++) { long v = i - 11; [many setArgument:&v atIndex:i]; }
    [many invokeWithTarget:target];
    double mr; [many getReturnValue:&mr];
    CHECK(mr == 385 + 100 * 91);

    NSInvocation *cls = [NSInvocation invocationWithMethodSignature:[Target methodSignatureForSelector:@selector(classGreeting:)]];
    cls.target = [Target class]; cls.selector = @selector(classGreeting:);
    NSString *arg = @"class"; [cls setArgument:&arg atIndex:2];
    [cls invoke];
    __unsafe_unretained NSString *greet; [cls getReturnValue:&greet];
    CHECK([greet isEqualToString:@"hello class"]);

    // nil target: no call, zeroed result
    NSInvocation *nilInv = [NSInvocation invocationWithMethodSignature:[Target instanceMethodSignatureForSelector:@selector(half:)]];
    nilInv.selector = @selector(half:);
    float f = 3; [nilInv setArgument:&f atIndex:2];
    [nilInv invoke];
    float fr = 1; [nilInv getReturnValue:&fr];
    CHECK(fr == 0);

    // retainArguments keeps object arguments alive and copies C strings
    NSInvocation *ret = [NSInvocation invocationWithMethodSignature:[Target instanceMethodSignatureForSelector:@selector(join:with:)]];
    __weak NSObject *weakArg = nil;
    @autoreleasepool {
        NSObject *o = [NSObject new]; weakArg = o;
        [ret setArgument:&o atIndex:3];
        [ret retainArguments];
    }
    CHECK(weakArg != nil && ret.argumentsRetained);
    NSString *first = @"first"; [ret setArgument:&first atIndex:2];
    ret.selector = @selector(join:with:);
    [ret invokeWithTarget:target];
    __unsafe_unretained NSString *joined; [ret getReturnValue:&joined];
    CHECK([joined hasPrefix:@"first+<NSObject: 0x"]);

    NSString *idx = nil;
    @try { [ret setArgument:&first atIndex:4]; } @catch (NSException *e) { idx = e.name; }
    CHECK([idx isEqualToString:NSInvalidArgumentException]);

    // invokeUsingIMP: (calls the IMP directly)
    NSInvocation *viaImp = [NSInvocation invocationWithMethodSignature:[Target instanceMethodSignatureForSelector:@selector(neg:)]];
    viaImp.target = target; viaImp.selector = @selector(neg:);
    char c = 9; [viaImp setArgument:&c atIndex:2];
    [viaImp invokeUsingIMP:class_getMethodImplementation([Target class], @selector(neg:))];
    char cr = 0; [viaImp getReturnValue:&cr];
    CHECK(cr == -9);

    // an exception raised by the invoked method reaches the caller of -invoke
    NSInvocation *raising = [NSInvocation invocationWithMethodSignature:[Target instanceMethodSignatureForSelector:@selector(raiseIt)]];
    raising.selector = @selector(raiseIt);
    NSString *name = nil;
    @try { [raising invokeWithTarget:target]; } @catch (NSException *e) { name = e.name; }
    CHECK([name isEqualToString:@"TargetException"]);

    // NSException call stack and uncaught handler getter
    NSException *captured = nil;
    @try { [target raiseIt]; } @catch (NSException *e) { captured = e; }
    CHECK(captured.callStackReturnAddresses.count >= 2 && captured.callStackSymbols.count == captured.callStackReturnAddresses.count);
    BOOL symbolized = NO;
    for (NSString *s in captured.callStackSymbols) if ([s containsString:@"ObjCRuntimeTest"] || [s containsString:@"raiseIt"]) symbolized = YES;
    CHECK(symbolized);
    CHECK(NSGetUncaughtExceptionHandler() == NULL);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        testExceptions();
        testForwarding();
        testInvocation();
        NSLog(@"objc runtime test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
