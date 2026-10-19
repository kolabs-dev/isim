/* isim XCUITest: XCUIApplication / XCUIElement / XCUIElementQuery / XCUIDevice.
 * The app under test runs as its own isim process (isim_xcui_launch); every element access takes a fresh
 * accessibility snapshot of it (script command "dump FILE", written by UIKit's UIAXSnapshot.m) and resolves the
 * query against it; actions are script commands (tap X Y, drag ..., type TEXT, key return, rotate ...).
 * System alerts (permission prompts, which iOS's SpringBoard shows) are presented inside the app by isim; they are
 * marked in the snapshot and belong to XCUIApplication(bundleIdentifier: "com.apple.springboard"), not the app. */
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#include <isim_host.h>
#include <unistd.h>

static const double kSettle = 0.25;          /* after an action, let the app process it and start animations */
static double xcui_now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
static void xcui_sleep(double s) { struct timespec ts = { (time_t)s, (long)((s - (time_t)s) * 1e9) }; while (nanosleep(&ts, &ts) != 0) {} }

/* ---------------- snapshot model ---------------- */
@interface _XCUINode : NSObject
@property XCUIElementType type;
@property CGRect frame;
@property (copy) NSString *identifier, *label, *value, *placeholder, *typeName;
@property BOOL enabled, selected, focused, hittable, system, background;
@property NSInteger orientation;                 /* the application row: UIDeviceOrientation */
@property (weak) _XCUINode *parent;
@property (strong) NSMutableArray<_XCUINode *> *children;
@end
@implementation _XCUINode
- (instancetype)init { if ((self = [super init])) _children = [NSMutableArray array]; return self; }
- (void)addDescendantsTo:(NSMutableArray *)out { for (_XCUINode *c in _children) { [out addObject:c]; [c addDescendantsTo:out]; } }
@end

static NSDictionary<NSString *, NSNumber *> *type_names(void) {
    static NSDictionary *d;
    static dispatch_once_t o;
    dispatch_once(&o, ^{
        d = @{ @"other": @(XCUIElementTypeOther), @"application": @(XCUIElementTypeApplication), @"window": @(XCUIElementTypeWindow),
               @"sheet": @(XCUIElementTypeSheet), @"alert": @(XCUIElementTypeAlert), @"button": @(XCUIElementTypeButton),
               @"navigationBar": @(XCUIElementTypeNavigationBar), @"tabBar": @(XCUIElementTypeTabBar), @"toolbar": @(XCUIElementTypeToolbar),
               @"table": @(XCUIElementTypeTable), @"collectionView": @(XCUIElementTypeCollectionView), @"slider": @(XCUIElementTypeSlider),
               @"pageIndicator": @(XCUIElementTypePageIndicator), @"progressIndicator": @(XCUIElementTypeProgressIndicator),
               @"activityIndicator": @(XCUIElementTypeActivityIndicator), @"segmentedControl": @(XCUIElementTypeSegmentedControl),
               @"picker": @(XCUIElementTypePicker), @"switch": @(XCUIElementTypeSwitch), @"image": @(XCUIElementTypeImage),
               @"searchField": @(XCUIElementTypeSearchField), @"scrollView": @(XCUIElementTypeScrollView), @"staticText": @(XCUIElementTypeStaticText),
               @"textField": @(XCUIElementTypeTextField), @"secureTextField": @(XCUIElementTypeSecureTextField), @"datePicker": @(XCUIElementTypeDatePicker),
               @"textView": @(XCUIElementTypeTextView), @"cell": @(XCUIElementTypeCell), @"stepper": @(XCUIElementTypeStepper),
               @"keyboard": @(XCUIElementTypeKeyboard), @"key": @(XCUIElementTypeKey), @"link": @(XCUIElementTypeLink) };
    });
    return d;
}
static NSString *type_display(XCUIElementType t) {
    static NSDictionary *names;
    static dispatch_once_t o;
    dispatch_once(&o, ^{
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        [type_names() enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSNumber *v, BOOL *stop) {
            m[v] = [[k substringToIndex:1].uppercaseString stringByAppendingString:[k substringFromIndex:1]];
        }];
        m[@(XCUIElementTypeAny)] = @"Any";
        names = m;
    });
    return names[@(t)] ?: [NSString stringWithFormat:@"ElementType(%lu)", (unsigned long)t];
}
static NSString *unesc(NSString *s) {
    if ([s rangeOfString:@"\\"].location == NSNotFound) return s;
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '\\' && i + 1 < s.length) {
            unichar n = [s characterAtIndex:++i];
            [o appendString:n == 't' ? @"\t" : n == 'n' ? @"\n" : n == 'r' ? @"\r" : [NSString stringWithFormat:@"%C", n]];
        } else [o appendFormat:@"%C", c];
    }
    return o;
}
static _XCUINode *parse_snapshot(const char *text) {
    NSArray *lines = [@(text) componentsSeparatedByString:@"\n"];
    _XCUINode *root = nil;
    NSMutableArray<_XCUINode *> *stack = [NSMutableArray array];
    for (NSString *line in lines) {
        NSMutableArray *f = [NSMutableArray array];        /* keep empty trailing fields */
        NSUInteger start = 0;
        for (NSUInteger i = 0; i <= line.length; i++)
            if (i == line.length || [line characterAtIndex:i] == '\t') { [f addObject:[line substringWithRange:NSMakeRange(start, i - start)]]; start = i + 1; }
        if (f.count < 11) continue;
        _XCUINode *n = [_XCUINode new];
        int depth = [f[0] intValue];
        n.typeName = f[1];
        n.type = [type_names()[f[1]] unsignedIntegerValue] ?: XCUIElementTypeOther;
        n.frame = CGRectMake([f[2] doubleValue], [f[3] doubleValue], [f[4] doubleValue], [f[5] doubleValue]);
        n.identifier = unesc(f[6]); n.label = unesc(f[7]); n.value = unesc(f[8]); n.placeholder = unesc(f[9]);
        NSString *flags = f[10];
        n.enabled = [flags containsString:@"e"]; n.selected = [flags containsString:@"s"];
        n.focused = [flags containsString:@"f"]; n.hittable = [flags containsString:@"h"];
        n.system = [flags containsString:@"y"]; n.background = [flags containsString:@"b"];
        if (f.count > 11) n.orientation = [f[11] integerValue];
        if (!root) { root = n; [stack addObject:n]; continue; }
        while ((int)stack.count > depth) [stack removeLastObject];
        _XCUINode *parent = stack.lastObject ?: root;
        n.parent = parent;
        [parent.children addObject:n];
        [stack addObject:n];
    }
    return root;
}

