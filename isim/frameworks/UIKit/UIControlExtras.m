/* Control members from the documentation sweep (#9): UIControl event handlers, the primary action and context menus;
 * UIButton attributed titles, roles and hover; the button configuration's transformers, indicator, image reservation
 * and selection look; segment actions and metrics; stepper images; switch styles; progress views that follow an
 * NSProgress. Stored outside the instances (associated objects): apps' subclasses keep their sizes. The drawing that
 * uses them is in UIControls.m / UIMoreControls.m. */
#import "UIKitPrivate.h"
#import <UIKit/UIControlExtras.h>
#import <objc/runtime.h>

static char kMenuEnabled, kMenuInteraction, kShowsMenu, kAttrTitles, kSubtitleLabel, kRole, kPointerProvider, kBehavior,
    kConfigExtras, kSegmentActions, kSegmentOffsets, kSegmentAdjust, kSegmentDividers, kStepperInc, kStepperDec, kStepperDividers,
    kSwitchStyle, kSwitchTitle, kSwitchOn, kSwitchOff, kSliderBehavior, kObserved, kProgressImage, kTrackImage;
static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static NSMutableDictionary *dict(id o, const void *k) {
    NSMutableDictionary *d = get(o, k);
    if (!d) { d = [NSMutableDictionary dictionary]; put(o, k, d); }
    return d;
}
static void set_state(id o, const void *k, id v, UIControlState s) { if (v) dict(o, k)[@(s)] = v; else [dict(o, k) removeObjectForKey:@(s)]; isim_ui_set_needs_display(); }
static id for_state(id o, const void *k, UIControlState s) { NSDictionary *d = get(o, k); return d[@(s)] ?: d[@(UIControlStateNormal)]; }

/* (UIControls.m's record of an action or a target-action pair) */
@interface __IsimTargetAction : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic) BOOL hasTarget;
@property (nonatomic) SEL action;
@property (nonatomic, strong) UIAction *uiAction;
@property (nonatomic) UIControlEvents events;
@end

/* ================= UIControl ================= */
@implementation UIControl (UIControlExtras)
- (UIControlContentHorizontalAlignment)effectiveContentHorizontalAlignment {
    UIControlContentHorizontalAlignment a = self.contentHorizontalAlignment;
    BOOL rtl = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    if (a == UIControlContentHorizontalAlignmentLeading) return rtl ? UIControlContentHorizontalAlignmentRight : UIControlContentHorizontalAlignmentLeft;
    if (a == UIControlContentHorizontalAlignmentTrailing) return rtl ? UIControlContentHorizontalAlignmentLeft : UIControlContentHorizontalAlignmentRight;
    return a;
}
- (void)removeActionForIdentifier:(NSString *)identifier forControlEvents:(UIControlEvents)events {
    NSMutableArray *handlers = [self _isim_handlers];
    for (__IsimTargetAction *t in [handlers copy])
        if (t.uiAction && [t.uiAction.identifier isEqualToString:identifier] && (t.events & events)) [handlers removeObjectIdenticalTo:t];
}
- (void)enumerateEventHandlers:(void (NS_NOESCAPE ^)(UIAction *, id, SEL, UIControlEvents, BOOL *))iterator {
    BOOL stop = NO;
    for (__IsimTargetAction *t in [[self _isim_handlers] copy]) {
        if (t.hasTarget && !t.target) continue;            /* (a deallocated target) */
        iterator(t.uiAction, t.uiAction ? nil : t.target, t.uiAction ? NULL : t.action, t.events, &stop);
        if (stop) break;
    }
}
/* what a tap does: the control's own response (a toggle, a menu) and the primary action */
- (void)performPrimaryAction {
    [self _isim_touchUpInside];
    [self _isim_sendEvents:UIControlEventPrimaryActionTriggered withEvent:nil];
}
- (BOOL)isContextMenuInteractionEnabled { return [get(self, &kMenuEnabled) boolValue]; }
- (void)setContextMenuInteractionEnabled:(BOOL)enabled {
    put(self, &kMenuEnabled, @(enabled));
    UIContextMenuInteraction *i = get(self, &kMenuInteraction);
    if (enabled && !i) { i = [[UIContextMenuInteraction alloc] initWithDelegate:self]; put(self, &kMenuInteraction, i); [self addInteraction:i]; }
    else if (!enabled && i) { [self removeInteraction:i]; put(self, &kMenuInteraction, nil); }
}
- (UIContextMenuInteraction *)contextMenuInteraction { return get(self, &kMenuInteraction); }
- (BOOL)showsMenuAsPrimaryAction { return [get(self, &kShowsMenu) boolValue]; }
- (void)setShowsMenuAsPrimaryAction:(BOOL)s { put(self, &kShowsMenu, @(s)); }
- (CGPoint)menuAttachmentPointForConfiguration:(UIContextMenuConfiguration *)configuration { CGRect b = self.bounds; return CGPointMake(CGRectGetMidX(b), CGRectGetMaxY(b)); }
/* a plain control has no menu of its own (subclasses answer one) */
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location { return nil; }
@end

