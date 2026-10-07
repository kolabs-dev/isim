// isim home screen: horizontal paging (HSPager: rubber-banding, velocity snapping, a spring settle), the page
// indicator above the dock (HSPageDots: tap or drag to switch pages; in edit mode a tap opens Edit Pages) and the
// Edit Pages overview (thumbnails with checkmarks to hide or show pages), like iOS 17/18.
#import "SpringBoard.h"
#include <math.h>

/* ================= pager ================= */
@implementation HSPager {
    UIView *_content; NSMutableArray<UIView *> *_pageViews;
    CGFloat _offset, _start; NSTimer *_anim; double _v;           /* points; velocity points/s during the settle */
    int _axis;                                                    /* current pan: 0 undecided, 1 horizontal, 2 vertical */
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _content = [UIView new]; [self addSubview:_content];
        _pageViews = [NSMutableArray array];
        self.clipsToBounds = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
        pan.cancelsTouchesInView = YES;
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (NSArray<UIView *> *)pages { return _pageViews; }
- (void)setPages:(NSArray<UIView *> *)pages {
    for (UIView *v in _pageViews) [v removeFromSuperview];
    _pageViews = [pages mutableCopy];
    for (UIView *v in _pageViews) [_content addSubview:v];
    if (_currentPage >= (NSInteger)_pageViews.count) _currentPage = MAX(0, (NSInteger)_pageViews.count - 1);
    _offset = _currentPage * self.bounds.size.width;
    [self setNeedsLayout];
}
- (void)appendPage:(UIView *)page { [_pageViews addObject:page]; [_content addSubview:page]; [self setNeedsLayout]; [self layoutIfNeeded]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize b = self.bounds.size;
    for (NSUInteger i = 0; i < _pageViews.count; i++) _pageViews[i].frame = CGRectMake(i * b.width, 0, b.width, b.height);
    if (!_anim) _offset = _currentPage * b.width;
    [self applyOffset];
}
- (CGFloat)maxOffset { return MAX(0, ((CGFloat)_pageViews.count - 1) * self.bounds.size.width); }
- (void)applyOffset {
    _content.frame = CGRectMake(-_offset, 0, _pageViews.count * self.bounds.size.width, self.bounds.size.height);
    id<HSPagerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(pagerDidScroll:)]) [d pagerDidScroll:self];
}
- (CGFloat)pagePosition { return _offset / MAX(1, self.bounds.size.width); }
static CGFloat rubber(CGFloat over, CGFloat dim) { return (1 - 1 / (fabs(over) * 0.55 / MAX(dim, 1) + 1)) * dim * (over < 0 ? -1 : 1); }
- (void)panned:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self];
    id<HSPagerDelegate> d = _delegate;
    if (g.state == UIGestureRecognizerStateBegan) { [_anim invalidate]; _anim = nil; _start = _offset; _axis = 0; }
    if (!_axis && hypot(t.x, t.y) > 6) _axis = fabs(t.x) >= fabs(t.y) ? 1 : 2;
    if (_axis == 2) {                                             /* vertical: pull down for Spotlight */
        if (g.state == UIGestureRecognizerStateEnded && t.y > 60 && [d respondsToSelector:@selector(pagerPulledDown:)]) [d pagerPulledDown:self];
        return;
    }
    if (_axis != 1 || !_scrollEnabled) return;
    CGFloat W = self.bounds.size.width, o = _start - t.x, mx = [self maxOffset];
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        _offset = o < 0 ? rubber(o, W) : o > mx ? mx + rubber(o - mx, W) : o;
        [self applyOffset];
        return;
    }
    if (g.state != UIGestureRecognizerStateEnded && g.state != UIGestureRecognizerStateCancelled) return;
    CGFloat vx = -[g velocityInView:self].x;                      /* points/s, positive = towards later pages */
    NSInteger from = lround(_start / MAX(W, 1)), target = lround(_offset / MAX(W, 1));
    if (fabs(vx) > 300) target = from + (vx > 0 ? 1 : -1);        /* a flick turns one page */
    target = MAX(from - 1, MIN(from + 1, target));
    [self settleOn:target velocity:vx];
}
- (void)setCurrentPage:(NSInteger)p animated:(BOOL)animated {
    p = MAX(0, MIN((NSInteger)_pageViews.count - 1, p));
    if (!animated) { [_anim invalidate]; _anim = nil; _currentPage = p; _offset = p * self.bounds.size.width; [self applyOffset]; [self settled]; return; }
    [self settleOn:p velocity:0];
}
/* an under-damped spring (iOS-like page settle) towards the page */
- (void)settleOn:(NSInteger)p velocity:(CGFloat)v0 {
    p = MAX(0, MIN((NSInteger)_pageViews.count - 1, p));
    _currentPage = p;
    CGFloat target = p * self.bounds.size.width;
    _v = v0;
    [_anim invalidate];
    __block double last = isim_time();
    __weak HSPager *weakSelf = self;
    _anim = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *timer) {
        HSPager *s = weakSelf; if (!s) { [timer invalidate]; return; }
        double now = isim_time(), dt = fmin(0.033, now - last); last = now;
        const double k = 170, c = 2 * 0.86 * sqrt(k);             /* stiffness, damping (ratio 0.86: a slight overshoot) */
        for (int i = 0; i < 4; i++) {                             /* sub-steps for stability */
            double h = dt / 4, x = s->_offset - target;
            s->_v += (-k * x - c * s->_v) * h; s->_offset += s->_v * h;
        }
        if (fabs(s->_offset - target) < 0.3 && fabs(s->_v) < 4) { s->_offset = target; [timer invalidate]; s->_anim = nil; [s applyOffset]; [s settled]; return; }
        [s applyOffset];
    }];
}
- (void)settled {
    id<HSPagerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(pagerDidSettle:)]) [d pagerDidSettle:self];
}
- (BOOL)isSettling { return _anim != nil; }
@end

