/* Accessibility additions (ARC): the further Settings > Accessibility values and their notifications, Guided Access
 * (script `guidedaccess on|off|restrict ID allow|deny`), attributed and block-based element properties (iOS 11 / 17),
 * container types and data tables, textual contexts, expanded status, location descriptors, speech attributes,
 * custom actions and rotors with attributed names / images / categories / system types, and the coordinate
 * conversions. VoiceOver's use of them lives in UIAccessibilityRuntime.m. */
#import "UIKitPrivate.h"
#import <objc/runtime.h>

extern NSDictionary *isim_global_preferences(void);
static BOOL pref(NSString *key, BOOL dflt) { id v = isim_global_preferences()[key]; return v ? [v boolValue] : dflt; }

/* ================= constants ================= */
NSNotificationName const UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification = @"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification";
NSNotificationName const UIAccessibilityClosedCaptioningStatusDidChangeNotification = @"UIAccessibilityClosedCaptioningStatusDidChangeNotification";
NSNotificationName const UIAccessibilityGrayscaleStatusDidChangeNotification = @"UIAccessibilityGrayscaleStatusDidChangeNotification";
NSNotificationName const UIAccessibilityInvertColorsStatusDidChangeNotification = @"UIAccessibilityInvertColorsStatusDidChangeNotification";
NSNotificationName const UIAccessibilityAssistiveTouchStatusDidChangeNotification = @"UIAccessibilityAssistiveTouchStatusDidChangeNotification";
NSNotificationName const UIAccessibilityGuidedAccessStatusDidChangeNotification = @"UIAccessibilityGuidedAccessStatusDidChangeNotification";
NSNotificationName const UIAccessibilityMonoAudioStatusDidChangeNotification = @"UIAccessibilityMonoAudioStatusDidChangeNotification";
NSNotificationName const UIAccessibilitySpeakScreenStatusDidChangeNotification = @"UIAccessibilitySpeakScreenStatusDidChangeNotification";
NSNotificationName const UIAccessibilitySpeakSelectionStatusDidChangeNotification = @"UIAccessibilitySpeakSelectionStatusDidChangeNotification";
NSNotificationName const UIAccessibilityHearingDevicePairedEarDidChangeNotification = @"UIAccessibilityHearingDevicePairedEarDidChangeNotification";
NSNotificationName const UIAccessibilityShakeToUndoDidChangeNotification = @"UIAccessibilityShakeToUndoDidChangeNotification";
NSNotificationName const UIAccessibilityVideoAutoplayStatusDidChangeNotification = @"UIAccessibilityVideoAutoplayStatusDidChangeNotification";
NSNotificationName const UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification = @"UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification";
NSNotificationName const UIAccessibilityOnOffSwitchLabelsDidChangeNotification = @"UIAccessibilityOnOffSwitchLabelsDidChangeNotification";
NSString *const UIAccessibilityUnfocusedElementKey = @"UIAccessibilityUnfocusedElementKey";
NSString *const UIAccessibilityAssistiveTechnologyKey = @"UIAccessibilityAssistiveTechnologyKey";
UIAccessibilityAssistiveTechnologyIdentifier const UIAccessibilityNotificationSwitchControlIdentifier = @"UIAccessibilityNotificationSwitchControlIdentifier";
UIAccessibilityAssistiveTechnologyIdentifier const UIAccessibilityNotificationVoiceOverIdentifier = @"UIAccessibilityNotificationVoiceOverIdentifier";
UIAccessibilityTextualContext const UIAccessibilityTextualContextWordProcessing = @"UIAccessibilityTextualContextWordProcessing";
UIAccessibilityTextualContext const UIAccessibilityTextualContextNarrative = @"UIAccessibilityTextualContextNarrative";
UIAccessibilityTextualContext const UIAccessibilityTextualContextMessaging = @"UIAccessibilityTextualContextMessaging";
UIAccessibilityTextualContext const UIAccessibilityTextualContextSpreadsheet = @"UIAccessibilityTextualContextSpreadsheet";
UIAccessibilityTextualContext const UIAccessibilityTextualContextFileSystem = @"UIAccessibilityTextualContextFileSystem";
UIAccessibilityTextualContext const UIAccessibilityTextualContextSourceCode = @"UIAccessibilityTextualContextSourceCode";
UIAccessibilityTextualContext const UIAccessibilityTextualContextConsole = @"UIAccessibilityTextualContextConsole";
UIAccessibilityPriority const UIAccessibilityPriorityHigh = @"UIAccessibilityPriorityHigh";
UIAccessibilityPriority const UIAccessibilityPriorityDefault = @"UIAccessibilityPriorityDefault";
UIAccessibilityPriority const UIAccessibilityPriorityLow = @"UIAccessibilityPriorityLow";
NSAttributedStringKey const UIAccessibilitySpeechAttributePunctuation = @"UIAccessibilitySpeechAttributePunctuation";
NSAttributedStringKey const UIAccessibilitySpeechAttributeLanguage = @"UIAccessibilitySpeechAttributeLanguage";
NSAttributedStringKey const UIAccessibilitySpeechAttributePitch = @"UIAccessibilitySpeechAttributePitch";
NSAttributedStringKey const UIAccessibilitySpeechAttributeQueueAnnouncement = @"UIAccessibilitySpeechAttributeQueueAnnouncement";
NSAttributedStringKey const UIAccessibilitySpeechAttributeIPANotation = @"UIAccessibilitySpeechAttributeIPANotation";
NSAttributedStringKey const UIAccessibilitySpeechAttributeSpellOut = @"UIAccessibilitySpeechAttributeSpellOut";
NSAttributedStringKey const UIAccessibilitySpeechAttributeAnnouncementPriority = @"UIAccessibilitySpeechAttributeAnnouncementPriority";
NSAttributedStringKey const UIAccessibilityTextAttributeHeadingLevel = @"UIAccessibilityTextAttributeHeadingLevel";
NSAttributedStringKey const UIAccessibilityTextAttributeCustom = @"UIAccessibilityTextAttributeCustom";
NSAttributedStringKey const UIAccessibilityTextAttributeContext = @"UIAccessibilityTextAttributeContext";
NSString *const UIAccessibilityCustomActionCategoryEdit = @"UIAccessibilityCustomActionCategoryEdit";
NSErrorDomain const UIGuidedAccessErrorDomain = @"UIGuidedAccessErrorDomain";