/* ================= UIButton ================= */
static __weak UIView *hovered_view;
static UIButton *button_of(UIView *v) { while (v && ![v isKindOfClass:[UIButton class]]) v = v.superview; return (UIButton *)v; }
/* the pointer's view (UIHover.m); a button it enters or leaves updates its configuration (isHovered) */
void isim_ui_set_hovered_view(UIView *v) {
    UIButton *was = button_of(hovered_view), *now = button_of(v);
    hovered_view = v;
    if (was == now) return;
    if (was.automaticallyUpdatesConfiguration) [was setNeedsUpdateConfiguration];
    if (now.automaticallyUpdatesConfiguration) [now setNeedsUpdateConfiguration];
}

@implementation UIButton (UIButtonExtras)
@dynamic held;                                                     /* UIControls.m */
+ (instancetype)systemButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action {
    UIButton *b = [self buttonWithType:UIButtonTypeSystem];
    [b setImage:image forState:UIControlStateNormal];
    if (action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
    set_state(self, &kAttrTitles, [title copy], state);
    [self invalidateIntrinsicContentSize];
}
- (NSAttributedString *)attributedTitleForState:(UIControlState)state { return for_state(self, &kAttrTitles, state); }
- (NSAttributedString *)currentAttributedTitle { return [self attributedTitleForState:self.state]; }
- (UIColor *)currentTitleShadowColor { return [self titleShadowColorForState:self.state]; }
- (UIImageSymbolConfiguration *)preferredSymbolConfigurationForImageInState:(UIControlState)state { return [self _isim_symbolConfigurationForState:state]; }
- (UIImageSymbolConfiguration *)currentPreferredSymbolConfiguration { return [self _isim_symbolConfigurationForState:self.state] ?: self.configuration.preferredSymbolConfigurationForImage; }
- (UILabel *)subtitleLabel {
    UIButtonConfiguration *c = self.configuration;
    if (!c.subtitle && !c.attributedSubtitle) return nil;
    UILabel *l = get(self, &kSubtitleLabel);
    if (!l) { l = [[UILabel alloc] initWithFrame:CGRectZero]; put(self, &kSubtitleLabel, l); }
    if (c.attributedSubtitle) l.attributedText = c.attributedSubtitle; else l.text = c.subtitle;
    l.font = [self _isim_subtitleFont];
    return l;
}
- (BOOL)isHovered { UIView *v = hovered_view; return v && (v == self || [v isDescendantOfView:self]); }
- (UIButtonRole)role { return [get(self, &kRole) integerValue]; }
- (void)setRole:(UIButtonRole)r { put(self, &kRole, @(r)); }
- (UIButtonPointerStyleProvider)pointerStyleProvider { return get(self, &kPointerProvider); }
- (void)setPointerStyleProvider:(UIButtonPointerStyleProvider)p { put(self, &kPointerProvider, [p copy]); }
- (UIBehavioralStyle)preferredBehavioralStyle { return [get(self, &kBehavior) unsignedIntegerValue]; }
- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)s { put(self, &kBehavior, @(s)); }
- (UIBehavioralStyle)behavioralStyle { return UIBehavioralStylePad; }     /* (Mac is Mac Catalyst's) */
/* a button with a menu shows it on a long press */
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    UIMenu *m = self.menu;
    if (!m || !self.enabled) return nil;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) { return m; }];
}
@end

