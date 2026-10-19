/* isim Symbols for Objective-C (issue #235): the effect, option and content transition classes. Each one describes
 * itself the way the Swift overlay's effects do (_IsimSymbolEffectDescription: kind, direction, layers, flags, angle,
 * axis), and UIKit's overlay plays that description (UIKit+Symbols.swift). The kinds match the Swift enum. */
#import <Symbols/Symbols.h>
/* the subclasses inherit effectWithByLayer / effectWithWholeSymbol from NSSymbolEffect */
#pragma clang diagnostic ignored "-Wincomplete-implementation"

enum { K_APPEAR, K_DISAPPEAR, K_BOUNCE, K_PULSE, K_VARIABLE_COLOR, K_SCALE, K_REPLACE, K_AUTOMATIC, K_WIGGLE, K_BREATHE, K_ROTATE,
       K_DRAW_ON, K_DRAW_OFF };

/* ================= options ================= */
@implementation NSSymbolEffectOptionsRepeatBehavior { NSInteger _count; double _delay; BOOL _continuous; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)_make:(NSInteger)count delay:(double)delay continuous:(BOOL)continuous {
    NSSymbolEffectOptionsRepeatBehavior *b = [[self alloc] initForIsim];
    b->_count = count; b->_delay = delay; b->_continuous = continuous;
    return b;
}
- (instancetype)initForIsim { return [super init]; }
+ (instancetype)behaviorPeriodic { return [self _make:-1 delay:0 continuous:NO]; }
+ (instancetype)behaviorPeriodicWithCount:(NSInteger)count { return [self _make:count delay:0 continuous:NO]; }
+ (instancetype)behaviorPeriodicWithDelay:(double)delay { return [self _make:-1 delay:delay continuous:NO]; }
+ (instancetype)behaviorPeriodicWithCount:(NSInteger)count delay:(double)delay { return [self _make:count delay:delay continuous:NO]; }
+ (instancetype)behaviorContinuous { return [self _make:-1 delay:0 continuous:YES]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { _count = [c decodeIntegerForKey:@"count"]; _delay = [c decodeDoubleForKey:@"delay"]; _continuous = [c decodeBoolForKey:@"continuous"]; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:_count forKey:@"count"]; [c encodeDouble:_delay forKey:@"delay"]; [c encodeBool:_continuous forKey:@"continuous"]; }
/* for UIKit: -1 repeats without end */
- (NSInteger)_isimRepeatCount { return _count > 0 ? _count : -1; }
- (double)_isimRepeatDelay { return _delay; }
@end

@implementation NSSymbolEffectOptions { NSInteger _repeat; double _speed, _delay; }   /* _repeat: 0 default, -1 forever, n times */
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initForIsim { if ((self = [super init])) _speed = 1; return self; }
+ (instancetype)options { return [[self alloc] initForIsim]; }
- (instancetype)_with:(void (^)(NSSymbolEffectOptions *o))change { NSSymbolEffectOptions *o = [self copy]; change(o); return o; }
+ (instancetype)optionsWithRepeating { return [[self options] optionsWithRepeating]; }
- (instancetype)optionsWithRepeating { return [self _with:^(NSSymbolEffectOptions *o) { o->_repeat = -1; }]; }
+ (instancetype)optionsWithNonRepeating { return [[self options] optionsWithNonRepeating]; }
- (instancetype)optionsWithNonRepeating { return [self _with:^(NSSymbolEffectOptions *o) { o->_repeat = 1; }]; }
+ (instancetype)optionsWithRepeatCount:(NSInteger)count { return [[self options] optionsWithRepeatCount:count]; }
- (instancetype)optionsWithRepeatCount:(NSInteger)count { return [self _with:^(NSSymbolEffectOptions *o) { o->_repeat = MAX(1, count); }]; }
+ (instancetype)optionsWithSpeed:(double)speed { return [[self options] optionsWithSpeed:speed]; }
- (instancetype)optionsWithSpeed:(double)speed { return [self _with:^(NSSymbolEffectOptions *o) { o->_speed = speed > 0 ? speed : 1; }]; }
+ (instancetype)optionsWithRepeatBehavior:(NSSymbolEffectOptionsRepeatBehavior *)b { return [[self options] optionsWithRepeatBehavior:b]; }
- (instancetype)optionsWithRepeatBehavior:(NSSymbolEffectOptionsRepeatBehavior *)b {
    return [self _with:^(NSSymbolEffectOptions *o) { o->_repeat = [b _isimRepeatCount]; o->_delay = [b _isimRepeatDelay]; }];
}
- (id)copyWithZone:(NSZone *)zone {
    NSSymbolEffectOptions *o = [[[self class] allocWithZone:zone] initForIsim];
    o->_repeat = _repeat; o->_speed = _speed; o->_delay = _delay;
    return o;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [self initForIsim])) { _repeat = [c decodeIntegerForKey:@"repeat"]; _speed = [c decodeDoubleForKey:@"speed"] ?: 1; _delay = [c decodeDoubleForKey:@"delay"]; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:_repeat forKey:@"repeat"]; [c encodeDouble:_speed forKey:@"speed"]; [c encodeDouble:_delay forKey:@"delay"]; }
