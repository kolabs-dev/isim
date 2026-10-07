/* UISlider, UIStepper, UISegmentedControl, UIProgressView, UIActivityIndicatorView, UIPageControl,
 * UIMenu (pop-up menus as UIKit shows for UIButton.menu) and CADisplayLink — drawn with iOS 17 metrics. */
#import "UIKitPrivate.h"
#include <math.h>

static UIColor *tint_of(UIView *v) { return v.tintColor ?: UIColor.systemBlueColor; }
static void fill(UIColor *c, double x, double y, double w, double h, double r, double alpha) {
    double rgba[4]; isim_ui_rgba(c, rgba); rgba[3] *= alpha; isim_gfx_fill_rounded(x, y, w, h, r, rgba);
}

/* ================= UISlider ================= */
@implementation UISlider { BOOL _dragging; double _grab; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, f.size.width, f.size.height ?: 31)])) { _maximumValue = 1; _continuous = YES; }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 31); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 ? s.width : 118, 31); }
- (void)setValue:(float)v { _value = fmaxf(_minimumValue, fminf(_maximumValue, v)); isim_ui_set_needs_display(); }
- (void)setValue:(float)v animated:(BOOL)a { self.value = v; }
- (void)setMinimumValue:(float)v { _minimumValue = v; if (_maximumValue < v) _maximumValue = v; self.value = _value; }
- (void)setMaximumValue:(float)v { _maximumValue = v; if (_minimumValue > v) _minimumValue = v; self.value = _value; }
- (double)_fraction { return _maximumValue > _minimumValue ? (_value - _minimumValue) / (_maximumValue - _minimumValue) : 0; }
- (double)_thumbX { CGFloat w = self.bounds.size.width; return 14 + [self _fraction] * (w - 28); }
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    CGPoint p = [t locationInView:self];
    double tx = [self _thumbX];
    if (fabs(p.x - tx) > 22) return NO;                                /* like iOS: grab the thumb */
    _dragging = YES; _grab = p.x - tx;
    return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    CGFloat w = self.bounds.size.width;
    double x = [t locationInView:self].x - _grab, f = fmin(1, fmax(0, (x - 14) / fmax(1, w - 28)));
    float v = _minimumValue + (float)f * (_maximumValue - _minimumValue);
    if (v != _value) { self.value = v; if (_continuous) [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
    return YES;
}
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    _dragging = NO; isim_ui_set_needs_display();
    if (!_continuous) [self _isim_sendEvents:UIControlEventValueChanged withEvent:e];
}
- (void)cancelTrackingWithEvent:(UIEvent *)e { _dragging = NO; isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height, cy = h / 2;
    double alpha = self.enabled ? 1 : 0.45, tx = [self _thumbX];
    fill(_maximumTrackTintColor ?: UIColor.tertiarySystemFillColor, 2, cy - 2, w - 4, 4, 2, alpha);
    fill(_minimumTrackTintColor ?: tint_of(self), 2, cy - 2, fmax(0, tx - 2), 4, 2, alpha);
    double shadow[4] = { 0, 0, 0, 0.12 * alpha };
    isim_gfx_fill_ellipse(tx - 14.5, cy - 13.5, 29, 29, shadow);
    double ring[4] = { 0, 0, 0, 0.06 }; isim_gfx_fill_ellipse(tx - 14.5, cy - 14.5, 29, 29, ring);
    double th[4]; isim_ui_rgba(_thumbTintColor ?: UIColor.whiteColor, th);
    isim_gfx_fill_ellipse(tx - 14, cy - 14, 28, 28, th);
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
    fill(UIColor.tertiarySystemFillColor, 0, 0, 94, 32, 8, 1);
    if (_pressed) fill(UIColor.tertiarySystemFillColor, _pressed < 0 ? 0 : 47, 0, 47, 32, 8, 1);
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
@implementation UISegmentedControl { NSMutableArray *_items; NSMutableSet<NSNumber *> *_disabled; UIView *_thumb; NSInteger _pressedIndex; NSMutableDictionary<NSNumber *, NSNumber *> *_widths; }
- (instancetype)initWithItems:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectZero])) {
        _items = [NSMutableArray arrayWithArray:items ?: @[]]; _disabled = [NSMutableSet set]; _widths = [NSMutableDictionary dictionary];
        _selectedSegmentIndex = UISegmentedControlNoSegment; _pressedIndex = -1;
        _thumb = [[UIView alloc] initWithFrame:CGRectZero];
        _thumb.layer.cornerRadius = 7; _thumb.userInteractionEnabled = NO;
        _thumb.layer.shadowColor = UIColor.blackColor.CGColor; _thumb.layer.shadowOpacity = 0.12; _thumb.layer.shadowRadius = 4; _thumb.layer.shadowOffset = CGSizeMake(0, 2);
        _thumb.hidden = YES;
        [self addSubview:_thumb];
        CGSize s = [self sizeThatFits:CGSizeZero]; self.frame = CGRectMake(0, 0, s.width, s.height);
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { if ((self = [self initWithItems:nil])) self.frame = f; return self; }
- (UIFont *)_font:(BOOL)sel { return [UIFont systemFontOfSize:13 weight:sel ? UIFontWeightSemibold : UIFontWeightMedium]; }
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
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { _pressedIndex = [self _indexAt:[t locationInView:self]]; isim_ui_set_needs_display(); return YES; }
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    NSInteger i = [self _indexAt:[t locationInView:self]];
    _pressedIndex = -1; isim_ui_set_needs_display();
    if (i < 0 || ![self isEnabledForSegmentAtIndex:(NSUInteger)i] || !CGRectContainsPoint(CGRectInset(self.bounds, -20, -20), [t locationInView:self])) return;
    if (_momentary) { [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; return; }
    if (i != _selectedSegmentIndex) { self.selectedSegmentIndex = i; [self _isim_sendEvents:UIControlEventValueChanged withEvent:e]; }
}
- (void)cancelTrackingWithEvent:(UIEvent *)e { _pressedIndex = -1; isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    fill(UIColor.tertiarySystemFillColor, 0, 0, s.width, s.height, 9, 1);
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
            CGSize ts = isim_ui_measure([it description], f, r.size.width - 8, 1);
            isim_ui_draw_text([it description], f, UIColor.labelColor, CGRectMake(r.origin.x + 4, CGRectGetMidY(r) - ts.height / 2, r.size.width - 8, ts.height), NSTextAlignmentCenter, 1, a);
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
    CGSize ts = isim_ui_measure(self.element.title, f, s.width - x - 48, 1);
    isim_ui_draw_text(self.element.title, f, c, CGRectMake(x, s.height / 2 - ts.height / 2, s.width - x - 48, ts.height), NSTextAlignmentLeft, 1, alpha);
    UIImage *img = [self.element isKindOfClass:[UIMenu class]] ? [UIImage systemImageNamed:@"chevron.right"] : self.element.image;
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
@end
@implementation __IsimMenuOverlay
static __weak __IsimMenuOverlay *current_menu;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e { [self dismiss]; }   /* tap outside */
- (void)dismiss {
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
            __IsimMenuRow *row = [[__IsimMenuRow alloc] initWithFrame:CGRectMake(0, y, W, 44)];
            row.element = s[i]; row.showsCheckColumn = checks; row.last = i + 1 == s.count;
            row.accessibilityIdentifier = [@"menu-" stringByAppendingString:row.element.title];
            [row addTarget:self action:@selector(_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self.card.contentView addSubview:row];
            y += 44;
        }
    }
    CGRect b = self.bounds; const struct isim_device *d = isim_ui_device();
    CGFloat x = fmin(fmax(16, anchor.origin.x), b.size.width - W - 16);
    CGFloat top = CGRectGetMaxY(anchor) + 8;
    if (top + y > b.size.height - d->safe_bottom - 8) top = fmax(d->safe_top + 8, anchor.origin.y - 8 - y);
    self.card.frame = CGRectMake(x, top, W, y);
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

@implementation UIView (IsimMenu)
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect {
    UIWindow *w = self.window;
    if (!w || !menu) return;
    [current_menu removeFromSuperview];
    __IsimMenuOverlay *o = [[__IsimMenuOverlay alloc] initWithFrame:w.bounds];
    o.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    o.source = self;
    o.accessibilityIdentifier = @"isim-menu";
    if (isim_ui_glass()) {                    /* iOS 26: glass menu with large corners */
        UIGlassEffect *g = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        g.tintColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [UIColor colorWithWhite:t.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.98 alpha:0.55]; }];
        o.card = [[UIVisualEffectView alloc] initWithEffect:g];
        o.card.layer.cornerRadius = 26;
    } else {
        o.card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
        o.card.layer.cornerRadius = 13;
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
    preview.layer.cornerRadius = 13; preview.clipsToBounds = YES;
    preview.accessibilityIdentifier = preview.accessibilityIdentifier ?: @"isim-menu-preview";
    [o insertSubview:preview belowSubview:o.card];
    card.origin.y = CGRectGetMaxY(preview.frame) + 8;
    card.origin.x = fmin(fmax(16, CGRectGetMinX(preview.frame)), b.size.width - 16 - card.size.width);
    o.card.frame = card;
}
@end
