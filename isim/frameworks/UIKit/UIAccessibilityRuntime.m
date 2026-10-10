/* Accessibility runtime: the accessibility tree (elements, containers, accessibilityElements order, custom actions and
 * rotors), UIAccessibilityPostNotification, a VoiceOver simulation, the Settings > Accessibility values (VoiceOver,
 * Larger Text / Dynamic Type, Bold Text, Increase Contrast, Reduce Motion, Reduce Transparency) and the Large Content
 * Viewer.
 *
 * VoiceOver: Settings > Accessibility > VoiceOver (global preference ISIMVoiceOver) or the script command
 * `voiceover on|off|next|prev|activate|increment|decrement|action|escape|read`. Elements are visited top to bottom,
 * left to right (containers' accessibilityElements keep their own order; an accessibilityViewIsModal view hides its
 * siblings). The focused element gets the black VoiceOver cursor; its description ("label, value, traits" then the hint)
 * is logged ("isim: VoiceOver: ...") and spoken through the host TTS (espeak-ng) when the host has audio. While it runs
 * touches work like VoiceOver: a tap focuses the element under the finger, a double tap activates the focused one,
 * a horizontal swipe moves to the next / previous element. */
#import "UIKitInputPrivate.h"
#import <UIKit/UIContentSizeCategory.h>
#import <objc/runtime.h>
#include <math.h>

/* ================= traits, notifications ================= */
const UIAccessibilityTraits UIAccessibilityTraitStartsMediaSession = 1 << 11, UIAccessibilityTraitAllowsDirectInteraction = 1 << 13,
    UIAccessibilityTraitCausesPageTurn = 1 << 14, UIAccessibilityTraitTabBar = 1 << 15, UIAccessibilityTraitSupportsZoom = 1 << 17,
    UIAccessibilityTraitToggleButton = 1ULL << 53;
const UIAccessibilityNotifications UIAccessibilityScreenChangedNotification = 1000, UIAccessibilityLayoutChangedNotification = 1001,
    UIAccessibilityAnnouncementNotification = 1008, UIAccessibilityPageScrolledNotification = 1009,
    UIAccessibilityPauseAssistiveTechnologyNotification = 1016, UIAccessibilityResumeAssistiveTechnologyNotification = 1017;
NSNotificationName const UIAccessibilityAnnouncementDidFinishNotification = @"UIAccessibilityAnnouncementDidFinishNotification";
NSNotificationName const UIAccessibilityElementFocusedNotification = @"UIAccessibilityElementFocusedNotification";
NSString *const UIAccessibilityAnnouncementKeyStringValue = @"UIAccessibilityAnnouncementKeyStringValue";
NSString *const UIAccessibilityAnnouncementKeyWasSuccessful = @"UIAccessibilityAnnouncementKeyWasSuccessful";
NSString *const UIAccessibilityFocusedElementKey = @"UIAccessibilityFocusedElementKey";
NSNotificationName const UIAccessibilityVoiceOverStatusDidChangeNotification = @"UIAccessibilityVoiceOverStatusDidChangeNotification";
NSNotificationName const UIAccessibilitySwitchControlStatusDidChangeNotification = @"UIAccessibilitySwitchControlStatusDidChangeNotification";
NSNotificationName const UIAccessibilityReduceMotionStatusDidChangeNotification = @"UIAccessibilityReduceMotionStatusDidChangeNotification";
NSNotificationName const UIAccessibilityBoldTextStatusDidChangeNotification = @"UIAccessibilityBoldTextStatusDidChangeNotification";
NSNotificationName const UIAccessibilityReduceTransparencyStatusDidChangeNotification = @"UIAccessibilityReduceTransparencyStatusDidChangeNotification";
NSNotificationName const UIAccessibilityDarkerSystemColorsStatusDidChangeNotification = @"UIAccessibilityDarkerSystemColorsStatusDidChangeNotification";
NSNotificationName const UIAccessibilityDifferentiateWithoutColorDidChangeNotification = @"UIAccessibilityDifferentiateWithoutColorDidChangeNotification";

/* ================= settings ================= */
UIContentSizeCategory const UIContentSizeCategoryUnspecified = @"_UICTContentSizeCategoryUnspecified";
UIContentSizeCategory const UIContentSizeCategoryExtraSmall = @"UICTContentSizeCategoryXS";
UIContentSizeCategory const UIContentSizeCategorySmall = @"UICTContentSizeCategoryS";
UIContentSizeCategory const UIContentSizeCategoryMedium = @"UICTContentSizeCategoryM";
UIContentSizeCategory const UIContentSizeCategoryLarge = @"UICTContentSizeCategoryL";
UIContentSizeCategory const UIContentSizeCategoryExtraLarge = @"UICTContentSizeCategoryXL";
UIContentSizeCategory const UIContentSizeCategoryExtraExtraLarge = @"UICTContentSizeCategoryXXL";
UIContentSizeCategory const UIContentSizeCategoryExtraExtraExtraLarge = @"UICTContentSizeCategoryXXXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityMedium = @"UICTContentSizeCategoryAccessibilityM";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityLarge = @"UICTContentSizeCategoryAccessibilityL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraLarge = @"UICTContentSizeCategoryAccessibilityXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraLarge = @"UICTContentSizeCategoryAccessibilityXXL";
UIContentSizeCategory const UIContentSizeCategoryAccessibilityExtraExtraExtraLarge = @"UICTContentSizeCategoryAccessibilityXXXL";
NSNotificationName const UIContentSizeCategoryDidChangeNotification = @"UIContentSizeCategoryDidChangeNotification";
NSString *const UIContentSizeCategoryNewValueKey = @"UIContentSizeCategoryNewValueKey";

static NSArray<NSString *> *categories(void) {
    return @[UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall, UIContentSizeCategoryMedium, UIContentSizeCategoryLarge,
             UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge, UIContentSizeCategoryExtraExtraExtraLarge,
             UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityLarge, UIContentSizeCategoryAccessibilityExtraLarge,
             UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
}
/* body text size per category (iOS: 14 15 16 17 19 21 23, accessibility 28 33 40 47 53) */
static const double body_sizes[] = { 14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53 };
static NSInteger category_index(NSString *c) { NSUInteger i = [categories() indexOfObject:c]; return i == NSNotFound ? 3 : (NSInteger)i; }
BOOL UIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory c) { return category_index(c) >= 7; }
NSComparisonResult UIContentSizeCategoryCompareToCategory(UIContentSizeCategory a, UIContentSizeCategory b) {
    NSInteger x = category_index(a), y = category_index(b); return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame;
}

extern NSDictionary *isim_global_preferences(void);
static BOOL env_flag(const char *name) { const char *v = getenv(name); return v && *v && strcmp(v, "0"); }
static BOOL pref(NSString *key, const char *env) { return [isim_global_preferences()[key] boolValue] || (env && env_flag(env)); }
static BOOL vo_script_override, vo_script_on;               /* `voiceover on|off` in this app */
static NSString *settings_category(void) {
    NSString *c = isim_global_preferences()[@"ISIMContentSizeCategory"];
    const char *e = getenv("ISIM_CONTENT_SIZE");
    if (e && *e) c = @(e);
    return [categories() containsObject:c] ? c : UIContentSizeCategoryLarge;
}
NSString *isim_ui_content_size_category(void) { return settings_category(); }
CGFloat isim_ui_content_size_multiplier(void) { return body_sizes[category_index(settings_category())] / 17.0; }
/* readableContentGuide's maximum width per category: iOS's widths for the standard categories; the accessibility
   categories scale the Large width with the body text size (adapted) */
