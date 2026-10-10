/* UIPickerView and UIDatePicker.
 *
 * UIPickerView draws each component as a wheel: rows sit on a cylinder (vertically squashed and faded
 * away from the middle) behind a rounded selection band, like iOS 14+. Drag a column to spin it (it
 * keeps spinning after a fling and settles on a row), or tap a row above/below the band to select it.
 * The delegate's didSelectRow fires when a wheel comes to rest on a different row. Rows come from
 * titleForRow (drawn text) or viewForRow (real subviews, reused).
 *
 * UIDatePicker: wheels (an internal UIPickerView: cyclic hour/minute/month/day wheels), compact (pill
 * buttons; tapping one opens a popover with a calendar or time wheels) and inline (a month calendar,
 * plus a time pill for .dateAndTime). Dates use the Gregorian calendar in the device time zone (TZ);
 * the pills format text with NSDateFormatter (device locale, 12/24-hour setting). */
#import "UIKitPrivate.h"
#import <UIKit/UIPickerView.h>
#import <UIKit/UIDatePicker.h>
#import <objc/runtime.h>
#include <math.h>
#include <time.h>

static void pk_fill(UIColor *c, double x, double y, double w, double h, double r) { double v[4]; isim_ui_rgba(c, v); isim_gfx_fill_rounded(x, y, w, h, r, v); }
static UIColor *band_color(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithRed:118 / 255.0 green:118 / 255.0 blue:128 / 255.0 alpha:0.24]
                                                                : [UIColor colorWithRed:118 / 255.0 green:118 / 255.0 blue:128 / 255.0 alpha:0.12]; }];
}

/* ================= UIPickerView ================= */
typedef struct {
    double offset;          /* fractional row at the band (cyclic wheels: unbounded) */
    NSInteger rows, selected;
    BOOL cyclic;
    NSTextAlignment align;
    double animFrom, animTo, animStart, animDur;   /* settle animation (animDur 0 = idle) */
    BOOL notify;                                   /* report the row when the settle animation ends */
} pk_wheel;

@interface UIPickerView ()
- (void)_isim_setCyclic:(BOOL)c forComponent:(NSInteger)k;
- (void)_isim_setAlignment:(NSTextAlignment)a forComponent:(NSInteger)k;
@property (nonatomic, copy) void (^_isim_onSelect)(NSInteger row, NSInteger component);   /* internal clients (UIDatePicker) */
- (NSString *)_isim_titleFor:(NSInteger)row comp:(NSInteger)k;
- (CGRect)_isim_compRect:(NSInteger)k;
- (void)_isim_axStep:(NSInteger)d component:(NSInteger)k;
@property (nonatomic, strong) UIFont *_isim_font;
@end
@interface __IsimPickerComponentElement : UIAccessibilityElement
- (instancetype)initWithPicker:(UIPickerView *)p component:(NSInteger)k;
@property (nonatomic, readonly) NSInteger component;
@end

@implementation UIPickerView {
    pk_wheel *_w; NSInteger _n;
    NSMutableDictionary<NSNumber *, NSNumber *> *_cyclicReq, *_alignReq;
    NSInteger _dragComp; double _dragStart;
    NSTimer *_timer;
    NSMutableDictionary<NSString *, UIView *> *_rowViews;     /* "component:row" -> delegate view */
    BOOL _usesViews;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _cyclicReq = [NSMutableDictionary dictionary]; _alignReq = [NSMutableDictionary dictionary]; _rowViews = [NSMutableDictionary dictionary];
        _dragComp = -1;
        self._isim_font = [UIFont systemFontOfSize:21];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_pkPan:)];
        [pan _isim_setExclusive:YES];
        [self addGestureRecognizer:pan];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_pkTap:)]];
        self.clipsToBounds = YES;
    }
    return self;
}
- (void)dealloc { [_timer invalidate]; free(_w); }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 216); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 && s.width < 1e5 ? s.width : 320, 216); }
- (void)setDataSource:(id<UIPickerViewDataSource>)d { _dataSource = d; [self reloadAllComponents]; }
- (void)setDelegate:(id<UIPickerViewDelegate>)d { _delegate = d; [self reloadAllComponents]; }
- (void)didMoveToWindow { [super didMoveToWindow]; if (self.window && !_w) [self reloadAllComponents]; }