/* ================= UIButtonConfiguration ================= */
/* the extras live in one dictionary per configuration (copied with it) */
static NSMutableDictionary *extras(UIButtonConfiguration *c) { return dict(c, &kConfigExtras); }
static id extra(UIButtonConfiguration *c, NSString *k) { return ((NSDictionary *)get(c, &kConfigExtras))[k]; }
static void set_extra(UIButtonConfiguration *c, NSString *k, id v) { if (v) extras(c)[k] = v; else [extras(c) removeObjectForKey:k]; }

@implementation UIButtonConfiguration (UIButtonConfigurationExtras)
- (void)_isim_copyExtrasTo:(UIButtonConfiguration *)c { NSDictionary *d = get(self, &kConfigExtras); if (d) put(c, &kConfigExtras, [d mutableCopy]); }
- (UIConfigurationTextAttributesTransformer)titleTextAttributesTransformer { return extra(self, @"titleTransformer"); }
- (void)setTitleTextAttributesTransformer:(UIConfigurationTextAttributesTransformer)t { set_extra(self, @"titleTransformer", [t copy]); }
- (UIConfigurationTextAttributesTransformer)subtitleTextAttributesTransformer { return extra(self, @"subtitleTransformer"); }
- (void)setSubtitleTextAttributesTransformer:(UIConfigurationTextAttributesTransformer)t { set_extra(self, @"subtitleTransformer", [t copy]); }
- (NSLineBreakMode)titleLineBreakMode { NSNumber *n = extra(self, @"titleBreak"); return n ? n.integerValue : NSLineBreakByTruncatingTail; }
- (void)setTitleLineBreakMode:(NSLineBreakMode)m { set_extra(self, @"titleBreak", @(m)); }
- (NSLineBreakMode)subtitleLineBreakMode { NSNumber *n = extra(self, @"subtitleBreak"); return n ? n.integerValue : NSLineBreakByTruncatingTail; }
- (void)setSubtitleLineBreakMode:(NSLineBreakMode)m { set_extra(self, @"subtitleBreak", @(m)); }
- (CGFloat)imageReservation { return [extra(self, @"imageReservation") doubleValue]; }
- (void)setImageReservation:(CGFloat)r { set_extra(self, @"imageReservation", @(r)); }
- (UIConfigurationColorTransformer)imageColorTransformer { return extra(self, @"imageColor"); }
- (void)setImageColorTransformer:(UIConfigurationColorTransformer)t { set_extra(self, @"imageColor", [t copy]); }
- (UIImageSymbolConfiguration *)preferredSymbolConfigurationForImage { return extra(self, @"symbolConfiguration"); }
- (void)setPreferredSymbolConfigurationForImage:(UIImageSymbolConfiguration *)c { set_extra(self, @"symbolConfiguration", [c copy]); }
- (void)setDefaultContentInsets { self.contentInsets = [self _isim_defaultContentInsets]; }
- (UIButtonConfigurationIndicator)indicator { return [extra(self, @"indicator") integerValue]; }
- (void)setIndicator:(UIButtonConfigurationIndicator)i { set_extra(self, @"indicator", @(i)); }
- (UIConfigurationColorTransformer)indicatorColorTransformer { return extra(self, @"indicatorColor"); }
- (void)setIndicatorColorTransformer:(UIConfigurationColorTransformer)t { set_extra(self, @"indicatorColor", [t copy]); }
- (UIConfigurationColorTransformer)activityIndicatorColorTransformer { return extra(self, @"activityColor"); }
- (void)setActivityIndicatorColorTransformer:(UIConfigurationColorTransformer)t { set_extra(self, @"activityColor", [t copy]); }
- (BOOL)automaticallyUpdateForSelection { return ![extra(self, @"noSelectionLook") boolValue]; }
- (void)setAutomaticallyUpdateForSelection:(BOOL)a { set_extra(self, @"noSelectionLook", a ? nil : @YES); }
- (UIButtonConfigurationMacIdiomStyle)macIdiomStyle { return [extra(self, @"macIdiomStyle") integerValue]; }
- (void)setMacIdiomStyle:(UIButtonConfigurationMacIdiomStyle)s { set_extra(self, @"macIdiomStyle", @(s)); }
@end

