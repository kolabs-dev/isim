/* UISlider, UIStepper, UISegmentedControl, UIProgressView, UIActivityIndicatorView, UIPageControl,
 * UIMenu (pop-up menus as UIKit shows for UIButton.menu) and CADisplayLink — drawn with iOS 17 metrics. */
#import "UIKitPrivate.h"
#include <math.h>

static UIColor *tint_of(UIView *v) { return v.tintColor ?: UIColor.systemBlueColor; }
static void fill(UIColor *c, double x, double y, double w, double h, double r, double alpha) {
    double rgba[4]; isim_ui_rgba(c, rgba); rgba[3] *= alpha; isim_gfx_fill_rounded(x, y, w, h, r, rgba);
}

/* ================= UISlider ================= */
/* iOS 17/18: 4 pt track, 28 pt round white thumb. iOS 26/27 (Liquid Glass): 6 pt track, a 38 x 24 white capsule thumb
   that turns into clear glass and grows while dragged; stepped sliders (trackConfiguration) show tick dots; the
   thumbless style is a thicker track the finger drags anywhere. */
@implementation UISliderTick
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)tickWithPosition:(float)position title:(NSString *)title image:(UIImage *)image {
    UISliderTick *t = [self new]; t->_position = position; t.title = title; t.image = image; return t;
}
- (id)copyWithZone:(NSZone *)z { return [UISliderTick tickWithPosition:_position title:_title image:_image]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UISliderTick class]] && ((UISliderTick *)o)->_position == _position && [((UISliderTick *)o).title ?: @"" isEqual:_title ?: @""] && ((UISliderTick *)o).image == _image; }
- (NSUInteger)hash { return (NSUInteger)(_position * 1000) ^ _title.hash; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeFloat:_position forKey:@"position"]; [c encodeObject:_title forKey:@"title"]; [c encodeObject:_image forKey:@"image"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { _position = [c decodeFloatForKey:@"position"]; _title = [c decodeObjectOfClass:[NSString class] forKey:@"title"]; _image = [c decodeObjectOfClass:[UIImage class] forKey:@"image"]; }
    return self;
}
@end
@implementation UISliderTrackConfiguration
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { if ((self = [super init])) { _allowsTickValuesOnly = YES; _maximumEnabledValue = 1; _ticks = @[]; } return self; }
+ (instancetype)configurationWithNumberOfTicks:(NSInteger)n {
    NSMutableArray *t = [NSMutableArray array];
    for (NSInteger i = 0; i < n; i++) [t addObject:[UISliderTick tickWithPosition:n > 1 ? (float)i / (float)(n - 1) : 0 title:nil image:nil]];
    return [self configurationWithTicks:t];
}
+ (instancetype)configurationWithTicks:(NSArray<UISliderTick *> *)ticks {
    UISliderTrackConfiguration *c = [self new];
    c->_ticks = [[ticks ?: @[] copy] sortedArrayUsingComparator:^NSComparisonResult(UISliderTick *a, UISliderTick *b) { return a.position < b.position ? NSOrderedAscending : a.position > b.position ? NSOrderedDescending : NSOrderedSame; }];
    return c;
}
- (id)copyWithZone:(NSZone *)z {
    UISliderTrackConfiguration *c = [UISliderTrackConfiguration configurationWithTicks:_ticks];
    c.allowsTickValuesOnly = _allowsTickValuesOnly; c.neutralValue = _neutralValue; c.minimumEnabledValue = _minimumEnabledValue; c.maximumEnabledValue = _maximumEnabledValue;
    return c;
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[UISliderTrackConfiguration class]]) return NO;
    UISliderTrackConfiguration *c = o;
    return c.allowsTickValuesOnly == _allowsTickValuesOnly && c.neutralValue == _neutralValue && c.minimumEnabledValue == _minimumEnabledValue
        && c.maximumEnabledValue == _maximumEnabledValue && [c.ticks isEqualToArray:_ticks];
}
- (NSUInteger)hash { return _ticks.count ^ (NSUInteger)(_neutralValue * 1000); }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeBool:_allowsTickValuesOnly forKey:@"allowsTickValuesOnly"]; [c encodeFloat:_neutralValue forKey:@"neutralValue"];
    [c encodeFloat:_minimumEnabledValue forKey:@"minimumEnabledValue"]; [c encodeFloat:_maximumEnabledValue forKey:@"maximumEnabledValue"];
    [c encodeObject:_ticks forKey:@"ticks"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _allowsTickValuesOnly = [c decodeBoolForKey:@"allowsTickValuesOnly"]; _neutralValue = [c decodeFloatForKey:@"neutralValue"];
        _minimumEnabledValue = [c decodeFloatForKey:@"minimumEnabledValue"]; _maximumEnabledValue = [c decodeFloatForKey:@"maximumEnabledValue"];
        _ticks = [c decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [UISliderTick class], nil] forKey:@"ticks"] ?: @[];
    }
    return self;
}
@end

@implementation UISlider { BOOL _dragging; double _grab; NSMutableDictionary<NSNumber *, UIImage *> *_thumbImages, *_minTrackImages, *_maxTrackImages;
    UISliderStyle _sliderStyle; UISliderTrackConfiguration *_trackConfiguration; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, f.size.width, f.size.height ?: 31)])) {
        _maximumValue = 1; _continuous = YES;
        _thumbImages = [NSMutableDictionary dictionary]; _minTrackImages = [NSMutableDictionary dictionary]; _maxTrackImages = [NSMutableDictionary dictionary];
    }
    return self;
}
- (CGFloat)_height {
    CGFloat h = 31;
    for (UIImage *i in @[_minimumValueImage ?: (id)NSNull.null, _maximumValueImage ?: (id)NSNull.null, self.currentThumbImage ?: (id)NSNull.null])
        if ([i isKindOfClass:[UIImage class]]) h = fmax(h, i.size.height);
    return h;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, [self _height]); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 ? s.width : 118, [self _height]); }