/* for UIKit: repeat 0 = the effect's default, -1 = forever */
- (NSInteger)_isimRepeatCount { return _repeat; }
- (double)_isimSpeed { return _speed; }
- (double)_isimRepeatDelay { return _delay; }
@end

/* ================= effects ================= */
@interface NSSymbolEffect ()
@property (nonatomic) NSInteger _isimKind, _isimDirection, _isimFlags, _isimAxis;
@property (nonatomic) BOOL _isimByLayer;
@property (nonatomic) double _isimAngle;
@end
@implementation NSSymbolEffect
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initForIsim { return [super init]; }
+ (instancetype)_kind:(NSInteger)kind { NSSymbolEffect *e = [[self alloc] initForIsim]; e._isimKind = kind; return e; }
- (instancetype)_with:(void (^)(NSSymbolEffect *e))change { NSSymbolEffect *e = [self copy]; change(e); return e; }
- (instancetype)effectWithByLayer { return [self _with:^(NSSymbolEffect *e) { e._isimByLayer = YES; }]; }
- (instancetype)effectWithWholeSymbol { return [self _with:^(NSSymbolEffect *e) { e._isimByLayer = NO; }]; }
- (id)copyWithZone:(NSZone *)zone {
    NSSymbolEffect *e = [[[self class] allocWithZone:zone] initForIsim];
    e._isimKind = __isimKind; e._isimDirection = __isimDirection; e._isimFlags = __isimFlags; e._isimAxis = __isimAxis;
    e._isimByLayer = __isimByLayer; e._isimAngle = __isimAngle;
    return e;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        __isimKind = [c decodeIntegerForKey:@"kind"]; __isimDirection = [c decodeIntegerForKey:@"direction"]; __isimFlags = [c decodeIntegerForKey:@"flags"];
        __isimAxis = [c decodeIntegerForKey:@"axis"]; __isimByLayer = [c decodeBoolForKey:@"byLayer"]; __isimAngle = [c decodeDoubleForKey:@"angle"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:__isimKind forKey:@"kind"]; [c encodeInteger:__isimDirection forKey:@"direction"]; [c encodeInteger:__isimFlags forKey:@"flags"];
    [c encodeInteger:__isimAxis forKey:@"axis"]; [c encodeBool:__isimByLayer forKey:@"byLayer"]; [c encodeDouble:__isimAngle forKey:@"angle"];
}
- (BOOL)isEqual:(id)o {
    if ([o class] != [self class]) return NO;
    NSSymbolEffect *e = o;
    return e._isimKind == __isimKind && e._isimDirection == __isimDirection && e._isimFlags == __isimFlags && e._isimAxis == __isimAxis &&
           e._isimByLayer == __isimByLayer && e._isimAngle == __isimAngle;
}
- (NSUInteger)hash { return __isimKind * 31 + __isimDirection * 7 + __isimFlags * 3 + __isimByLayer; }
/* the description UIKit reads (the Swift overlay's _IsimSymbolEffectDescription) */
- (NSDictionary *)_isimDescription {
    return @{ @"kind": @(__isimKind), @"direction": @(__isimDirection), @"byLayer": @(__isimByLayer), @"flags": @(__isimFlags),
              @"angle": @(__isimAngle), @"axis": @(__isimAxis) };
}
@end