/* ---- data ---- */
- (NSInteger)numberOfComponents { return _n; }
- (NSInteger)numberOfRowsInComponent:(NSInteger)k { return k >= 0 && k < _n ? _w[k].rows : 0; }
- (void)reloadAllComponents {
    id<UIPickerViewDataSource> ds = _dataSource;
    NSInteger n = ds ? MAX(0, [ds numberOfComponentsInPickerView:self]) : 0;
    pk_wheel *old = _w; NSInteger oldN = _n;
    _w = calloc((size_t)MAX(n, 1), sizeof *_w); _n = n;
    for (NSInteger k = 0; k < n; k++) {
        if (k < oldN) _w[k] = old[k];
        _w[k].animDur = 0;
        _w[k].rows = MAX(0, [ds pickerView:self numberOfRowsInComponent:k]);
        _w[k].cyclic = [_cyclicReq[@(k)] boolValue];
        _w[k].align = _alignReq[@(k)] ? (NSTextAlignment)[_alignReq[@(k)] integerValue] : NSTextAlignmentCenter;
        if (_w[k].rows == 0) { _w[k].selected = 0; _w[k].offset = 0; continue; }
        if (!_w[k].cyclic && _w[k].selected >= _w[k].rows) _w[k].selected = _w[k].rows - 1;
        if (k >= oldN) _w[k].offset = _w[k].selected;
    }
    free(old);
    _usesViews = [_delegate respondsToSelector:@selector(pickerView:viewForRow:forComponent:reusingView:)];
    for (UIView *v in _rowViews.allValues) [v removeFromSuperview];
    [_rowViews removeAllObjects];
    [self _isim_pkLayoutRows];
    isim_ui_set_needs_display();
}
- (void)reloadComponent:(NSInteger)k {
    if (k < 0 || k >= _n) return;
    _w[k].rows = MAX(0, [_dataSource pickerView:self numberOfRowsInComponent:k]);
    if (!_w[k].cyclic && _w[k].selected >= _w[k].rows) { _w[k].selected = MAX(0, _w[k].rows - 1); _w[k].offset = _w[k].selected; }
    for (NSString *key in _rowViews.allKeys) if ([key hasPrefix:[NSString stringWithFormat:@"%ld:", (long)k]]) { [_rowViews[key] removeFromSuperview]; [_rowViews removeObjectForKey:key]; }
    [self _isim_pkLayoutRows];
    isim_ui_set_needs_display();
}
- (void)_isim_setCyclic:(BOOL)c forComponent:(NSInteger)k { _cyclicReq[@(k)] = @(c); if (k < _n) _w[k].cyclic = c; }
- (void)_isim_setAlignment:(NSTextAlignment)a forComponent:(NSInteger)k { _alignReq[@(k)] = @(a); if (k < _n) _w[k].align = a; }
- (NSInteger)selectedRowInComponent:(NSInteger)k { return k >= 0 && k < _n && _w[k].rows ? _w[k].selected : -1; }
- (NSInteger)_isim_wrap:(NSInteger)row comp:(NSInteger)k {
    NSInteger n = _w[k].rows; if (n <= 0) return 0;
    if (_w[k].cyclic) return ((row % n) + n) % n;
    return MAX(0, MIN(n - 1, row));
}
- (void)selectRow:(NSInteger)row inComponent:(NSInteger)k animated:(BOOL)animated {
    if (k < 0 || k >= _n || _w[k].rows == 0) return;
    row = [self _isim_wrap:row comp:k];
    double target = row;
    if (_w[k].cyclic) {                        /* nearest copy of the row to where the wheel is */
        double n = _w[k].rows, base = floor(_w[k].offset / n) * n;
        target = base + row;
        if (target - _w[k].offset > n / 2) target -= n; else if (_w[k].offset - target > n / 2) target += n;
    }
    _w[k].selected = row;
    if (animated && self.window) [self _isim_pkAnimate:k to:target duration:0.35 notify:NO];
    else { _w[k].animDur = 0; _w[k].offset = target; [self _isim_pkLayoutRows]; isim_ui_set_needs_display(); }
}