/* ---------------- the application process ---------------- */
@interface XCUIApplication ()
@property (copy) NSString *appPath;
@property int handle;
@property BOOL springboard;                     /* com.apple.springboard: the system alerts of the foreground app */
- (_XCUINode *)_isim_rawSnapshot;
- (_XCUINode *)_isim_snapshotQuiet:(BOOL)quiet;
- (void)_isim_send:(NSString *)cmd;
- (int)_isim_target;
@end
static __weak XCUIApplication *last_app;
/* bundle identifier -> the handle of its process: one per app, like iOS, whichever XCUIApplication launched it (a new
   XCUIApplication() finds it; launch() replaces it: measure(metrics: [XCTApplicationLaunchMetric()]) launches from a
   new instance each iteration) */
static NSMutableDictionary<NSString *, NSNumber *> *app_handles;
static void handle_interruptions(XCUIApplication *app);     /* UI interruption monitors (system alerts) */

/* ---------------- queries ---------------- */
typedef BOOL (^XCUIFilter)(_XCUINode *n);
@interface XCUIElementQuery ()
@property (strong) XCUIApplication *app;
@property (strong) XCUIElement *rootElement;        /* nil: the application */
@property (strong) XCUIElementQuery *source;        /* nil: start from rootElement */
@property XCUIElementType type;
@property BOOL childrenOnly;
@property (copy) NSArray<XCUIFilter> *filters;
@property (copy) NSString *desc;
- (NSArray<_XCUINode *> *)_isim_resolveIn:(_XCUINode *)root;
@end

typedef NS_ENUM(int, XCUIBinding) { XCUIBindUnique, XCUIBindFirst, XCUIBindIndex, XCUIBindApp };
@interface XCUIElement ()
@property (strong) XCUIApplication *ownerApp;
@property (strong) XCUIElementQuery *query;
@property XCUIBinding binding;
@property NSUInteger index;
- (_XCUINode *)_isim_node:(_XCUINode *)root error:(NSString **)err;
- (XCUIApplication *)_isim_app;
@end

static BOOL type_matches(_XCUINode *n, XCUIElementType t) { return t == XCUIElementTypeAny || n.type == t; }
static BOOL ident_matches(_XCUINode *n, NSString *ident) {
    return [n.identifier isEqualToString:ident] || [n.label isEqualToString:ident] || [n.value isEqualToString:ident]
        || (n.placeholder.length && [n.placeholder isEqualToString:ident]);
}