- (void)setValue:(float)v { _value = fmaxf(_minimumValue, fminf(_maximumValue, v)); isim_ui_set_needs_display(); }
- (void)setValue:(float)v animated:(BOOL)a { self.value = v; }
- (void)setMinimumValue:(float)v { _minimumValue = v; if (_maximumValue < v) _maximumValue = v; self.value = _value; }
- (void)setMaximumValue:(float)v { _maximumValue = v; if (_minimumValue > v) _minimumValue = v; self.value = _value; }
- (void)setMinimumValueImage:(UIImage *)i { _minimumValueImage = i; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setMaximumValueImage:(UIImage *)i { _maximumValueImage = i; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
/* images: setting a thumb tint drops custom thumb images and vice versa, like UIKit */
- (void)setThumbTintColor:(UIColor *)c { _thumbTintColor = c; if (c) [_thumbImages removeAllObjects]; isim_ui_set_needs_display(); }
- (void)setMinimumTrackTintColor:(UIColor *)c { _minimumTrackTintColor = c; if (c) [_minTrackImages removeAllObjects]; isim_ui_set_needs_display(); }
- (void)setMaximumTrackTintColor:(UIColor *)c { _maximumTrackTintColor = c; if (c) [_maxTrackImages removeAllObjects]; isim_ui_set_needs_display(); }
static void set_state_image(NSMutableDictionary *d, UIImage *i, UIControlState s) { if (i) d[@(s)] = i; else [d removeObjectForKey:@(s)]; isim_ui_set_needs_display(); }
- (void)setThumbImage:(UIImage *)i forState:(UIControlState)s { set_state_image(_thumbImages, i, s); if (i) _thumbTintColor = nil; [self invalidateIntrinsicContentSize]; }
- (void)setMinimumTrackImage:(UIImage *)i forState:(UIControlState)s { set_state_image(_minTrackImages, i, s); if (i) _minimumTrackTintColor = nil; }
- (void)setMaximumTrackImage:(UIImage *)i forState:(UIControlState)s { set_state_image(_maxTrackImages, i, s); if (i) _maximumTrackTintColor = nil; }
- (UIImage *)thumbImageForState:(UIControlState)s { return _thumbImages[@(s)]; }
- (UIImage *)minimumTrackImageForState:(UIControlState)s { return _minTrackImages[@(s)]; }
- (UIImage *)maximumTrackImageForState:(UIControlState)s { return _maxTrackImages[@(s)]; }
- (UIImage *)_current:(NSDictionary *)d { return d[@(self.state)] ?: d[@(UIControlStateNormal)]; }
- (UIImage *)currentThumbImage { return [self _current:_thumbImages]; }
- (UIImage *)currentMinimumTrackImage { return [self _current:_minTrackImages]; }
- (UIImage *)currentMaximumTrackImage { return [self _current:_maxTrackImages]; }
- (UIControlState)state { return [super state] | (_dragging ? UIControlStateHighlighted : 0); }
- (UISliderStyle)sliderStyle { return _sliderStyle; }
- (void)setSliderStyle:(UISliderStyle)st { _sliderStyle = st; isim_ui_set_needs_display(); }
- (UISliderTrackConfiguration *)trackConfiguration { return [_trackConfiguration copy]; }
- (void)setTrackConfiguration:(UISliderTrackConfiguration *)c { _trackConfiguration = [c copy]; self.value = _value; isim_ui_set_needs_display(); }
- (BOOL)_glassLook { return isim_ui_glass(); }
- (BOOL)_thumbless { return _sliderStyle == UISliderStyleThumbless; }
/* the default thumb: 28 pt circle (iOS 17/18), 38 x 24 capsule (iOS 26+), or the custom image's size */
- (CGSize)_thumbSize {
    UIImage *i = self.currentThumbImage;
    if (i) return i.size;
    if ([self _thumbless]) return CGSizeZero;
    return [self _glassLook] ? CGSizeMake(38, 24) : CGSizeMake(28, 28);
}
- (CGRect)minimumValueImageRectForBounds:(CGRect)b {
    UIImage *i = _minimumValueImage; if (!i) return CGRectZero;
    CGSize s = i.size; BOOL rtl = [self _isim_isRTL];
    return CGRectMake(rtl ? CGRectGetMaxX(b) - s.width : b.origin.x, CGRectGetMidY(b) - s.height / 2, s.width, s.height);
}
- (CGRect)maximumValueImageRectForBounds:(CGRect)b {
    UIImage *i = _maximumValueImage; if (!i) return CGRectZero;
    CGSize s = i.size; BOOL rtl = [self _isim_isRTL];
    return CGRectMake(rtl ? b.origin.x : CGRectGetMaxX(b) - s.width, CGRectGetMidY(b) - s.height / 2, s.width, s.height);
}
- (CGRect)trackRectForBounds:(CGRect)b {
    CGFloat lead = _minimumValueImage ? _minimumValueImage.size.width + 8 : 0, trail = _maximumValueImage ? _maximumValueImage.size.width + 8 : 0;
    if ([self _isim_isRTL]) { CGFloat t = lead; lead = trail; trail = t; }
    CGFloat th = [self _thumbless] ? 10 : [self _glassLook] ? 6 : 4;
    return CGRectMake(b.origin.x + lead + 2, CGRectGetMidY(b) - th / 2, fmax(0, b.size.width - lead - trail - 4), th);
}
- (double)_fractionOf:(float)v { return _maximumValue > _minimumValue ? (v - _minimumValue) / (_maximumValue - _minimumValue) : 0; }
- (double)_fraction { return [self _fractionOf:_value]; }
- (CGRect)thumbRectForBounds:(CGRect)b trackRect:(CGRect)r value:(float)v {
    CGSize s = [self _thumbSize];
    double f = [self _fractionOf:v]; if ([self _isim_isRTL]) f = 1 - f;
    CGFloat inset = s.width / 2 - 2, cx = r.origin.x + inset + f * fmax(0, r.size.width - 2 * inset);
    return CGRectMake(cx - s.width / 2, CGRectGetMidY(r) - s.height / 2, s.width, s.height);
}
- (CGRect)_track { return [self trackRectForBounds:self.bounds]; }
- (double)_thumbX { CGRect t = [self thumbRectForBounds:self.bounds trackRect:[self _track] value:_value]; return CGRectGetMidX(t); }
/* the value under x: the track's thumb travel mapped to the range, clamped to the enabled range, snapped to ticks */
- (float)_valueAtX:(double)x {
    CGRect r = [self _track]; CGFloat inset = [self _thumbSize].width / 2 - 2;
    double f = fmin(1, fmax(0, (x - r.origin.x - fmax(0, inset)) / fmax(1, r.size.width - 2 * fmax(0, inset))));
    if ([self _isim_isRTL]) f = 1 - f;
    UISliderTrackConfiguration *c = _trackConfiguration;
    if (c) {
        f = fmin(fmax(f, c.minimumEnabledValue), c.maximumEnabledValue);
        if (c.allowsTickValuesOnly && c.ticks.count) {
            double best = c.ticks[0].position;
            for (UISliderTick *t in c.ticks)
                if (t.position >= c.minimumEnabledValue && t.position <= c.maximumEnabledValue && fabs(t.position - f) < fabs(best - f)) best = t.position;
            f = best;
        }
    }
    return _minimumValue + (float)f * (_maximumValue - _minimumValue);
}
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    CGPoint p = [t locationInView:self];
    double tx = [self _thumbX];
    if ([self _thumbless]) _grab = 0;                                    /* thumbless: the finger drags the value anywhere */
    else if (fabs(p.x - tx) > fmax(22, [self _thumbSize].width / 2 + 6)) return NO;   /* like iOS: grab the thumb */
    else _grab = p.x - tx;
    _dragging = YES; isim_ui_set_needs_display();
    if ([self _thumbless]) [self continueTrackingWithTouch:t withEvent:e];
    return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    float v = [self _valueAtX:[t locationInView:self].x - _grab];
    if (v != _value) { self.value = v; if (_continuous) [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
    return YES;
}
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    _dragging = NO; isim_ui_set_needs_display();
    if (!_continuous) [self _isim_sendEvents:UIControlEventValueChanged withEvent:e];
}
- (void)cancelTrackingWithEvent:(UIEvent *)e { _dragging = NO; isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    CGRect b = self.bounds, tr = [self _track];
    double alpha = self.enabled ? 1 : 0.45, tx = [self _thumbX], rad = tr.size.height / 2;
    UIColor *minC = _minimumTrackTintColor ?: tint_of(self), *maxC = _maximumTrackTintColor ?: UIColor.tertiarySystemFillColor;
    BOOL rtl = [self _isim_isRTL];
    if (_minimumValueImage) [_minimumValueImage _isim_drawInRect:[self minimumValueImageRectForBounds:b] tint:UIColor.secondaryLabelColor alpha:alpha];
    if (_maximumValueImage) [_maximumValueImage _isim_drawInRect:[self maximumValueImageRectForBounds:b] tint:UIColor.secondaryLabelColor alpha:alpha];
    UIImage *minI = self.currentMinimumTrackImage, *maxI = self.currentMaximumTrackImage;
    CGRect lead = CGRectMake(tr.origin.x, tr.origin.y, fmax(0, tx - tr.origin.x), tr.size.height);
    CGRect trail = CGRectMake(tx, tr.origin.y, fmax(0, CGRectGetMaxX(tr) - tx), tr.size.height);
    CGRect minR = rtl ? trail : lead, maxR = rtl ? lead : trail;
    if (maxI) [maxI _isim_drawInRect:maxR tint:nil alpha:alpha];
    else fill(maxC, tr.origin.x, tr.origin.y, tr.size.width, tr.size.height, rad, alpha);
    UISliderTrackConfiguration *c = _trackConfiguration;
    if (c && (c.minimumEnabledValue > 0 || c.maximumEnabledValue < 1)) {   /* outside the enabled range: dimmer */
        double x0 = tr.origin.x + tr.size.width * c.minimumEnabledValue, x1 = tr.origin.x + tr.size.width * c.maximumEnabledValue;
        if (rtl) { double a0 = CGRectGetMaxX(tr) - (x1 - tr.origin.x), a1 = CGRectGetMaxX(tr) - (x0 - tr.origin.x); x0 = a0; x1 = a1; }
        UIColor *bg = UIColor.systemBackgroundColor;
        if (x0 > tr.origin.x) fill(bg, tr.origin.x, tr.origin.y, x0 - tr.origin.x, tr.size.height, rad, 0.55 * alpha);
        if (x1 < CGRectGetMaxX(tr)) fill(bg, x1, tr.origin.y, CGRectGetMaxX(tr) - x1, tr.size.height, rad, 0.55 * alpha);
    }
    if (minI) [minI _isim_drawInRect:minR tint:nil alpha:alpha];
    else if (c && c.neutralValue > 0) {                                  /* the fill runs from the neutral value to the value */
        double nf = c.neutralValue; if (rtl) nf = 1 - nf;
        double nx = tr.origin.x + nf * tr.size.width, x0 = fmin(nx, tx), x1 = fmax(nx, tx);
        fill(minC, x0, tr.origin.y, x1 - x0, tr.size.height, rad, alpha);
    } else fill(minC, minR.origin.x, tr.origin.y, minR.size.width + (rtl ? 0 : rad), tr.size.height, rad, alpha);
    if (c.ticks.count && !minI && !maxI) {                             /* stepped slider: tick dots on the track */
        double dot = fmin(4, tr.size.height - 2);
        for (UISliderTick *t in c.ticks) {
            double f = rtl ? 1 - t.position : t.position, inset = fmax(rad, [self _thumbSize].width / 2 - 2);
            double x = tr.origin.x + inset + f * fmax(0, tr.size.width - 2 * inset);
            double rgba[4]; isim_ui_rgba(UIColor.systemBackgroundColor, rgba); rgba[3] *= 0.75 * alpha;
            isim_gfx_fill_ellipse(x - dot / 2, CGRectGetMidY(tr) - dot / 2, dot, dot, rgba);
        }
    }
    if ([self _thumbless]) return;
    UIImage *thumb = self.currentThumbImage;
    CGRect th = [self thumbRectForBounds:b trackRect:tr value:_value];
    if (thumb) { [thumb _isim_drawInRect:th tint:nil alpha:alpha]; return; }
    if ([self _glassLook]) {
        if (_dragging) {                                                 /* clear glass, grown, while dragged */
            CGRect g = CGRectInset(th, -th.size.width * 0.22, -th.size.height * 0.22);
            isim_ui_draw_glass(g, g.size.height / 2, _thumbTintColor, 2);
            return;
        }
        double shadow[4] = { 0, 0, 0, 0.14 * alpha };
        isim_gfx_fill_rounded(th.origin.x, th.origin.y + 1.5, th.size.width, th.size.height, th.size.height / 2, shadow);
        double ring[4] = { 0, 0, 0, 0.05 }; isim_gfx_fill_rounded(th.origin.x - 0.5, th.origin.y - 0.5, th.size.width + 1, th.size.height + 1, th.size.height / 2 + 0.5, ring);
        double tc[4]; isim_ui_rgba(_thumbTintColor ?: UIColor.whiteColor, tc);
        isim_gfx_fill_rounded(th.origin.x, th.origin.y, th.size.width, th.size.height, th.size.height / 2, tc);
        return;
    }
    double cx = CGRectGetMidX(th), cy = CGRectGetMidY(th);
    double shadow[4] = { 0, 0, 0, 0.12 * alpha };
    isim_gfx_fill_ellipse(cx - 14.5, cy - 13.5, 29, 29, shadow);
    double ring[4] = { 0, 0, 0, 0.06 }; isim_gfx_fill_ellipse(cx - 14.5, cy - 14.5, 29, 29, ring);
    double tc[4]; isim_ui_rgba(_thumbTintColor ?: UIColor.whiteColor, tc);
    isim_gfx_fill_ellipse(cx - 14, cy - 14, 28, 28, tc);
}
@end

/* ================= UIStepper ================= */
@implementation UIStepper { int _pressed; }   /* -1 minus, 1 plus */
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, 94, 32)])) { _maximumValue = 100; _stepValue = 1; _continuous = YES; _autorepeat = YES; }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(94, 32); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(94, 32); }
- (void)setValue:(double)v { _value = fmax(_minimumValue, fmin(_maximumValue, v)); isim_ui_set_needs_display(); }
- (void)setMinimumValue:(double)v { _minimumValue = v; self.value = _value; }
- (void)setMaximumValue:(double)v { _maximumValue = v; self.value = _value; }
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { _pressed = [t locationInView:self].x < 47 ? -1 : 1; isim_ui_set_needs_display(); return YES; }
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    int side = _pressed; _pressed = 0; isim_ui_set_needs_display();
    if (!CGRectContainsPoint(CGRectInset(self.bounds, -20, -20), [t locationInView:self])) return;
    double v = _value + side * _stepValue;
    if (_wraps) { if (v > _maximumValue) v = _minimumValue; else if (v < _minimumValue) v = _maximumValue; }
    v = fmax(_minimumValue, fmin(_maximumValue, v));
    if (v != _value) { self.value = v; [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
}
- (void)cancelTrackingWithEvent:(UIEvent *)e { _pressed = 0; isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    double r = isim_ui_glass() ? 16 : 8;                                /* iOS 26: a capsule */
    fill(UIColor.tertiarySystemFillColor, 0, 0, 94, 32, r, 1);
    if (_pressed) fill(UIColor.tertiarySystemFillColor, _pressed < 0 ? 0 : 47, 0, 47, 32, r, 1);
    fill(UIColor.separatorColor, 46.5, 8, 1, 16, 0, 1);
    BOOL canDec = self.enabled && (_wraps || _value > _minimumValue), canInc = self.enabled && (_wraps || _value < _maximumValue);
    UIColor *c = UIColor.labelColor;
    fill(c, 23.5 - 7, 15.25, 14, 1.5, 0.75, canDec ? 1 : 0.3);                       /* − */
    fill(c, 70.5 - 7, 15.25, 14, 1.5, 0.75, canInc ? 1 : 0.3);                       /* + */
    fill(c, 70.5 - 0.75, 9, 1.5, 14, 0.75, canInc ? 1 : 0.3);
}
@end

/* ================= UISegmentedControl ================= */
const NSInteger UISegmentedControlNoSegment = -1;
@implementation UISegmentedControl { NSMutableArray *_items; NSMutableSet<NSNumber *> *_disabled; UIView *_thumb; NSInteger _pressedIndex; NSMutableDictionary<NSNumber *, NSNumber *> *_widths;
    NSMutableDictionary<NSNumber *, NSDictionary *> *_titleAttrs; }
- (void)setTitleTextAttributes:(NSDictionary *)a forState:(UIControlState)s {
    if (!_titleAttrs) _titleAttrs = [NSMutableDictionary dictionary];
    if (a) _titleAttrs[@(s)] = [a copy]; else [_titleAttrs removeObjectForKey:@(s)];
    [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
- (NSDictionary *)titleTextAttributesForState:(UIControlState)s { return _titleAttrs[@(s)]; }
- (NSDictionary *)_attrs:(UIControlState)s { return _titleAttrs[@(s)] ?: _titleAttrs[@(UIControlStateNormal)]; }
- (instancetype)initWithItems:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectZero])) {
        _items = [NSMutableArray arrayWithArray:items ?: @[]]; _disabled = [NSMutableSet set]; _widths = [NSMutableDictionary dictionary];
        _selectedSegmentIndex = UISegmentedControlNoSegment; _pressedIndex = -1;
        _thumb = [[UIView alloc] initWithFrame:CGRectZero];
        _thumb.layer.cornerRadius = 7; _thumb.userInteractionEnabled = NO;   /* iOS 26: capsule (_placeThumb) */
        _thumb.layer.shadowColor = UIColor.blackColor.CGColor; _thumb.layer.shadowOpacity = 0.12; _thumb.layer.shadowRadius = 4; _thumb.layer.shadowOffset = CGSizeMake(0, 2);
        _thumb.hidden = YES;
        [self addSubview:_thumb];
        CGSize s = [self sizeThatFits:CGSizeZero]; self.frame = CGRectMake(0, 0, s.width, s.height);
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { if ((self = [self initWithItems:nil])) self.frame = f; return self; }
- (UIFont *)_font:(BOOL)sel {
    UIFont *f = [self _attrs:sel ? UIControlStateSelected : UIControlStateNormal][NSFontAttributeName];
    return [f isKindOfClass:[UIFont class]] ? f : [UIFont systemFontOfSize:13 weight:sel ? UIFontWeightSemibold : UIFontWeightMedium];
}
- (CGSize)_contentSize:(NSUInteger)i {
    id it = _items[i];
    if ([it isKindOfClass:[UIImage class]]) return ((UIImage *)it).size;
    return isim_ui_measure([it description], [self _font:YES], 1000, 1);
}
- (CGSize)intrinsicContentSize {
    CGFloat w = 0; for (NSUInteger i = 0; i < _items.count; i++) w = fmax(w, [self _contentSize:i].width + 24);
    return CGSizeMake(fmax(1, w * _items.count), 32);
}
- (CGSize)sizeThatFits:(CGSize)s { return [self intrinsicContentSize]; }
- (NSUInteger)numberOfSegments { return _items.count; }
- (CGRect)_segmentRect:(NSUInteger)i {
    CGFloat W = self.bounds.size.width, n = fmax(1, _items.count), x = 0;
    if (_apportionsSegmentWidthsByContent || _widths.count) {
        CGFloat total = 0, ws[_items.count];
        for (NSUInteger k = 0; k < _items.count; k++) { NSNumber *fw = _widths[@(k)]; ws[k] = fw.doubleValue > 0 ? fw.doubleValue : [self _contentSize:k].width + 24; total += ws[k]; }
        CGFloat scale = total > 0 ? W / total : 1;
        for (NSUInteger k = 0; k < i; k++) x += ws[k] * scale;
        return CGRectMake(x, 0, ws[i] * scale, self.bounds.size.height);
    }
    return CGRectMake(i * W / n, 0, W / n, self.bounds.size.height);
}
- (void)_placeThumb {
    BOOL show = _selectedSegmentIndex >= 0 && (NSUInteger)_selectedSegmentIndex < _items.count && !_momentary;
    _thumb.hidden = !show;
    if (!show) return;
    _thumb.backgroundColor = _selectedSegmentTintColor ?: [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.39 alpha:1] : UIColor.whiteColor; }];
    _thumb.frame = CGRectInset([self _segmentRect:(NSUInteger)_selectedSegmentIndex], 2, 2);
    _thumb.layer.cornerRadius = isim_ui_glass() ? (_thumb.frame.size.height) / 2 : 7;
}
- (void)layoutSubviews { [super layoutSubviews]; [UIView performWithoutAnimation:^{ [self _placeThumb]; }]; }
- (void)setSelectedSegmentIndex:(NSInteger)i {
    BOOL hadThumb = !_thumb.hidden;
    _selectedSegmentIndex = i < (NSInteger)_items.count ? i : UISegmentedControlNoSegment;
    if (hadThumb && self.window) [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{ [self _placeThumb]; } completion:nil];
    else [UIView performWithoutAnimation:^{ [self _placeThumb]; }];
    isim_ui_set_needs_display();
}
- (void)setSelectedSegmentTintColor:(UIColor *)c { _selectedSegmentTintColor = c; [self _placeThumb]; }
- (void)insertSegmentWithTitle:(NSString *)t atIndex:(NSUInteger)i animated:(BOOL)a { [_items insertObject:t ?: @"" atIndex:MIN(i, _items.count)]; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)insertSegmentWithImage:(UIImage *)img atIndex:(NSUInteger)i animated:(BOOL)a { if (img) [_items insertObject:img atIndex:MIN(i, _items.count)]; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)removeSegmentAtIndex:(NSUInteger)i animated:(BOOL)a {
    if (i >= _items.count) return;
    [_items removeObjectAtIndex:i];
    if (_selectedSegmentIndex == (NSInteger)i) _selectedSegmentIndex = UISegmentedControlNoSegment;
    else if (_selectedSegmentIndex > (NSInteger)i) _selectedSegmentIndex--;
    [self invalidateIntrinsicContentSize]; [self setNeedsLayout];
}
- (void)removeAllSegments { [_items removeAllObjects]; _selectedSegmentIndex = UISegmentedControlNoSegment; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)setTitle:(NSString *)t forSegmentAtIndex:(NSUInteger)i { if (i < _items.count) { _items[i] = t ?: @""; isim_ui_set_needs_display(); } }
- (NSString *)titleForSegmentAtIndex:(NSUInteger)i { return i < _items.count && [_items[i] isKindOfClass:[NSString class]] ? _items[i] : nil; }
- (void)setImage:(UIImage *)img forSegmentAtIndex:(NSUInteger)i { if (i < _items.count && img) { _items[i] = img; isim_ui_set_needs_display(); } }
- (UIImage *)imageForSegmentAtIndex:(NSUInteger)i { return i < _items.count && [_items[i] isKindOfClass:[UIImage class]] ? _items[i] : nil; }
- (void)setEnabled:(BOOL)e forSegmentAtIndex:(NSUInteger)i { if (e) [_disabled removeObject:@(i)]; else [_disabled addObject:@(i)]; isim_ui_set_needs_display(); }
- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)i { return ![_disabled containsObject:@(i)]; }
- (void)setWidth:(CGFloat)w forSegmentAtIndex:(NSUInteger)i { _widths[@(i)] = @(w); [self setNeedsLayout]; }
- (NSInteger)_indexAt:(CGPoint)p { for (NSUInteger i = 0; i < _items.count; i++) if (p.x < CGRectGetMaxX([self _segmentRect:i])) return (NSInteger)i; return (NSInteger)_items.count - 1; }
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    _pressedIndex = [self _indexAt:[t locationInView:self]];
    if (isim_ui_glass() && _pressedIndex == _selectedSegmentIndex && !_momentary) _thumb.alpha = 0;   /* the selection turns to glass while held */
    isim_ui_set_needs_display(); return YES;
}
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    NSInteger i = [self _indexAt:[t locationInView:self]];
    _pressedIndex = -1; _thumb.alpha = 1; isim_ui_set_needs_display();
    if (i < 0 || ![self isEnabledForSegmentAtIndex:(NSUInteger)i] || !CGRectContainsPoint(CGRectInset(self.bounds, -20, -20), [t locationInView:self])) return;
    if (_momentary) { [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; return; }
    if (i != _selectedSegmentIndex) { self.selectedSegmentIndex = i; [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
}
- (void)cancelTrackingWithEvent:(UIEvent *)e { _pressedIndex = -1; _thumb.alpha = 1; isim_ui_set_needs_display(); }
- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    if (_thumb.alpha == 0) {                       /* iOS 26: dragging the held glass selection moves it */
        NSInteger i = [self _indexAt:[t locationInView:self]];
        if (i >= 0 && i != _selectedSegmentIndex && [self isEnabledForSegmentAtIndex:(NSUInteger)i]) {
            _pressedIndex = i; self.selectedSegmentIndex = i; [self _isim_sendEvents:UIControlEventValueChanged withEvent:e];
        }
    }
    return YES;
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    BOOL glass = isim_ui_glass();
    fill(UIColor.tertiarySystemFillColor, 0, 0, s.width, s.height, glass ? s.height / 2 : 9, 1);
    if (glass) {                                   /* iOS 26: no separators; a held selection is glass, a little larger */
        if (_thumb.alpha == 0 && !_thumb.hidden) {
            CGRect r = [_thumb _isim_presentedFrame:NULL radius:NULL];
            r = CGRectInset(r, -4, -4);
            isim_ui_draw_glass(r, r.size.height / 2, nil, 2);
        }
        return;
    }
    for (NSUInteger i = 0; i + 1 < _items.count; i++) {
        BOOL nearSel = (NSInteger)i == _selectedSegmentIndex || (NSInteger)i + 1 == _selectedSegmentIndex;
        if (!nearSel || _momentary) fill(UIColor.separatorColor, CGRectGetMaxX([self _segmentRect:i]) - 0.5, 8, 1, s.height - 16, 0, 1);
    }
}
- (void)_isim_drawOverlay {           /* titles draw above the sliding selection */
    for (NSUInteger i = 0; i < _items.count; i++) {
        CGRect r = [self _segmentRect:i];
        BOOL sel = (NSInteger)i == _selectedSegmentIndex && !_momentary;
        double a = (!self.enabled || ![self isEnabledForSegmentAtIndex:i]) ? 0.3 : (_pressedIndex == (NSInteger)i && !sel ? 0.5 : 1);
        id it = _items[i];
        if ([it isKindOfClass:[UIImage class]]) {
            UIImage *img = it; CGSize is = img.size;
            [img _isim_drawInRect:CGRectMake(CGRectGetMidX(r) - is.width / 2, CGRectGetMidY(r) - is.height / 2, is.width, is.height) tint:UIColor.labelColor alpha:a];
        } else {
            UIFont *f = [self _font:sel];
            UIColor *c = [self _attrs:sel ? UIControlStateSelected : (![self isEnabledForSegmentAtIndex:i] || !self.enabled) ? UIControlStateDisabled : UIControlStateNormal][NSForegroundColorAttributeName];
            if (![c isKindOfClass:[UIColor class]]) c = UIColor.labelColor;
            CGSize ts = isim_ui_measure([it description], f, r.size.width - 8, 1);
            isim_ui_draw_text([it description], f, c, CGRectMake(r.origin.x + 4, CGRectGetMidY(r) - ts.height / 2, r.size.width - 8, ts.height), NSTextAlignmentCenter, 1, a);
        }
    }
}
@end

/* ================= UIProgressView ================= */
@implementation UIProgressView
- (instancetype)initWithFrame:(CGRect)f { return [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, f.size.width, 4)]; }
- (instancetype)initWithProgressViewStyle:(UIProgressViewStyle)st { if ((self = [self initWithFrame:CGRectZero])) _progressViewStyle = st; return self; }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 4); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 ? s.width : 150, 4); }
- (void)setProgress:(float)p { _progress = fmaxf(0, fminf(1, p)); isim_ui_set_needs_display(); }
- (void)setProgress:(float)p animated:(BOOL)a { self.progress = p; }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; double r = _progressViewStyle == UIProgressViewStyleBar ? 0 : s.height / 2;
    fill(_trackTintColor ?: (_progressViewStyle == UIProgressViewStyleBar ? UIColor.clearColor : UIColor.tertiarySystemFillColor), 0, 0, s.width, s.height, r, 1);
    if (_progress > 0) fill(_progressTintColor ?: tint_of(self), 0, 0, s.width * _progress, s.height, r, 1);
}
@end

