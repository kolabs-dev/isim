/* isim Accessibility: audio graphs (ARC). AXChartDescriptor and its axes, series and points; isim's VoiceOver (UIKit's
   UIAccessibilityRuntime.m) asks a descriptor for its spoken description, its details and to play itself:
   - Describe Chart: the title, the summary, the axes (with their ranges or categories) and the number of series;
   - Chart Details: per series the number of points, the minimum, the maximum and the mean;
   - Play Audio Graph: each series in turn as sound through isim's audio: the y value sets the pitch (220-880 Hz,
     on the y axis' scale), a gliding tone for a continuous series and a short tone per point for a discrete one.
   AXLiveAudioGraph plays each updated value (0...1) as a short tone at its pitch. Adapted: iOS's Chart Details is a
   full-screen view; isim's VoiceOver speaks it. */
#import <Accessibility/Accessibility.h>
#include <isim_host.h>
#include <math.h>

static NSString *ax_num(double v) {
    if (v == floor(v) && fabs(v) < 1e15) return [NSString stringWithFormat:@"%.0f", v];
    return [NSString stringWithFormat:@"%.4g", v];
}

@implementation AXNumericDataAxisDescriptor
@synthesize title = _title, attributedTitle = _attributedTitle;
- (instancetype)initWithTitle:(NSString *)title lowerBound:(double)lower upperBound:(double)upper gridlinePositions:(NSArray<NSNumber *> *)grid
     valueDescriptionProvider:(NSString *(^)(double))provider {
    return [self initWithAttributedTitle:[[NSAttributedString alloc] initWithString:title ?: @""] lowerBound:lower upperBound:upper
                       gridlinePositions:grid valueDescriptionProvider:provider];
}
- (instancetype)initWithAttributedTitle:(NSAttributedString *)title lowerBound:(double)lower upperBound:(double)upper
                      gridlinePositions:(NSArray<NSNumber *> *)grid valueDescriptionProvider:(NSString *(^)(double))provider {
    if ((self = [super init])) {
        _attributedTitle = [title copy]; _title = [title.string copy] ?: @"";
        _lowerBound = lower; _upperBound = upper; _gridlinePositions = [grid copy] ?: @[];
        NSString *(^fallback)(double) = ^NSString *(double v) { return ax_num(v); };
        _valueDescriptionProvider = provider ? (NSString *(^)(double))[provider copy] : fallback;
    }
    return self;
}
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; _attributedTitle = [[NSAttributedString alloc] initWithString:_title]; }
- (void)setAttributedTitle:(NSAttributedString *)t { _attributedTitle = [t copy]; _title = [t.string copy] ?: @""; }
- (id)copyWithZone:(NSZone *)zone {
    AXNumericDataAxisDescriptor *c = [[AXNumericDataAxisDescriptor alloc] initWithAttributedTitle:_attributedTitle lowerBound:_lowerBound
                                                                                        upperBound:_upperBound gridlinePositions:_gridlinePositions
                                                                          valueDescriptionProvider:_valueDescriptionProvider];
    c.scaleType = _scaleType;
    return c;
}
- (NSString *)_isim_describe:(double)v { return _valueDescriptionProvider ? _valueDescriptionProvider(v) : ax_num(v); }
/* the value's position on the axis (0...1), on its scale */
- (double)_isim_position:(double)v {
    double lo = _lowerBound, hi = _upperBound;
    if (_scaleType != AXScaleTypeLinear && lo > 0 && hi > 0 && v > 0) { lo = log(lo); hi = log(hi); v = log(v); }
    return hi > lo ? fmin(1, fmax(0, (v - lo) / (hi - lo))) : 0.5;
}
@end

@implementation AXCategoricalDataAxisDescriptor
@synthesize title = _title, attributedTitle = _attributedTitle;
- (instancetype)initWithTitle:(NSString *)title categoryOrder:(NSArray<NSString *> *)order {
    return [self initWithAttributedTitle:[[NSAttributedString alloc] initWithString:title ?: @""] categoryOrder:order];
}
- (instancetype)initWithAttributedTitle:(NSAttributedString *)title categoryOrder:(NSArray<NSString *> *)order {
    if ((self = [super init])) { _attributedTitle = [title copy]; _title = [title.string copy] ?: @""; _categoryOrder = [order copy] ?: @[]; }
    return self;
}
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; _attributedTitle = [[NSAttributedString alloc] initWithString:_title]; }
- (void)setAttributedTitle:(NSAttributedString *)t { _attributedTitle = [t copy]; _title = [t.string copy] ?: @""; }
- (id)copyWithZone:(NSZone *)zone { return [[AXCategoricalDataAxisDescriptor alloc] initWithAttributedTitle:_attributedTitle categoryOrder:_categoryOrder]; }
@end