/* ================= page dots ================= */
@implementation HSPageDots { NSMutableArray<UIView *> *_dots; UIView *_pill; BOOL _dragging; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _dots = [NSMutableArray array];
        _pill = [UIView new]; _pill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22]; _pill.layer.cornerRadius = 13; _pill.userInteractionEnabled = NO;
        [self addSubview:_pill];
        self.accessibilityIdentifier = @"home-page-dots";
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)]];
        [self addTarget:self action:@selector(tappedDots:forEvent:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)setNumberOfPages:(NSInteger)n { _numberOfPages = n; [self rebuildDots]; }
- (void)setCurrentPage:(NSInteger)p { _currentPage = p; [self updateDots]; }
- (void)rebuildDots {
    for (UIView *d in _dots) [d removeFromSuperview];
    [_dots removeAllObjects];
    for (NSInteger i = 0; i < _numberOfPages; i++) {
        UIView *d = [UIView new]; d.layer.cornerRadius = 3.5; d.userInteractionEnabled = NO;
        [self addSubview:d]; [_dots addObject:d];
    }
    [self setNeedsLayout]; [self updateDots];
}
- (void)updateDots {
    for (NSInteger i = 0; i < (NSInteger)_dots.count; i++) _dots[i].backgroundColor = [UIColor colorWithWhite:1 alpha:i == _currentPage ? 1 : 0.38];
}
- (CGFloat)dotPitch { return 15; }
- (void)layoutSubviews {
    CGSize b = self.bounds.size; CGFloat pitch = [self dotPitch], w = _dots.count * pitch;
    CGFloat x0 = (b.width - w) / 2;
    _pill.frame = CGRectMake(x0 - 9, (b.height - 26) / 2, w + 18, 26);
    for (NSUInteger i = 0; i < _dots.count; i++) _dots[i].frame = CGRectMake(x0 + i * pitch + (pitch - 7) / 2, (b.height - 7) / 2, 7, 7);
}
- (NSInteger)pageAtX:(CGFloat)x {
    CGFloat w = _dots.count * [self dotPitch], x0 = (self.bounds.size.width - w) / 2;
    return MAX(0, MIN(_numberOfPages - 1, (NSInteger)floor((x - x0) / [self dotPitch])));
}
- (NSString *)_isim_dumpText { return [NSString stringWithFormat:@"page %ld of %ld", (long)_currentPage + 1, (long)_numberOfPages]; }
- (void)tappedDots:(UIControl *)c forEvent:(UIEvent *)e {
    id<HSPageDotsDelegate> d = _delegate;
    if (_editMode) { if ([d respondsToSelector:@selector(pageDotsWantEditPages:)]) [d pageDotsWantEditPages:self]; return; }
    UITouch *t = e.allTouches.anyObject;
    NSInteger p = t ? [self pageAtX:[t locationInView:self].x] : (_currentPage + 1) % MAX(1, _numberOfPages);
    if ([d respondsToSelector:@selector(pageDots:selectPage:)]) [d pageDots:self selectPage:p];
}
- (void)dragged:(UIPanGestureRecognizer *)g {                     /* scrub across the dots */
    if (_editMode) return;
    id<HSPageDotsDelegate> d = _delegate;
    NSInteger p = [self pageAtX:[g locationInView:self].x];
    _pill.backgroundColor = [UIColor colorWithWhite:1 alpha:g.state == UIGestureRecognizerStateEnded ? 0.22 : 0.4];
    if (p != _currentPage && [d respondsToSelector:@selector(pageDots:selectPage:)]) [d pageDots:self selectPage:p];
}
@end

/* ================= Edit Pages ================= */
@implementation HSEditPagesView { NSMutableArray<UIButton *> *_checks; NSArray *_hidden; }
- (instancetype)initWithFrame:(CGRect)f thumbnails:(NSArray<UIImage *> *)thumbs hidden:(NSArray<NSNumber *> *)hidden {
    if ((self = [super initWithFrame:f])) {
        self.accessibilityIdentifier = @"editpages";
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        blur.frame = self.bounds; blur.userInteractionEnabled = NO; [self addSubview:blur];
        _hiddenFlags = [hidden mutableCopy];
        _checks = [NSMutableArray array];
        /* a grid of thumbnails that fits the screen: 2 columns, 3 from 5 pages, smaller when there are many rows */
        NSUInteger n = thumbs.count, cols = n <= 4 ? 2 : 3, rows = (n + cols - 1) / cols;
        CGFloat W = f.size.width, H = f.size.height, gap = cols == 2 ? 36 : 24, top = 100, below = 52;
        CGFloat tw = (W - (cols + 1) * gap) / cols, th = tw * H / W;
        CGFloat maxTh = (H - top - 40) / MAX(rows, 1) - below;
        if (th > maxTh) { th = maxTh; tw = th * W / H; }
        CGFloat x0 = (W - cols * tw - (cols - 1) * gap) / 2;
        for (NSUInteger i = 0; i < n; i++) {
            CGFloat x = x0 + (i % cols) * (tw + gap), y = top + (i / cols) * (th + below);
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, tw, th)];
            iv.image = thumbs[i]; iv.layer.cornerRadius = 14; iv.clipsToBounds = YES; iv.contentMode = UIViewContentModeScaleToFill;
            iv.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor; iv.layer.borderWidth = 1;
            iv.accessibilityIdentifier = [NSString stringWithFormat:@"editpages-thumb-%lu", (unsigned long)i + 1];
            [self addSubview:iv];
            UIButton *c = [UIButton buttonWithType:UIButtonTypeCustom];
            c.frame = CGRectMake(x + (tw - 30) / 2, y + th + 12, 30, 30);
            c.tag = (NSInteger)i;
            c.accessibilityIdentifier = [NSString stringWithFormat:@"editpages-page-%lu", (unsigned long)i + 1];
            [c addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:c]; [_checks addObject:c];
        }
        UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
        [done setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
        [done setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        done.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        done.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8]; done.layer.cornerRadius = 15;
        done.frame = CGRectMake(W - 82, 54, 66, 30); done.accessibilityIdentifier = @"editpages-done";
        [done addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:done];
        [self updateChecks];
    }
    return self;
}
- (void)updateChecks {
    for (UIButton *c in _checks) {
        BOOL shown = ![_hiddenFlags[c.tag] boolValue];
        [c setImage:[UIImage systemImageNamed:shown ? @"checkmark.circle.fill" : @"circle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:26]] forState:UIControlStateNormal];
        c.tintColor = shown ? UIColor.systemBlueColor : [UIColor colorWithWhite:1 alpha:0.8];
        c.backgroundColor = shown ? UIColor.whiteColor : UIColor.clearColor; c.layer.cornerRadius = 15;
        c.accessibilityValue = shown ? @"shown" : @"hidden";
    }
}
- (NSString *)_isim_dumpText { return [NSString stringWithFormat:@"%lu pages", (unsigned long)_checks.count]; }
- (void)toggle:(UIButton *)c {
    BOOL hide = ![_hiddenFlags[c.tag] boolValue];
    NSUInteger shown = 0; for (NSNumber *h in _hiddenFlags) if (!h.boolValue) shown++;
    if (hide && shown <= 1) return;                               /* at least one page stays */
    _hiddenFlags[c.tag] = @(hide);
    NSLog(@"SpringBoard: page %ld %@", (long)c.tag + 1, hide ? @"hidden" : @"shown");
    [self updateChecks];
}
- (void)finish { if (self.onDone) self.onDone(_hiddenFlags); [self removeFromSuperview]; }
@end