/* ================= settings ================= */
BOOL UIAccessibilityDarkerSystemColorsEnabled(void) { return UIAccessibilityIsDarkerSystemColorsEnabled(); }
static int guided_override = -1;                    /* script / requestGuidedAccessSession; else the preference */
BOOL UIAccessibilityIsGuidedAccessEnabled(void) { return guided_override >= 0 ? guided_override : pref(@"ISIMGuidedAccess", NO); }
BOOL UIAccessibilityIsMonoAudioEnabled(void) { return pref(@"ISIMMonoAudio", NO); }
BOOL UIAccessibilityIsSpeakScreenEnabled(void) { return pref(@"ISIMSpeakScreen", NO); }
BOOL UIAccessibilityIsSpeakSelectionEnabled(void) { return pref(@"ISIMSpeakSelection", NO); }
BOOL UIAccessibilityIsAssistiveTouchRunning(void) { return pref(@"ISIMAssistiveTouch", NO); }
BOOL UIAccessibilityIsShakeToUndoEnabled(void) { return pref(@"ISIMShakeToUndo", YES); }
UIAccessibilityHearingDeviceEar UIAccessibilityHearingDevicePairedEar(void) { return UIAccessibilityHearingDeviceEarNone; }
/* the values Settings changes (UIAccessibilityRuntime.m compares snapshots and posts the notifications) */
NSDictionary *isim_ui_accessibility_extra_settings(void) {
    return @{ UIAccessibilityGuidedAccessStatusDidChangeNotification: @(UIAccessibilityIsGuidedAccessEnabled()),
              UIAccessibilityMonoAudioStatusDidChangeNotification: @(UIAccessibilityIsMonoAudioEnabled()),
              UIAccessibilitySpeakScreenStatusDidChangeNotification: @(UIAccessibilityIsSpeakScreenEnabled()),
              UIAccessibilitySpeakSelectionStatusDidChangeNotification: @(UIAccessibilityIsSpeakSelectionEnabled()),
              UIAccessibilityAssistiveTouchStatusDidChangeNotification: @(UIAccessibilityIsAssistiveTouchRunning()),
              UIAccessibilityShakeToUndoDidChangeNotification: @(UIAccessibilityIsShakeToUndoEnabled()),
              UIAccessibilityOnOffSwitchLabelsDidChangeNotification: @(UIAccessibilityIsOnOffSwitchLabelsEnabled()),
              UIAccessibilityVideoAutoplayStatusDidChangeNotification: @(UIAccessibilityIsVideoAutoplayEnabled()),
              UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification: @(UIAccessibilityPrefersCrossFadeTransitions()) };
}