/* ---- geometry ---- */
- (CGFloat)_isim_rowHeight:(NSInteger)k {
    if ([_delegate respondsToSelector:@selector(pickerView:rowHeightForComponent:)]) return fmax(10, [_delegate pickerView:self rowHeightForComponent:k]);
    return 34;
}
- (CGRect)_isim_compRect:(NSInteger)k {
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, margin = 12, gap = 4;
    if (_n == 0) return CGRectZero;
    CGFloat widths[_n], total = 0; BOOL custom = [_delegate respondsToSelector:@selector(pickerView:widthForComponent:)];
    for (NSInteger i = 0; i < _n; i++) { widths[i] = custom ? [_delegate pickerView:self widthForComponent:i] : (W - 2 * margin - gap * (_n - 1)) / _n; total += widths[i]; }
    total += gap * (_n - 1);
    CGFloat x = custom ? (W - total) / 2 : margin;
    for (NSInteger i = 0; i < k; i++) x += widths[i] + gap;
    return CGRectMake(x, 0, widths[k], H);
}
- (CGSize)rowSizeForComponent:(NSInteger)k { return k >= 0 && k < _n ? CGSizeMake([self _isim_compRect:k].size.width, [self _isim_rowHeight:k]) : CGSizeZero; }
- (NSInteger)_isim_compAt:(CGFloat)x {
    for (NSInteger k = 0; k < _n; k++) { CGRect r = [self _isim_compRect:k]; if (x < CGRectGetMaxX(r) + 2) return k; }
    return _n - 1;
}
- (double)_isim_radius { return self.bounds.size.height / 2 * 0.96; }
/* row d rows away from the band: angle on the cylinder */
- (double)_isim_angle:(double)d comp:(NSInteger)k { return d * [self _isim_rowHeight:k] / [self _isim_radius]; }