/* ================= CADisplayLink ================= */
static NSMutableArray<CADisplayLink *> *display_links;
@implementation CADisplayLink { __weak id _target; SEL _sel; BOOL _added; }
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel { CADisplayLink *l = [self new]; l->_target = target; l->_sel = sel; return l; }
- (void)addToRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode {
    if (_added) return;
    _added = YES;
    if (!display_links) display_links = [NSMutableArray array];
    [display_links addObject:self];
    isim_ui_set_needs_display();
}
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode { [self invalidate]; }
- (void)invalidate { _added = NO; [display_links removeObjectIdenticalTo:self]; }
- (double)duration { return 1.0 / 60; }
- (double)targetTimestamp { return _timestamp + 1.0 / 60; }
- (void)_isim_fire:(double)now {
    id t = _target;
    if (!t) { [self invalidate]; return; }
    _timestamp = now;
    ((void (*)(id, SEL, id))[t methodForSelector:_sel])(t, _sel, self);
}
@end
/* called by the run loop once per frame; YES while any display link is active */
BOOL isim_ui_display_links_fire(void) {
    if (!display_links.count) return NO;
    double now = isim_time();
    BOOL any = NO;
    for (CADisplayLink *l in [display_links copy]) if (!l.paused) { [l _isim_fire:now]; any = YES; }
    return any;
}
BOOL isim_ui_display_links_active(void) { for (CADisplayLink *l in display_links) if (!l.paused) return YES; return NO; }