/* ================= focus, coordinates, Zoom ================= */
extern id isim_ui_voiceover_focus(void), isim_ui_switch_control_item(void);
id UIAccessibilityFocusedElement(UIAccessibilityAssistiveTechnologyIdentifier at) {
    if ((!at || [at isEqualToString:UIAccessibilityNotificationVoiceOverIdentifier]) && UIAccessibilityIsVoiceOverRunning() && isim_ui_voiceover_focus()) return isim_ui_voiceover_focus();
    if ((!at || [at isEqualToString:UIAccessibilityNotificationSwitchControlIdentifier]) && UIAccessibilityIsSwitchControlRunning()) return isim_ui_switch_control_item();
    return nil;
}
static CGPoint screen_point(UIView *v, CGPoint p) { p = [v convertPoint:p toView:nil]; return v.window ? [v.window convertPoint:p toView:nil] : p; }
CGRect UIAccessibilityConvertFrameToScreenCoordinates(CGRect r, UIView *v) {
    CGRect w = [v convertRect:r toView:nil];
    if (v.window) w.origin = [v.window convertPoint:w.origin toView:nil];
    return w;
}
UIBezierPath *UIAccessibilityConvertPathToScreenCoordinates(UIBezierPath *path, UIView *v) {
    UIBezierPath *p = [path copy];
    CGPoint o = screen_point(v, CGPointZero);
    [p applyTransform:CGAffineTransformMakeTranslation(o.x, o.y)];
    return p;
}
void UIAccessibilityZoomFocusChanged(UIAccessibilityZoomType type, CGRect frame, UIView *view) {
    CGRect s = UIAccessibilityConvertFrameToScreenCoordinates(frame, view);
    NSLog(@"isim: Zoom focus %.0f,%.0f %.0fx%.0f (no Zoom)", s.origin.x, s.origin.y, s.size.width, s.size.height);
}
void UIAccessibilityRegisterGestureConflictWithZoom(void) { NSLog(@"isim: gesture conflict with Zoom registered (no Zoom)"); }

/* ================= Guided Access ================= */
static NSMutableDictionary<NSString *, NSNumber *> *restrictions;    /* identifier -> UIGuidedAccessRestrictionState */
UIGuidedAccessRestrictionState UIGuidedAccessRestrictionStateForIdentifier(NSString *ident) {
    return (UIGuidedAccessRestrictionState)[restrictions[ident] integerValue];
}
static void set_guided(BOOL on) {
    BOOL was = UIAccessibilityIsGuidedAccessEnabled();
    guided_override = on;
    if (!on) [restrictions removeAllObjects];
    NSLog(@"isim: Guided Access %@", on ? @"on" : @"off");
    if (was != on) [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityGuidedAccessStatusDidChangeNotification object:nil];
}
void UIAccessibilityRequestGuidedAccessSession(BOOL enable, void (^done)(BOOL)) {
    /* adapted: as on a supervised device whose configuration allows the app Autonomous Single App Mode */
    set_guided(enable);
    if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(YES); });
}
void UIGuidedAccessConfigureAccessibilityFeatures(UIGuidedAccessAccessibilityFeature f, BOOL enabled, void (^done)(BOOL, NSError *)) {
    BOOL ok = UIAccessibilityIsGuidedAccessEnabled();
    if (ok) NSLog(@"isim: Guided Access features 0x%lx %@", (unsigned long)f, enabled ? @"on" : @"off");
    NSError *e = ok ? nil : [NSError errorWithDomain:UIGuidedAccessErrorDomain code:UIGuidedAccessErrorPermissionDenied userInfo:nil];
    if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(ok, e); });
}
/* script "guidedaccess on|off" and "guidedaccess restrict ID allow|deny" (the person changing an app restriction in
   the Guided Access options) */