@implementation AXDataPointValue
+ (instancetype)valueWithNumber:(double)number { AXDataPointValue *v = [[self alloc] _isim_init]; v.number = number; return v; }
+ (instancetype)valueWithCategory:(NSString *)category { AXDataPointValue *v = [[self alloc] _isim_init]; v.category = category; return v; }
- (instancetype)_isim_init { return [super init]; }
- (id)copyWithZone:(NSZone *)zone { AXDataPointValue *v = [[AXDataPointValue alloc] _isim_init]; v.number = _number; v.category = _category; return v; }
- (NSString *)description { return _category ?: ax_num(_number); }
@end

@implementation AXDataPoint
- (instancetype)initWithX:(AXDataPointValue *)x y:(AXDataPointValue *)y { return [self initWithX:x y:y additionalValues:nil label:nil]; }
- (instancetype)initWithX:(AXDataPointValue *)x y:(AXDataPointValue *)y additionalValues:(NSArray *)more { return [self initWithX:x y:y additionalValues:more label:nil]; }
- (instancetype)initWithX:(AXDataPointValue *)x y:(AXDataPointValue *)y additionalValues:(NSArray *)more label:(NSString *)label {
    if ((self = [super init])) { _xValue = [x copy]; _yValue = [y copy]; _additionalValues = [more copy] ?: @[]; self.label = label; }
    return self;
}
- (void)setLabel:(NSString *)l { _label = [l copy]; _attributedLabel = l ? [[NSAttributedString alloc] initWithString:l] : nil; }
- (void)setAttributedLabel:(NSAttributedString *)l { _attributedLabel = [l copy]; _label = [l.string copy]; }
- (id)copyWithZone:(NSZone *)zone {
    AXDataPoint *p = [[AXDataPoint alloc] initWithX:_xValue y:_yValue additionalValues:_additionalValues label:nil];
    p.attributedLabel = _attributedLabel;
    return p;
}
@end

@implementation AXDataSeriesDescriptor
- (instancetype)initWithName:(NSString *)name isContinuous:(BOOL)continuous dataPoints:(NSArray<AXDataPoint *> *)points {
    return [self initWithAttributedName:[[NSAttributedString alloc] initWithString:name ?: @""] isContinuous:continuous dataPoints:points];
}
- (instancetype)initWithAttributedName:(NSAttributedString *)name isContinuous:(BOOL)continuous dataPoints:(NSArray<AXDataPoint *> *)points {
    if ((self = [super init])) { self.attributedName = name; _isContinuous = continuous; _dataPoints = [points copy] ?: @[]; }
    return self;
}
- (void)setName:(NSString *)n { _name = [n copy]; _attributedName = n ? [[NSAttributedString alloc] initWithString:n] : nil; }
- (void)setAttributedName:(NSAttributedString *)n { _attributedName = [n copy]; _name = [n.string copy]; }
- (id)copyWithZone:(NSZone *)zone {
    return [[AXDataSeriesDescriptor alloc] initWithAttributedName:_attributedName ?: [NSAttributedString new] isContinuous:_isContinuous dataPoints:_dataPoints];
}
@end

/* ---- sound ---- */
static const double kRate = 44100;
static long graph_voice;
static void ax_play(float *pcm, long frames) {
    if (!isim_audio_available() || getenv("ISIM_HEADLESS")) return;
    int buf = isim_audio_buffer_create(pcm, frames, 1, kRate);
    if (graph_voice) isim_audio_stop(graph_voice);
    graph_voice = isim_audio_play(buf, 0.6, 0);
    isim_audio_buffer_release(buf);
}
static double ax_pitch(double position) { return 220.0 * pow(4.0, position); }   /* 0 -> 220 Hz, 1 -> 880 Hz (two octaves) */