@implementation XCUIElementQuery
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSArray<_XCUINode *> *)_isim_resolveIn:(_XCUINode *)root {
    NSMutableArray *bases = [NSMutableArray array];
    if (_source) [bases addObjectsFromArray:[_source _isim_resolveIn:root]];
    else if (_rootElement && _rootElement.binding != XCUIBindApp) { _XCUINode *n = [_rootElement _isim_node:root error:NULL]; if (n) [bases addObject:n]; }
    else [bases addObject:root];
    NSMutableArray *out = [NSMutableArray array];
    for (_XCUINode *b in bases) {
        NSMutableArray *cands = [NSMutableArray array];
        if (_childrenOnly) [cands addObjectsFromArray:b.children]; else [b addDescendantsTo:cands];
        for (_XCUINode *n in cands) {
            if (!type_matches(n, _type) || [out containsObject:n]) continue;
            BOOL ok = YES;
            for (XCUIFilter f in _filters) if (!f(n)) { ok = NO; break; }
            if (ok) [out addObject:n];
        }
    }
    return out;
}
- (XCUIElementQuery *)_isim_derive:(XCUIElementType)type children:(BOOL)children {
    XCUIElementQuery *q = [XCUIElementQuery new];
    q.app = _app; q.source = self; q.type = type; q.childrenOnly = children; q.filters = @[];
    q.desc = [NSString stringWithFormat:@"%@ matching type %@ from input {%@}", children ? @"Children" : @"Descendants", type_display(type), _desc];
    return q;
}
- (XCUIElementQuery *)_isim_filter:(XCUIFilter)f desc:(NSString *)d {
    XCUIElementQuery *q = [XCUIElementQuery new];
    q.app = _app; q.rootElement = _rootElement; q.source = _source; q.type = _type; q.childrenOnly = _childrenOnly;
    q.filters = [_filters arrayByAddingObject:f]; q.desc = [NSString stringWithFormat:@"%@, %@", _desc, d];
    return q;
}
- (XCUIElement *)_isim_element:(XCUIBinding)b index:(NSUInteger)i {
    XCUIElement *e = [XCUIElement new];
    e.ownerApp = _app; e.query = self; e.binding = b; e.index = i;
    return e;
}
- (XCUIElement *)element { return [self _isim_element:XCUIBindUnique index:0]; }
- (XCUIElement *)firstMatch { return [self _isim_element:XCUIBindFirst index:0]; }
- (XCUIElement *)elementAtIndex:(NSUInteger)i { return [self elementBoundByIndex:i]; }
- (XCUIElement *)elementBoundByIndex:(NSUInteger)i { return [self _isim_element:XCUIBindIndex index:i]; }
- (NSUInteger)count { _XCUINode *root = [_app _isim_snapshotQuiet:NO]; return root ? [self _isim_resolveIn:root].count : 0; }
- (NSArray<XCUIElement *> *)allElementsBoundByIndex {
    NSMutableArray *a = [NSMutableArray array];
    for (NSUInteger i = 0, n = self.count; i < n; i++) [a addObject:[self elementBoundByIndex:i]];
    return a;
}
- (NSArray<XCUIElement *> *)allElementsBoundByAccessibilityElement { return self.allElementsBoundByIndex; }
- (XCUIElementQuery *)matchingIdentifier:(NSString *)ident {
    return [self _isim_filter:^BOOL(_XCUINode *n) { return ident_matches(n, ident); } desc:[NSString stringWithFormat:@"identifier == '%@'", ident]];
}
- (XCUIElementQuery *)matchingType:(XCUIElementType)t identifier:(NSString *)ident {
    return [self _isim_filter:^BOOL(_XCUINode *n) { return type_matches(n, t) && (!ident || ident_matches(n, ident)); }
                         desc:[NSString stringWithFormat:@"type %@%@", type_display(t), ident ? [NSString stringWithFormat:@" identifier '%@'", ident] : @""]];
}
- (XCUIElementQuery *)matchingPredicate:(NSPredicate *)p {
    return [self _isim_filter:^BOOL(_XCUINode *n) { return [p evaluateWithObject:@{ @"identifier": n.identifier ?: @"", @"label": n.label ?: @"",
        @"value": n.value ?: @"", @"title": n.label ?: @"", @"placeholderValue": n.placeholder ?: @"", @"elementType": @(n.type),
        @"isEnabled": @(n.enabled), @"enabled": @(n.enabled), @"isSelected": @(n.selected), @"selected": @(n.selected), @"hasFocus": @(n.focused) }]; }
                         desc:[NSString stringWithFormat:@"predicate `%@`", p]];
}
- (XCUIElementQuery *)containingPredicate:(NSPredicate *)p {
    XCUIElementQuery *inner = [[XCUIElementQuery new] matchingPredicate:p];
    return [self _isim_filter:^BOOL(_XCUINode *n) {
        NSMutableArray *ds = [NSMutableArray array]; [n addDescendantsTo:ds];
        for (_XCUINode *d in ds) { BOOL ok = YES; for (XCUIFilter f in inner.filters) if (!f(d)) ok = NO; if (ok) return YES; }
        return NO; } desc:[NSString stringWithFormat:@"containing predicate `%@`", p]];
}
- (XCUIElementQuery *)containingType:(XCUIElementType)t identifier:(NSString *)ident {
    return [self _isim_filter:^BOOL(_XCUINode *n) {
        NSMutableArray *ds = [NSMutableArray array]; [n addDescendantsTo:ds];
        for (_XCUINode *d in ds) if (type_matches(d, t) && (!ident || ident_matches(d, ident))) return YES;
        return NO; } desc:[NSString stringWithFormat:@"containing type %@%@", type_display(t), ident ? [NSString stringWithFormat:@" identifier '%@'", ident] : @""]];
}
- (XCUIElement *)elementMatchingPredicate:(NSPredicate *)p { return [self matchingPredicate:p].element; }
- (XCUIElement *)elementMatchingType:(XCUIElementType)t identifier:(NSString *)ident { return [self matchingType:t identifier:ident].element; }
- (XCUIElement *)objectForKeyedSubscript:(NSString *)key { return [self matchingIdentifier:key].element; }
- (XCUIElementQuery *)descendantsMatchingType:(XCUIElementType)t { return [self _isim_derive:t children:NO]; }
- (XCUIElementQuery *)childrenMatchingType:(XCUIElementType)t { return [self _isim_derive:t children:YES]; }
- (NSString *)debugDescription { return [NSString stringWithFormat:@"Query: %@", _desc]; }
- (NSString *)description { return _desc; }
#define TYPEQ(name, T) - (XCUIElementQuery *)name { return [self descendantsMatchingType:T]; }
TYPEQ(touchBars, XCUIElementTypeTouchBar) TYPEQ(groups, XCUIElementTypeGroup) TYPEQ(windows, XCUIElementTypeWindow)
TYPEQ(sheets, XCUIElementTypeSheet) TYPEQ(alerts, XCUIElementTypeAlert) TYPEQ(dialogs, XCUIElementTypeDialog)
TYPEQ(buttons, XCUIElementTypeButton) TYPEQ(navigationBars, XCUIElementTypeNavigationBar) TYPEQ(tabBars, XCUIElementTypeTabBar)
TYPEQ(tabs, XCUIElementTypeTab) TYPEQ(toolbars, XCUIElementTypeToolbar) TYPEQ(statusBars, XCUIElementTypeStatusBar)
TYPEQ(tables, XCUIElementTypeTable) TYPEQ(collectionViews, XCUIElementTypeCollectionView) TYPEQ(sliders, XCUIElementTypeSlider)
TYPEQ(pageIndicators, XCUIElementTypePageIndicator) TYPEQ(progressIndicators, XCUIElementTypeProgressIndicator)
TYPEQ(activityIndicators, XCUIElementTypeActivityIndicator) TYPEQ(segmentedControls, XCUIElementTypeSegmentedControl)
TYPEQ(pickers, XCUIElementTypePicker) TYPEQ(pickerWheels, XCUIElementTypePickerWheel) TYPEQ(switches, XCUIElementTypeSwitch)
TYPEQ(toggles, XCUIElementTypeToggle) TYPEQ(links, XCUIElementTypeLink) TYPEQ(images, XCUIElementTypeImage) TYPEQ(icons, XCUIElementTypeIcon)
TYPEQ(searchFields, XCUIElementTypeSearchField) TYPEQ(scrollViews, XCUIElementTypeScrollView) TYPEQ(staticTexts, XCUIElementTypeStaticText)
TYPEQ(textFields, XCUIElementTypeTextField) TYPEQ(secureTextFields, XCUIElementTypeSecureTextField) TYPEQ(datePickers, XCUIElementTypeDatePicker)
TYPEQ(textViews, XCUIElementTypeTextView) TYPEQ(menus, XCUIElementTypeMenu) TYPEQ(menuItems, XCUIElementTypeMenuItem) TYPEQ(maps, XCUIElementTypeMap)
TYPEQ(webViews, XCUIElementTypeWebView) TYPEQ(steppers, XCUIElementTypeStepper) TYPEQ(cells, XCUIElementTypeCell)
TYPEQ(keyboards, XCUIElementTypeKeyboard) TYPEQ(keys, XCUIElementTypeKey) TYPEQ(otherElements, XCUIElementTypeOther)
@end