/* the system colour transformers: grey at the colour's luminance, the accent colour, a grey of the label's tone */
UIConfigurationColorTransformer const UIConfigurationColorTransformerGrayscale = ^UIColor *(UIColor *c) {
    double v[4]; isim_ui_rgba(c, v);
    return [UIColor colorWithWhite:0.299 * v[0] + 0.587 * v[1] + 0.114 * v[2] alpha:v[3]];
};
UIConfigurationColorTransformer const UIConfigurationColorTransformerPreferredTint = ^UIColor *(UIColor *c) {
    double v[4]; isim_ui_rgba(c, v);
    return [UIColor.systemBlueColor colorWithAlphaComponent:v[3]];
};
UIConfigurationColorTransformer const UIConfigurationColorTransformerMonochromeTint = ^UIColor *(UIColor *c) {
    double v[4]; isim_ui_rgba(c, v);
    return [UIColor.secondaryLabelColor colorWithAlphaComponent:v[3]];
};

/* ================= UISegmentedControl ================= */
/* the actions per segment, kept in step with the segments (UIMoreControls.m reports inserts and removals) */
static NSMutableArray *segment_actions(UISegmentedControl *s) {
    NSMutableArray *a = get(s, &kSegmentActions);
    if (!a) { a = [NSMutableArray array]; put(s, &kSegmentActions, a); }
    while (a.count < s.numberOfSegments) [a addObject:NSNull.null];
    return a;
}
@implementation UISegmentedControl (UISegmentedControlExtras)
- (instancetype)initWithFrame:(CGRect)frame actions:(NSArray<UIAction *> *)actions {
    if ((self = [self initWithFrame:frame]))
        for (UIAction *a in actions) [self insertSegmentWithAction:a atIndex:self.numberOfSegments animated:NO];
    return self;
}
- (void)insertSegmentWithAction:(UIAction *)action atIndex:(NSUInteger)segment animated:(BOOL)animated {
    segment = MIN(segment, self.numberOfSegments);
    if (action.image && !action.title.length) [self insertSegmentWithImage:action.image atIndex:segment animated:animated];
    else [self insertSegmentWithTitle:action.title atIndex:segment animated:animated];
    segment_actions(self)[segment] = action ?: (id)NSNull.null;
}
- (void)setAction:(UIAction *)action forSegmentAtIndex:(NSUInteger)segment {
    if (segment >= self.numberOfSegments) return;
    if (action.image && !action.title.length) [self setImage:action.image forSegmentAtIndex:segment];
    else [self setTitle:action.title forSegmentAtIndex:segment];
    segment_actions(self)[segment] = action ?: (id)NSNull.null;
}
- (UIAction *)actionForSegmentAtIndex:(NSUInteger)segment {
    if (segment >= self.numberOfSegments) return nil;
    id a = segment_actions(self)[segment]; return a == NSNull.null ? nil : a;
}
- (NSInteger)segmentIndexForActionIdentifier:(NSString *)identifier {
    NSArray *a = segment_actions(self);
    for (NSUInteger i = 0; i < self.numberOfSegments; i++) if (a[i] != NSNull.null && [((UIAction *)a[i]).identifier isEqualToString:identifier]) return (NSInteger)i;
    return UISegmentedControlNoSegment;
}
- (void)_isim_segmentInsertedAt:(NSUInteger)i { NSMutableArray *a = get(self, &kSegmentActions); if (a && i <= a.count) [a insertObject:NSNull.null atIndex:i]; }
- (void)_isim_segmentRemovedAt:(NSUInteger)i {
    NSMutableArray *a = get(self, &kSegmentActions); if (a && i < a.count) [a removeObjectAtIndex:i];
    NSMutableDictionary *o = get(self, &kSegmentOffsets), *moved = [NSMutableDictionary dictionary];
    for (NSNumber *k in o) if (k.unsignedIntegerValue != i) moved[@(k.unsignedIntegerValue > i ? k.unsignedIntegerValue - 1 : k.unsignedIntegerValue)] = o[k];
    if (o) put(self, &kSegmentOffsets, moved);
}
- (void)_isim_segmentsRemoved { put(self, &kSegmentActions, nil); put(self, &kSegmentOffsets, nil); }
/* the selected segment's action runs with the value change */
- (void)_isim_runSegmentAction {
    NSInteger i = self.selectedSegmentIndex;
    UIAction *a = i >= 0 ? [self actionForSegmentAtIndex:(NSUInteger)i] : nil;
    if (!a) return;
    a.sender = self;
    if (a.handler) a.handler(a);
}
- (CGFloat)widthForSegmentAtIndex:(NSUInteger)segment { return [self _isim_explicitWidthForSegment:segment]; }
- (void)setContentOffset:(CGSize)offset forSegmentAtIndex:(NSUInteger)segment { dict(self, &kSegmentOffsets)[@(segment)] = [NSValue valueWithCGSize:offset]; isim_ui_set_needs_display(); }
- (CGSize)contentOffsetForSegmentAtIndex:(NSUInteger)segment { return [((NSDictionary *)get(self, &kSegmentOffsets))[@(segment)] CGSizeValue]; }
- (void)setContentPositionAdjustment:(UIOffset)adjustment forSegmentType:(UISegmentedControlSegment)type barMetrics:(UIBarMetrics)metrics {
    dict(self, &kSegmentAdjust)[[NSString stringWithFormat:@"%ld-%ld", (long)type, (long)metrics]] = [NSValue valueWithUIOffset:adjustment];
    isim_ui_set_needs_display();
}
- (UIOffset)contentPositionAdjustmentForSegmentType:(UISegmentedControlSegment)type barMetrics:(UIBarMetrics)metrics {
    return [((NSDictionary *)get(self, &kSegmentAdjust))[[NSString stringWithFormat:@"%ld-%ld", (long)type, (long)metrics]] UIOffsetValue];
}
- (void)setDividerImage:(UIImage *)image forLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r barMetrics:(UIBarMetrics)metrics {
    NSString *k = [NSString stringWithFormat:@"%lu-%lu-%ld", (unsigned long)l, (unsigned long)r, (long)metrics];
    if (image) dict(self, &kSegmentDividers)[k] = image; else [dict(self, &kSegmentDividers) removeObjectForKey:k];
}
- (UIImage *)dividerImageForLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r barMetrics:(UIBarMetrics)metrics {
    return ((NSDictionary *)get(self, &kSegmentDividers))[[NSString stringWithFormat:@"%lu-%lu-%ld", (unsigned long)l, (unsigned long)r, (long)metrics]];
}
@end