@implementation AXChartDescriptor
- (instancetype)initWithTitle:(NSString *)title summary:(NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)x
              yAxisDescriptor:(AXNumericDataAxisDescriptor *)y series:(NSArray *)series {
    return [self initWithTitle:title summary:summary xAxisDescriptor:x yAxisDescriptor:y additionalAxes:nil series:series];
}
- (instancetype)initWithAttributedTitle:(NSAttributedString *)title summary:(NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)x
                        yAxisDescriptor:(AXNumericDataAxisDescriptor *)y series:(NSArray *)series {
    return [self initWithAttributedTitle:title summary:summary xAxisDescriptor:x yAxisDescriptor:y additionalAxes:nil series:series];
}
- (instancetype)initWithTitle:(NSString *)title summary:(NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)x
              yAxisDescriptor:(AXNumericDataAxisDescriptor *)y additionalAxes:(NSArray *)more series:(NSArray *)series {
    return [self initWithAttributedTitle:title ? [[NSAttributedString alloc] initWithString:title] : nil summary:summary xAxisDescriptor:x
                         yAxisDescriptor:y additionalAxes:more series:series];
}
- (instancetype)initWithAttributedTitle:(NSAttributedString *)title summary:(NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)x
                        yAxisDescriptor:(AXNumericDataAxisDescriptor *)y additionalAxes:(NSArray *)more series:(NSArray *)series {
    if ((self = [super init])) {
        self.attributedTitle = title; _summary = [summary copy];
        _xAxis = [(id)x copy]; _yAxis = [y copy]; _additionalAxes = [more copy] ?: @[]; _series = [series copy] ?: @[];
        _contentFrame = CGRectZero;
    }
    return self;
}
- (void)setTitle:(NSString *)t { _title = [t copy]; _attributedTitle = t ? [[NSAttributedString alloc] initWithString:t] : nil; }
- (void)setAttributedTitle:(NSAttributedString *)t { _attributedTitle = [t copy]; _title = [t.string copy]; }
- (id)copyWithZone:(NSZone *)zone {
    AXChartDescriptor *c = [[AXChartDescriptor alloc] initWithAttributedTitle:_attributedTitle summary:_summary xAxisDescriptor:_xAxis
                                                              yAxisDescriptor:_yAxis additionalAxes:_additionalAxes series:_series];
    c.contentDirection = _contentDirection; c.contentFrame = _contentFrame;
    return c;
}