/* ---------------- elements ---------------- */
@interface XCUICoordinate ()
@property (strong, readwrite) XCUIElement *referencedElement;
@property CGVector isimNormalized;
@property CGVector isimPoints;
@end
@implementation XCUIElement
- (id)copyWithZone:(NSZone *)z { return self; }
- (XCUIApplication *)_isim_app { return _binding == XCUIBindApp ? (XCUIApplication *)self : _ownerApp; }
- (NSString *)_isim_desc { return _binding == XCUIBindApp ? @"Application" : _query.desc; }
- (_XCUINode *)_isim_node:(_XCUINode *)root error:(NSString **)err {
    if (_binding == XCUIBindApp) return root;
    NSArray *m = [_query _isim_resolveIn:root];
    if (_binding == XCUIBindFirst) { if (!m.count && err) *err = @"No matches found"; return m.firstObject; }
    if (_binding == XCUIBindIndex) { if (_index >= m.count) { if (err) *err = [NSString stringWithFormat:@"No match at index %lu (%lu matches)", (unsigned long)_index, (unsigned long)m.count]; return nil; } return m[_index]; }
    if (m.count == 1) return m[0];
    if (err) *err = m.count ? [NSString stringWithFormat:@"Multiple matching elements found (%lu)", (unsigned long)m.count] : @"No matches found";
    return m.count ? m[0] : nil;
}
/* the element's node in a fresh snapshot; records a failure (named after the action) when it cannot be resolved */
- (_XCUINode *)_isim_resolveFor:(NSString *)action {
    XCUIApplication *app = [self _isim_app];
    _XCUINode *root = [app _isim_snapshotQuiet:NO];
    if (!root) { _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed to %@: the application is not running", action], nil, 0, YES); return nil; }
    NSString *err = nil;
    _XCUINode *n = [self _isim_node:root error:&err];
    BOOL ambiguous = n && err && _binding == XCUIBindUnique;
    if (!n || ambiguous) {
        _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed to %@: %@ for %@", action, err ?: @"No matches found", [self _isim_desc]], nil, 0, YES);
        return nil;
    }
    return n;
}
- (_XCUINode *)_isim_peek { _XCUINode *root = [[self _isim_app] _isim_snapshotQuiet:YES]; return root ? [self _isim_node:root error:NULL] : nil; }
- (BOOL)exists { return [self _isim_peek] != nil; }
- (BOOL)isHittable { _XCUINode *n = [self _isim_peek]; return n.hittable; }
- (BOOL)waitForExistenceWithTimeout:(NSTimeInterval)t {
    double end = xcui_now() + t;
    do { if (self.exists) return YES; xcui_sleep(50 / 1000.0); } while (xcui_now() < end);
    return self.exists;
}
- (BOOL)waitForNonExistenceWithTimeout:(NSTimeInterval)t {
    double end = xcui_now() + t;
    do { if (!self.exists) return YES; xcui_sleep(50 / 1000.0); } while (xcui_now() < end);
    return !self.exists;
}
#define ATTR(type, name, expr, dflt) - (type)name { _XCUINode *n = [self _isim_resolveFor:@"get " #name]; return n ? (expr) : (dflt); }
ATTR(NSString *, identifier, n.identifier ?: @"", @"")
ATTR(NSString *, label, n.label ?: @"", @"")
ATTR(NSString *, title, @"", @"")
ATTR(id, value, n.value.length ? n.value : nil, nil)
ATTR(NSString *, placeholderValue, n.placeholder.length ? n.placeholder : nil, nil)
ATTR(CGRect, frame, n.frame, CGRectZero)
ATTR(XCUIElementType, elementType, n.type, XCUIElementTypeAny)
ATTR(BOOL, isEnabled, n.enabled, NO)
ATTR(BOOL, isSelected, n.selected, NO)
ATTR(BOOL, hasFocus, n.focused, NO)

- (XCUIElementQuery *)descendantsMatchingType:(XCUIElementType)t {
    XCUIElementQuery *q = [XCUIElementQuery new];
    q.app = [self _isim_app]; q.rootElement = self; q.type = t; q.filters = @[];
    q.desc = [NSString stringWithFormat:@"Descendants matching type %@ from input {%@}", type_display(t), [self _isim_desc]];
    return q;
}
- (XCUIElementQuery *)childrenMatchingType:(XCUIElementType)t {
    XCUIElementQuery *q = [self descendantsMatchingType:t];
    q.childrenOnly = YES;
    q.desc = [NSString stringWithFormat:@"Children matching type %@ from input {%@}", type_display(t), [self _isim_desc]];
    return q;
}
TYPEQ(touchBars, XCUIElementTypeTouchBar) TYPEQ(groups, XCUIElementTypeGroup) TYPEQ(windows, XCUIElementTypeWindow)
TYPEQ(sheets, XCUIElementTypeSheet) TYPEQ(alerts, XCUIElementTypeAlert) TYPEQ(dialogs, XCUIElementTypeDialog)
TYPEQ(buttons, XCUIElementTypeButton) TYPEQ(navigationBars, XCUIElementTypeNavigationBar) TYPEQ(tabBars, XCUIElementTypeTabBar)
TYPEQ(tabs, XCUIElementTypeTab) TYPEQ(toolbars, XCUIElementTypeToolbar) TYPEQ(statusBars, XCUIElementTypeStatusBar)
TYPEQ(tables, XCUIElementTypeTable) TYPEQ(collectionViews, XCUIElementTypeCollectionView) TYPEQ(sliders, XCUIElementTypeSlider)
TYPEQ(pageIndicators, XCUIElementTypePageIndicator) TYPEQ(progressIndicators, XCUIElementTypeProgressIndicator)
TYPEQ(activityIndicators, XCUIElementTypeActivityIndicator) TYPEQ(segmentedControls, XCUIElementTypeSegmentedControl)
TYPEQ(pickers, XCUIElementTypePicker) TYPEQ(pickerWheels, XCUIElementTypePickerWheel) TYPEQ(switches, XCUIElementTypeSwitch)
TYPEQ(toggles, XCUIElementTypeToggle) TYPEQ(links, XCUIElementTypeLink) TYPEQ(images, XCUIElementTypeImage) TYPEQ(icons, XCUIElementTypeIcon)
TYPEQ(searchFields, XCUIElementTypeSearchField) TYPEQ(scrollViews, XCUIElementTypeScrollView) TYPEQ(staticTexts, XCUIElementTypeStaticText)
TYPEQ(textFields, XCUIElementTypeTextField) TYPEQ(secureTextFields, XCUIElementTypeSecureTextField) TYPEQ(datePickers, XCUIElementTypeDatePicker)
TYPEQ(textViews, XCUIElementTypeTextView) TYPEQ(menus, XCUIElementTypeMenu) TYPEQ(menuItems, XCUIElementTypeMenuItem) TYPEQ(maps, XCUIElementTypeMap)
TYPEQ(webViews, XCUIElementTypeWebView) TYPEQ(steppers, XCUIElementTypeStepper) TYPEQ(cells, XCUIElementTypeCell)
TYPEQ(keyboards, XCUIElementTypeKeyboard) TYPEQ(keys, XCUIElementTypeKey) TYPEQ(otherElements, XCUIElementTypeOther)

static CGPoint center_of(_XCUINode *n) { return CGPointMake(CGRectGetMidX(n.frame), CGRectGetMidY(n.frame)); }
- (void)_isim_do:(NSString *)action with:(void (^)(_XCUINode *n, XCUIApplication *app))f {
    handle_interruptions([self _isim_app]);
    _XCUINode *n = [self _isim_resolveFor:action];
    if (!n) return;
    XCUIApplication *app = [self _isim_app];
    f(n, app);
    xcui_sleep(kSettle);
}
- (void)tap {
    [self _isim_do:@"tap" with:^(_XCUINode *n, XCUIApplication *app) { CGPoint c = center_of(n); [app _isim_send:[NSString stringWithFormat:@"tap %g %g", c.x, c.y]]; }];
}
- (void)doubleTap {
    [self _isim_do:@"double tap" with:^(_XCUINode *n, XCUIApplication *app) {
        CGPoint c = center_of(n); NSString *t = [NSString stringWithFormat:@"tap %g %g", c.x, c.y]; [app _isim_send:t]; [app _isim_send:t]; }];
}
- (void)twoFingerTap { [self tap]; }
- (void)pressForDuration:(NSTimeInterval)d {
    [self _isim_do:@"press" with:^(_XCUINode *n, XCUIApplication *app) {
        CGPoint c = center_of(n); [app _isim_send:[NSString stringWithFormat:@"drag %g %g %g %g %g", c.x, c.y, c.x, c.y, d]]; xcui_sleep(d); }];
}
- (void)_isim_swipe:(CGVector)dir name:(NSString *)name {
    [self _isim_do:name with:^(_XCUINode *n, XCUIApplication *app) {
        CGPoint c = center_of(n);
        double dist = fmax(80, fmin(300, (dir.dx ? n.frame.size.width : n.frame.size.height) * 0.6));
        [app _isim_send:[NSString stringWithFormat:@"drag %g %g %g %g 0.2", c.x, c.y, c.x + dir.dx * dist, c.y + dir.dy * dist]];
        xcui_sleep(200 / 1000.0); }];
}
- (void)swipeUp { [self _isim_swipe:CGVectorMake(0, -1) name:@"swipe up"]; }
- (void)swipeDown { [self _isim_swipe:CGVectorMake(0, 1) name:@"swipe down"]; }
- (void)swipeLeft { [self _isim_swipe:CGVectorMake(-1, 0) name:@"swipe left"]; }
- (void)swipeRight { [self _isim_swipe:CGVectorMake(1, 0) name:@"swipe right"]; }
- (void)adjustToNormalizedSliderPosition:(CGFloat)pos {
    [self _isim_do:@"adjust slider" with:^(_XCUINode *n, XCUIApplication *app) {
        double cur = n.value.doubleValue / 100.0, inset = 14, w = n.frame.size.width - 2 * inset, y = CGRectGetMidY(n.frame);
        double x0 = n.frame.origin.x + inset + w * cur, x1 = n.frame.origin.x + inset + w * fmin(1, fmax(0, pos));
        [app _isim_send:[NSString stringWithFormat:@"drag %g %g %g %g 0.3", x0, y, x1, y]];
        xcui_sleep(300 / 1000.0); }];
}
- (void)typeText:(NSString *)text {
    handle_interruptions([self _isim_app]);
    _XCUINode *n = [self _isim_resolveFor:@"type text"];
    if (!n) return;
    BOOL focus = n.focused;
    NSMutableArray *ds = [NSMutableArray array]; [n addDescendantsTo:ds];
    for (_XCUINode *d in ds) if (d.focused) focus = YES;
    if (!focus) { _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed to type text: Neither element nor any descendant has keyboard focus (%@)", [self _isim_desc]], nil, 0, YES); return; }
    XCUIApplication *app = [self _isim_app];
    NSArray *parts = [text componentsSeparatedByString:@"\n"];
    for (NSUInteger i = 0; i < parts.count; i++) {
        NSString *p = parts[i];
        p = [p stringByReplacingOccurrencesOfString:@";" withString:@"\\;"];    /* `type`: "\;" is a literal ';' */
        if (p.length) [app _isim_send:[@"type " stringByAppendingString:p]];
        if (i + 1 < parts.count) [app _isim_send:@"key return"];
    }
    xcui_sleep(kSettle);
}
- (XCUICoordinate *)coordinateWithNormalizedOffset:(CGVector)off {
    XCUICoordinate *c = [XCUICoordinate new];
    c.referencedElement = self;
    c.isimNormalized = off;
    return c;
}
static void describe_tree(NSMutableString *s, _XCUINode *n, int depth) {
    [s appendFormat:@"%*s%@%@, {{%.1f, %.1f}, {%.1f, %.1f}}", depth * 2, "", depth == 0 ? @" →" : @"", type_display(n.type),
        n.frame.origin.x, n.frame.origin.y, n.frame.size.width, n.frame.size.height];
    if (n.identifier.length) [s appendFormat:@", identifier: '%@'", n.identifier];
    if (n.label.length) [s appendFormat:@", label: '%@'", n.label];
    if (n.value.length) [s appendFormat:@", value: %@", n.value];
    if (n.placeholder.length) [s appendFormat:@", placeholderValue: '%@'", n.placeholder];
    if (n.selected) [s appendString:@", Selected"];
    if (!n.enabled) [s appendString:@", Disabled"];
    [s appendString:@"\n"];
    for (_XCUINode *c in n.children) describe_tree(s, c, depth + 1);
}
- (NSString *)debugDescription {
    _XCUINode *root = [[self _isim_app] _isim_snapshotQuiet:YES];
    if (!root) return @"(application not running)";
    _XCUINode *n = [self _isim_node:root error:NULL];
    if (!n) return [NSString stringWithFormat:@"No matches for %@", [self _isim_desc]];
    NSMutableString *s = [NSMutableString stringWithFormat:@"Attributes: %@\nElement subtree:\n", type_display(n.type)];
    describe_tree(s, n, 0);
    return s;
}
- (NSString *)description { return [self _isim_desc]; }
@end

/* ---------------- coordinates ---------------- */
@implementation XCUICoordinate
- (CGVector)normalizedOffset { return _isimNormalized; }
- (CGVector)pointsOffset { return _isimPoints; }
- (CGPoint)screenPoint {
    CGRect f = _referencedElement ? _referencedElement.frame : CGRectZero;
    CGVector n = self.normalizedOffset;
    return CGPointMake(f.origin.x + f.size.width * n.dx + _isimPoints.dx, f.origin.y + f.size.height * n.dy + _isimPoints.dy);
}
- (XCUICoordinate *)coordinateWithOffset:(CGVector)o {
    XCUICoordinate *c = [XCUICoordinate new];
    c.referencedElement = _referencedElement; c.isimNormalized = _isimNormalized;
    c.isimPoints = CGVectorMake(_isimPoints.dx + o.dx, _isimPoints.dy + o.dy);
    return c;
}
- (XCUIApplication *)_isim_app { return _referencedElement.binding == XCUIBindApp ? (XCUIApplication *)_referencedElement : _referencedElement.ownerApp ?: last_app; }
- (void)tap { handle_interruptions([self _isim_app]); CGPoint p = self.screenPoint; [[self _isim_app] _isim_send:[NSString stringWithFormat:@"tap %g %g", p.x, p.y]]; xcui_sleep(kSettle); }
- (void)doubleTap { [self tap]; [self tap]; }
- (void)pressForDuration:(NSTimeInterval)d {
    handle_interruptions([self _isim_app]);
    CGPoint p = self.screenPoint;
    [[self _isim_app] _isim_send:[NSString stringWithFormat:@"drag %g %g %g %g %g", p.x, p.y, p.x, p.y, d]];
    xcui_sleep((d + kSettle));
}
- (void)pressForDuration:(NSTimeInterval)d thenDragToCoordinate:(XCUICoordinate *)other {
    handle_interruptions([self _isim_app]);
    CGPoint a = self.screenPoint, b = other.screenPoint;
    /* pressed at the start for d seconds, then dragged over 0.3 s (and lifted) */
    [[self _isim_app] _isim_send:[NSString stringWithFormat:@"drag %g %g %g %g 0.3 0 %g", a.x, a.y, b.x, b.y, fmax(0, d)]];
    xcui_sleep((d + 0.3 + kSettle));
}
@end

/* ---------------- XCUIApplication ---------------- */
static NSString *app_for_bundle_id(NSString *bid) {
    NSMutableArray *cands = [NSMutableArray array];
    const char *t = getenv("ISIM_XCUI_TARGET_APP");
    if (t && *t) [cands addObject:@(t)];
    const char *more = getenv("ISIM_XCUI_APPS");
    if (more && *more) [cands addObjectsFromArray:[@(more) componentsSeparatedByString:@":"]];
    for (NSString *c in cands) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[c stringByAppendingPathComponent:@"Info.plist"]];
        if (!bid || [info[@"CFBundleIdentifier"] isEqualToString:bid]) return c;
    }
    return nil;
}