/* ================= UIStepper ================= */
@implementation UIStepper (UIStepperExtras)
- (void)setIncrementImage:(UIImage *)image forState:(UIControlState)state { set_state(self, &kStepperInc, image, state); }
- (UIImage *)incrementImageForState:(UIControlState)state { return for_state(self, &kStepperInc, state); }
- (void)setDecrementImage:(UIImage *)image forState:(UIControlState)state { set_state(self, &kStepperDec, image, state); }
- (UIImage *)decrementImageForState:(UIControlState)state { return for_state(self, &kStepperDec, state); }
- (void)setDividerImage:(UIImage *)image forLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r {
    NSString *k = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)l, (unsigned long)r];
    if (image) dict(self, &kStepperDividers)[k] = image; else [dict(self, &kStepperDividers) removeObjectForKey:k];
}
- (UIImage *)dividerImageForLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r {
    return ((NSDictionary *)get(self, &kStepperDividers))[[NSString stringWithFormat:@"%lu-%lu", (unsigned long)l, (unsigned long)r]];
}
@end

/* ================= UISwitch, UISlider ================= */
@implementation UISwitch (UISwitchExtras)
- (UISwitchStyle)preferredStyle { return [get(self, &kSwitchStyle) integerValue]; }
- (void)setPreferredStyle:(UISwitchStyle)s { put(self, &kSwitchStyle, @(s)); }
- (UISwitchStyle)style { return UISwitchStyleSliding; }
- (NSString *)title { return get(self, &kSwitchTitle); }
- (void)setTitle:(NSString *)t { put(self, &kSwitchTitle, [t copy]); }
- (UIImage *)onImage { return get(self, &kSwitchOn); }
- (void)setOnImage:(UIImage *)i { put(self, &kSwitchOn, i); }
- (UIImage *)offImage { return get(self, &kSwitchOff); }
- (void)setOffImage:(UIImage *)i { put(self, &kSwitchOff, i); }
@end
@implementation UISlider (UISliderExtras)
- (UIBehavioralStyle)preferredBehavioralStyle { return [get(self, &kSliderBehavior) unsignedIntegerValue]; }
- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)s { put(self, &kSliderBehavior, @(s)); }
- (UIBehavioralStyle)behavioralStyle { return UIBehavioralStylePad; }
@end