/* ---- what isim's VoiceOver says and plays ---- */
static NSString *axis_text(id<AXDataAxisDescriptor> axis, NSString *which) {
    if (!axis) return nil;
    if ([(id)axis isKindOfClass:[AXNumericDataAxisDescriptor class]]) {
        AXNumericDataAxisDescriptor *n = (id)axis;
        return [NSString stringWithFormat:@"%@ axis: %@. From %@ to %@", which, n.title, [n _isim_describe:n.lowerBound], [n _isim_describe:n.upperBound]];
    }
    if ([(id)axis isKindOfClass:[AXCategoricalDataAxisDescriptor class]]) {
        NSArray *c = [(AXCategoricalDataAxisDescriptor *)axis categoryOrder];
        return [NSString stringWithFormat:@"%@ axis: %@. %lu categories%@", which, axis.title, (unsigned long)c.count,
                c.count ? [NSString stringWithFormat:@", %@ to %@", c.firstObject, c.lastObject] : @""];
    }
    return [NSString stringWithFormat:@"%@ axis: %@", which, axis.title];
}
- (NSString *)_isim_spokenDescription {
    NSMutableArray *parts = [NSMutableArray array];
    if (_title.length) [parts addObject:_title];
    if (_summary.length) [parts addObject:_summary];
    if (axis_text(_xAxis, @"X")) [parts addObject:axis_text(_xAxis, @"X")];
    if (axis_text(_yAxis, @"Y")) [parts addObject:axis_text(_yAxis, @"Y")];
    [parts addObject:_series.count == 1 ? @"1 series" : [NSString stringWithFormat:@"%lu series", (unsigned long)_series.count]];
    return [parts componentsJoinedByString:@". "];
}
- (NSString *)_isim_xText:(AXDataPoint *)p {
    if (p.xValue.category) return p.xValue.category;
    return [(id)_xAxis isKindOfClass:[AXNumericDataAxisDescriptor class]] ? [(AXNumericDataAxisDescriptor *)_xAxis _isim_describe:p.xValue.number] : ax_num(p.xValue.number);
}
- (NSString *)_isim_yText:(double)v { return _yAxis ? [_yAxis _isim_describe:v] : ax_num(v); }
- (NSString *)_isim_details {
    NSMutableArray *parts = [NSMutableArray array];
    for (AXDataSeriesDescriptor *s in _series) {
        AXDataPoint *lo = nil, *hi = nil; double sum = 0; NSUInteger n = 0;
        for (AXDataPoint *p in s.dataPoints) {
            if (!p.yValue) continue;
            double v = p.yValue.number; sum += v; n++;
            if (!lo || v < lo.yValue.number) lo = p;
            if (!hi || v > hi.yValue.number) hi = p;
        }
        NSString *name = s.name.length ? s.name : @"Series";
        if (!n) { [parts addObject:[NSString stringWithFormat:@"%@: %lu points", name, (unsigned long)s.dataPoints.count]]; continue; }
        [parts addObject:[NSString stringWithFormat:@"%@: %lu points. Minimum %@ at %@. Maximum %@ at %@. Mean %@", name, (unsigned long)n,
                          [self _isim_yText:lo.yValue.number], [self _isim_xText:lo], [self _isim_yText:hi.yValue.number], [self _isim_xText:hi],
                          [self _isim_yText:sum / n]]];
    }
    return [parts componentsJoinedByString:@". "];
}
/* the y position (0...1) of a value: on the y axis, or between the series' extremes */
- (double)_isim_position:(double)v min:(double)mn max:(double)mx {
    if (_yAxis) return [_yAxis _isim_position:v];
    return mx > mn ? (v - mn) / (mx - mn) : 0.5;
}
/* plays every series in turn; returns what it played (for the log) */
- (NSString *)_isim_playAudioGraph {
    NSMutableArray *played = [NSMutableArray array];
    long total = 0, cap = (long)(kRate * 12);
    float *pcm = calloc((size_t)cap, sizeof(float));
    for (AXDataSeriesDescriptor *s in _series) {
        NSMutableArray<AXDataPoint *> *pts = [NSMutableArray array];
        for (AXDataPoint *p in s.dataPoints) if (p.yValue) [pts addObject:p];
        if (!pts.count) continue;
        double mn = INFINITY, mx = -INFINITY;
        for (AXDataPoint *p in pts) { mn = fmin(mn, p.yValue.number); mx = fmax(mx, p.yValue.number); }
        double seconds = fmin(4.0, fmax(1.0, pts.count * 0.12)), per = seconds / pts.count, phase = 0;
        long frames = (long)(seconds * kRate);
        if (total + frames + (long)(kRate * 0.3) > cap) break;
        for (long i = 0; i < frames; i++) {
            double t = (double)i / frames * pts.count;
            NSUInteger k = MIN((NSUInteger)t, pts.count - 1);
            double f0 = ax_pitch([self _isim_position:pts[k].yValue.number min:mn max:mx]), f = f0;
            double env = 1;
            if (s.isContinuous && k + 1 < pts.count) {         /* glide toward the next point */
                double f1 = ax_pitch([self _isim_position:pts[k + 1].yValue.number min:mn max:mx]);
                f = f0 + (f1 - f0) * (t - k);
            } else if (!s.isContinuous) {                     /* a short tone per point */
                double local = (t - k) * per;
                env = local < per * 0.7 ? fmin(1, local * 200) * fmin(1, (per * 0.7 - local) * 200) : 0;
            }
            phase += 2 * M_PI * f / kRate;
            pcm[total + i] = (float)(0.35 * env * sin(phase));
        }
        total += frames + (long)(kRate * 0.3);                 /* a pause between series */
        [played addObject:[NSString stringWithFormat:@"“%@” %lu points %@ %.0f–%.0f Hz %.1f s", s.name ?: @"", (unsigned long)pts.count,
                           s.isContinuous ? @"continuous" : @"discrete",
                           ax_pitch([self _isim_position:mn min:mn max:mx]), ax_pitch([self _isim_position:mx min:mn max:mx]), seconds]];
    }
    if (total) ax_play(pcm, total);
    free(pcm);
    return [played componentsJoinedByString:@"; "];
}
@end

@implementation AXLiveAudioGraph
static BOOL live_running;
+ (void)start { live_running = YES; NSLog(@"isim: live audio graph started"); }
+ (void)updateValue:(double)value {
    if (!live_running) return;
    double v = fmin(1, fmax(0, value)), f = ax_pitch(v);
    NSLog(@"isim: live audio graph value %@ (%.0f Hz)", ax_num(v), f);
    long frames = (long)(kRate * 0.15);
    float *pcm = calloc((size_t)frames, sizeof(float));
    for (long i = 0; i < frames; i++) {
        double env = fmin(1, i / 200.0) * fmin(1, (frames - i) / 200.0);
        pcm[i] = (float)(0.3 * env * sin(2 * M_PI * f * i / kRate));
    }
    ax_play(pcm, frames);
    free(pcm);
}
+ (void)stop {
    if (!live_running) return;
    live_running = NO;
    if (graph_voice) { isim_audio_stop(graph_voice); graph_voice = 0; }
    NSLog(@"isim: live audio graph stopped");
}
@end