/* the application whose process gets the system alerts and the device buttons: the one the test launched last */
static XCUIApplication *foreground_app(void) { XCUIApplication *a = last_app; return a && isim_xcui_running(a.handle) ? a : nil; }
static NSString *const kSpringboard = @"com.apple.springboard";

@implementation XCUIApplication
- (instancetype)init {
    if ((self = [super init])) {
        self.binding = XCUIBindApp; _handle = -1;
        _appPath = app_for_bundle_id(nil);
        _launchArguments = @[]; _launchEnvironment = @{};
        NSDictionary *info = _appPath ? [NSDictionary dictionaryWithContentsOfFile:[_appPath stringByAppendingPathComponent:@"Info.plist"]] : nil;
        _bundleIdentifier = info[@"CFBundleIdentifier"] ?: @"";
        NSNumber *running = app_handles[_bundleIdentifier];
        if (running && isim_xcui_running(running.intValue)) _handle = running.intValue;                  /* the same running app */
    }
    return self;
}
- (instancetype)initWithBundleIdentifier:(NSString *)bid {
    if ((self = [self init])) {
        _bundleIdentifier = [bid copy];
        _springboard = [bid isEqualToString:kSpringboard];
        _appPath = _springboard ? nil : app_for_bundle_id(bid);
        NSNumber *running = app_handles[bid];
        _handle = running && isim_xcui_running(running.intValue) ? running.intValue : -1;
    }
    return self;
}
/* SpringBoard (adapted): isim has no SpringBoard process under `isim test`; its elements are the system alerts the
   foreground app shows, and its actions go to that app's process */
