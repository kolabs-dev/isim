// isim Sound Analysis for Objective-C (issue #368): the C side of the Swift overlay's classes — the string constants,
// SNTimeDurationConstraint, and the CMTime / CMTimeRange properties (the overlay has CMTime as a Swift struct: they
// travel as NSNumbers).
#import <SoundAnalysis/SoundAnalysis.h>
// windowDuration, windowDurationConstraint and timeRange are declared in the classes' @interfaces (Apple's headers)
// and implemented here
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

NSString * const SNErrorDomain = @"com.apple.SoundAnalysis";
SNClassifierIdentifier const SNClassifierIdentifierVersion1 = @"SNClassifierIdentifierVersion1";

static NSValue *sn_value(CMTime t) { return [NSValue valueWithBytes:&t objCType:@encode(CMTime)]; }
static CMTime sn_time(NSArray<NSNumber *> *v, NSUInteger i) {
    if (v.count < i + 4) return (CMTime){ 0, 0, 0, 0 };
    return (CMTime){ v[i].longLongValue, v[i + 1].intValue, v[i + 2].unsignedIntValue, v[i + 3].longLongValue };
}

@implementation SNTimeDurationConstraint {
    NSArray<NSValue *> *_durations;
    CMTimeRange _range;
    SNTimeDurationConstraintType _type;
}
- (instancetype)initWithEnumeratedDurations:(NSArray<NSValue *> *)enumeratedDurations {
    if ((self = [super init])) { _type = SNTimeDurationConstraintTypeEnumerated; _durations = [enumeratedDurations copy]; }
    return self;
}
- (instancetype)initWithDurationRange:(CMTimeRange)durationRange {
    if ((self = [super init])) { _type = SNTimeDurationConstraintTypeRange; _durations = @[]; _range = durationRange; }
    return self;
}
- (SNTimeDurationConstraintType)type { return _type; }
- (NSArray<NSValue *> *)enumeratedDurations { return _durations; }
- (CMTimeRange)durationRange { return _range; }
- (id)copyWithZone:(NSZone *)zone { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:_type forKey:@"type"];
    NSMutableArray *d = [NSMutableArray array];
    for (NSValue *v in _durations) { CMTime t; [v getValue:&t]; [d addObject:@[ @(t.value), @(t.timescale), @(t.flags), @(t.epoch) ]]; }
    [c encodeObject:d forKey:@"durations"];
    [c encodeObject:@[ @(_range.start.value), @(_range.start.timescale), @(_range.start.flags), @(_range.start.epoch),
                       @(_range.duration.value), @(_range.duration.timescale), @(_range.duration.flags), @(_range.duration.epoch) ] forKey:@"range"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if (!(self = [super init])) return nil;
    _type = [c decodeIntegerForKey:@"type"];
    NSSet *classes = [NSSet setWithObjects:NSArray.class, NSNumber.class, nil];
    NSMutableArray *d = [NSMutableArray array];
    for (NSArray *t in [c decodeObjectOfClasses:classes forKey:@"durations"]) [d addObject:sn_value(sn_time(t, 0))];
    _durations = d;
    NSArray *r = [c decodeObjectOfClasses:classes forKey:@"range"];
    _range = (CMTimeRange){ sn_time(r, 0), sn_time(r, 4) };
    return self;
}
@end

@interface SNClassifySoundRequest (ISIMTime)
@property (nonatomic, copy) NSArray<NSNumber *> *_isim_windowDuration;
- (NSArray<NSNumber *> *)_isim_windowDurationConstraint;
@end
@implementation SNClassifySoundRequest (ISIMStructs)
- (CMTime)windowDuration { return sn_time(self._isim_windowDuration, 0); }
- (void)setWindowDuration:(CMTime)t { self._isim_windowDuration = @[ @(t.value), @(t.timescale), @(t.flags), @(t.epoch) ]; }
- (SNTimeDurationConstraint *)windowDurationConstraint {
    NSArray<NSNumber *> *v = [self _isim_windowDurationConstraint];
    if (v.count >= 9 && v[0].integerValue == SNTimeDurationConstraintTypeRange)
        return [[SNTimeDurationConstraint alloc] initWithDurationRange:(CMTimeRange){ sn_time(v, 1), sn_time(v, 5) }];
    NSMutableArray *d = [NSMutableArray array];
    for (NSUInteger i = 1; i + 4 <= v.count; i += 4) [d addObject:sn_value(sn_time(v, i))];
    return [[SNTimeDurationConstraint alloc] initWithEnumeratedDurations:d];
}
@end

@interface SNClassificationResult (ISIMTime)
- (NSArray<NSNumber *> *)_isim_timeRange;
@end
@implementation SNClassificationResult (ISIMStructs)
- (CMTimeRange)timeRange {
    NSArray<NSNumber *> *v = [self _isim_timeRange];
    return (CMTimeRange){ sn_time(v, 0), sn_time(v, 4) };
}
@end