/* ================= UIProgressView ================= */
/* follows the progress's fractionCompleted (on the main thread, as UIKit does) */
@interface __IsimProgressObserver : NSObject
@property (nonatomic, weak) UIProgressView *view;
@property (nonatomic, strong) NSProgress *progress;
@end
@implementation __IsimProgressObserver
- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    __weak UIProgressView *v = self.view; NSProgress *p = self.progress;
    void (^update)(void) = ^{ v.progress = (float)p.fractionCompleted; };
    if (NSThread.isMainThread) update(); else dispatch_async(dispatch_get_main_queue(), update);
}
- (void)dealloc { [_progress removeObserver:self forKeyPath:@"fractionCompleted"]; }
@end
@implementation UIProgressView (UIProgressViewExtras)
- (NSProgress *)observedProgress { return ((__IsimProgressObserver *)get(self, &kObserved)).progress; }
- (void)setObservedProgress:(NSProgress *)p {
    put(self, &kObserved, nil);                          /* (the old observer stops observing) */
    if (!p) return;
    __IsimProgressObserver *o = [__IsimProgressObserver new]; o.view = self; o.progress = p;
    [p addObserver:o forKeyPath:@"fractionCompleted" options:0 context:NULL];
    put(self, &kObserved, o);
    self.progress = (float)p.fractionCompleted;
}
- (UIImage *)progressImage { return get(self, &kProgressImage); }
- (void)setProgressImage:(UIImage *)i { put(self, &kProgressImage, i); isim_ui_set_needs_display(); }
- (UIImage *)trackImage { return get(self, &kTrackImage); }
- (void)setTrackImage:(UIImage *)i { put(self, &kTrackImage, i); isim_ui_set_needs_display(); }
@end

/* ================= UIPageControl ================= */
static char kPageBackground, kPageInteraction, kPageContinuous, kPageDirection, kPageImage, kPageImages, kPageCurrentImage, kPageCurrentImages, kPageProgress;
@implementation UIPageControlProgress { __weak UIPageControl *_pageControl; }
- (instancetype)init { return [super init]; }
- (UIPageControl *)_isim_pageControl { return _pageControl; }
- (void)_isim_setPageControl:(UIPageControl *)p { _pageControl = p; [self _isim_pageChanged]; }
- (void)setCurrentProgress:(float)p { _currentProgress = fmaxf(0, fminf(1, p)); isim_ui_set_needs_display(); }
- (BOOL)isProgressVisible { return YES; }
/* a new page starts at the delegate's initial progress */
- (void)_isim_pageChanged {
    UIPageControl *pc = _pageControl; id<UIPageControlProgressDelegate> d = self.delegate;
    self.currentProgress = pc && [d respondsToSelector:@selector(pageControlProgress:initialProgressForPage:)] ? [d pageControlProgress:self initialProgressForPage:pc.currentPage] : 0;
}
- (void)_isim_visibilityChanged {
    id<UIPageControlProgressDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(pageControlProgressVisibilityDidChange:)]) [d pageControlProgressVisibilityDidChange:self];
    [_pageControl invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
@end

/* the timer fills the current page's progress over its duration, then moves to the next page (sending the value
   change, as a tap does) */
@implementation UIPageControlTimerProgress { NSMutableDictionary<NSNumber *, NSNumber *> *_durations; CADisplayLink *_link; double _last; }
@dynamic delegate;
- (instancetype)initWithPreferredDuration:(NSTimeInterval)d {
    if ((self = [super init])) { _preferredDuration = d; _durations = [NSMutableDictionary dictionary]; }
    return self;
}
- (BOOL)isProgressVisible { return _running; }
- (void)setDuration:(NSTimeInterval)d forPage:(NSInteger)page { _durations[@(page)] = @(d); }
- (NSTimeInterval)durationForPage:(NSInteger)page { NSNumber *n = _durations[@(page)]; return n ? n.doubleValue : _preferredDuration; }
- (void)_isim_changed {
    id<UIPageControlTimerProgressDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(pageControlTimerProgressDidChange:)]) [d pageControlTimerProgressDidChange:self];
}
- (void)resumeTimer {
    if (_running) return;
    _running = YES; _last = CACurrentMediaTime();
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(_isim_tick:)];
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    NSLog(@"isim: page control timer resumed");
    [self _isim_visibilityChanged]; [self _isim_changed];
}
- (void)pauseTimer {
    if (!_running) return;
    _running = NO; [_link invalidate]; _link = nil;
    NSLog(@"isim: page control timer paused");
    [self _isim_visibilityChanged]; [self _isim_changed];
}
- (void)_isim_tick:(CADisplayLink *)l {
    double now = CACurrentMediaTime(), dt = now - _last; _last = now;
    UIPageControl *pc = [self _isim_pageControl];
    if (!pc) return;
    NSTimeInterval dur = [self durationForPage:pc.currentPage];
    float p = self.currentProgress + (dur > 0 ? (float)(dt / dur) : 1);
    if (p < 1) { self.currentProgress = p; return; }
    NSInteger next = pc.currentPage + 1;
    if (next >= pc.numberOfPages) {
        if (!_resetsToInitialPageAfterEnd) { self.currentProgress = 1; [self pauseTimer]; return; }
        next = 0;
    }
    id<UIPageControlTimerProgressDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(pageControlTimerProgress:shouldAdvanceToPage:)] && ![d pageControlTimerProgress:self shouldAdvanceToPage:next]) { self.currentProgress = 1; return; }
    pc.currentPage = next;
    NSLog(@"isim: page control timer advanced to page %ld", (long)next);
    [pc _isim_sendEvents:UIControlEventValueChanged withEvent:nil];
}
- (void)dealloc { [_link invalidate]; }
@end