/* ---- drawing ---- */
- (NSString *)_isim_titleFor:(NSInteger)row comp:(NSInteger)k {
    if ([_delegate respondsToSelector:@selector(pickerView:titleForRow:forComponent:)]) return [_delegate pickerView:self titleForRow:row forComponent:k] ?: @"";
    return @"?";
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double rh = _n ? [self _isim_rowHeight:0] : 34;
    pk_fill(band_color(), 8, s.height / 2 - rh / 2, s.width - 16, rh, 8);       /* selection band */
    if (_usesViews) return;
    UIFont *font = self._isim_font;
    for (NSInteger k = 0; k < _n; k++) {
        pk_wheel *w = &_w[k];
        if (!w->rows) continue;
        CGRect cr = [self _isim_compRect:k];
        double h = [self _isim_rowHeight:k], R = [self _isim_radius];
        NSInteger first = (NSInteger)floor(w->offset) - 6, last = (NSInteger)ceil(w->offset) + 6;
        for (NSInteger r = first; r <= last; r++) {
            if (!w->cyclic && (r < 0 || r >= w->rows)) continue;
            double d = r - w->offset, a = d * h / R;
            if (fabs(a) >= M_PI / 2 * 0.98) continue;
            double cy = s.height / 2 + R * sin(a), squash = cos(a);
            NSString *t = [self _isim_titleFor:[self _isim_wrap:r comp:k] comp:k];
            CGSize ts = isim_ui_measure(t, font, cr.size.width - 8, 1);
            double alpha = fabs(d) < 0.5 ? 1 : 0.3 + 0.45 * squash * squash;
            isim_gfx_save();
            isim_gfx_translate(0, cy);
            isim_gfx_scale(1, squash);
            CGRect tr = CGRectMake(cr.origin.x + 4, -ts.height / 2, cr.size.width - 8, ts.height);
            isim_ui_draw_text(t, font, UIColor.labelColor, tr, w->align, 1, alpha);
            isim_gfx_restore();
        }
    }
}
/* delegate views: real subviews positioned on the wheel */
- (void)_isim_pkLayoutRows {
    if (!_usesViews) return;
    CGSize s = self.bounds.size;
    NSMutableSet *live = [NSMutableSet set];
    for (NSInteger k = 0; k < _n; k++) {
        pk_wheel *w = &_w[k];
        if (!w->rows) continue;
        CGRect cr = [self _isim_compRect:k];
        double h = [self _isim_rowHeight:k], R = [self _isim_radius];
        for (NSInteger r = (NSInteger)floor(w->offset) - 6; r <= (NSInteger)ceil(w->offset) + 6; r++) {
            if (!w->cyclic && (r < 0 || r >= w->rows)) continue;
            double d = r - w->offset, a = d * h / R;
            if (fabs(a) >= M_PI / 2 * 0.98) continue;
            NSInteger row = [self _isim_wrap:r comp:k];
            NSString *key = [NSString stringWithFormat:@"%ld:%ld", (long)k, (long)r];
            UIView *v = _rowViews[key];
            if (!v) {
                v = [_delegate pickerView:self viewForRow:row forComponent:k reusingView:nil];
                if (!v) continue;
                _rowViews[key] = v; [self addSubview:v];
            }
            [live addObject:key];
            [UIView performWithoutAnimation:^{
                v.transform = CGAffineTransformIdentity;
                v.frame = CGRectMake(cr.origin.x, s.height / 2 + R * sin(a) - h / 2, cr.size.width, h);
                v.transform = CGAffineTransformMakeScale(1, cos(a));
                v.alpha = fabs(d) < 0.5 ? 1 : 0.3 + 0.45 * cos(a) * cos(a);
            }];
        }
    }
    for (NSString *key in _rowViews.allKeys) if (![live containsObject:key]) { [_rowViews[key] removeFromSuperview]; [_rowViews removeObjectForKey:key]; }
}
- (UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)k {
    if (k < 0 || k >= _n) return nil;
    for (NSString *key in _rowViews) {
        NSArray *p = [key componentsSeparatedByString:@":"];
        if ([p[0] integerValue] == k && [self _isim_wrap:[p[1] integerValue] comp:k] == row) return _rowViews[key];
    }
    return nil;
}
- (void)layoutSubviews { [super layoutSubviews]; [self _isim_pkLayoutRows]; }
- (NSString *)_isim_dumpText {
    NSMutableArray *a = [NSMutableArray array];
    for (NSInteger k = 0; k < _n; k++) [a addObject:_usesViews ? @(_w[k].selected).stringValue : [NSString stringWithFormat:@"%ld:%@", (long)_w[k].selected, [self _isim_titleFor:_w[k].selected comp:k]]];
    return [NSString stringWithFormat:@"rows %@", [a componentsJoinedByString:@" | "]];
}