CGFloat isim_ui_readable_width(NSString *category) {
    static const double widths[] = { 560, 600, 632, 672, 728, 792, 856 };
    if ([category isEqualToString:UIContentSizeCategoryUnspecified] || !category.length) category = settings_category();
    NSInteger i = category_index(category);
    return i < 7 ? widths[i] : round(672 * body_sizes[i] / 17.0);
}
BOOL UIAccessibilityIsVoiceOverRunning(void) { return vo_script_override ? vo_script_on : pref(@"ISIMVoiceOver", NULL); }
BOOL UIAccessibilityIsReduceMotionEnabled(void) { return pref(@"ISIMReduceMotion", "ISIM_REDUCE_MOTION"); }
BOOL UIAccessibilityIsBoldTextEnabled(void) { return pref(@"ISIMBoldText", "ISIM_BOLD_TEXT"); }
BOOL UIAccessibilityIsReduceTransparencyEnabled(void) { return pref(@"ISIMReduceTransparency", "ISIM_REDUCE_TRANSPARENCY"); }
BOOL UIAccessibilityIsDarkerSystemColorsEnabled(void) { return pref(@"ISIMIncreaseContrast", "ISIM_INCREASE_CONTRAST"); }
BOOL UIAccessibilityShouldDifferentiateWithoutColor(void) { return pref(@"ISIMDifferentiateWithoutColor", NULL); }
BOOL UIAccessibilityIsInvertColorsEnabled(void) { return NO; }
BOOL UIAccessibilityIsGrayscaleEnabled(void) { return NO; }
static BOOL sc_script_override, sc_script_on;               /* `switchcontrol on|off` in this app */
BOOL UIAccessibilityIsSwitchControlRunning(void) { return sc_script_override ? sc_script_on : pref(@"ISIMSwitchControl", NULL); }
BOOL UIAccessibilityIsClosedCaptioningEnabled(void) { return NO; }
BOOL UIAccessibilityIsOnOffSwitchLabelsEnabled(void) { return pref(@"ISIMOnOffLabels", NULL); }
BOOL UIAccessibilityButtonShapesEnabled(void) { return pref(@"ISIMButtonShapes", NULL); }
BOOL UIAccessibilityPrefersCrossFadeTransitions(void) { return NO; }
BOOL UIAccessibilityIsVideoAutoplayEnabled(void) { return YES; }
CGFloat isim_ui_bold_text_weight(CGFloat w) {
    if (!UIAccessibilityIsBoldTextEnabled()) return w;
    return w < UIFontWeightMedium ? UIFontWeightSemibold : w < UIFontWeightBold ? UIFontWeightBold : w < UIFontWeightHeavy ? UIFontWeightHeavy : w;
}

/* fonts remember their text style (preferredFontForTextStyle:, UIFontMetrics) to follow category changes */
static char k_style, k_base;
void isim_ui_font_set_text_style(UIFont *f, NSString *style) { if (f) objc_setAssociatedObject(f, &k_style, style, OBJC_ASSOCIATION_COPY_NONATOMIC); }
static NSString *font_style(UIFont *f) { return f ? objc_getAssociatedObject(f, &k_style) : nil; }
NSString *isim_ui_font_text_style(UIFont *f) { return font_style(f); }