/* ================= UIActivityIndicatorView ================= */
@implementation UIActivityIndicatorView { CADisplayLink *_link; }
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)st {
    BOOL large = st == UIActivityIndicatorViewStyleLarge || st == UIActivityIndicatorViewStyleWhiteLarge;
    if ((self = [super initWithFrame:CGRectMake(0, 0, large ? 37 : 20, large ? 37 : 20)])) { _activityIndicatorViewStyle = st; _hidesWhenStopped = YES; self.hidden = YES; self.userInteractionEnabled = NO; }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { if ((self = [self initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium])) self.frame = f; return self; }
- (BOOL)_large { return _activityIndicatorViewStyle == UIActivityIndicatorViewStyleLarge || _activityIndicatorViewStyle == UIActivityIndicatorViewStyleWhiteLarge; }
- (CGSize)intrinsicContentSize { return [self _large] ? CGSizeMake(37, 37) : CGSizeMake(20, 20); }
- (CGSize)sizeThatFits:(CGSize)s { return [self intrinsicContentSize]; }
- (UIColor *)color {
    if (_color) return _color;
    if (_activityIndicatorViewStyle == UIActivityIndicatorViewStyleWhite || _activityIndicatorViewStyle == UIActivityIndicatorViewStyleWhiteLarge) return UIColor.whiteColor;
    return UIColor.secondaryLabelColor;
}
- (void)setHidesWhenStopped:(BOOL)h { _hidesWhenStopped = h; if (!_animating) self.hidden = h; }
- (void)startAnimating {
    if (_animating) return;
    _animating = YES; self.hidden = NO;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(_isim_tick:)];
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)stopAnimating { _animating = NO; [_link invalidate]; _link = nil; if (_hidesWhenStopped) self.hidden = YES; isim_ui_set_needs_display(); }
- (void)_isim_tick:(CADisplayLink *)l { if (self.window) isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; double cx = s.width / 2, cy = s.height / 2, R = fmin(s.width, s.height) / 2;
    int n = 8; double t = _animating ? isim_time() : 0;
    int lead = (int)floor(t * 8) % n;
    double rgba[4]; isim_ui_rgba(self.color, rgba);
    double len = R * 0.42, wid = fmax(2, R * 0.2);
    for (int i = 0; i < n; i++) {
        double ang = (double)i / n * 2 * M_PI - M_PI / 2;
        int age = (lead - i + n) % n;
        double c[4] = { rgba[0], rgba[1], rgba[2], rgba[3] * (1 - age * 0.1) };
        isim_gfx_save();
        isim_gfx_translate(cx, cy); isim_gfx_rotate(ang + M_PI / 2);
        isim_gfx_fill_rounded(-wid / 2, -R, wid, len, wid / 2, c);
        isim_gfx_restore();
    }
}
@end