@implementation UIPageControl (UIPageControlExtras)
- (UIPageControlBackgroundStyle)backgroundStyle { return [get(self, &kPageBackground) integerValue]; }
- (void)setBackgroundStyle:(UIPageControlBackgroundStyle)s { put(self, &kPageBackground, @(s)); isim_ui_set_needs_display(); }
- (UIPageControlInteractionState)interactionState { return [get(self, &kPageInteraction) integerValue]; }
- (void)_isim_setInteractionState:(UIPageControlInteractionState)s { put(self, &kPageInteraction, @(s)); isim_ui_set_needs_display(); }
- (BOOL)allowsContinuousInteraction { NSNumber *n = get(self, &kPageContinuous); return n ? n.boolValue : YES; }
- (void)setAllowsContinuousInteraction:(BOOL)a { put(self, &kPageContinuous, @(a)); }
- (UIPageControlDirection)direction { return [get(self, &kPageDirection) integerValue]; }
- (void)setDirection:(UIPageControlDirection)d { put(self, &kPageDirection, @(d)); [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (UIImage *)preferredIndicatorImage { return get(self, &kPageImage); }
- (void)setPreferredIndicatorImage:(UIImage *)i { put(self, &kPageImage, i); isim_ui_set_needs_display(); }
- (UIImage *)indicatorImageForPage:(NSInteger)page { return ((NSDictionary *)get(self, &kPageImages))[@(page)]; }
- (void)setIndicatorImage:(UIImage *)i forPage:(NSInteger)page { if (i) dict(self, &kPageImages)[@(page)] = i; else [dict(self, &kPageImages) removeObjectForKey:@(page)]; isim_ui_set_needs_display(); }
- (UIImage *)preferredCurrentPageIndicatorImage { return get(self, &kPageCurrentImage); }
- (void)setPreferredCurrentPageIndicatorImage:(UIImage *)i { put(self, &kPageCurrentImage, i); isim_ui_set_needs_display(); }
- (UIImage *)currentPageIndicatorImageForPage:(NSInteger)page { return ((NSDictionary *)get(self, &kPageCurrentImages))[@(page)]; }
- (void)setCurrentPageIndicatorImage:(UIImage *)i forPage:(NSInteger)page { if (i) dict(self, &kPageCurrentImages)[@(page)] = i; else [dict(self, &kPageCurrentImages) removeObjectForKey:@(page)]; isim_ui_set_needs_display(); }
- (UIPageControlProgress *)progress { return get(self, &kPageProgress); }
- (void)setProgress:(UIPageControlProgress *)p {
    UIPageControlProgress *old = get(self, &kPageProgress);
    if (old == p) return;
    if ([old isKindOfClass:[UIPageControlTimerProgress class]]) [(UIPageControlTimerProgress *)old pauseTimer];
    [old _isim_setPageControl:nil];
    put(self, &kPageProgress, p);
    [p _isim_setPageControl:self];
    [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
@end