@implementation NSSymbolPulseEffect
+ (instancetype)effect { return [self _kind:K_PULSE]; }
@end
@implementation NSSymbolBounceEffect
+ (instancetype)effect { return [self _kind:K_BOUNCE]; }
+ (instancetype)bounceUpEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = 1; return (id)e; }
+ (instancetype)bounceDownEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = -1; return (id)e; }
@end
@implementation NSSymbolVariableColorEffect
+ (instancetype)effect { return [self _kind:K_VARIABLE_COLOR]; }
- (instancetype)effectWithIterative { return [self _with:^(NSSymbolEffect *e) { e._isimFlags |= 1; }]; }
- (instancetype)effectWithCumulative { return [self _with:^(NSSymbolEffect *e) { e._isimFlags &= ~1; }]; }
- (instancetype)effectWithReversing { return [self _with:^(NSSymbolEffect *e) { e._isimFlags |= 2; }]; }
- (instancetype)effectWithNonReversing { return [self _with:^(NSSymbolEffect *e) { e._isimFlags &= ~2; }]; }
- (instancetype)effectWithHideInactiveLayers { return [self _with:^(NSSymbolEffect *e) { e._isimFlags |= 4; }]; }
- (instancetype)effectWithDimInactiveLayers { return [self _with:^(NSSymbolEffect *e) { e._isimFlags &= ~4; }]; }
@end
@implementation NSSymbolScaleEffect
+ (instancetype)effect { NSSymbolEffect *e = [self _kind:K_SCALE]; e._isimDirection = 1; return (id)e; }
+ (instancetype)scaleUpEffect { return [self effect]; }
+ (instancetype)scaleDownEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = -1; return (id)e; }
@end
@implementation NSSymbolAppearEffect
+ (instancetype)effect { return [self _kind:K_APPEAR]; }
+ (instancetype)appearUpEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = 1; return (id)e; }
+ (instancetype)appearDownEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = -1; return (id)e; }
@end
@implementation NSSymbolDisappearEffect
+ (instancetype)effect { return [self _kind:K_DISAPPEAR]; }
+ (instancetype)disappearUpEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = 1; return (id)e; }
+ (instancetype)disappearDownEffect { NSSymbolEffect *e = [self effect]; e._isimDirection = -1; return (id)e; }
@end
@implementation NSSymbolWiggleEffect
+ (instancetype)_axis:(NSInteger)axis angle:(double)angle { NSSymbolEffect *e = [self _kind:K_WIGGLE]; e._isimAxis = axis; e._isimAngle = angle; return (id)e; }
+ (instancetype)effect { return [self _axis:0 angle:1]; }
+ (instancetype)wiggleClockwiseEffect { return [self _axis:0 angle:1]; }
+ (instancetype)wiggleCounterClockwiseEffect { return [self _axis:0 angle:-1]; }
+ (instancetype)wiggleLeftEffect { return [self _axis:1 angle:-1]; }
+ (instancetype)wiggleRightEffect { return [self _axis:1 angle:1]; }
+ (instancetype)wiggleUpEffect { return [self _axis:2 angle:-1]; }
+ (instancetype)wiggleDownEffect { return [self _axis:2 angle:1]; }
+ (instancetype)wiggleForwardEffect { return [self _axis:3 angle:1]; }
+ (instancetype)wiggleBackwardEffect { return [self _axis:3 angle:-1]; }
+ (instancetype)wiggleCustomAngleEffect:(double)angle { return [self _axis:0 angle:angle]; }
@end
@implementation NSSymbolRotateEffect
+ (instancetype)effect { NSSymbolEffect *e = [self _kind:K_ROTATE]; e._isimAngle = 1; return (id)e; }
+ (instancetype)rotateClockwiseEffect { return [self effect]; }
+ (instancetype)rotateCounterClockwiseEffect { NSSymbolEffect *e = [self effect]; e._isimAngle = -1; return (id)e; }
@end
@implementation NSSymbolBreatheEffect
+ (instancetype)effect { return [self _kind:K_BREATHE]; }
+ (instancetype)breathePulseEffect { NSSymbolEffect *e = [self effect]; e._isimFlags = 1; return (id)e; }
+ (instancetype)breathePlainEffect { return [self effect]; }
@end
@implementation NSSymbolDrawOnEffect
+ (instancetype)effect { return [self _kind:K_DRAW_ON]; }
- (instancetype)effectWithIndividually { return [self effectWithByLayer]; }
@end
@implementation NSSymbolDrawOffEffect
+ (instancetype)effect { return [self _kind:K_DRAW_OFF]; }
- (instancetype)effectWithIndividually { return [self effectWithByLayer]; }
- (instancetype)effectWithReversed { return [self _with:^(NSSymbolEffect *e) { e._isimFlags = 1; }]; }
- (instancetype)effectWithNonReversed { return [self _with:^(NSSymbolEffect *e) { e._isimFlags = 0; }]; }
@end