void isim_ui_guided_access_command(NSString *args) {
    NSArray *p = [[args stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] componentsSeparatedByString:@" "];
    if ([p.firstObject isEqualToString:@"on"] || [p.firstObject isEqualToString:@"off"]) {
        set_guided([p.firstObject isEqualToString:@"on"]);
        if ([p.firstObject isEqualToString:@"on"]) {
            id<UIGuidedAccessRestrictionDelegate> d = (id)UIApplication.sharedApplication.delegate;
            if ([d respondsToSelector:@selector(guidedAccessRestrictionIdentifiers)])
                for (NSString *i in d.guidedAccessRestrictionIdentifiers ?: @[])
                    NSLog(@"isim: Guided Access restriction %@ \"%@\"%@", i, [d textForGuidedAccessRestrictionWithIdentifier:i] ?: @"",
                          [d respondsToSelector:@selector(detailTextForGuidedAccessRestrictionWithIdentifier:)] && [d detailTextForGuidedAccessRestrictionWithIdentifier:i]
                              ? [NSString stringWithFormat:@" (%@)", [d detailTextForGuidedAccessRestrictionWithIdentifier:i]] : @"");
        }
        return;
    }
    if (p.count == 3 && [p[0] isEqualToString:@"restrict"]) {
        if (!UIAccessibilityIsGuidedAccessEnabled()) { NSLog(@"isim: Guided Access is off"); return; }
        id<UIGuidedAccessRestrictionDelegate> d = (id)UIApplication.sharedApplication.delegate;
        if (![d respondsToSelector:@selector(guidedAccessRestrictionIdentifiers)] || ![d.guidedAccessRestrictionIdentifiers containsObject:p[1]]) {
            NSLog(@"isim: Guided Access: no restriction %@", p[1]); return;
        }
        UIGuidedAccessRestrictionState st = [p[2] isEqualToString:@"deny"] ? UIGuidedAccessRestrictionStateDeny : UIGuidedAccessRestrictionStateAllow;
        if (!restrictions) restrictions = [NSMutableDictionary dictionary];
        restrictions[p[1]] = @(st);
        NSLog(@"isim: Guided Access restriction %@ %@", p[1], st == UIGuidedAccessRestrictionStateDeny ? @"deny" : @"allow");
        [d guidedAccessRestrictionWithIdentifier:p[1] didChangeState:st];
        return;
    }
    NSLog(@"isim: guidedaccess on|off|restrict ID allow|deny");
}

/* ================= location descriptors ================= */
@implementation UIAccessibilityLocationDescriptor
- (instancetype)initWithName:(NSString *)n view:(UIView *)v { return [self initWithName:n point:CGPointMake(CGRectGetMidX(v.bounds), CGRectGetMidY(v.bounds)) inView:v]; }
- (instancetype)initWithName:(NSString *)n point:(CGPoint)p inView:(UIView *)v { return [self initWithAttributedName:[[NSAttributedString alloc] initWithString:n ?: @""] point:p inView:v]; }
- (instancetype)initWithAttributedName:(NSAttributedString *)a point:(CGPoint)p inView:(UIView *)v {
    if ((self = [super init])) { _attributedName = [a copy]; _point = p; _view = v; }
    return self;
}
- (NSString *)name { return _attributedName.string; }
@end