- (int)_isim_target { if (!_springboard) return _handle; XCUIApplication *a = foreground_app(); return a ? a.handle : -1; }
- (XCUIApplicationState)state {
    if (_springboard) return XCUIApplicationStateRunningForeground;          /* the system is always running */
    if (!isim_xcui_running(_handle)) return XCUIApplicationStateNotRunning;
    _XCUINode *root = [self _isim_rawSnapshot];
    return root.background ? XCUIApplicationStateRunningBackground : XCUIApplicationStateRunningForeground;
}
- (void)launch {
    if (_springboard) { [self activate]; return; }
    if (!_appPath) { _XCTIsimRecordFailure(@"Failed to launch: no target application (isim test sets it from the UI-test target's TEST_TARGET_NAME)", nil, 0, YES); return; }
    if (isim_xcui_running(_handle)) isim_xcui_terminate(_handle);
    NSNumber *running = app_handles[_bundleIdentifier];               /* launched by another XCUIApplication */
    if (running && isim_xcui_running(running.intValue)) isim_xcui_terminate(running.intValue);
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[_appPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *exe = [_appPath stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: _appPath.lastPathComponent.stringByDeletingPathExtension];
    const char **argv = calloc(_launchArguments.count + 1, sizeof *argv);
    for (NSUInteger i = 0; i < _launchArguments.count; i++) argv[i] = _launchArguments[i].UTF8String;
    NSArray *keys = _launchEnvironment.allKeys;
    const char **envp = calloc(keys.count + 1, sizeof *envp);
    for (NSUInteger i = 0; i < keys.count; i++) envp[i] = [NSString stringWithFormat:@"%@=%@", keys[i], _launchEnvironment[keys[i]]].UTF8String;
    _handle = isim_xcui_launch(exe.UTF8String, argv, envp);
    free(argv); free(envp);
    if (_handle < 0) { _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed to launch %@", _appPath.lastPathComponent], nil, 0, YES); return; }
    last_app = self;
    if (!app_handles) app_handles = [NSMutableDictionary dictionary];
    if (_bundleIdentifier.length) app_handles[_bundleIdentifier] = @(_handle);
    /* launched = it answers a snapshot with a window that has content (like XCUITest waiting for the app to idle) */
    double end = xcui_now() + 30;
    while (xcui_now() < end && isim_xcui_running(_handle)) {
        _XCUINode *root = [self _isim_snapshotQuiet:YES];
        BOOL content = NO;                    /* a window with views (the root view controller has loaded) */
        for (_XCUINode *w in root.children) if (w.children.count) content = YES;
        if (content) { xcui_sleep(kSettle); return; }
        xcui_sleep(50 / 1000.0);
    }
    _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed to launch %@: %@", _appPath.lastPathComponent,
        isim_xcui_running(_handle) ? @"the app did not show a window within 30 seconds" : @"the app exited"], nil, 0, YES);
}
/* waits until the app is in the foreground (YES) or in the background (NO) */
- (BOOL)_isim_waitForeground:(BOOL)fg timeout:(double)t {
    double end = xcui_now() + t;
    do {
        _XCUINode *root = [self _isim_rawSnapshot];
        if (root && root.background != fg) return YES;
        xcui_sleep(50 / 1000.0);
    } while (xcui_now() < end && isim_xcui_running(_handle));
    return NO;
}
- (void)activate {
    if (_springboard) {                       /* SpringBoard to the front: the foreground app goes to the background */
        XCUIApplication *a = foreground_app();
        if (a) { [a _isim_send:@"home"]; [a _isim_waitForeground:NO timeout:5]; }
        return;
    }
    if (!isim_xcui_running(_handle)) { [self launch]; return; }
    last_app = self;
    if ([self _isim_rawSnapshot].background) {
        [self _isim_send:@"activate"];        /* back from the background, like tapping its icon */
        if (![self _isim_waitForeground:YES timeout:5]) _XCTIsimRecordFailure(@"Failed to activate the application: it stayed in the background", nil, 0, YES);
        xcui_sleep(kSettle);
    }
}
- (void)terminate { if (!_springboard) isim_xcui_terminate(_handle); }
- (BOOL)waitForState:(XCUIApplicationState)st timeout:(NSTimeInterval)t {
    double end = xcui_now() + t;
    do { if (self.state == st) return YES; xcui_sleep(50 / 1000.0); } while (xcui_now() < end);
    return self.state == st;
}
- (void)_isim_send:(NSString *)cmd { if (isim_xcui_send([self _isim_target], cmd.UTF8String) != 0) _XCTIsimRecordFailure(@"The application is not running", nil, 0, YES); }
- (_XCUINode *)_isim_rawSnapshot {
    int h = [self _isim_target];
    char *text = isim_xcui_snapshot(h, 10);
    if (getenv("ISIM_XCUI_DEBUG")) fprintf(stderr, "xcui snapshot (handle %d):\n%s\n", h, text ?: "(none)");
    if (!text) return nil;
    _XCUINode *root = parse_snapshot(text);
    isim_xcui_free(text);
    return root;
}
static void collect_system(_XCUINode *n, NSMutableArray *out) {
    for (_XCUINode *c in n.children) { if (c.system) [out addObject:c]; else collect_system(c, out); }
}
static void prune_system(_XCUINode *n) {
    for (_XCUINode *c in [n.children copy]) { if (c.system) [n.children removeObject:c]; else prune_system(c); }
}
- (_XCUINode *)_isim_snapshotQuiet:(BOOL)quiet {
    _XCUINode *root = [self _isim_rawSnapshot];
    if (!root) {
        if (!_springboard) return nil;
        root = [_XCUINode new];               /* no app running: SpringBoard with nothing on it */
        root.frame = CGRectZero;
    }
    if (!_springboard) { prune_system(root); return root; }
    _XCUINode *sb = [_XCUINode new];
    sb.type = XCUIElementTypeApplication; sb.typeName = @"application"; sb.frame = root.frame;
    sb.identifier = kSpringboard; sb.label = @"SpringBoard"; sb.enabled = YES; sb.hittable = YES; sb.orientation = root.orientation;
    NSMutableArray *alerts = [NSMutableArray array];
    collect_system(root, alerts);
    for (_XCUINode *a in alerts) { a.parent = sb; [sb.children addObject:a]; }
    return sb;
}
- (NSString *)description { return [NSString stringWithFormat:@"Application '%@'", _bundleIdentifier]; }
@end