/* ================= content transitions ================= */
@interface NSSymbolContentTransition ()
@property (nonatomic) NSInteger _isimKind, _isimDirection;
@property (nonatomic) BOOL _isimByLayer;
@end
@implementation NSSymbolContentTransition
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initForIsim { return [super init]; }
+ (instancetype)_kind:(NSInteger)kind direction:(NSInteger)dir { NSSymbolContentTransition *t = [[self alloc] initForIsim]; t._isimKind = kind; t._isimDirection = dir; return t; }
- (id)copyWithZone:(NSZone *)zone {
    NSSymbolContentTransition *t = [[[self class] allocWithZone:zone] initForIsim];
    t._isimKind = __isimKind; t._isimDirection = __isimDirection; t._isimByLayer = __isimByLayer;
    return t;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { __isimKind = [c decodeIntegerForKey:@"kind"]; __isimDirection = [c decodeIntegerForKey:@"direction"]; __isimByLayer = [c decodeBoolForKey:@"byLayer"]; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:__isimKind forKey:@"kind"]; [c encodeInteger:__isimDirection forKey:@"direction"]; [c encodeBool:__isimByLayer forKey:@"byLayer"]; }
- (NSDictionary *)_isimDescription {
    return @{ @"kind": @(__isimKind), @"direction": @(__isimDirection), @"byLayer": @(__isimByLayer), @"flags": @0, @"angle": @0, @"axis": @0 };
}
@end
@implementation NSSymbolReplaceContentTransition
+ (instancetype)transition { return [self _kind:K_REPLACE direction:0]; }
+ (instancetype)replaceDownUpTransition { return [self _kind:K_REPLACE direction:-1]; }
+ (instancetype)replaceUpUpTransition { return [self _kind:K_REPLACE direction:1]; }
+ (instancetype)replaceOffUpTransition { return [self _kind:K_REPLACE direction:0]; }
- (instancetype)transitionWithByLayer { NSSymbolContentTransition *t = [self copy]; t._isimByLayer = YES; return (id)t; }
- (instancetype)transitionWithWholeSymbol { NSSymbolContentTransition *t = [self copy]; t._isimByLayer = NO; return (id)t; }
@end
@implementation NSSymbolAutomaticContentTransition
+ (instancetype)transition { return [self _kind:K_AUTOMATIC direction:0]; }
@end