/* ================= attributed and block-based element properties ================= */
#define ASSOC(getter, setter, type, key, policy) \
    static char key; \
    - (type)getter { return objc_getAssociatedObject(self, &key); } \
    - (void)setter:(type)v { objc_setAssociatedObject(self, &key, v, policy); }
#define BLOCK(getter, setter, type) ASSOC(getter, setter, type, k_##getter, OBJC_ASSOCIATION_COPY_NONATOMIC)
static NSAttributedString *attr(NSString *s) { return s ? [[NSAttributedString alloc] initWithString:s] : nil; }
static char k_alabel, k_ahint, k_avalue, k_ainput, k_context, k_ctype, k_expanded, k_direct, k_headers, k_next, k_prev, k_tinput, k_drag, k_drop, k_auto;
@implementation NSObject (UIAccessibilityAttributes)
/* attributed variants: set together with their plain text; a stored one counts while the plain text still matches */
- (NSAttributedString *)accessibilityAttributedLabel {
    AXAttributedStringReturnBlock b = self.accessibilityAttributedLabelBlock; if (b) return b();
    NSAttributedString *a = objc_getAssociatedObject(self, &k_alabel); NSString *l = self.accessibilityLabel;
    return a && [a.string isEqualToString:l ?: @""] ? a : attr(l);
}
- (void)setAccessibilityAttributedLabel:(NSAttributedString *)a { objc_setAssociatedObject(self, &k_alabel, a, OBJC_ASSOCIATION_COPY_NONATOMIC); self.accessibilityLabel = a.string; }
- (NSAttributedString *)accessibilityAttributedHint {
    AXAttributedStringReturnBlock b = self.accessibilityAttributedHintBlock; if (b) return b();
    NSAttributedString *a = objc_getAssociatedObject(self, &k_ahint); NSString *l = self.accessibilityHint;
    return a && [a.string isEqualToString:l ?: @""] ? a : attr(l);
}
- (void)setAccessibilityAttributedHint:(NSAttributedString *)a { objc_setAssociatedObject(self, &k_ahint, a, OBJC_ASSOCIATION_COPY_NONATOMIC); self.accessibilityHint = a.string; }
- (NSAttributedString *)accessibilityAttributedValue {
    AXAttributedStringReturnBlock b = self.accessibilityAttributedValueBlock; if (b) return b();
    NSAttributedString *a = objc_getAssociatedObject(self, &k_avalue); NSString *l = self.accessibilityValue;
    return a && [a.string isEqualToString:l ?: @""] ? a : attr(l);
}
- (void)setAccessibilityAttributedValue:(NSAttributedString *)a { objc_setAssociatedObject(self, &k_avalue, a, OBJC_ASSOCIATION_COPY_NONATOMIC); self.accessibilityValue = a.string; }
- (NSArray<NSAttributedString *> *)accessibilityAttributedUserInputLabels {
    AXAttributedStringArrayReturnBlock b = self.accessibilityAttributedUserInputLabelsBlock; if (b) return b();
    NSArray *a = objc_getAssociatedObject(self, &k_ainput);
    if (a) return a;
    NSMutableArray *m = nil; for (NSString *s in self.accessibilityUserInputLabels) { if (!m) m = [NSMutableArray array]; [m addObject:attr(s)]; }
    return m;
}
- (void)setAccessibilityAttributedUserInputLabels:(NSArray<NSAttributedString *> *)a {
    objc_setAssociatedObject(self, &k_ainput, a, OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSMutableArray *plain = [NSMutableArray array]; for (NSAttributedString *s in a) [plain addObject:s.string];
    objc_setAssociatedObject(self, &k_ainput, a, OBJC_ASSOCIATION_COPY_NONATOMIC);
    self.accessibilityUserInputLabels = a ? plain : nil;
}
- (UIAccessibilityTextualContext)accessibilityTextualContext { AXTextualContextReturnBlock b = self.accessibilityTextualContextBlock; return b ? b() : objc_getAssociatedObject(self, &k_context); }
- (void)setAccessibilityTextualContext:(UIAccessibilityTextualContext)c { objc_setAssociatedObject(self, &k_context, c, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (UIAccessibilityContainerType)accessibilityContainerType {
    AXContainerTypeReturnBlock b = self.accessibilityContainerTypeBlock; if (b) return b();
    NSNumber *n = objc_getAssociatedObject(self, &k_ctype);
    if (n) return n.integerValue;
    return [self conformsToProtocol:@protocol(UIAccessibilityContainerDataTable)] ? UIAccessibilityContainerTypeDataTable : UIAccessibilityContainerTypeNone;
}
- (void)setAccessibilityContainerType:(UIAccessibilityContainerType)t { objc_setAssociatedObject(self, &k_ctype, @(t), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIAccessibilityExpandedStatus)accessibilityExpandedStatus { UIAccessibilityExpandedStatus (^b)(void) = self.accessibilityExpandedStatusBlock; return b ? b() : [objc_getAssociatedObject(self, &k_expanded) integerValue]; }
- (void)setAccessibilityExpandedStatus:(UIAccessibilityExpandedStatus)s { objc_setAssociatedObject(self, &k_expanded, @(s), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIAccessibilityDirectTouchOptions)accessibilityDirectTouchOptions { return [objc_getAssociatedObject(self, &k_direct) unsignedIntegerValue]; }
- (void)setAccessibilityDirectTouchOptions:(UIAccessibilityDirectTouchOptions)o { objc_setAssociatedObject(self, &k_direct, @(o), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray *)accessibilityHeaderElements { AXArrayReturnBlock b = self.accessibilityHeaderElementsBlock; return b ? b() : objc_getAssociatedObject(self, &k_headers); }
- (void)setAccessibilityHeaderElements:(NSArray *)a { objc_setAssociatedObject(self, &k_headers, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
/* weak references (an object holding a weak box) */
static id weak_get(id o, const void *k) { NSPointerArray *p = objc_getAssociatedObject(o, k); return p.count ? [p pointerAtIndex:0] : nil; }
static void weak_set(id o, const void *k, id v) { NSPointerArray *p = [NSPointerArray weakObjectsPointerArray]; [p addPointer:(__bridge void *)v]; objc_setAssociatedObject(o, k, v ? p : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (id)accessibilityNextTextNavigationElement { AXObjectReturnBlock b = self.accessibilityNextTextNavigationElementBlock; return b ? b() : weak_get(self, &k_next); }
- (void)setAccessibilityNextTextNavigationElement:(id)e { weak_set(self, &k_next, e); }
- (id)accessibilityPreviousTextNavigationElement { AXObjectReturnBlock b = self.accessibilityPreviousTextNavigationElementBlock; return b ? b() : weak_get(self, &k_prev); }
- (void)setAccessibilityPreviousTextNavigationElement:(id)e { weak_set(self, &k_prev, e); }
- (UIResponder<UITextInput> *)accessibilityTextInputResponder {
    AXUITextInputReturnBlock b = self.accessibilityTextInputResponderBlock; if (b) return b();
    id r = weak_get(self, &k_tinput);
    return r ?: ([self conformsToProtocol:@protocol(UITextInput)] && [self isKindOfClass:[UIResponder class]] ? (id)self : nil);
}
- (void)setAccessibilityTextInputResponder:(UIResponder<UITextInput> *)r { weak_set(self, &k_tinput, r); }
- (NSArray *)accessibilityDragSourceDescriptors { return objc_getAssociatedObject(self, &k_drag); }
- (void)setAccessibilityDragSourceDescriptors:(NSArray *)a { objc_setAssociatedObject(self, &k_drag, a, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSArray *)accessibilityDropPointDescriptors { return objc_getAssociatedObject(self, &k_drop); }
- (void)setAccessibilityDropPointDescriptors:(NSArray *)a { objc_setAssociatedObject(self, &k_drop, a, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSArray *)automationElements { return objc_getAssociatedObject(self, &k_auto); }
- (void)setAutomationElements:(NSArray *)a { objc_setAssociatedObject(self, &k_auto, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
/* the accessibility element under a screen point within the receiver */
- (id)accessibilityHitTest:(CGPoint)p withEvent:(UIEvent *)e {
    extern NSArray *isim_ui_accessibility_elements(void);
    id hit = nil;
    for (id el in isim_ui_accessibility_elements()) {
        if (!CGRectContainsPoint([el accessibilityFrame], p)) continue;
        BOOL inside = el == self;
        if (!inside && [self isKindOfClass:[UIView class]])
            for (id x = el; x && !inside; x = [x isKindOfClass:[UIView class]] ? [(UIView *)x superview] : [x respondsToSelector:@selector(accessibilityContainer)] ? [x accessibilityContainer] : nil)
                inside = x == self;
        if (inside) hit = el;
    }
    return hit;
}
- (BOOL)accessibilityZoomInAtPoint:(CGPoint)p { return NO; }
- (BOOL)accessibilityZoomOutAtPoint:(CGPoint)p { return NO; }
- (NSSet *)accessibilityAssistiveTechnologyFocusedIdentifiers {
    NSMutableSet *s = [NSMutableSet set];
    if (UIAccessibilityIsVoiceOverRunning() && isim_ui_voiceover_focus() == self) [s addObject:UIAccessibilityNotificationVoiceOverIdentifier];
    if (UIAccessibilityIsSwitchControlRunning() && isim_ui_switch_control_item() == self) [s addObject:UIAccessibilityNotificationSwitchControlIdentifier];
    return s.count ? s : nil;
}
BLOCK(isAccessibilityElementBlock, setIsAccessibilityElementBlock, AXBoolReturnBlock)
BLOCK(accessibilityLabelBlock, setAccessibilityLabelBlock, AXStringReturnBlock)
BLOCK(accessibilityAttributedLabelBlock, setAccessibilityAttributedLabelBlock, AXAttributedStringReturnBlock)
BLOCK(accessibilityHintBlock, setAccessibilityHintBlock, AXStringReturnBlock)
BLOCK(accessibilityAttributedHintBlock, setAccessibilityAttributedHintBlock, AXAttributedStringReturnBlock)
BLOCK(accessibilityValueBlock, setAccessibilityValueBlock, AXStringReturnBlock)
BLOCK(accessibilityAttributedValueBlock, setAccessibilityAttributedValueBlock, AXAttributedStringReturnBlock)
BLOCK(accessibilityTraitsBlock, setAccessibilityTraitsBlock, AXTraitsReturnBlock)
BLOCK(accessibilityIdentifierBlock, setAccessibilityIdentifierBlock, AXStringReturnBlock)
BLOCK(accessibilityLanguageBlock, setAccessibilityLanguageBlock, AXStringReturnBlock)
BLOCK(accessibilityUserInputLabelsBlock, setAccessibilityUserInputLabelsBlock, AXStringArrayReturnBlock)
BLOCK(accessibilityAttributedUserInputLabelsBlock, setAccessibilityAttributedUserInputLabelsBlock, AXAttributedStringArrayReturnBlock)
BLOCK(accessibilityTextualContextBlock, setAccessibilityTextualContextBlock, AXTextualContextReturnBlock)
BLOCK(accessibilityFrameBlock, setAccessibilityFrameBlock, AXRectReturnBlock)
BLOCK(accessibilityPathBlock, setAccessibilityPathBlock, AXPathReturnBlock)
BLOCK(accessibilityActivationPointBlock, setAccessibilityActivationPointBlock, AXPointReturnBlock)
BLOCK(accessibilityElementsHiddenBlock, setAccessibilityElementsHiddenBlock, AXBoolReturnBlock)
BLOCK(accessibilityViewIsModalBlock, setAccessibilityViewIsModalBlock, AXBoolReturnBlock)
BLOCK(accessibilityShouldGroupAccessibilityChildrenBlock, setAccessibilityShouldGroupAccessibilityChildrenBlock, AXBoolReturnBlock)
BLOCK(accessibilityRespondsToUserInteractionBlock, setAccessibilityRespondsToUserInteractionBlock, AXBoolReturnBlock)
BLOCK(accessibilityNavigationStyleBlock, setAccessibilityNavigationStyleBlock, AXNavigationStyleReturnBlock)
BLOCK(accessibilityElementsBlock, setAccessibilityElementsBlock, AXArrayReturnBlock)
BLOCK(accessibilityContainerTypeBlock, setAccessibilityContainerTypeBlock, AXContainerTypeReturnBlock)
BLOCK(accessibilityHeaderElementsBlock, setAccessibilityHeaderElementsBlock, AXArrayReturnBlock)
BLOCK(accessibilityActivateBlock, setAccessibilityActivateBlock, AXBoolReturnBlock)
BLOCK(accessibilityIncrementBlock, setAccessibilityIncrementBlock, AXVoidReturnBlock)
BLOCK(accessibilityDecrementBlock, setAccessibilityDecrementBlock, AXVoidReturnBlock)
BLOCK(accessibilityPerformEscapeBlock, setAccessibilityPerformEscapeBlock, AXBoolReturnBlock)
BLOCK(accessibilityMagicTapBlock, setAccessibilityMagicTapBlock, AXBoolReturnBlock)
BLOCK(accessibilityCustomActionsBlock, setAccessibilityCustomActionsBlock, AXCustomActionsReturnBlock)
BLOCK(accessibilityCustomRotorsBlock, setAccessibilityCustomRotorsBlock, AXCustomRotorsReturnBlock)
BLOCK(accessibilityExpandedStatusBlock, setAccessibilityExpandedStatusBlock, UIAccessibilityExpandedStatus (^)(void))
BLOCK(accessibilityNextTextNavigationElementBlock, setAccessibilityNextTextNavigationElementBlock, AXObjectReturnBlock)
BLOCK(accessibilityPreviousTextNavigationElementBlock, setAccessibilityPreviousTextNavigationElementBlock, AXObjectReturnBlock)
BLOCK(accessibilityTextInputResponderBlock, setAccessibilityTextInputResponderBlock, AXUITextInputReturnBlock)
@end

/* image views draw their image larger at the accessibility text sizes (UIImage.m reads the flag) */
static char k_adjusts_image;
@implementation UIImageView (UIAccessibilityContentSizeCategoryImageAdjusting)
- (BOOL)adjustsImageSizeForAccessibilityContentSizeCategory { return [objc_getAssociatedObject(self, &k_adjusts_image) boolValue]; }
- (void)setAdjustsImageSizeForAccessibilityContentSizeCategory:(BOOL)b { objc_setAssociatedObject(self, &k_adjusts_image, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self invalidateIntrinsicContentSize]; }
@end
@implementation UIButton (UIAccessibilityContentSizeCategoryImageAdjusting)
- (BOOL)adjustsImageSizeForAccessibilityContentSizeCategory { return [objc_getAssociatedObject(self, &k_adjusts_image) boolValue]; }
- (void)setAdjustsImageSizeForAccessibilityContentSizeCategory:(BOOL)b {
    objc_setAssociatedObject(self, &k_adjusts_image, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.imageView.adjustsImageSizeForAccessibilityContentSizeCategory = b;
    [self invalidateIntrinsicContentSize];
}
@end
/* the scale an adjusting image view applies (the body text size relative to Large, at the accessibility sizes) */
CGFloat isim_ui_accessibility_image_scale(UIView *v) {
    if (![objc_getAssociatedObject(v, &k_adjusts_image) boolValue]) return 1;
    extern NSString *isim_ui_content_size_category(void);
    extern CGFloat isim_ui_content_size_multiplier(void);
    return UIContentSizeCategoryIsAccessibilityCategory(isim_ui_content_size_category()) ? isim_ui_content_size_multiplier() : 1;
}