/* ================= UIPageControl ================= */
@implementation UIPageControl
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) {} return self; }
- (CGSize)sizeForNumberOfPages:(NSInteger)n { return CGSizeMake(n > 0 ? n * 16 + 16 : 0, 26); }
- (CGSize)intrinsicContentSize { return [self sizeForNumberOfPages:_numberOfPages]; }
- (CGSize)sizeThatFits:(CGSize)s { return [self intrinsicContentSize]; }
- (void)setNumberOfPages:(NSInteger)n { _numberOfPages = MAX(0, n); if (_currentPage >= _numberOfPages) _currentPage = MAX(0, _numberOfPages - 1); [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setCurrentPage:(NSInteger)p { _currentPage = MAX(0, MIN(p, _numberOfPages - 1)); isim_ui_set_needs_display(); }
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    BOOL right = [t locationInView:self].x > self.bounds.size.width / 2;
    NSInteger p = _currentPage + (right ? 1 : -1);
    if (p >= 0 && p < _numberOfPages) { self.currentPage = p; [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
}
- (void)_isim_drawContent {
    if (_numberOfPages <= 0 || (_hidesForSinglePage && _numberOfPages == 1)) return;
    CGSize s = self.bounds.size; double total = _numberOfPages * 16 - 9, x = (s.width - total) / 2, y = s.height / 2 - 3.5;
    for (NSInteger i = 0; i < _numberOfPages; i++) {
        UIColor *c = i == _currentPage ? (_currentPageIndicatorTintColor ?: UIColor.labelColor) : (_pageIndicatorTintColor ?: UIColor.tertiaryLabelColor);
        double rgba[4]; isim_ui_rgba(c, rgba);
        isim_gfx_fill_ellipse(x + i * 16, y, 7, 7, rgba);
    }
}
@end

/* ================= UIMenu & pop-up menus ================= */
@implementation UIMenu { NSArray *_children; UIMenuOptions _options; }
+ (UIMenu *)menuWithChildren:(NSArray *)c { return [self menuWithTitle:@"" image:nil identifier:nil options:0 children:c]; }
+ (UIMenu *)menuWithTitle:(NSString *)t children:(NSArray *)c { return [self menuWithTitle:t image:nil identifier:nil options:0 children:c]; }
+ (UIMenu *)menuWithTitle:(NSString *)t image:(UIImage *)img identifier:(NSString *)ident options:(UIMenuOptions)o children:(NSArray *)c {
    UIMenu *m = [self new]; m.title = t ?: @""; m.image = img; m->_children = [c copy] ?: @[]; m->_options = o; return m;
}
- (NSArray *)children { return _children; }
- (UIMenuOptions)options { return _options; }
@end

@interface __IsimMenuRow : UIControl
@property (nonatomic, strong) UIMenuElement *element;
@property (nonatomic) BOOL showsCheckColumn, last;
@end
@implementation __IsimMenuRow
/* iOS 27 highlightStateUpdateHandler: told when the row is highlighted (touch, keyboard) and unhighlighted */
- (void)setHighlighted:(BOOL)h {
    BOOL was = self.highlighted;
    [super setHighlighted:h];
    if (was != h) { void (^u)(UIMenuElement *, BOOL) = self.element.highlightStateUpdateHandler; if (u) u(self.element, h); isim_ui_set_needs_display(); }
}
- (BOOL)_isim_showsImage {
    UIMenuElement *e = self.element;
    if ([e isKindOfClass:[UIMenu class]]) return YES;              /* the submenu chevron */
    return e.image && e.preferredImageVisibility != UIMenuElementImageVisibilityHidden;
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    if (self.highlighted) fill(UIColor.tertiarySystemFillColor, 0, 0, s.width, s.height, 0, 1);
    UIAction *a = [self.element isKindOfClass:[UIAction class]] ? (UIAction *)self.element : nil;
    BOOL destructive = a && (a.attributes & UIMenuElementAttributesDestructive), disabled = a && (a.attributes & UIMenuElementAttributesDisabled);
    UIColor *c = destructive ? UIColor.systemRedColor : UIColor.labelColor;
    double alpha = disabled ? 0.35 : 1, x = self.showsCheckColumn ? 40 : 16;
    if (a.state == UIMenuElementStateOn) {
        UIImage *check = [UIImage systemImageNamed:@"checkmark"];
        [check _isim_drawInRect:CGRectMake(14, s.height / 2 - 7, 15, 14) tint:c alpha:alpha];
    }
    UIFont *f = [UIFont systemFontOfSize:17];
    BOOL showsImage = [self _isim_showsImage];
    CGFloat tw = s.width - x - (showsImage ? 48 : 16);
    CGSize ts = isim_ui_measure(self.element.title, f, tw, 1);
    NSString *sub = self.element.subtitle;
    if (sub.length) {                       /* a title over a 15 pt secondary subtitle */
        UIFont *sf = [UIFont systemFontOfSize:15];
        CGSize ss = isim_ui_measure(sub, sf, tw, 1);
        CGFloat top = (s.height - ts.height - 2 - ss.height) / 2;
        isim_ui_draw_text(self.element.title, f, c, CGRectMake(x, top, tw, ts.height), NSTextAlignmentLeft, 1, alpha);
        isim_ui_draw_text(sub, sf, UIColor.secondaryLabelColor, CGRectMake(x, top + ts.height + 2, tw, ss.height), NSTextAlignmentLeft, 1, alpha);
    } else isim_ui_draw_text(self.element.title, f, c, CGRectMake(x, s.height / 2 - ts.height / 2, tw, ts.height), NSTextAlignmentLeft, 1, alpha);
    UIImage *img = !showsImage ? nil : [self.element isKindOfClass:[UIMenu class]] ? [UIImage systemImageNamed:@"chevron.right"] : self.element.image;
    if (img) {
        CGSize is = img.size; double k = fmin(1, 20 / fmax(is.width, is.height)); is.width *= k; is.height *= k;
        [img _isim_drawInRect:CGRectMake(s.width - 16 - is.width, s.height / 2 - is.height / 2, is.width, is.height) tint:c alpha:alpha];
    }
    if (!self.last && !isim_ui_glass()) fill(UIColor.separatorColor, 0, s.height - 0.5, s.width, 0.5, 0, 1);   /* iOS 26 menus: no row separators */
}
@end

@interface __IsimMenuOverlay : UIView
@property (nonatomic, strong) UIVisualEffectView *card;
@property (nonatomic, weak) UIView *source;
@property (nonatomic) CGRect previewRect;                 /* context menus: the lifted preview (a tap commits it) */
@property (nonatomic, copy) void (^onPreviewTap)(void), (^onDismiss)(void);
@property (nonatomic) BOOL typeSelect;                   /* hardware keyboard type select (UIContextMenuConfiguration.allowsTypeSelect) */
@property (nonatomic, copy) NSString *typed; @property (nonatomic) double typedAt;
@end
@implementation __IsimMenuOverlay
static __weak __IsimMenuOverlay *current_menu;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {   /* tap outside (or on a context menu's preview) */
    CGPoint p = [touches.anyObject locationInView:self];
    if (self.onPreviewTap && CGRectContainsPoint(self.previewRect, p)) { void (^t)(void) = self.onPreviewTap; self.onPreviewTap = nil; self.onDismiss = nil; [self dismiss]; t(); return; }
    [self dismiss];
}
- (void)dismiss {
    void (^d)(void) = self.onDismiss; self.onDismiss = nil; self.onPreviewTap = nil;
    if (d) d();
    UIView *card = self.card;
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{ card.alpha = 0; card.transform = CGAffineTransformMakeScale(0.9, 0.9); }
                     completion:^(BOOL f) { [self removeFromSuperview]; }];
    self.userInteractionEnabled = NO;
}
/* flattens inline submenus into sections: [[elements], ...] */
static void collect(UIMenu *m, NSMutableArray<NSMutableArray *> *sections) {
    NSMutableArray *cur = sections.lastObject;
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIAction class]] && (((UIAction *)e).attributes & UIMenuElementAttributesHidden)) continue;
        if ([e isKindOfClass:[UIMenu class]] && (((UIMenu *)e).options & UIMenuOptionsDisplayInline)) {
            if (cur.count) [sections addObject:[NSMutableArray array]];
            collect((UIMenu *)e, sections);
            [sections addObject:[NSMutableArray array]];
            cur = sections.lastObject;
        } else { [cur addObject:e]; }
    }
}
- (void)showMenu:(UIMenu *)menu anchor:(CGRect)anchor {
    for (UIView *v in [self.card.contentView.subviews copy]) [v removeFromSuperview];
    NSMutableArray<NSMutableArray *> *sections = [NSMutableArray arrayWithObject:[NSMutableArray array]];
    collect(menu, sections);
    for (NSInteger k = (NSInteger)sections.count - 1; k >= 0; k--) if (!sections[(NSUInteger)k].count) [sections removeObjectAtIndex:(NSUInteger)k];
    BOOL checks = NO;
    for (NSArray *s in sections) for (UIMenuElement *e in s) if ([e isKindOfClass:[UIAction class]] && ((UIAction *)e).state != UIMenuElementStateOff) checks = YES;
    CGFloat W = 250, y = 0;
    if (menu.title.length) {
        UILabel *t = [UILabel new]; t.text = menu.title; t.font = [UIFont systemFontOfSize:13]; t.textColor = UIColor.secondaryLabelColor;
        t.textAlignment = NSTextAlignmentCenter; t.frame = CGRectMake(16, 8, W - 32, 22);
        [self.card.contentView addSubview:t]; y = 36;
        UIView *sep = [UIView new]; sep.backgroundColor = UIColor.separatorColor; sep.frame = CGRectMake(0, y - 0.5, W, 0.5); [self.card.contentView addSubview:sep];
    }
    for (NSUInteger si = 0; si < sections.count; si++) {
        if (si > 0) { UIView *gap = [UIView new]; gap.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08]; gap.frame = CGRectMake(0, y, W, 8); [self.card.contentView addSubview:gap]; y += 8; }
        NSArray *s = sections[si];
        for (NSUInteger i = 0; i < s.count; i++) {
            CGFloat rh = ((UIMenuElement *)s[i]).subtitle.length ? 58 : 44;
            __IsimMenuRow *row = [[__IsimMenuRow alloc] initWithFrame:CGRectMake(0, y, W, rh)];
            row.element = s[i]; row.showsCheckColumn = checks; row.last = i + 1 == s.count;
            row.accessibilityIdentifier = [@"menu-" stringByAppendingString:row.element.title];
            [row addTarget:self action:@selector(_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self.card.contentView addSubview:row];
            y += rh;
        }
    }
    CGRect b = self.bounds; const struct isim_device *d = isim_ui_device();
    CGFloat x = fmin(fmax(16, anchor.origin.x), b.size.width - W - 16);
    CGFloat top = CGRectGetMaxY(anchor) + 8;
    if (top + y > b.size.height - d->safe_bottom - 8) top = fmax(d->safe_top + 8, anchor.origin.y - 8 - y);
    self.card.frame = CGRectMake(x, top, W, y);
}
/* ---- hardware keyboard: arrows move the highlight, Return chooses, Escape closes, letters type-select ---- */
- (NSArray<__IsimMenuRow *> *)_rows {
    NSMutableArray *a = [NSMutableArray array];
    for (UIView *v in self.card.contentView.subviews) if ([v isKindOfClass:[__IsimMenuRow class]]) [a addObject:v];
    return a;
}
- (void)_highlight:(__IsimMenuRow *)row { for (__IsimMenuRow *r in [self _rows]) r.highlighted = r == row; }
- (BOOL)_key:(int)hid characters:(NSString *)chars {
    NSArray<__IsimMenuRow *> *rows = [self _rows];
    NSUInteger cur = NSNotFound;
    for (NSUInteger i = 0; i < rows.count; i++) if (rows[i].highlighted) cur = i;
    if (hid == 0x51 || hid == 0x52) {                                     /* down / up */
        if (!rows.count) return YES;
        NSUInteger n = cur == NSNotFound ? (hid == 0x51 ? 0 : rows.count - 1) : (hid == 0x51 ? (cur + 1) % rows.count : (cur + rows.count - 1) % rows.count);
        [self _highlight:rows[n]]; return YES;
    }
    if (hid == 0x28 || hid == 0x58) { if (cur != NSNotFound) [self _rowTapped:rows[cur]]; return YES; }   /* return */
    if (hid == 0x29) { [self dismiss]; return YES; }                      /* escape */
    if (!self.typeSelect || chars.length != 1) return NO;                  /* the keys reach the text field */
    double now = isim_time();
    self.typed = now - self.typedAt < 1.0 ? [(self.typed ?: @"") stringByAppendingString:chars] : chars;
    self.typedAt = now;
    for (__IsimMenuRow *r in rows)
        if ([r.element.title.lowercaseString hasPrefix:self.typed.lowercaseString]) { [self _highlight:r]; NSLog(@"isim: menu type select \"%@\" -> %@", self.typed, r.element.title); break; }
    return YES;
}
- (void)_rowTapped:(__IsimMenuRow *)row {
    UIMenuElement *e = row.element;
    if ([e isKindOfClass:[UIMenu class]]) { [self showMenu:(UIMenu *)e anchor:self.card.frame]; return; }
    UIAction *a = (UIAction *)e;
    if (a.attributes & UIMenuElementAttributesDisabled) return;
    [self dismiss];
    [a setSender:self.source];
    UIActionHandler h = a.handler;
    if (h) dispatch_async(dispatch_get_main_queue(), ^{ h(a); });
}
@end