/* UITraitCollection's preferredContentSizeCategory, accessibilityContrast, legibilityWeight: UITraits.m */
@implementation UIApplication (UIContentSizeCategory)
- (UIContentSizeCategory)preferredContentSizeCategory { return settings_category(); }
@end
@implementation UIFont (UIContentSizeCategory)
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)t {
    UIFont *f = [self preferredFontForTextStyle:style];
    NSString *c = t ? t.preferredContentSizeCategory : nil;
    if (!c || [c isEqualToString:UIContentSizeCategoryUnspecified] || [c isEqualToString:settings_category()]) return f;
    UIFont *g = [f fontWithSize:round(f.pointSize / isim_ui_content_size_multiplier() * body_sizes[category_index(c)] / 17.0)];
    isim_ui_font_set_text_style(g, style);
    return g;
}
@end
static char k_adjusts;
@implementation UITextField (UIContentSizeCategoryAdjusting)
- (BOOL)adjustsFontForContentSizeCategory { return [objc_getAssociatedObject(self, &k_adjusts) boolValue]; }
- (void)setAdjustsFontForContentSizeCategory:(BOOL)a { objc_setAssociatedObject(self, &k_adjusts, @(a), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

@implementation UIFontMetrics { NSString *_style; }
+ (UIFontMetrics *)defaultMetrics { return [[self alloc] initForTextStyle:UIFontTextStyleBody]; }
+ (instancetype)metricsForTextStyle:(UIFontTextStyle)s { return [[self alloc] initForTextStyle:s]; }
- (instancetype)initForTextStyle:(UIFontTextStyle)s { if ((self = [super init])) _style = [s copy] ?: UIFontTextStyleBody; return self; }
- (CGFloat)_factorFor:(NSString *)c { if ([c isEqualToString:UIContentSizeCategoryUnspecified]) c = nil; return body_sizes[category_index(c ?: settings_category())] / 17.0; }
- (UIFont *)scaledFontForFont:(UIFont *)f { return [self scaledFontForFont:f maximumPointSize:0]; }
- (UIFont *)scaledFontForFont:(UIFont *)f maximumPointSize:(CGFloat)max {
    CGFloat s = round(f.pointSize * [self _factorFor:nil]);
    if (max > 0) s = MIN(s, max);
    UIFont *g = [f fontWithSize:s];
    isim_ui_font_set_text_style(g, _style);
    objc_setAssociatedObject(g, &k_base, @[f, @(max)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return g;
}
- (UIFont *)scaledFontForFont:(UIFont *)f compatibleWithTraitCollection:(UITraitCollection *)t {
    return [f fontWithSize:round(f.pointSize * [self _factorFor:t.preferredContentSizeCategory])];
}
- (CGFloat)scaledValueForValue:(CGFloat)v { return v * [self _factorFor:nil]; }
- (CGFloat)scaledValueForValue:(CGFloat)v compatibleWithTraitCollection:(UITraitCollection *)t { return v * [self _factorFor:t.preferredContentSizeCategory]; }
@end
/* a font for the current category: the same text style, or the same UIFontMetrics scaling of its base font */
static UIFont *refreshed_font(UIFont *f) {
    NSString *style = font_style(f);
    if (!style) return nil;
    NSArray *base = objc_getAssociatedObject(f, &k_base);
    if (base) return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:base[0] maximumPointSize:[base[1] doubleValue]];
    UIFont *g = [UIFont preferredFontForTextStyle:style];
    return f.pointSize == g.pointSize && f._isim_weight == g._isim_weight ? nil : g;
}
static void adjust_fonts(UIView *v) {
    BOOL adjusts = [v respondsToSelector:@selector(adjustsFontForContentSizeCategory)] && [(id)v adjustsFontForContentSizeCategory];
    if (adjusts && [v respondsToSelector:@selector(font)]) {
        UIFont *g = refreshed_font([(id)v font]);
        if (g) { [(id)v setFont:g]; [v invalidateIntrinsicContentSize]; [v setNeedsLayout]; }
    }
    for (UIView *s in v.subviews) adjust_fonts(s);
}

/* ================= stored accessibility properties (the basic ones live in UIInput.m) ================= */
static char k_frame, k_path, k_act, k_lang, k_group, k_responds, k_nav, k_inputlabels, k_elements, k_actions, k_rotors;
@implementation NSObject (UIAccessibilityExtras)
- (CGRect)accessibilityFrame {
    NSValue *v = objc_getAssociatedObject(self, &k_frame);
    if (v) return v.CGRectValue;
    if ([self isKindOfClass:[UIView class]]) {
        UIView *view = (UIView *)self;
        if (!view.window) return CGRectZero;
        CGRect r = [view convertRect:view.bounds toView:nil];
        r.origin = [view.window convertPoint:r.origin toView:nil];
        return r;
    }
    return CGRectZero;
}
- (void)setAccessibilityFrame:(CGRect)r { objc_setAssociatedObject(self, &k_frame, [NSValue valueWithCGRect:r], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIBezierPath *)accessibilityPath { return objc_getAssociatedObject(self, &k_path); }
- (void)setAccessibilityPath:(UIBezierPath *)p { objc_setAssociatedObject(self, &k_path, p, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (CGPoint)accessibilityActivationPoint {
    NSValue *v = objc_getAssociatedObject(self, &k_act);
    if (v) return v.CGPointValue;
    CGRect f = self.accessibilityFrame; return CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
}
- (void)setAccessibilityActivationPoint:(CGPoint)p { objc_setAssociatedObject(self, &k_act, [NSValue valueWithCGPoint:p], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)accessibilityLanguage { return objc_getAssociatedObject(self, &k_lang); }
- (void)setAccessibilityLanguage:(NSString *)l { objc_setAssociatedObject(self, &k_lang, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)shouldGroupAccessibilityChildren { return [objc_getAssociatedObject(self, &k_group) boolValue]; }
- (void)setShouldGroupAccessibilityChildren:(BOOL)b { objc_setAssociatedObject(self, &k_group, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)accessibilityRespondsToUserInteraction { NSNumber *n = objc_getAssociatedObject(self, &k_responds); return n ? n.boolValue : [self isKindOfClass:[UIControl class]]; }
- (void)setAccessibilityRespondsToUserInteraction:(BOOL)b { objc_setAssociatedObject(self, &k_responds, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle { return [objc_getAssociatedObject(self, &k_nav) integerValue]; }
- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)s { objc_setAssociatedObject(self, &k_nav, @(s), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray<NSString *> *)accessibilityUserInputLabels { return objc_getAssociatedObject(self, &k_inputlabels); }
- (void)setAccessibilityUserInputLabels:(NSArray<NSString *> *)a { objc_setAssociatedObject(self, &k_inputlabels, a, OBJC_ASSOCIATION_COPY_NONATOMIC); }
/* containers */
- (NSArray *)accessibilityElements { return objc_getAssociatedObject(self, &k_elements); }
- (void)setAccessibilityElements:(NSArray *)a { objc_setAssociatedObject(self, &k_elements, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSInteger)accessibilityElementCount { return (NSInteger)self.accessibilityElements.count; }
- (id)accessibilityElementAtIndex:(NSInteger)i { NSArray *a = self.accessibilityElements; return i >= 0 && i < (NSInteger)a.count ? a[(NSUInteger)i] : nil; }
- (NSInteger)indexOfAccessibilityElement:(id)e { NSUInteger i = [self.accessibilityElements indexOfObject:e]; return i == NSNotFound ? NSNotFound : (NSInteger)i; }
/* actions */
- (BOOL)accessibilityActivate { return NO; }
- (void)accessibilityIncrement {}
- (void)accessibilityDecrement {}
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)d { return NO; }
- (BOOL)accessibilityPerformEscape { return NO; }
- (BOOL)accessibilityPerformMagicTap { return NO; }
- (NSArray *)accessibilityCustomActions { return objc_getAssociatedObject(self, &k_actions); }
- (void)setAccessibilityCustomActions:(NSArray *)a { objc_setAssociatedObject(self, &k_actions, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray *)accessibilityCustomRotors { return objc_getAssociatedObject(self, &k_rotors); }
- (void)setAccessibilityCustomRotors:(NSArray *)a { objc_setAssociatedObject(self, &k_rotors, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (void)accessibilityElementDidBecomeFocused {}
- (void)accessibilityElementDidLoseFocus {}
@end

/* hooks for SwiftUI's accessibilityAction / accessibilityAdjustableAction / accessibilitySortPriority */
static char k_act_handler, k_adj_handler, k_sort;
@implementation NSObject (IsimAccessibilityHooks)
- (void)_isim_setAccessibilityActivateHandler:(BOOL (^)(void))h { objc_setAssociatedObject(self, &k_act_handler, h, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (void)_isim_setAccessibilityAdjustHandler:(void (^)(NSInteger))h { objc_setAssociatedObject(self, &k_adj_handler, h, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (void)_isim_setAccessibilitySortPriority:(double)p { objc_setAssociatedObject(self, &k_sort, @(p), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
static double sort_priority(id e) {
    for (id x = e; x; x = [x isKindOfClass:[UIView class]] ? ((UIView *)x).superview : nil) {
        NSNumber *n = objc_getAssociatedObject(x, &k_sort);
        if (n) return n.doubleValue;
    }
    return 0;
}

/* UIKit's defaults for its controls */
@implementation UISlider (IsimAccessibility)
- (void)accessibilityIncrement { [self setValue:self.value + (self.maximumValue - self.minimumValue) / 10 animated:NO]; [self _isim_sendEvents:UIControlEventValueChanged withEvent:nil]; }
- (void)accessibilityDecrement { [self setValue:self.value - (self.maximumValue - self.minimumValue) / 10 animated:NO]; [self _isim_sendEvents:UIControlEventValueChanged withEvent:nil]; }
@end
static NSString *default_value(id e) {
    if ([e isKindOfClass:[UISwitch class]]) return ((UISwitch *)e).on ? @"1" : @"0";
    if ([e isKindOfClass:[UISlider class]]) { UISlider *s = e; double f = s.maximumValue > s.minimumValue ? (s.value - s.minimumValue) / (s.maximumValue - s.minimumValue) : 0; return [NSString stringWithFormat:@"%.0f%%", f * 100]; }
    if ([e isKindOfClass:[UITextField class]]) return ((UITextField *)e).text;
    if ([e isKindOfClass:[UITextView class]]) return ((UITextView *)e).text;
    if ([e isKindOfClass:[UISegmentedControl class]]) { UISegmentedControl *s = e; return s.selectedSegmentIndex >= 0 ? [s titleForSegmentAtIndex:(NSUInteger)s.selectedSegmentIndex] : nil; }
    return nil;
}
static UIAccessibilityTraits effective_traits(id e) {
    UIAccessibilityTraits t = [e accessibilityTraits];
    if (objc_getAssociatedObject(e, &k_adj_handler)) t |= UIAccessibilityTraitAdjustable;
    if ([e isKindOfClass:[UISlider class]]) t |= UIAccessibilityTraitAdjustable;
    if ([e isKindOfClass:[UISwitch class]]) t |= UIAccessibilityTraitButton | UIAccessibilityTraitToggleButton;
    if ([e isKindOfClass:[UIControl class]] && !((UIControl *)e).enabled) t |= UIAccessibilityTraitNotEnabled;
    return t;
}
static BOOL is_element(id e) {
    return [e isAccessibilityElement] || [e isKindOfClass:[UITextView class]];      /* text views are elements in UIKit */
}

/* ================= UIAccessibilityElement, custom actions, rotors ================= */
@implementation UIAccessibilityElement
@synthesize accessibilityIdentifier = _accessibilityIdentifier;
- (instancetype)initWithAccessibilityContainer:(id)c { if ((self = [super init])) { _accessibilityContainer = c; self.isAccessibilityElement = YES; } return self; }
- (CGRect)accessibilityFrame {
    id c = _accessibilityContainer;
    if (!CGRectIsEmpty(_accessibilityFrameInContainerSpace) && [c isKindOfClass:[UIView class]] && ((UIView *)c).window) {
        UIView *v = c;
        CGRect r = [v convertRect:_accessibilityFrameInContainerSpace toView:nil];
        r.origin = [v.window convertPoint:r.origin toView:nil];
        return r;
    }
    return [super accessibilityFrame];
}
@end
@implementation UIAccessibilityCustomAction
- (instancetype)initWithName:(NSString *)n target:(id)t selector:(SEL)s { if ((self = [super init])) { _name = [n copy]; _target = t; _selector = s; } return self; }
- (instancetype)initWithName:(NSString *)n actionHandler:(UIAccessibilityCustomActionHandler)h { if ((self = [super init])) { _name = [n copy]; _actionHandler = [h copy]; } return self; }
- (BOOL)_isim_perform {
    if (_actionHandler) return _actionHandler(self);
    id t = _target;
    if (!t || ![t respondsToSelector:_selector]) return NO;
    /* selectors take the action (performAction:) or nothing; both return BOOL by convention */
    if ([NSStringFromSelector(_selector) hasSuffix:@":"]) return ((BOOL (*)(id, SEL, id))[t methodForSelector:_selector])(t, _selector, self);
    return ((BOOL (*)(id, SEL))[t methodForSelector:_selector])(t, _selector);
}
@end
@implementation UIAccessibilityCustomRotorSearchPredicate @end
@implementation UIAccessibilityCustomRotorItemResult
- (instancetype)initWithTargetElement:(id<NSObject>)e targetRange:(UITextRange *)r { if ((self = [super init])) { _targetElement = e; _targetRange = r; } return self; }
@end
@implementation UIAccessibilityCustomRotor
- (instancetype)initWithName:(NSString *)n itemSearchBlock:(UIAccessibilityCustomRotorSearch)b { if ((self = [super init])) { _name = [n copy]; _itemSearchBlock = [b copy]; } return self; }
@end

/* ================= the accessibility tree ================= */
static BOOL visible(UIView *v) { return !v.hidden && v.alpha > 0.01 && !v.accessibilityElementsHidden; }
/* elements in VoiceOver order; groups keep explicit (accessibilityElements) order and sort as a whole */
static NSArray *collect(id node, BOOL top);
static CGRect group_frame(NSArray *g) { id f = g.firstObject; return [f isKindOfClass:[NSArray class]] ? group_frame(f) : [f accessibilityFrame]; }
static NSArray *flatten_groups(NSArray *g) {
    NSMutableArray *out = [NSMutableArray array];
    for (id x in g) { if ([x isKindOfClass:[NSArray class]]) [out addObjectsFromArray:flatten_groups(x)]; else [out addObject:x]; }
    return out;
}
static NSArray *collect(id node, BOOL top) {
    if ([node isKindOfClass:[UIView class]] && !visible(node)) return @[];
    if (!top && [node accessibilityElementsHidden]) return @[];
    NSArray *explicitElems = [node accessibilityElements];
    if (explicitElems) {
        NSMutableArray *g = [NSMutableArray array];
        for (id e in explicitElems) {
            if ([e isKindOfClass:[UIView class]]) [g addObjectsFromArray:flatten_groups(collect(e, NO))];
            else if (is_element(e)) [g addObject:e];
            else if ([e accessibilityElements]) [g addObjectsFromArray:flatten_groups(collect(e, NO))];
        }
        return g.count ? @[g] : @[];
    }
    if (!top && is_element(node)) return @[node];
    if (![node isKindOfClass:[UIView class]]) return @[];
    NSMutableArray *parts = [NSMutableArray array];
    for (UIView *s in ((UIView *)node).subviews) {
        NSArray *c = collect(s, NO);
        BOOL group = [s shouldGroupAccessibilityChildren] && c.count > 1;
        if (group) [parts addObject:flatten_groups(c)]; else [parts addObjectsFromArray:c];
    }
    /* top to bottom, then left to right (rows within ~8 pt) */
    [parts sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id a, id b) {
        double pa = sort_priority([a isKindOfClass:[NSArray class]] ? flatten_groups(a).firstObject : a), pb = sort_priority([b isKindOfClass:[NSArray class]] ? flatten_groups(b).firstObject : b);
        if (pa != pb) return pa > pb ? NSOrderedAscending : NSOrderedDescending;
        CGRect fa = [a isKindOfClass:[NSArray class]] ? group_frame(a) : [a accessibilityFrame], fb = [b isKindOfClass:[NSArray class]] ? group_frame(b) : [b accessibilityFrame];
        if (fabs(fa.origin.y - fb.origin.y) > 8) return fa.origin.y < fb.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return fa.origin.x < fb.origin.x ? NSOrderedAscending : fa.origin.x > fb.origin.x ? NSOrderedDescending : NSOrderedSame;
    }];
    return parts;
}
static UIView *find_modal(UIView *v) {
    if (!visible(v)) return nil;
    for (UIView *s in v.subviews.reverseObjectEnumerator) { UIView *m = find_modal(s); if (m) return m; }
    return v.accessibilityViewIsModal ? v : nil;
}
static UIWindow *app_window(void) {
    UIWindow *best = nil;
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (!w.hidden && ![w _isim_isSystemWindow] && (!best || w.windowLevel >= best.windowLevel)) best = w;
    return best ?: UIApplication.sharedApplication.keyWindow;
}
NSArray *isim_ui_accessibility_elements(void) {
    UIWindow *w = app_window();
    if (!w) return @[];
    UIView *root = find_modal(w) ?: w;
    return flatten_groups(collect(root, YES));
}

/* ================= description of an element ================= */
static NSString *trait_words(id e, UIAccessibilityTraits t) {
    NSMutableArray *w = [NSMutableArray array];
    if (t & UIAccessibilityTraitSelected) [w addObject:@"Selected"];
    if (t & UIAccessibilityTraitToggleButton) [w addObject:@"Switch button"];
    else if (t & UIAccessibilityTraitButton) [w addObject:@"Button"];
    if (t & UIAccessibilityTraitLink) [w addObject:@"Link"];
    if (t & UIAccessibilityTraitHeader) [w addObject:@"Heading"];
    if (t & UIAccessibilityTraitSearchField) [w addObject:@"Search Field"];
    else if ([e isKindOfClass:[UITextField class]] || [e isKindOfClass:[UITextView class]]) [w addObject:@"Text Field"];
    if (t & UIAccessibilityTraitImage) [w addObject:@"Image"];
    if (t & UIAccessibilityTraitAdjustable) [w addObject:@"Adjustable"];
    if (t & UIAccessibilityTraitTabBar) [w addObject:@"Tab Bar"];
    if (t & UIAccessibilityTraitNotEnabled) [w addObject:@"Dimmed"];
    return [w componentsJoinedByString:@", "];
}
static NSString *label_of(id e) {
    NSString *l = [e accessibilityLabel];
    if (!l.length && [e isKindOfClass:[UITextField class]]) l = ((UITextField *)e).placeholder;
    if (!l.length && [e isKindOfClass:[UIImageView class]]) l = nil;
    return l;
}
NSString *isim_ui_accessibility_description(id e, BOOL withHint) {
    UIAccessibilityTraits t = effective_traits(e);
    NSMutableArray *parts = [NSMutableArray array];
    NSString *l = label_of(e), *v = [e accessibilityValue] ?: default_value(e);
    if (l.length) [parts addObject:l];
    if (t & UIAccessibilityTraitToggleButton) { if (v.length) v = [v isEqualToString:@"1"] ? @"On" : [v isEqualToString:@"0"] ? @"Off" : v; }
    NSString *tw = trait_words(e, t);
    if (t & UIAccessibilityTraitToggleButton) { if (tw.length) [parts addObject:tw]; if (v.length) [parts addObject:v]; }
    else { if (v.length && ![v isEqualToString:l]) [parts addObject:v]; if (tw.length) [parts addObject:tw]; }
    NSString *s = [parts componentsJoinedByString:@", "];
    NSString *hint = [e accessibilityHint];
    if (withHint && !hint && (t & UIAccessibilityTraitAdjustable)) hint = @"Swipe up or down with one finger to adjust the value.";
    if (withHint && [e accessibilityCustomActions].count) hint = [(hint ?: @"") stringByAppendingString:hint ? @" Actions available." : @"Actions available."];
    if (withHint && hint.length) s = [s stringByAppendingFormat:@". %@", hint];
    return s;
}
NSString *isim_ui_accessibility_dump(UIView *v) {
    if (!is_element(v)) return nil;
    NSString *d = isim_ui_accessibility_description(v, NO);
    return d.length ? d : nil;
}

/* ================= speech ================= */
static long speaking_voice;
static void speak(NSString *text) {
    if (!text.length) return;
    NSLog(@"isim: VoiceOver: \"%@\"", text);
    if (!isim_audio_available() || getenv("ISIM_HEADLESS")) return;
    if (speaking_voice) { isim_audio_stop(speaking_voice); speaking_voice = 0; }
    NSString *copy = [text copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        float *pcm = NULL; long frames = 0; double rate = 0;
        if (!isim_tts_synthesize(copy.UTF8String, "en", 190, 50, &pcm, &frames, &rate) || !pcm) return;
        int buf = isim_audio_buffer_create(pcm, frames, 1, rate);
        isim_media_free(pcm);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (speaking_voice) isim_audio_stop(speaking_voice);
            speaking_voice = isim_audio_play(buf, 1, 0);
            isim_audio_buffer_release(buf);
        });
    });
}

/* ================= VoiceOver ================= */
@interface __IsimVoiceOverWindow : UIWindow
@property (nonatomic) CGRect cursor;
@end
@implementation __IsimVoiceOverWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    if (CGRectIsEmpty(_cursor)) return;
    CGRect r = CGRectInset(_cursor, -4, -4);
    double black[4] = { 0, 0, 0, 1 }, white[4] = { 1, 1, 1, 1 };
    isim_gfx_stroke_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, 8, 4, black);
    isim_gfx_stroke_rounded(r.origin.x + 2.5, r.origin.y + 2.5, r.size.width - 5, r.size.height - 5, 6, 1, white);
}
@end
static __IsimVoiceOverWindow *vo_window;
static __weak id vo_focus;
static __strong id vo_focus_strong __attribute__((unused));      /* non-view elements (UIAccessibilityElement) are owned by their containers */
static BOOL vo_was_running;

@implementation NSObject (UIAccessibilityFocusState)
- (BOOL)accessibilityElementIsFocused { return UIAccessibilityIsVoiceOverRunning() && vo_focus == self; }
@end

static void draw_cursor(void) {
    if (!UIAccessibilityIsVoiceOverRunning()) { vo_window.hidden = YES; return; }
    if (!vo_window) {
        vo_window = [[__IsimVoiceOverWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        vo_window.windowLevel = 17000000;
        vo_window.backgroundColor = UIColor.clearColor;
        vo_window.accessibilityIdentifier = @"isim-voiceover-cursor";
    }
    vo_window.frame = UIScreen.mainScreen.bounds;
    id f = vo_focus;
    vo_window.cursor = f ? [f accessibilityFrame] : CGRectZero;
    vo_window.hidden = !f;
    isim_ui_set_needs_display();
}
static void focus(id e, BOOL announce) {
    id old = vo_focus;
    if (old && old != e) [old accessibilityElementDidLoseFocus];
    vo_focus = e; vo_focus_strong = [e isKindOfClass:[UIView class]] ? nil : e;
    if (e && e != old) {
        [e accessibilityElementDidBecomeFocused];
        [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityElementFocusedNotification object:nil userInfo:@{ UIAccessibilityFocusedElementKey: e }];
    }
    draw_cursor();
    if (e && announce) speak(isim_ui_accessibility_description(e, YES));
}
static void move(int dir) {
    NSArray *els = isim_ui_accessibility_elements();
    if (!els.count) { speak(@"No items"); return; }
    NSUInteger i = vo_focus ? [els indexOfObjectIdenticalTo:vo_focus] : NSNotFound;
    NSInteger n = i == NSNotFound ? (dir > 0 ? 0 : (NSInteger)els.count - 1) : (NSInteger)i + dir;
    if (n < 0 || n >= (NSInteger)els.count) { NSLog(@"isim: VoiceOver: (end of list)"); return; }
    focus(els[(NSUInteger)n], YES);
}
static void set_running(BOOL on) {
    vo_was_running = on;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityVoiceOverStatusDidChangeNotification object:nil];
    if (on) { NSLog(@"isim: VoiceOver on"); focus(nil, NO); move(1); }
    else { focus(nil, NO); vo_window.hidden = YES; NSLog(@"isim: VoiceOver off"); isim_ui_set_needs_display(); }
}
extern void isim_ui_synthesize_tap(CGPoint screenPoint);
static void activate(void) {
    id e = vo_focus;
    if (!e) return;
    BOOL (^handler)(void) = objc_getAssociatedObject(e, &k_act_handler);
    if (handler && handler()) { NSLog(@"isim: VoiceOver activated %@ (action)", label_of(e) ?: NSStringFromClass([e class])); }
    else if ([e accessibilityActivate]) { NSLog(@"isim: VoiceOver activated %@ (accessibilityActivate)", label_of(e) ?: NSStringFromClass([e class])); }
    else {
        CGPoint p = [e accessibilityActivationPoint];
        NSLog(@"isim: VoiceOver activated %@ (tap at %.0f,%.0f)", label_of(e) ?: NSStringFromClass([e class]), p.x, p.y);
        isim_ui_synthesize_tap(p);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id f = vo_focus;
        if (f && [isim_ui_accessibility_elements() indexOfObjectIdenticalTo:f] == NSNotFound) { focus(nil, NO); move(1); }   /* the screen changed */
        else draw_cursor();
    });
}
void isim_ui_voiceover_command(NSString *c);
/* ---- the rotor: custom rotors (the focused element and its containers), Headings, Actions, Adjust Value ---- */
static NSInteger rotor_index = -1;                  /* among rotor_entries(); the first turn selects the first */
static NSUInteger rotor_action;                     /* Actions: the selected custom action */
static NSArray *rotor_customs(void) {
    NSMutableArray *a = [NSMutableArray array];
    for (id r = vo_focus; r; r = [r isKindOfClass:[UIView class]] ? [(UIView *)r superview] : [r respondsToSelector:@selector(accessibilityContainer)] ? [r accessibilityContainer] : nil)
        for (UIAccessibilityCustomRotor *c in [r accessibilityCustomRotors] ?: @[]) if (![a containsObject:c]) [a addObject:c];
    for (UIWindow *w in UIApplication.sharedApplication.windows) for (UIViewController *vc = w.rootViewController; vc; vc = vc.presentedViewController)
        for (UIAccessibilityCustomRotor *c in [vc accessibilityCustomRotors] ?: @[]) if (![a containsObject:c]) [a addObject:c];
    return a;
}
static NSArray *rotor_entries(void) {              /* UIAccessibilityCustomRotor or a built-in name */
    NSMutableArray *a = [NSMutableArray arrayWithArray:rotor_customs()];
    [a addObject:@"Headings"];
    if ([[vo_focus accessibilityCustomActions] count]) [a addObject:@"Actions"];
    if (effective_traits(vo_focus) & UIAccessibilityTraitAdjustable) [a addObject:@"Adjust Value"];
    return a;
}
static NSString *rotor_name(id entry) { return [entry isKindOfClass:[UIAccessibilityCustomRotor class]] ? [(UIAccessibilityCustomRotor *)entry name] : entry; }
static id rotor_current(void) { NSArray *a = rotor_entries(); return a.count ? a[(NSUInteger)(((rotor_index % (NSInteger)a.count) + (NSInteger)a.count) % (NSInteger)a.count)] : nil; }
static void rotor_turn(int dir) {
    rotor_index += dir; rotor_action = 0;
    NSString *n = rotor_name(rotor_current());
    NSLog(@"isim: VoiceOver rotor: %@", n);
    speak(n);
}
/* swipe down (dir 1) / up (-1): the rotor's next / previous item */
static void rotor_move(int dir) {
    id entry = rotor_current();
    if ([entry isKindOfClass:[UIAccessibilityCustomRotor class]]) {
        UIAccessibilityCustomRotor *r = entry;
        UIAccessibilityCustomRotorSearchPredicate *p = [UIAccessibilityCustomRotorSearchPredicate new];
        p.currentItem = [[UIAccessibilityCustomRotorItemResult alloc] initWithTargetElement:vo_focus targetRange:nil];
        p.searchDirection = dir > 0 ? UIAccessibilityCustomRotorDirectionNext : UIAccessibilityCustomRotorDirectionPrevious;
        UIAccessibilityCustomRotorItemResult *res = r.itemSearchBlock ? r.itemSearchBlock(p) : nil;
        if (!res.targetElement) { NSLog(@"isim: VoiceOver rotor %@: no more items", r.name); speak(@"No more items"); return; }
        focus(res.targetElement, YES);
    } else if ([entry isEqual:@"Headings"]) {
        NSArray *els = isim_ui_accessibility_elements();
        NSInteger i = vo_focus ? (NSInteger)[els indexOfObjectIdenticalTo:vo_focus] : -1;
        for (NSInteger k = i + dir; k >= 0 && k < (NSInteger)els.count; k += dir)
            if (effective_traits(els[(NSUInteger)k]) & UIAccessibilityTraitHeader) { focus(els[(NSUInteger)k], YES); return; }
        speak(@"No more headings");
    } else if ([entry isEqual:@"Actions"]) {
        NSArray *acts = [vo_focus accessibilityCustomActions];
        if (!acts.count) return;
        rotor_action = (rotor_action + (dir > 0 ? 1 : acts.count - 1)) % acts.count;
        speak([acts[rotor_action] name]);
    } else if ([entry isEqual:@"Adjust Value"]) {
        isim_ui_voiceover_command(dir > 0 ? @"decrement" : @"increment");
    }
}

/* ================= Switch Control (simulated: item scanning) ================= */
@interface __IsimSwitchWindow : UIWindow
@property (nonatomic) CGRect highlight;
@end
@implementation __IsimSwitchWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    if (CGRectIsEmpty(_highlight)) return;
    CGRect r = CGRectInset(_highlight, -3, -3);
    double blue[4] = { 0.0, 0.48, 1.0, 1 };
    isim_gfx_stroke_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, 8, 5, blue);
}
@end
static __IsimSwitchWindow *sc_window;
static __weak id sc_item;
static NSTimer *sc_timer;
static void sc_draw(void) {
    if (!UIAccessibilityIsSwitchControlRunning()) { sc_window.hidden = YES; return; }
    if (!sc_window) { sc_window = [[__IsimSwitchWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; sc_window.windowLevel = 16900000; sc_window.backgroundColor = UIColor.clearColor; sc_window.accessibilityIdentifier = @"isim-switch-control"; }
    id it = sc_item;
    sc_window.highlight = it ? [it accessibilityFrame] : CGRectZero;
    sc_window.hidden = !it;
    isim_ui_set_needs_display();
}
static void sc_next(void) {
    NSArray *els = isim_ui_accessibility_elements();
    if (!els.count) return;
    NSUInteger i = sc_item ? [els indexOfObjectIdenticalTo:sc_item] : NSNotFound;
    sc_item = els[i == NSNotFound || i + 1 >= els.count ? 0 : i + 1];
    NSLog(@"isim: Switch Control: %@", label_of(sc_item) ?: NSStringFromClass([sc_item class]));
    sc_draw();
}
static void sc_select(void) {
    id e = sc_item;
    if (!e) { sc_next(); return; }
    BOOL (^handler)(void) = objc_getAssociatedObject(e, &k_act_handler);
    NSLog(@"isim: Switch Control selected %@", label_of(e) ?: NSStringFromClass([e class]));
    if (handler && handler()) return;
    if ([e accessibilityActivate]) return;
    isim_ui_synthesize_tap([e accessibilityActivationPoint]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (sc_item && [isim_ui_accessibility_elements() indexOfObjectIdenticalTo:sc_item] == NSNotFound) sc_item = nil;   /* the screen changed */
        sc_draw();
    });
}
static void sc_set_running(BOOL on) {
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilitySwitchControlStatusDidChangeNotification object:nil];
    NSLog(@"isim: Switch Control %@", on ? @"on" : @"off");
    [sc_timer invalidate]; sc_timer = nil;
    sc_item = nil;
    if (on) sc_next(); else sc_draw();
}
static void switch_command(NSString *c) {
    if ([c isEqualToString:@"on"] || [c isEqualToString:@"off"]) { sc_script_override = YES; sc_script_on = [c isEqualToString:@"on"]; sc_set_running(sc_script_on); return; }
    if (!UIAccessibilityIsSwitchControlRunning()) { NSLog(@"isim: switchcontrol %@: Switch Control is off", c); return; }
    if ([c isEqualToString:@"next"]) sc_next();
    else if ([c isEqualToString:@"select"]) sc_select();
    else if ([c hasPrefix:@"auto"]) {                 /* auto scanning: the highlight moves every interval (default 1 s) */
        double t = [[c substringFromIndex:4] doubleValue]; if (t <= 0) t = 1;
        [sc_timer invalidate];
        sc_timer = [NSTimer scheduledTimerWithTimeInterval:t repeats:YES block:^(NSTimer *x) { sc_next(); }];
        NSLog(@"isim: Switch Control auto scanning every %g s", t);
    } else if ([c isEqualToString:@"stop"]) { [sc_timer invalidate]; sc_timer = nil; }
    else NSLog(@"isim: unknown switchcontrol command '%@'", c);
}

/* ================= Voice Control (simulated: spoken commands as script text) ================= */
@interface __IsimVoiceWindow : UIWindow
@property (nonatomic, copy) NSArray *badges;          /* @[frame, label] */
@end
@implementation __IsimVoiceWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    double bg[4] = { 0.0, 0.48, 1.0, 0.95 };
    UIFont *f = [UIFont boldSystemFontOfSize:12];
    for (NSArray *b in _badges) {
        CGRect r = [b[0] CGRectValue]; NSString *t = b[1];
        CGSize ts = isim_ui_measure(t, f, 200, 1);
        CGRect box = CGRectMake(r.origin.x, r.origin.y, ts.width + 8, ts.height + 2);
        isim_gfx_fill_rounded(box.origin.x, box.origin.y, box.size.width, box.size.height, 4, bg);
        isim_ui_draw_text(t, f, UIColor.whiteColor, CGRectInset(box, 4, 1), NSTextAlignmentLeft, 1, 1);
    }
}
@end
static __IsimVoiceWindow *vc_window;
static NSString *vc_overlay;                          /* nil, @"numbers" or @"names" */
static NSArray *vc_targets(void) {                    /* what can be tapped: interactive elements on the screen */
    NSMutableArray *a = [NSMutableArray array];
    CGRect screen = UIScreen.mainScreen.bounds;
    for (id e in isim_ui_accessibility_elements()) {
        if (!CGRectIntersectsRect([e accessibilityFrame], screen)) continue;
        UIAccessibilityTraits t = effective_traits(e);
        if ((t & (UIAccessibilityTraitButton | UIAccessibilityTraitLink | UIAccessibilityTraitAdjustable | UIAccessibilityTraitSearchField | UIAccessibilityTraitKeyboardKey))
            || [e isKindOfClass:[UIControl class]] || [[e accessibilityUserInputLabels] count]) [a addObject:e];
    }
    return a;
}
static NSArray<NSString *> *vc_names(id e) {
    NSArray *labels = [e accessibilityUserInputLabels];
    if (labels.count) return labels;
    NSString *l = label_of(e);
    return l.length ? @[l] : @[];
}
static void vc_draw(void) {
    if (!vc_overlay) { vc_window.hidden = YES; isim_ui_set_needs_display(); return; }
    if (!vc_window) { vc_window = [[__IsimVoiceWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; vc_window.windowLevel = 16800000; vc_window.backgroundColor = UIColor.clearColor; vc_window.accessibilityIdentifier = @"isim-voice-control"; }
    NSMutableArray *b = [NSMutableArray array];
    NSUInteger i = 0;
    for (id e in vc_targets()) {
        i++;
        NSString *t = [vc_overlay isEqualToString:@"numbers"] ? [NSString stringWithFormat:@"%lu", (unsigned long)i] : vc_names(e).firstObject;
        if (t.length) [b addObject:@[[NSValue valueWithCGRect:[e accessibilityFrame]], t]];
    }
    vc_window.badges = b; vc_window.hidden = NO;
    isim_ui_set_needs_display();
}
static void vc_activate(id e) {
    BOOL (^handler)(void) = objc_getAssociatedObject(e, &k_act_handler);
    NSLog(@"isim: Voice Control tapped %@", vc_names(e).firstObject ?: NSStringFromClass([e class]));
    if (handler && handler()) return;
    if ([e accessibilityActivate]) return;
    isim_ui_synthesize_tap([e accessibilityActivationPoint]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ vc_draw(); });
}
static void voice_command(NSString *phrase) {
    NSString *p = [[phrase stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
    NSString *l = p.lowercaseString;
    NSLog(@"isim: Voice Control heard \"%@\"", p);
    if ([l isEqualToString:@"show numbers"] || [l isEqualToString:@"show names"]) { vc_overlay = [l hasSuffix:@"numbers"] ? @"numbers" : @"names"; vc_draw(); return; }
    if ([l isEqualToString:@"hide numbers"] || [l isEqualToString:@"hide names"]) { vc_overlay = nil; vc_draw(); return; }
    if ([l hasPrefix:@"scroll "]) {
        NSString *dir = [l substringFromIndex:7];
        UIScrollView *sv = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            NSMutableArray *q = [NSMutableArray arrayWithObject:w];
            while (q.count && !sv) { UIView *v = q.firstObject; [q removeObjectAtIndex:0]; if ([v isKindOfClass:[UIScrollView class]] && !v.hidden && ((UIScrollView *)v).scrollEnabled) sv = (UIScrollView *)v; [q addObjectsFromArray:v.subviews]; }
        }
        if (!sv) { NSLog(@"isim: Voice Control: nothing to scroll"); return; }
        CGPoint o = sv.contentOffset; CGFloat h = sv.bounds.size.height * 0.8, w = sv.bounds.size.width * 0.8;
        UIEdgeInsets in = sv.adjustedContentInset;
        if ([dir hasPrefix:@"down"]) o.y = fmin(o.y + h, fmax(-in.top, sv.contentSize.height + in.bottom - sv.bounds.size.height));
        else if ([dir hasPrefix:@"up"]) o.y = fmax(-in.top, o.y - h);
        else if ([dir hasPrefix:@"right"]) o.x = fmin(o.x + w, fmax(-in.left, sv.contentSize.width + in.right - sv.bounds.size.width));
        else if ([dir hasPrefix:@"left"]) o.x = fmax(-in.left, o.x - w);
        [sv setContentOffset:o animated:YES];
        NSLog(@"isim: Voice Control scrolled %@", dir);
        return;
    }
    if ([l isEqualToString:@"go back"]) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            UIViewController *vc = w.rootViewController; while (vc.presentedViewController) vc = vc.presentedViewController;
            UINavigationController *nav = [vc isKindOfClass:[UINavigationController class]] ? (id)vc : vc.navigationController;
            if (nav.viewControllers.count > 1) { [nav popViewControllerAnimated:YES]; NSLog(@"isim: Voice Control went back"); return; }
        }
        NSLog(@"isim: Voice Control: nothing to go back from");
        return;
    }
    if ([l hasPrefix:@"tap "] || [l hasPrefix:@"press "]) {
        NSString *what = [p substringFromIndex:[l hasPrefix:@"tap "] ? 4 : 6];
        NSArray *targets = vc_targets();
        NSInteger n = what.integerValue;
        if (n > 0 && [what isEqualToString:[NSString stringWithFormat:@"%ld", (long)n]]) {
            if (n <= (NSInteger)targets.count) vc_activate(targets[(NSUInteger)n - 1]); else NSLog(@"isim: Voice Control: no item %ld", (long)n);
            return;
        }
        for (id e in targets) for (NSString *name in vc_names(e)) if ([name caseInsensitiveCompare:what] == NSOrderedSame) { vc_activate(e); return; }
        NSLog(@"isim: Voice Control: no item named \"%@\"", what);
        return;
    }
    NSLog(@"isim: Voice Control: not a command");
}

void isim_ui_voiceover_command(NSString *c) {
    if ([c hasPrefix:@"switch:"]) { switch_command([c substringFromIndex:7]); return; }
    if ([c hasPrefix:@"voice:"]) { voice_command([c substringFromIndex:6]); return; }
    if ([c isEqualToString:@"on"] || [c isEqualToString:@"off"]) {
        vo_script_override = YES; vo_script_on = [c isEqualToString:@"on"];
        set_running(vo_script_on);
        return;
    }
    if (!UIAccessibilityIsVoiceOverRunning()) { NSLog(@"isim: voiceover %@: VoiceOver is off", c); return; }
    if ([c isEqualToString:@"next"]) move(1);
    else if ([c isEqualToString:@"prev"] || [c isEqualToString:@"previous"]) move(-1);
    else if ([c isEqualToString:@"rotor"] || [c isEqualToString:@"rotor next"]) rotor_turn(1);
    else if ([c isEqualToString:@"rotor prev"] || [c isEqualToString:@"rotor previous"]) rotor_turn(-1);
    else if ([c isEqualToString:@"down"]) rotor_move(1);
    else if ([c isEqualToString:@"up"]) rotor_move(-1);
    else if ([c isEqualToString:@"activate"] && [rotor_current() isEqual:@"Actions"] && [[vo_focus accessibilityCustomActions] count]) {
        UIAccessibilityCustomAction *a = [vo_focus accessibilityCustomActions][rotor_action % [[vo_focus accessibilityCustomActions] count]];
        NSLog(@"isim: VoiceOver performed action %@", a.name);
        [a _isim_perform];
    }
    else if ([c isEqualToString:@"activate"]) activate();
    else if ([c isEqualToString:@"increment"] || [c isEqualToString:@"decrement"]) {
        id e = vo_focus;
        if (!(effective_traits(e) & UIAccessibilityTraitAdjustable)) { NSLog(@"isim: VoiceOver: not adjustable"); return; }
        void (^adj)(NSInteger) = objc_getAssociatedObject(e, &k_adj_handler);
        if (adj) adj([c isEqualToString:@"increment"] ? 1 : -1);
        else if ([c isEqualToString:@"increment"]) [e accessibilityIncrement]; else [e accessibilityDecrement];
        NSString *v = [e accessibilityValue] ?: default_value(e);
        speak(v);
        draw_cursor();
    } else if ([c isEqualToString:@"action"]) {
        id e = vo_focus;
        UIAccessibilityCustomAction *a = [[e accessibilityCustomActions] firstObject];
        if (!a) { speak(@"No actions"); return; }
        speak(a.name);
        [a _isim_perform];
    } else if ([c isEqualToString:@"escape"]) {
        BOOL done = NO;
        for (id r = vo_focus; r && !done; r = [r isKindOfClass:[UIResponder class]] ? [(UIResponder *)r nextResponder] : nil) done = [r accessibilityPerformEscape];
        NSLog(@"isim: VoiceOver escape %@", done ? @"handled" : @"not handled");
    } else if ([c isEqualToString:@"magictap"]) {
        BOOL done = NO;
        for (id r = vo_focus; r && !done; r = [r isKindOfClass:[UIResponder class]] ? [(UIResponder *)r nextResponder] : nil) done = [r accessibilityPerformMagicTap];
    } else if ([c isEqualToString:@"read"]) {
        for (id e in isim_ui_accessibility_elements()) focus(e, YES);
    } else NSLog(@"isim: unknown voiceover command '%@'", c);
}
/* VoiceOver gestures: tap focuses, double tap activates, horizontal swipe moves */
static BOOL vo_touch(const struct isim_event *ev) {
    static CGPoint down; static double downAt, lastTap; static BOOL tracking;
    if (!UIAccessibilityIsVoiceOverRunning() || ev->pad == 1) return NO;
    CGPoint p = CGPointMake(ev->x, ev->y);
    if (ev->type == ISIM_EV_TOUCH_DOWN) { down = p; downAt = ev->timestamp; tracking = YES; return YES; }
    if (ev->type == ISIM_EV_TOUCH_MOVE) return tracking;
    if (!tracking) return NO;
    tracking = NO;
    double dx = p.x - down.x, dy = p.y - down.y;
    if (fabs(dx) > 40 && fabs(dx) > fabs(dy) * 1.5) { move(dx > 0 ? 1 : -1); return YES; }
    if (fabs(dy) > 40 && fabs(dy) > fabs(dx) * 1.5) { rotor_move(dy > 0 ? 1 : -1); return YES; }   /* swipe down / up: the rotor */
    if (hypot(dx, dy) > 12) return YES;
    if (ev->timestamp - lastTap < 0.35) { lastTap = 0; activate(); return YES; }
    lastTap = ev->timestamp;
    id hit = nil;
    for (id e in isim_ui_accessibility_elements()) if (CGRectContainsPoint([e accessibilityFrame], p)) hit = e;      /* the last (front-most) wins */
    if (hit) focus(hit, YES);
    (void)downAt;
    return YES;
}

/* ================= UIAccessibilityPostNotification ================= */
void UIAccessibilityPostNotification(UIAccessibilityNotifications n, id arg) {
    NSString *name = n == UIAccessibilityAnnouncementNotification ? @"announcement" : n == UIAccessibilityScreenChangedNotification ? @"screenChanged"
                   : n == UIAccessibilityLayoutChangedNotification ? @"layoutChanged" : n == UIAccessibilityPageScrolledNotification ? @"pageScrolled" : [NSString stringWithFormat:@"%u", n];
    NSString *desc = [arg isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@"\"%@\"", arg] : [arg isKindOfClass:[NSAttributedString class]] ? [NSString stringWithFormat:@"\"%@\"", [arg string]]
                   : arg ? NSStringFromClass([arg class]) : @"nil";
    NSLog(@"isim: accessibility notification %@ %@", name, desc);
    if (!UIAccessibilityIsVoiceOverRunning()) return;
    NSString *text = [arg isKindOfClass:[NSString class]] ? arg : [arg isKindOfClass:[NSAttributedString class]] ? [arg string] : nil;
    if (n == UIAccessibilityAnnouncementNotification || n == UIAccessibilityPageScrolledNotification) {
        speak(text);
        if (n == UIAccessibilityAnnouncementNotification)
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityAnnouncementDidFinishNotification object:nil
                                                                userInfo:@{ UIAccessibilityAnnouncementKeyStringValue: text ?: @"", UIAccessibilityAnnouncementKeyWasSuccessful: @YES }];
            });
    } else if (n == UIAccessibilityScreenChangedNotification || n == UIAccessibilityLayoutChangedNotification) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (arg && !text) focus(arg, YES);
            else if (n == UIAccessibilityScreenChangedNotification) { focus(nil, NO); move(1); }
            else if (text) speak(text);
        });
    }
}

/* ================= settings changes ================= */
static NSDictionary *last_settings;
static NSDictionary *snapshot(void) {
    return @{ @"vo": @(UIAccessibilityIsVoiceOverRunning()), @"sc": @(UIAccessibilityIsSwitchControlRunning()), @"cat": settings_category(), @"bold": @(UIAccessibilityIsBoldTextEnabled()),
              @"motion": @(UIAccessibilityIsReduceMotionEnabled()), @"transp": @(UIAccessibilityIsReduceTransparencyEnabled()),
              @"contrast": @(UIAccessibilityIsDarkerSystemColorsEnabled()), @"color": @(UIAccessibilityShouldDifferentiateWithoutColor()) };
}
void isim_ui_accessibility_reload_settings(void) {
    NSDictionary *now = snapshot(), *old = last_settings ?: now;
    last_settings = now;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    if (![now[@"cat"] isEqual:old[@"cat"]] || ![now[@"bold"] isEqual:old[@"bold"]]) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) adjust_fonts(w);
        isim_ui_set_needs_layout();
    }
    if (![now[@"cat"] isEqual:old[@"cat"]]) {
        NSLog(@"isim: content size category %@", now[@"cat"]);
        [nc postNotificationName:UIContentSizeCategoryDidChangeNotification object:UIApplication.sharedApplication userInfo:@{ UIContentSizeCategoryNewValueKey: now[@"cat"] }];
    }
    if (![now[@"bold"] isEqual:old[@"bold"]]) [nc postNotificationName:UIAccessibilityBoldTextStatusDidChangeNotification object:nil];
    if (![now[@"motion"] isEqual:old[@"motion"]]) [nc postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    if (![now[@"transp"] isEqual:old[@"transp"]]) [nc postNotificationName:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    if (![now[@"contrast"] isEqual:old[@"contrast"]]) [nc postNotificationName:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
    if (![now[@"color"] isEqual:old[@"color"]]) [nc postNotificationName:UIAccessibilityDifferentiateWithoutColorDidChangeNotification object:nil];
    if ([now[@"vo"] boolValue] != vo_was_running) set_running([now[@"vo"] boolValue]);
    if (![now[@"sc"] isEqual:old[@"sc"]]) sc_set_running([now[@"sc"] boolValue]);
}
/* launch: settings baseline, VoiceOver if it is on, touch filter */
void isim_ui_accessibility_install(void) {
    last_settings = snapshot();
    isim_ui_add_touch_filter(^BOOL(const struct isim_event *ev) { return vo_touch(ev); });
    if (UIAccessibilityIsVoiceOverRunning())
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ set_running(YES); });
    if (UIAccessibilityIsSwitchControlRunning())
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ sc_set_running(YES); });
}
void isim_ui_accessibility_frame_tick(void) {
    if (vo_was_running && vo_focus) draw_cursor();
    if (sc_item) sc_draw();
    if (vc_overlay) vc_draw();
}

/* ================= Large Content Viewer ================= */
static char k_lcv_shows, k_lcv_title, k_lcv_image;
@implementation UIView (UILargeContentViewer)
- (BOOL)showsLargeContentViewer { return [objc_getAssociatedObject(self, &k_lcv_shows) boolValue]; }
- (void)setShowsLargeContentViewer:(BOOL)b { objc_setAssociatedObject(self, &k_lcv_shows, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)largeContentTitle {
    NSString *t = objc_getAssociatedObject(self, &k_lcv_title);
    if (t) return t;
    if ([self isKindOfClass:[UILabel class]]) return ((UILabel *)self).text;
    if ([self isKindOfClass:[UIButton class]]) return ((UIButton *)self).currentTitle;
    return self.accessibilityLabel;
}
- (void)setLargeContentTitle:(NSString *)t { objc_setAssociatedObject(self, &k_lcv_title, t, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (UIImage *)largeContentImage { return objc_getAssociatedObject(self, &k_lcv_image) ?: ([self isKindOfClass:[UIButton class]] ? ((UIButton *)self).currentImage : nil); }
- (void)setLargeContentImage:(UIImage *)i { objc_setAssociatedObject(self, &k_lcv_image, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@interface __IsimLargeContentWindow : UIWindow
@property (nonatomic, strong) UIView *hud;
@end
@implementation __IsimLargeContentWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
@end
static __IsimLargeContentWindow *lcv_window;
@implementation UILargeContentViewerInteraction { __weak UIView *_view; __weak id<UILargeContentViewerInteractionDelegate> _delegate; UILongPressGestureRecognizer *_press; id _item; }
+ (BOOL)isEnabled { return UIContentSizeCategoryIsAccessibilityCategory(settings_category()); }
- (instancetype)initWithDelegate:(id<UILargeContentViewerInteractionDelegate>)d { if ((self = [super init])) _delegate = d; return self; }
- (id<UILargeContentViewerInteractionDelegate>)delegate { return _delegate; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { if (_press) [_view removeGestureRecognizer:_press]; }
- (void)didMoveToView:(UIView *)v {
    _view = v;
    if (!v) return;
    _press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_pressed:)];
    _press.minimumPressDuration = 0.5; _press.cancelsTouchesInView = NO;
    [v addGestureRecognizer:_press];
}
- (id)_itemAt:(CGPoint)p {
    id<UILargeContentViewerInteractionDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(largeContentViewerInteraction:itemAtPoint:)]) return [d largeContentViewerInteraction:self itemAtPoint:p];
    UIView *hit = [_view hitTest:p withEvent:nil];
    for (UIView *v = hit; v; v = v.superview) { if (v.showsLargeContentViewer) return v; if (v == _view) break; }
    return nil;
}
- (void)_pressed:(UILongPressGestureRecognizer *)g {
    if (![UILargeContentViewerInteraction isEnabled]) return;
    CGPoint p = [g locationInView:_view];
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        id item = [self _itemAt:p];
        if (item == _item) return;
        _item = item;
        [lcv_window.hud removeFromSuperview];
        if (!item) { lcv_window.hidden = YES; return; }
        if (!lcv_window) { lcv_window = [[__IsimLargeContentWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; lcv_window.windowLevel = 16500000; lcv_window.backgroundColor = UIColor.clearColor; }
        CGSize s = UIScreen.mainScreen.bounds.size;
        UIView *hud = [[UIView alloc] initWithFrame:CGRectMake(s.width / 2 - 120, s.height / 2 - 120, 240, 240)];
        hud.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.92]; hud.layer.cornerRadius = 18; hud.layer.cornerCurve = kCACornerCurveContinuous;
        hud.accessibilityIdentifier = @"isim-large-content";
        UIImage *img = [item largeContentImage];
        if (img) { UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(70, 40, 100, 100)]; iv.image = img; iv.tintColor = UIColor.whiteColor; iv.contentMode = UIViewContentModeScaleAspectFit; [hud addSubview:iv]; }
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(10, img ? 150 : 60, 220, img ? 70 : 120)];
        l.text = [item largeContentTitle]; l.textColor = UIColor.whiteColor; l.font = [UIFont systemFontOfSize:30 weight:UIFontWeightSemibold];
        l.textAlignment = NSTextAlignmentCenter; l.numberOfLines = 2;
        [hud addSubview:l];
        lcv_window.hud = hud; [lcv_window addSubview:hud]; lcv_window.hidden = NO;
        NSLog(@"isim: large content viewer \"%@\"", [item largeContentTitle] ?: @"");
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        id item = _item; _item = nil;
        [lcv_window.hud removeFromSuperview]; lcv_window.hidden = YES;
        id<UILargeContentViewerInteractionDelegate> d = _delegate;
        if (item && [d respondsToSelector:@selector(largeContentViewerInteraction:didEndOnItem:atPoint:)]) [d largeContentViewerInteraction:self didEndOnItem:item atPoint:p];
    }
    isim_ui_set_needs_display();
}
@end