/* ---------------- UI interruption monitors ---------------- */
/* Like XCUITest: before an action on the app, a system alert (SpringBoard) that is up interrupts it; the monitors
   (most recently added first) get the alert until one returns true. */
@interface _XCUIInterruptionMonitor : NSObject
@property (copy) NSString *desc;
@property (copy) BOOL (^handler)(XCUIElement *);
@end
@implementation _XCUIInterruptionMonitor
- (NSString *)description { return [NSString stringWithFormat:@"UI interruption monitor “%@”", _desc]; }
@end
static NSMutableArray<_XCUIInterruptionMonitor *> *monitors;

@implementation XCTestCase (XCUIInterruptionMonitor)
- (id<NSObject>)addUIInterruptionMonitorWithDescription:(NSString *)description handler:(BOOL (^)(XCUIElement *))handler {
    if (!monitors) monitors = [NSMutableArray array];
    _XCUIInterruptionMonitor *m = [_XCUIInterruptionMonitor new];
    m.desc = description; m.handler = handler;
    [monitors addObject:m];
    [self addTeardownBlock:^{ [monitors removeObject:m]; }];        /* monitors live for the test that adds them */
    return m;
}
- (void)removeUIInterruptionMonitor:(id<NSObject>)monitor { [monitors removeObject:(id)monitor]; }
@end