/* ---- motion ---- */
- (void)_isim_setOffset:(double)o comp:(NSInteger)k {
    _w[k].offset = o;
    [self _isim_pkLayoutRows];
    isim_ui_set_needs_display();
}
/* glide to a row; with notify, the delegate hears about it when the wheel comes to rest on a new row */
- (void)_isim_pkAnimate:(NSInteger)k to:(double)target duration:(double)dur notify:(BOOL)notify {
    pk_wheel *w = &_w[k];
    w->animFrom = w->offset; w->animTo = target; w->animStart = isim_time(); w->animDur = fmax(0.05, dur);
    w->notify = notify && [self _isim_wrap:(NSInteger)llround(target) comp:k] != w->selected;
    if (!notify) w->selected = [self _isim_wrap:(NSInteger)llround(target) comp:k];
    if (_timer) return;
    __weak UIPickerView *ws = self;
    _timer = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) { [ws _isim_pkTick]; }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (void)_isim_pkTick {
    BOOL any = NO; double now = isim_time();
    for (NSInteger k = 0; k < _n; k++) {
        pk_wheel *w = &_w[k];
        if (w->animDur <= 0) continue;
        double x = fmin(1, (now - w->animStart) / w->animDur), e = 1 - pow(1 - x, 3);
        w->offset = w->animFrom + (w->animTo - w->animFrom) * e;
        if (x < 1) { any = YES; continue; }
        w->animDur = 0; w->offset = w->animTo;
        w->selected = [self _isim_wrap:(NSInteger)llround(w->offset) comp:k];
        if (w->notify) {
            w->notify = NO;
            NSInteger row = w->selected;
            if (self._isim_onSelect) self._isim_onSelect(row, k);
            else if ([_delegate respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)]) [_delegate pickerView:self didSelectRow:row inComponent:k];
        }
    }
    [self _isim_pkLayoutRows];
    isim_ui_set_needs_display();
    if (!any) { [_timer invalidate]; _timer = nil; }
}
- (void)_isim_pkPan:(UIPanGestureRecognizer *)g {
    if (!_n) return;
    CGPoint t = [g translationInView:self];
    if (g.state == UIGestureRecognizerStateBegan) {
        _dragComp = [self _isim_compAt:[g locationInView:self].x - t.x];
        if (_dragComp < 0 || !_w[_dragComp].rows) { _dragComp = -1; return; }
        _w[_dragComp].animDur = 0;
        _dragStart = _w[_dragComp].offset;
    }
    if (_dragComp < 0) return;
    NSInteger k = _dragComp;
    pk_wheel *w = &_w[k];
    double h = [self _isim_rowHeight:k], o = _dragStart - t.y / h;
    if (!w->cyclic) {                                                   /* rubber band past the ends */
        double mx = w->rows - 1;
        if (o < 0) o = -(1 - 1 / (-o * 0.5 + 1)) * 1.5; else if (o > mx) o = mx + (1 - 1 / ((o - mx) * 0.5 + 1)) * 1.5;
    }
    [self _isim_setOffset:o comp:k];
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) return;
    _dragComp = -1;
    double v = g.state == UIGestureRecognizerStateEnded ? -[g velocityInView:self].y / h : 0;   /* rows per second */
    double target = round(o + v * 0.3);
    if (!w->cyclic) target = fmax(0, fmin(w->rows - 1, target));
    double dist = fabs(target - o);
    [self _isim_pkAnimate:k to:target duration:fmin(1.2, 0.25 + 0.06 * dist + 0.1 * sqrt(dist)) notify:YES];
}
/* tapping a row above or below the band turns the wheel to it */
- (void)_isim_pkTap:(UITapGestureRecognizer *)g {
    if (!_n) return;
    CGPoint p = [g locationInView:self];
    NSInteger k = [self _isim_compAt:p.x];
    if (k < 0 || !_w[k].rows) return;
    double R = [self _isim_radius], dy = (p.y - self.bounds.size.height / 2) / R;
    if (fabs(dy) >= 1) return;
    double d = asin(dy) * R / [self _isim_rowHeight:k];
    if (fabs(d) < 0.5) return;
    double target = round(_w[k].offset + d);
    if (!_w[k].cyclic && (target < 0 || target > _w[k].rows - 1)) return;
    [self _isim_pkAnimate:k to:target duration:0.3 notify:YES];
}
/* ---- accessibility: one adjustable element per wheel (label and hint from a UIPickerViewAccessibilityDelegate, value the
   selected row's title; increment / decrement turn the wheel one row) ---- */