BOOL isim_ui_menu_key(int hid, NSString *characters) {
    __IsimMenuOverlay *o = current_menu;
    if (!o || !o.superview || !o.userInteractionEnabled) return NO;
    return [o _key:hid characters:characters ?: @""];
}
void isim_ui_menu_set_type_select(BOOL allowed) { current_menu.typeSelect = allowed; }
@implementation UIView (IsimMenu)
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect previewRect:(CGRect)previewRect onPreviewTap:(void (^)(void))tap onDismiss:(void (^)(void))dismissed {
    [self _isim_presentMenu:menu fromRect:rect];
    __IsimMenuOverlay *o = current_menu;
    if (!o) { if (dismissed) dismissed(); return; }
    o.previewRect = previewRect; o.onPreviewTap = tap; o.onDismiss = dismissed;
}
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect {
    UIWindow *w = self.window;
    if (!w || !menu) return;
    [current_menu removeFromSuperview];
    __IsimMenuOverlay *o = [[__IsimMenuOverlay alloc] initWithFrame:w.bounds];
    o.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    o.source = self;
    o.typeSelect = YES;
    o.accessibilityIdentifier = @"isim-menu";
    if (isim_ui_glass()) {                    /* iOS 26: glass menu with large corners */
        UIGlassEffect *g = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        g.tintColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [UIColor colorWithWhite:t.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.98 alpha:0.55]; }];
        o.card = [[UIVisualEffectView alloc] initWithEffect:g];
        o.card.layer.cornerRadius = 26; o.card.layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        o.card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
        o.card.layer.cornerRadius = 13; o.card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    o.card.clipsToBounds = YES;
    [o addSubview:o.card];
    [w addSubview:o];
    current_menu = o;
    [o showMenu:menu anchor:[self convertRect:rect toView:w]];
    UIView *card = o.card;
    [UIView performWithoutAnimation:^{ card.alpha = 0; card.transform = CGAffineTransformMakeScale(0.85, 0.85); }];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{ card.alpha = 1; card.transform = CGAffineTransformIdentity; } completion:nil];
}
/* a context menu with a preview (SwiftUI contextMenu(menuItems:preview:)): the preview (sized by the caller) is
   lifted over a dimmed screen near the source and the menu sits under it */
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect preview:(UIView *)preview {
    [self _isim_presentMenu:menu fromRect:rect];
    __IsimMenuOverlay *o = current_menu;
    if (!o || !preview) return;
    o.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    const struct isim_device *d = isim_ui_device();
    CGRect b = o.bounds, anchor = [self convertRect:rect toView:o], card = o.card.frame;
    CGSize ps = preview.bounds.size;
    CGFloat px = fmin(fmax(16, CGRectGetMidX(anchor) - ps.width / 2), b.size.width - 16 - ps.width);
    CGFloat py = fmin(fmax(d->safe_top + 8, anchor.origin.y), b.size.height - d->safe_bottom - 8 - card.size.height - 8 - ps.height);
    preview.frame = CGRectMake(px, fmax(d->safe_top + 8, py), ps.width, ps.height);
    preview.layer.cornerRadius = 13; preview.layer.cornerCurve = kCACornerCurveContinuous; preview.clipsToBounds = YES;
    preview.accessibilityIdentifier = preview.accessibilityIdentifier ?: @"isim-menu-preview";
    [o insertSubview:preview belowSubview:o.card];
    card.origin.y = CGRectGetMaxY(preview.frame) + 8;
    card.origin.x = fmin(fmax(16, CGRectGetMinX(preview.frame)), b.size.width - 16 - card.size.width);
    o.card.frame = card;
}
@end