static void handle_interruptions(XCUIApplication *app) {
    if (!monitors.count || !app || app.springboard) return;
    static BOOL busy;                         /* a handler's own actions do not re-enter */
    if (busy) return;
    XCUIApplication *sb = [[XCUIApplication alloc] initWithBundleIdentifier:kSpringboard];
    XCUIElement *alert = sb.alerts.firstMatch;
    if (!alert.exists) return;
    busy = YES;
    for (_XCUIInterruptionMonitor *m in monitors.reverseObjectEnumerator.allObjects) {
        fprintf(stderr, "    t = interrupting element %s, invoking %s\n", alert.label.UTF8String, m.description.UTF8String);
        if (m.handler(alert)) break;
    }
    busy = NO;
    [alert waitForNonExistenceWithTimeout:3];
}

/* ---------------- XCUIDevice ---------------- */
@implementation XCUIDevice
@synthesize orientation = _orientation;
+ (XCUIDevice *)sharedDevice { static XCUIDevice *d; static dispatch_once_t o; dispatch_once(&o, ^{ d = [XCUIDevice new]; d->_orientation = UIDeviceOrientationPortrait; }); return d; }
/* the device orientation the app under test reports (UIDevice.orientation), or the last one set */
- (UIDeviceOrientation)orientation {
    XCUIApplication *app = foreground_app();
    _XCUINode *root = app ? [app _isim_rawSnapshot] : nil;
    if (root.orientation > 0) _orientation = (UIDeviceOrientation)root.orientation;
    return _orientation;
}
- (void)setOrientation:(UIDeviceOrientation)o {
    _orientation = o;
    NSString *name = o == UIDeviceOrientationLandscapeLeft ? @"landscapeleft" : o == UIDeviceOrientationLandscapeRight ? @"landscaperight"
        : o == UIDeviceOrientationPortraitUpsideDown ? @"upsidedown" : o == UIDeviceOrientationPortrait ? @"portrait" : nil;
    XCUIApplication *app = foreground_app();
    if (!name) { fprintf(stderr, "XCUIDevice: orientation %ld (face up/down) is not simulated; the device keeps its orientation\n", (long)o); return; }
    if (!app) return;
    [app _isim_send:[@"rotate " stringByAppendingString:name]];
    double end = xcui_now() + 5;              /* the app has turned, then the rotation animation */
    while (xcui_now() < end && [app _isim_rawSnapshot].orientation != o) xcui_sleep(50 / 1000.0);
    xcui_sleep(500 / 1000.0);
}
- (void)pressButton:(XCUIDeviceButton)b {
    XCUIApplication *app = foreground_app();
    if (b == XCUIDeviceButtonHome) {          /* the foreground app goes to the background (no home screen under isim test) */
        if (!app) return;
        [app _isim_send:@"home"];
        [app _isim_waitForeground:NO timeout:5];
        xcui_sleep(kSettle);
        return;
    }
    /* stub: Apple's Simulator has no volume buttons (XCUIDevice.Button.volumeUp/Down are device-only) */
    fprintf(stderr, "XCUIDevice: the volume buttons exist only on devices (as with Apple's Simulator); press ignored\n");
}
@end

/* ---------------- screenshots (XCUIScreenshot, XCUIScreen, XCUIElement.screenshot()) ----------------
 * The app's process draws the device screen (script command "shot FILE": PNG at the screenshot scale); the image's
 * scale makes its size the screen's size in points. An element's screenshot is that part of the app's. */
#import <UIKit/UIKit.h>

@interface XCUIScreenshot ()
- (instancetype)initIsimWithPNG:(NSData *)png scale:(CGFloat)scale;
@end
@implementation XCUIScreenshot { NSData *_png; CGFloat _scale; UIImage *_image; }
- (instancetype)initIsimWithPNG:(NSData *)png scale:(CGFloat)scale {
    if ((self = [super init])) { _png = [png copy]; _scale = scale > 0 ? scale : 1; }
    return self;
}
- (NSData *)PNGRepresentation { return _png; }
- (UIImage *)image {
    if (!_image) _image = [UIImage imageWithData:_png scale:_scale] ?: [UIImage new];
    return _image;
}
@end

/* the app's screen, or the part of it showing `frame` (CGRectNull: all of it) */
static XCUIScreenshot *xcui_screenshot(XCUIApplication *app, CGRect frame) {
    long size = 0;
    char *bytes = app ? isim_xcui_screenshot([app _isim_target], 10, &size) : NULL;
    if (!bytes) {
        _XCTIsimRecordFailure(@"Failed to take a screenshot: the application is not running", nil, 0, YES);
        return [[XCUIScreenshot alloc] initIsimWithPNG:[NSData data] scale:1];
    }
    NSData *png = [NSData dataWithBytes:bytes length:size];
    isim_xcui_free(bytes);
    UIImage *full = [UIImage imageWithData:png];
    _XCUINode *root = [app _isim_rawSnapshot];
    CGFloat points = 0;                                  /* the screen's width in points: the widest window */
    for (_XCUINode *w in root.children) points = fmax(points, w.frame.size.width);
    CGFloat scale = points > 0 && full ? full.size.width / points : 1;
    if (CGRectIsNull(frame) || !full.CGImage) return [[XCUIScreenshot alloc] initIsimWithPNG:png scale:scale];
    CGRect px = CGRectIntegral(CGRectMake(frame.origin.x * scale, frame.origin.y * scale, frame.size.width * scale, frame.size.height * scale));
    CGImageRef part = CGImageCreateWithImageInRect(full.CGImage, px);
    if (!part) return [[XCUIScreenshot alloc] initIsimWithPNG:[NSData data] scale:scale];
    UIImage *crop = [UIImage imageWithCGImage:part scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(part);
    return [[XCUIScreenshot alloc] initIsimWithPNG:UIImagePNGRepresentation(crop) ?: [NSData data] scale:scale];
}

@implementation XCUIElement (XCUIScreenshotProviding)
- (XCUIScreenshot *)screenshot {
    XCUIApplication *app = [self _isim_app];
    if ((XCUIElement *)app == self) return xcui_screenshot(app, CGRectNull);
    CGRect f = self.frame;                               /* (records a failure when the element does not exist) */
    return xcui_screenshot(app, f);
}
@end

@implementation XCUIScreen
+ (XCUIScreen *)mainScreen { static XCUIScreen *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [XCUIScreen new]; }); return s; }
+ (NSArray<XCUIScreen *> *)screens { return @[self.mainScreen]; }
- (XCUIScreenshot *)screenshot { return xcui_screenshot(foreground_app(), CGRectNull); }
@end