- (NSArray *)accessibilityElements {
    NSArray *a = [super accessibilityElements];
    if (a) return a;
    NSMutableArray *els = objc_getAssociatedObject(self, @selector(accessibilityElements));
    if (els.count != (NSUInteger)_n) {
        els = [NSMutableArray array];
        for (NSInteger k = 0; k < _n; k++) [els addObject:[[__IsimPickerComponentElement alloc] initWithPicker:self component:k]];
        objc_setAssociatedObject(self, @selector(accessibilityElements), els, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (__IsimPickerComponentElement *e in els) e.accessibilityFrameInContainerSpace = [self _isim_compRect:e.component];
    return els;
}
- (void)_isim_axStep:(NSInteger)d component:(NSInteger)k {
    if (k < 0 || k >= _n || !_w[k].rows) return;
    NSInteger row = _w[k].selected + d;
    if (!_w[k].cyclic && (row < 0 || row >= _w[k].rows)) return;
    [self selectRow:row inComponent:k animated:NO];
    row = _w[k].selected;
    if (self._isim_onSelect) self._isim_onSelect(row, k);
    else if ([_delegate respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)]) [_delegate pickerView:self didSelectRow:row inComponent:k];
}
@end
@implementation __IsimPickerComponentElement { __weak UIPickerView *_picker; }
- (instancetype)initWithPicker:(UIPickerView *)p component:(NSInteger)k {
    if ((self = [super initWithAccessibilityContainer:p])) { _picker = p; _component = k; }
    return self;
}
- (id<UIPickerViewAccessibilityDelegate>)_ad { id d = _picker.delegate; return [d conformsToProtocol:@protocol(UIPickerViewAccessibilityDelegate)] || [d respondsToSelector:@selector(pickerView:accessibilityLabelForComponent:)] ? d : nil; }
- (NSString *)accessibilityLabel {
    id d = [self _ad];
    if ([d respondsToSelector:@selector(pickerView:accessibilityAttributedLabelForComponent:)]) { NSAttributedString *a = [d pickerView:_picker accessibilityAttributedLabelForComponent:_component]; if (a) return a.string; }
    if ([d respondsToSelector:@selector(pickerView:accessibilityLabelForComponent:)]) return [d pickerView:_picker accessibilityLabelForComponent:_component];
    return [super accessibilityLabel];
}
- (NSString *)accessibilityHint {
    id d = [self _ad];
    if ([d respondsToSelector:@selector(pickerView:accessibilityAttributedHintForComponent:)]) { NSAttributedString *a = [d pickerView:_picker accessibilityAttributedHintForComponent:_component]; if (a) return a.string; }
    if ([d respondsToSelector:@selector(pickerView:accessibilityHintForComponent:)]) return [d pickerView:_picker accessibilityHintForComponent:_component];
    return [super accessibilityHint];
}
- (NSArray<NSString *> *)accessibilityUserInputLabels {
    id d = [self _ad];
    if ([d respondsToSelector:@selector(pickerView:accessibilityAttributedUserInputLabelsForComponent:)]) {
        NSMutableArray *m = [NSMutableArray array]; for (NSAttributedString *a in [d pickerView:_picker accessibilityAttributedUserInputLabelsForComponent:_component]) [m addObject:a.string];
        return m;
    }
    if ([d respondsToSelector:@selector(pickerView:accessibilityUserInputLabelsForComponent:)]) return [d pickerView:_picker accessibilityUserInputLabelsForComponent:_component];
    return [super accessibilityUserInputLabels];
}
- (NSString *)accessibilityValue {
    UIPickerView *p = _picker;
    NSInteger row = [p selectedRowInComponent:_component];
    if (row < 0) return nil;
    NSInteger n = [p numberOfRowsInComponent:_component];
    return [NSString stringWithFormat:@"%@, %ld of %ld", [p _isim_titleFor:row comp:_component], (long)row + 1, (long)n];
}
- (UIAccessibilityTraits)accessibilityTraits { return UIAccessibilityTraitAdjustable; }
- (void)accessibilityIncrement { [_picker _isim_axStep:1 component:_component]; }
- (void)accessibilityDecrement { [_picker _isim_axStep:-1 component:_component]; }
@end
