/* UIBarButtonItem, UINavigationItem, UINavigationBar, UIToolbar, UITabBar(Item), bar appearances,
 * UINavigationController (push/pop with parallax, back swipe from the left edge, large titles that collapse
 * as content scrolls, scroll-edge transparency) and UITabBarController — iOS 17/18 metrics; with --os 26/27 the
 * Liquid Glass look (floating glass tab bar, glass bar buttons and back button, scroll-edge fade instead of the
 * bar material). iPad, iOS 18+: the tab bar floats at the top (iPadOS 18 style). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <math.h>

@interface NSObject (IsimZoomCheck)
- (BOOL)_isim_isZoom;
@end
@interface UIBarButtonItem (IsimNav)
- (BOOL)_isim_isFlexible; - (BOOL)_isim_isFixed; - (NSString *)_isim_displayTitle; - (UIImage *)_isim_displayImage; - (void)_isim_performFrom:(UIView *)sender;
@end
@interface UINavigationBar (IsimNav)
- (BOOL)_isim_topIsLarge;
- (CGFloat)_isim_largeHeight;
@end
@interface UITabBarController (IsimNav)
- (void)_isim_updateTabBar; - (void)_isim_layoutContainer;
@end
@interface UINavigationController (IsimNav)
- (void)_isim_layoutContainer;
@end

static NSString *const BarItemChanged = @"_IsimBarItemChanged";
static void bar_item_changed(id item) { [NSNotificationCenter.defaultCenter postNotificationName:BarItemChanged object:item]; isim_ui_set_needs_layout(); }
static UIColor *tint_for(UIView *v, UIColor *own) { return own ?: v.tintColor ?: UIColor.systemBlueColor; }
/* tab bar look: 0 bottom bar (iOS 17/18 iPhone, iOS 17 iPad), 1 floating glass capsule (iPhone, iOS 26+),
   2 top floating capsule (iPad, iOS 18), 3 top glass capsule (iPad, iOS 26+) */
static int tabbar_mode(void) {
    BOOL pad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; int os = isim_ui_os_major();
    if (pad && os >= 18) return os >= 26 ? 3 : 2;
    return os >= 26 ? 1 : 0;
}
/* the fade that replaces the bar material under Liquid Glass (scroll edge effect): from the background colour at
   the bar's outer edge to clear */
int isim_ui_edge_effect_mode(UIScrollView *sv, BOOL bottom);   /* UIScrollView.m: 0 fade, 1 hard, 2 none */
/* the hard style: an opaque band of the background with a divider on the content side */
static void draw_edge_hard(CGSize s, BOOL fromBottom) {
    double c[4], l[4]; isim_ui_rgba(UIColor.systemBackgroundColor, c); isim_ui_rgba(UIColor.separatorColor, l);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, c);
    isim_gfx_fill_rounded(0, fromBottom ? 0 : s.height - 0.5, s.width, 0.5, 0, l);
}
static void draw_edge_fade(CGSize s, BOOL fromBottom) {
    double c[4]; isim_ui_rgba(UIColor.systemBackgroundColor, c);
    int n = 16;
    for (int i = 0; i < n; i++) {
        double t = (i + 0.5) / n, a = 0.92 * (1 - t) * (1 - t);
        double rgba[4] = { c[0], c[1], c[2], a };
        double y = fromBottom ? s.height - (i + 1) * s.height / n : i * s.height / n;
        isim_gfx_fill_rounded(0, y, s.width, s.height / n + 0.5, 0, rgba);
    }
}

/* ================= bar items ================= */
void isim_ui_apply_bar_item_appearance(UIBarItem *item, UIView *bar);   /* UIAppearance.m */
static char kTitleAttrs;
@implementation UIBarItem
- (instancetype)init { if ((self = [super init])) _enabled = YES; return self; }
- (void)setTitleTextAttributes:(NSDictionary *)a forState:(UIControlState)s {
    NSMutableDictionary *d = objc_getAssociatedObject(self, &kTitleAttrs);
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(self, &kTitleAttrs, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if (a) d[@(s)] = [a copy]; else [d removeObjectForKey:@(s)];
    bar_item_changed(self);
}
- (NSDictionary *)titleTextAttributesForState:(UIControlState)s { return ((NSDictionary *)objc_getAssociatedObject(self, &kTitleAttrs))[@(s)]; }
- (NSDictionary *)_isim_attrs:(UIControlState)s { NSDictionary *d = objc_getAssociatedObject(self, &kTitleAttrs); return d[@(s)] ?: d[@(UIControlStateNormal)]; }
- (void)setEnabled:(BOOL)e { _enabled = e; bar_item_changed(self); }
- (void)setTitle:(NSString *)t { _title = [t copy]; bar_item_changed(self); }
- (void)setImage:(UIImage *)i { _image = i; bar_item_changed(self); }
@end

@implementation UIBarButtonItem { BOOL _isSystem; UIBarButtonSystemItem _system; }
- (instancetype)init { return [super init]; }
- (instancetype)initWithImage:(UIImage *)image style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action {
    if ((self = [self init])) { self.image = image; _style = style; _target = target; _action = action; } return self;
}
- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action {
    if ((self = [self init])) { self.title = title; _style = style; _target = target; _action = action; } return self;
}
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)item target:(id)target action:(SEL)action {
    if ((self = [self init])) {
        _isSystem = YES; _system = item; _target = target; _action = action;
        if (item == UIBarButtonSystemItemDone || item == UIBarButtonSystemItemSave) _style = UIBarButtonItemStyleDone;
    }
    return self;
}
- (instancetype)initWithCustomView:(UIView *)v { if ((self = [self init])) _customView = v; return self; }
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)item primaryAction:(UIAction *)a {
    if ((self = [self initWithBarButtonSystemItem:item target:nil action:NULL])) _primaryAction = a; return self;
}
- (instancetype)initWithPrimaryAction:(UIAction *)a {
    if ((self = [self init])) { _primaryAction = a; self.title = a.title.length ? a.title : nil; self.image = a.image; } return self;
}
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)item menu:(UIMenu *)m {
    if ((self = [self initWithBarButtonSystemItem:item target:nil action:NULL])) _menu = m; return self;
}
- (instancetype)initWithTitle:(NSString *)t menu:(UIMenu *)m { if ((self = [self init])) { self.title = t; _menu = m; } return self; }
- (instancetype)initWithImage:(UIImage *)i menu:(UIMenu *)m { if ((self = [self init])) { self.image = i; _menu = m; } return self; }
- (instancetype)initWithTitle:(NSString *)t image:(UIImage *)i primaryAction:(UIAction *)a menu:(UIMenu *)m {
    if ((self = [self init])) { self.title = t ?: (a.title.length ? a.title : nil); self.image = i ?: a.image; _primaryAction = a; _menu = m; } return self;
}
+ (instancetype)fixedSpaceItemOfWidth:(CGFloat)w { UIBarButtonItem *b = [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL]; b.width = w; return b; }
+ (instancetype)flexibleSpaceItem { return [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]; }
- (void)setHidden:(BOOL)h { _hidden = h; bar_item_changed(self); }
- (void)setTintColor:(UIColor *)c { _tintColor = c; bar_item_changed(self); }
- (void)setStyle:(UIBarButtonItemStyle)s { _style = s; bar_item_changed(self); }
- (void)setCustomView:(UIView *)v { _customView = v; bar_item_changed(self); }
- (BOOL)_isim_isFlexible { return _isSystem && _system == UIBarButtonSystemItemFlexibleSpace; }
- (BOOL)_isim_isFixed { return _isSystem && _system == UIBarButtonSystemItemFixedSpace; }
- (NSString *)_isim_displayTitle {
    if (self.title.length || !_isSystem) return self.title;
    switch (_system) {
    case UIBarButtonSystemItemDone: return @"Done";
    case UIBarButtonSystemItemCancel: return @"Cancel";
    case UIBarButtonSystemItemEdit: return @"Edit";
    case UIBarButtonSystemItemSave: return @"Save";
    case UIBarButtonSystemItemUndo: return @"Undo";
    case UIBarButtonSystemItemRedo: return @"Redo";
    default: return nil;
    }
}
- (UIImage *)_isim_displayImage {
    if (self.image || !_isSystem) return self.image;
    NSString *n = nil;
    switch (_system) {
    case UIBarButtonSystemItemAdd: n = @"plus"; break;
    case UIBarButtonSystemItemCompose: n = @"square.and.pencil"; break;
    case UIBarButtonSystemItemReply: n = @"arrowshape.turn.up.left"; break;
    case UIBarButtonSystemItemAction: n = @"square.and.arrow.up"; break;
    case UIBarButtonSystemItemOrganize: n = @"folder"; break;
    case UIBarButtonSystemItemBookmarks: n = @"book"; break;
    case UIBarButtonSystemItemSearch: n = @"magnifyingglass"; break;
    case UIBarButtonSystemItemRefresh: n = @"arrow.clockwise"; break;
    case UIBarButtonSystemItemStop: n = @"xmark"; break;
    case UIBarButtonSystemItemCamera: n = @"camera"; break;
    case UIBarButtonSystemItemTrash: n = @"trash"; break;
    case UIBarButtonSystemItemPlay: n = @"play.fill"; break;
    case UIBarButtonSystemItemPause: n = @"pause.fill"; break;
    case UIBarButtonSystemItemRewind: n = @"backward.fill"; break;
    case UIBarButtonSystemItemFastForward: n = @"forward.fill"; break;
    case UIBarButtonSystemItemClose: n = @"xmark.circle.fill"; break;
    default: break;
    }
    return n ? [UIImage systemImageNamed:n] : nil;
}
- (void)_isim_performFrom:(UIView *)sender {
    if (!self.enabled) return;
    if (_primaryAction) { [_primaryAction setSender:sender]; UIActionHandler h = _primaryAction.handler; if (h) h(_primaryAction); return; }
    if (_action) { [UIApplication.sharedApplication sendAction:_action to:_target from:self forEvent:nil]; return; }
    if (_menu) [sender _isim_presentMenu:_menu fromRect:sender.bounds];
}
@end

/* ---- iOS 26 bar button item badges ---- */
@implementation UIBarButtonItemBadge { NSString *_string; BOOL _indicator; }
+ (instancetype)badgeWithCount:(NSUInteger)count { UIBarButtonItemBadge *b = [self new]; b->_string = [NSString stringWithFormat:@"%lu", (unsigned long)count]; return b; }
+ (instancetype)badgeWithString:(NSString *)string { UIBarButtonItemBadge *b = [self new]; b->_string = [string copy] ?: @""; return b; }
+ (instancetype)indicatorBadge { UIBarButtonItemBadge *b = [self new]; b->_indicator = YES; return b; }
- (NSString *)stringValue { return _string; }
- (BOOL)_isim_indicator { return _indicator; }
- (id)copyWithZone:(NSZone *)z {
    UIBarButtonItemBadge *b = [UIBarButtonItemBadge new]; b->_string = _string; b->_indicator = _indicator;
    b.backgroundColor = self.backgroundColor; b.foregroundColor = self.foregroundColor; b.font = self.font; return b;
}
@end
static char kBadge;
@implementation UIBarButtonItem (UIBarButtonItemBadge)
- (UIBarButtonItemBadge *)badge { return objc_getAssociatedObject(self, &kBadge); }
- (void)setBadge:(UIBarButtonItemBadge *)b { objc_setAssociatedObject(self, &kBadge, [b copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); bar_item_changed(self); }
@end
/* the badge at the button's top trailing corner: a red dot, or a capsule with the count / string */
static void draw_badge(UIBarButtonItemBadge *b, CGSize s) {
    if (!b) return;
    double bg[4]; isim_ui_rgba(b.backgroundColor ?: UIColor.systemRedColor, bg);
    if ([b _isim_indicator] || !b.stringValue.length) { isim_gfx_fill_rounded(s.width - 12, 4, 8, 8, 4, bg); return; }
    UIFont *f = b.font ?: [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    CGSize ts = isim_ui_measure(b.stringValue, f, 100, 1);
    double w = fmax(16, ceil(ts.width) + 8), x = s.width - w + 4;
    isim_gfx_fill_rounded(x, 0, w, 16, 8, bg);
    isim_ui_draw_text(b.stringValue, f, b.foregroundColor ?: UIColor.whiteColor, CGRectMake(x, (16 - ts.height) / 2, w, ts.height), NSTextAlignmentCenter, 1, 1);
}

/* a bar button: text (17pt; Done style semibold) or a symbol, tinted */
@interface __IsimBarButton : UIControl
@property (nonatomic, strong) UIBarButtonItem *item;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) BOOL bold;
@property (nonatomic, strong) UIBarButtonItemAppearance *appearance;   /* the bar's buttonAppearance / doneButtonAppearance */
@end
@implementation __IsimBarButton
+ (instancetype)buttonFor:(UIBarButtonItem *)item host:(UIView *)host {
    isim_ui_apply_bar_item_appearance(item, host);     /* UIBarButtonItem.appearance() */
    return [self buttonFor:item];
}
+ (instancetype)buttonFor:(UIBarButtonItem *)item {
    __IsimBarButton *b = [[self alloc] initWithFrame:CGRectZero];
    b.item = item; b.text = [item _isim_displayTitle]; b.icon = [item _isim_displayImage]; b.bold = item.style == UIBarButtonItemStyleDone;
    b.accessibilityIdentifier = item.accessibilityIdentifier ?: (b.text ? [@"bar-" stringByAppendingString:b.text] : nil);
    [b addTarget:b action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)fire { [self.item _isim_performFrom:self]; }
/* the item's own title attributes win over the bar appearance's */
- (UIBarButtonItemStateAppearance *)_isim_state {
    UIBarButtonItemAppearance *a = self.appearance;
    return !self.item.enabled ? a.disabled : self.highlighted ? a.highlighted : a.normal;
}
- (id)_isim_attr:(NSString *)key {
    UIControlState st = self.highlighted ? UIControlStateHighlighted : self.item.enabled ? UIControlStateNormal : UIControlStateDisabled;
    id v = [self.item _isim_attrs:st][key];
    if (!v && st == UIControlStateHighlighted) v = [self.item _isim_attrs:UIControlStateNormal][key];
    if (!v) v = [self _isim_state].titleTextAttributes[key];
    if (!v && self.highlighted) v = self.appearance.normal.titleTextAttributes[key];
    return v;
}
- (UIFont *)font {
    UIFont *f = [self _isim_attr:NSFontAttributeName];
    return [f isKindOfClass:[UIFont class]] ? f : [UIFont systemFontOfSize:17 weight:self.bold ? UIFontWeightSemibold : UIFontWeightRegular];
}
- (UIColor *)_isim_attrColor { UIColor *c = [self _isim_attr:NSForegroundColorAttributeName]; return [c isKindOfClass:[UIColor class]] ? c : nil; }
- (CGSize)sizeThatFits:(CGSize)s {
    if (isim_ui_glass()) {                                   /* iOS 26: glass circles (symbols) and capsules (text) */
        if (self.icon) return CGSizeMake(44, 44);
        return CGSizeMake(ceil(isim_ui_measure(self.text ?: @"", [self font], 200, 1).width) + 28, 44);
    }
    if (self.icon) { CGSize i = self.icon.size; double k = 22 / fmax(1, fmax(i.width, i.height)); return CGSizeMake(fmax(28, i.width * k + 4), 44); }
    return CGSizeMake(isim_ui_measure(self.text ?: @"", [self font], 200, 1).width + 2, 44);
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    UIColor *c = self.item.enabled ? tint_for(self, self.item.tintColor) : UIColor.tertiaryLabelColor;
    double a = self.highlighted ? 0.3 : 1;
    if (isim_ui_glass()) {
        /* Done-style items are prominent (tinted glass, white glyph); the rest monochrome on clear glass */
        BOOL prominent = self.bold && self.item.enabled;
        isim_ui_draw_glass(CGRectMake(0, (s.height - 44) / 2, s.width, 44), 22, prominent ? tint_for(self, self.item.tintColor) : nil, self.highlighted ? 8 : 0);
        c = !self.item.enabled ? UIColor.tertiaryLabelColor : prominent ? UIColor.whiteColor : (self.item.tintColor ?: UIColor.labelColor);
        a = 1;
    }
    if (self.icon) {
        CGSize i = self.icon.size; double k = 22 / fmax(1, fmax(i.width, i.height));
        CGRect r = CGRectMake((s.width - i.width * k) / 2, (s.height - i.height * k) / 2, i.width * k, i.height * k);
        [self.icon _isim_drawInRect:r tint:c alpha:a];
    } else if (self.text) {
        CGSize ts = isim_ui_measure(self.text, [self font], s.width, 1);
        UIOffset o = [self _isim_state].titlePositionAdjustment;
        isim_ui_draw_text(self.text, [self font], [self _isim_attrColor] ?: c, CGRectMake(o.horizontal, (s.height - ts.height) / 2 + o.vertical, s.width, ts.height), NSTextAlignmentCenter, 1, [self _isim_attrColor] && self.highlighted ? 1 : a);
    }
    if (isim_ui_os_major() >= 26) draw_badge(self.item.badge, s);      /* iOS 26 */
}
@end

@interface UINavigationBar (IsimAppearance)
- (UINavigationBarAppearance *)_isim_appearance;
@end
/* lays out bar items left to right from x; returns the views */
static NSArray<UIView *> *place_items(UIView *host, NSArray<UIBarButtonItem *> *items, CGFloat x0, CGFloat y, CGFloat h, BOOL rightAligned, CGFloat limit) {
    NSMutableArray *views = [NSMutableArray array];
    CGFloat x = x0;
    for (UIBarButtonItem *it in rightAligned ? items.reverseObjectEnumerator.allObjects : items) {
        if (it.hidden || [it _isim_isFlexible]) continue;
        UIView *v = it.customView;
        if ([it _isim_isFixed]) { x += rightAligned ? -it.width : it.width; continue; }
        if (!v) {
            v = [__IsimBarButton buttonFor:it host:host];
            if ([host isKindOfClass:[UINavigationBar class]]) {
                UINavigationBarAppearance *ap = [(UINavigationBar *)host _isim_appearance];
                ((__IsimBarButton *)v).appearance = it.style == UIBarButtonItemStyleDone ? ap.doneButtonAppearance : ap.buttonAppearance;
            }
        }
        CGSize s = it.customView ? (CGSizeEqualToSize(v.bounds.size, CGSizeZero) ? [v sizeThatFits:CGSizeMake(200, h)] : v.bounds.size) : [v sizeThatFits:CGSizeMake(200, h)];
        if (it.width > 0) s.width = it.width;
        CGFloat vx = rightAligned ? x - s.width : x;
        if (rightAligned ? vx < limit : vx + s.width > limit) break;
        v.frame = CGRectMake(vx, y + (h - s.height) / 2, s.width, s.height);
        [host addSubview:v]; [views addObject:v];
        CGFloat gap = isim_ui_glass() ? 8 : 16;
        x = rightAligned ? vx - gap : vx + s.width + gap;
    }
    return views;
}

/* ================= navigation items & appearances ================= */
@implementation UINavigationItem
- (instancetype)init { if ((self = [super init])) _hidesSearchBarWhenScrolling = YES; return self; }
- (instancetype)initWithTitle:(NSString *)t { if ((self = [self init])) _title = [t copy]; return self; }
- (void)setSearchController:(UISearchController *)s { _searchController = s; bar_item_changed(self); }
- (void)setTitle:(NSString *)t { _title = [t copy]; bar_item_changed(self); }
- (void)setSubtitle:(NSString *)t { _subtitle = [t copy]; bar_item_changed(self); }
- (void)setAttributedSubtitle:(NSAttributedString *)t { _attributedSubtitle = [t copy]; bar_item_changed(self); }
- (void)setSubtitleView:(UIView *)v { _subtitleView = v; bar_item_changed(self); }
- (void)setLargeSubtitle:(NSString *)t { _largeSubtitle = [t copy]; bar_item_changed(self); }
- (void)setLargeAttributedSubtitle:(NSAttributedString *)t { _largeAttributedSubtitle = [t copy]; bar_item_changed(self); }
- (void)setLargeSubtitleView:(UIView *)v { _largeSubtitleView = v; bar_item_changed(self); }
- (BOOL)_isim_hasSubtitle { return _subtitle.length || _attributedSubtitle.length || _subtitleView; }
- (BOOL)_isim_hasLargeSubtitle { return _largeSubtitle.length || _largeAttributedSubtitle.length || _largeSubtitleView || [self _isim_hasSubtitle]; }
- (void)setTitleView:(UIView *)v { _titleView = v; bar_item_changed(self); }
- (void)setPrompt:(NSString *)p { _prompt = [p copy]; bar_item_changed(self); }
- (void)setBackButtonTitle:(NSString *)t { _backButtonTitle = [t copy]; bar_item_changed(self); }
- (void)setHidesBackButton:(BOOL)h { _hidesBackButton = h; bar_item_changed(self); }
- (void)setLargeTitleDisplayMode:(UINavigationItemLargeTitleDisplayMode)m { _largeTitleDisplayMode = m; bar_item_changed(self); }
- (void)setStandardAppearance:(UINavigationBarAppearance *)a { _standardAppearance = [a copy]; bar_item_changed(self); }
- (void)setScrollEdgeAppearance:(UINavigationBarAppearance *)a { _scrollEdgeAppearance = [a copy]; bar_item_changed(self); }
- (void)setCompactAppearance:(UINavigationBarAppearance *)a { _compactAppearance = [a copy]; bar_item_changed(self); }
- (void)setCompactScrollEdgeAppearance:(UINavigationBarAppearance *)a { _compactScrollEdgeAppearance = [a copy]; bar_item_changed(self); }
- (UIBarButtonItem *)leftBarButtonItem { return _leftBarButtonItems.firstObject; }
- (UIBarButtonItem *)rightBarButtonItem { return _rightBarButtonItems.firstObject; }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)i { self.leftBarButtonItems = i ? @[i] : nil; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)i { self.rightBarButtonItems = i ? @[i] : nil; }
- (void)setLeftBarButtonItems:(NSArray *)a { _leftBarButtonItems = [a copy]; bar_item_changed(self); }
- (void)setRightBarButtonItems:(NSArray *)a { _rightBarButtonItems = [a copy]; bar_item_changed(self); }
- (void)setLeftBarButtonItem:(UIBarButtonItem *)i animated:(BOOL)a { self.leftBarButtonItem = i; }
- (void)setRightBarButtonItem:(UIBarButtonItem *)i animated:(BOOL)a { self.rightBarButtonItem = i; }
- (void)setLeftBarButtonItems:(NSArray *)i animated:(BOOL)a { self.leftBarButtonItems = i; }
- (void)setRightBarButtonItems:(NSArray *)i animated:(BOOL)a { self.rightBarButtonItems = i; }
@end

@implementation UIBarButtonItemStateAppearance
- (instancetype)init { if ((self = [super init])) _titleTextAttributes = @{}; return self; }
- (void)_isim_copyFrom:(UIBarButtonItemStateAppearance *)o {
    _titleTextAttributes = [o.titleTextAttributes copy] ?: @{}; _titlePositionAdjustment = o.titlePositionAdjustment;
    _backgroundImage = o.backgroundImage; _backgroundImagePositionAdjustment = o.backgroundImagePositionAdjustment;
}
@end
@implementation UIBarButtonItemAppearance
- (instancetype)init { return [self initWithStyle:UIBarButtonItemStylePlain]; }
- (instancetype)initWithStyle:(UIBarButtonItemStyle)style {
    if ((self = [super init])) {
        _normal = [UIBarButtonItemStateAppearance new]; _highlighted = [UIBarButtonItemStateAppearance new];
        _disabled = [UIBarButtonItemStateAppearance new]; _focused = [UIBarButtonItemStateAppearance new];
        [self configureWithDefaultForStyle:style];
    }
    return self;
}
- (void)configureWithDefaultForStyle:(UIBarButtonItemStyle)style {
    for (UIBarButtonItemStateAppearance *s in @[_normal, _highlighted, _disabled, _focused]) [s _isim_copyFrom:[UIBarButtonItemStateAppearance new]];
    if (style == UIBarButtonItemStyleDone) _normal.titleTextAttributes = @{ NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] };
}
- (id)copyWithZone:(NSZone *)z {
    UIBarButtonItemAppearance *c = [UIBarButtonItemAppearance new];
    [c.normal _isim_copyFrom:_normal]; [c.highlighted _isim_copyFrom:_highlighted]; [c.disabled _isim_copyFrom:_disabled]; [c.focused _isim_copyFrom:_focused];
    return c;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
@end

@implementation UIBarAppearance { int _kind; }   /* 0 default (material), 1 opaque, 2 transparent */
- (instancetype)init { return [self initWithIdiom:UIDevice.currentDevice.userInterfaceIdiom]; }
- (instancetype)initWithIdiom:(UIUserInterfaceIdiom)idiom {
    if ((self = [super init])) { _idiom = idiom; _backgroundImageContentMode = UIViewContentModeScaleToFill; [self _isim_initSubclass]; [self configureWithDefaultBackground]; }
    return self;
}
- (instancetype)initWithBarAppearance:(UIBarAppearance *)a {
    if ((self = [self initWithIdiom:a.idiom])) [self _isim_copyFrom:a];
    return self;
}
- (void)_isim_initSubclass {}
- (void)_isim_copyFrom:(UIBarAppearance *)a {
    _kind = a->_kind; self.backgroundEffect = a.backgroundEffect; self.backgroundColor = a.backgroundColor;
    self.backgroundImage = a.backgroundImage; self.backgroundImageContentMode = a.backgroundImageContentMode;
    self.shadowColor = a.shadowColor; self.shadowImage = a.shadowImage;
}
- (id)copyWithZone:(NSZone *)z {
    UIBarAppearance *c = [[[self class] alloc] initWithIdiom:_idiom];
    [c _isim_copyFrom:self];
    return c;
}
- (void)configureWithDefaultBackground { _kind = 0; self.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]; self.backgroundColor = nil; self.shadowColor = UIColor.separatorColor; }
- (void)configureWithOpaqueBackground { _kind = 1; self.backgroundEffect = nil; self.backgroundColor = UIColor.systemBackgroundColor; self.shadowColor = UIColor.separatorColor; }
- (void)configureWithTransparentBackground { _kind = 2; self.backgroundEffect = nil; self.backgroundColor = nil; self.shadowColor = nil; }
@end
@implementation UINavigationBarAppearance
- (void)_isim_initSubclass {
    _titleTextAttributes = @{}; _largeTitleTextAttributes = @{};
    _buttonAppearance = [[UIBarButtonItemAppearance alloc] initWithStyle:UIBarButtonItemStylePlain];
    _doneButtonAppearance = [[UIBarButtonItemAppearance alloc] initWithStyle:UIBarButtonItemStyleDone];
    _backButtonAppearance = [[UIBarButtonItemAppearance alloc] initWithStyle:UIBarButtonItemStylePlain];
}
- (void)_isim_copyFrom:(UIBarAppearance *)a {
    [super _isim_copyFrom:a];
    if (![a isKindOfClass:[UINavigationBarAppearance class]]) return;
    UINavigationBarAppearance *n = (UINavigationBarAppearance *)a;
    _titleTextAttributes = [n.titleTextAttributes copy]; _largeTitleTextAttributes = [n.largeTitleTextAttributes copy];
    _titlePositionAdjustment = n.titlePositionAdjustment;
    _buttonAppearance = [n.buttonAppearance copy]; _doneButtonAppearance = [n.doneButtonAppearance copy]; _backButtonAppearance = [n.backButtonAppearance copy];
    _backIndicatorImage = n.backIndicatorImage; _backIndicatorTransitionMaskImage = n.backIndicatorTransitionMaskImage;
}
- (void)setBackIndicatorImage:(UIImage *)i transitionMaskImage:(UIImage *)m { _backIndicatorImage = i; _backIndicatorTransitionMaskImage = m; }
@end
@implementation UIToolbarAppearance @end
@implementation UITabBarAppearance @end

@interface UIView (IsimEdgeScroll)
- (UIScrollView *)_isim_edgeScrollView;     /* bars: the scroll view whose edge effect they draw */
@end
/* shared bar chrome: an appearance's background + hairline */
@interface __IsimBarBackground : UIView
- (void)apply:(UIBarAppearance *)a;
@end
@implementation __IsimBarBackground { UIVisualEffectView *_fx; UIView *_color, *_line; UIImageView *_image, *_shadowImage; BOOL _fade; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        _fx = [[UIVisualEffectView alloc] initWithEffect:nil]; _color = [UIView new]; _line = [UIView new];
        _image = [UIImageView new]; _image.clipsToBounds = YES; _shadowImage = [UIImageView new];
        for (UIView *v in @[_fx, _color, _image, _line, _shadowImage]) [self addSubview:v];
    }
    return self;
}
- (void)apply:(UIBarAppearance *)a {
    /* Liquid Glass: the default material becomes a soft edge fade, no hairline (custom colours stay) */
    BOOL fade = isim_ui_glass() && a.backgroundEffect && !a.backgroundColor;
    if (fade != _fade) { _fade = fade; isim_ui_set_needs_display(); }
    if (fade) { _fx.hidden = YES; _color.hidden = YES; _line.hidden = YES; return; }
    _fx.effect = a.backgroundEffect; _fx.hidden = !a.backgroundEffect;
    _color.backgroundColor = a.backgroundColor; _color.hidden = !a.backgroundColor;
    _image.image = a.backgroundImage; _image.contentMode = a.backgroundImageContentMode; _image.hidden = !a.backgroundImage;
    /* a shadow image replaces the hairline (tinted with the shadow colour when it is a template) */
    _shadowImage.image = a.shadowImage; _shadowImage.hidden = !a.shadowImage || !a.shadowColor;
    _shadowImage.tintColor = a.shadowColor;
    _line.backgroundColor = a.shadowColor; _line.hidden = !a.shadowColor || a.shadowImage;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds; _fx.frame = b; _color.frame = b; _image.frame = b;
    CGFloat sh = _shadowImage.image ? fmax(1.0 / 3, _shadowImage.image.size.height) : 0;
    _shadowImage.frame = self.tag == 1 ? CGRectMake(0, -sh, b.size.width, sh) : CGRectMake(0, b.size.height, b.size.width, sh);
    _line.frame = self.tag == 1 ? CGRectMake(0, 0, b.size.width, 1.0 / 3) : CGRectMake(0, b.size.height - 1.0 / 3, b.size.width, 1.0 / 3);   /* tag 1: top hairline */
}
- (void)_isim_drawContent {
    if (!_fade) return;
    /* iOS 26 scroll edge effect of the scroll view under the bar (its navigation controller's) */
    UIView *bar = self.superview;
    UIScrollView *sv = [bar respondsToSelector:@selector(_isim_edgeScrollView)] ? [(id)bar _isim_edgeScrollView] : nil;
    int mode = isim_ui_edge_effect_mode(sv, self.tag == 1);
    if (mode == 2) return;
    if (mode == 1) draw_edge_hard(self.bounds.size, self.tag == 1);
    else draw_edge_fade(self.bounds.size, self.tag == 1);
}
@end

/* ================= UINavigationBar ================= */
@interface __IsimBackButton : UIControl
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIBarButtonItemAppearance *appearance;     /* backButtonAppearance */
@property (nonatomic, strong) UIImage *indicator;                        /* backIndicatorImage (else the chevron) */
@end
@implementation __IsimBackButton
- (CGFloat)_chevronWidth { UIImage *c = [UIImage systemImageNamed:@"chevron.left"]; return c.size.width * 22 / fmax(1, c.size.height); }
- (CGSize)sizeThatFits:(CGSize)s {
    if (isim_ui_glass()) return CGSizeMake(44, 44);          /* iOS 26: a glass circle with the chevron, no title */
    return CGSizeMake(8 + [self _chevronWidth] + 6 + ceil(isim_ui_measure(self.text ?: @"", [UIFont systemFontOfSize:17], 1000, 1).width) + 2, 44);
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; UIColor *c = self.tintColor ?: UIColor.systemBlueColor; double a = self.highlighted ? 0.3 : 1;
    if (isim_ui_glass()) {
        isim_ui_draw_glass(CGRectMake(0, (s.height - 44) / 2, 44, 44), 22, nil, self.highlighted ? 8 : 0);
        UIImage *chev = [UIImage systemImageNamed:@"chevron.left"];
        if ([self _isim_isRTL]) chev = [chev imageWithHorizontallyFlippedOrientation];
        CGSize i = chev.size; double k = 20 / fmax(1, i.height);
        [chev _isim_drawInRect:CGRectMake((44 - i.width * k) / 2 - 1, (s.height - i.height * k) / 2, i.width * k, i.height * k) tint:UIColor.labelColor alpha:1];
        return;
    }
    BOOL rtl = [self _isim_isRTL];                     /* right to left: the chevron points right, after the title */
    UIImage *chev = self.indicator ?: [UIImage systemImageNamed:@"chevron.left"];
    if (rtl) chev = [chev imageWithHorizontallyFlippedOrientation];
    CGSize i = chev.size; double k = self.indicator ? fmin(1, 22 / fmax(1, i.height)) : 22 / fmax(1, i.height);
    CGRect cr = CGRectMake(8, (s.height - i.height * k) / 2, i.width * k, i.height * k);
    [chev _isim_drawInRect:rtl ? isim_ui_mirror_rect(cr, s.width) : cr tint:c alpha:a];
    UIBarButtonItemStateAppearance *st = self.highlighted ? self.appearance.highlighted : self.appearance.normal;
    UIFont *f = [st.titleTextAttributes[NSFontAttributeName] isKindOfClass:[UIFont class]] ? st.titleTextAttributes[NSFontAttributeName] : [UIFont systemFontOfSize:17];
    UIColor *tc = [st.titleTextAttributes[NSForegroundColorAttributeName] isKindOfClass:[UIColor class]] ? st.titleTextAttributes[NSForegroundColorAttributeName] : nil;
    if (tc) c = tc;
    CGSize ts = isim_ui_measure(self.text ?: @"", f, s.width, 1);
    CGRect tr = CGRectMake(8 + i.width * k + 6, (s.height - ts.height) / 2, s.width - 8 - i.width * k - 6, ts.height);
    isim_ui_draw_text(self.text ?: @"", f, c, rtl ? isim_ui_mirror_rect(tr, s.width) : tr, rtl ? NSTextAlignmentRight : NSTextAlignmentLeft, 1, a);
}
@end

@interface UINavigationBar ()
@property (nonatomic) CGFloat _isim_safeTop, _isim_largeExtra, _isim_searchExtra;
@property (nonatomic) BOOL _isim_scrolledEdge;
@property (nonatomic, copy) void (^_isim_back)(void);
@property (nonatomic, weak) UIScrollView *_isim_edgeScrollView;      /* iOS 26 scroll edge effect source */
@end
@interface UIToolbar (IsimEdge)
@property (nonatomic, weak) UIScrollView *_isim_edgeScrollView;
@end
@interface UINavigationItem (IsimSubtitle)
- (BOOL)_isim_hasSubtitle;
- (BOOL)_isim_hasLargeSubtitle;
@end
@implementation UINavigationBar { NSMutableArray<UINavigationItem *> *_stack; __IsimBarBackground *_bg; UILabel *_title, *_large; __IsimBackButton *_back; UIView *_largeClip;
                                  UILabel *_subtitle, *_largeSub; UIView *_subtitleHost, *_largeSubHost;   /* iOS 26 subtitles */
                                  NSMutableArray<UIView *> *_itemViews; UIView *_titleViewHost; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _stack = [NSMutableArray array]; _itemViews = [NSMutableArray array]; _translucent = YES;
        _bg = [__IsimBarBackground new]; [self addSubview:_bg];
        _largeClip = [UIView new]; _largeClip.clipsToBounds = YES; _largeClip.userInteractionEnabled = NO; [self addSubview:_largeClip];
        _large = [UILabel new]; _large.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold]; [_largeClip addSubview:_large];
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _title.textAlignment = NSTextAlignmentCenter; [self addSubview:_title];
        _subtitle = [UILabel new]; _subtitle.font = [UIFont systemFontOfSize:13]; _subtitle.textAlignment = NSTextAlignmentCenter; _subtitle.hidden = YES; [self addSubview:_subtitle];
        _largeSub = [UILabel new]; _largeSub.font = [UIFont systemFontOfSize:17]; _largeSub.hidden = YES; [_largeClip addSubview:_largeSub];
        _back = [__IsimBackButton new]; _back.accessibilityIdentifier = @"nav-back";
        [_back addTarget:self action:@selector(_isim_backTapped) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:_back];
        _standardAppearance = [UINavigationBarAppearance new];
        self.clipsToBounds = YES;
        self.accessibilityIdentifier = @"nav-bar";
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isim_itemChanged:) name:BarItemChanged object:nil];
    }
    return self;
}
- (void)_isim_itemChanged:(NSNotification *)n { [self setNeedsLayout]; }
- (void)_isim_backTapped { if (self._isim_back) self._isim_back(); else [self popNavigationItemAnimated:YES]; }
- (UINavigationItem *)topItem { return _stack.lastObject; }
- (UINavigationItem *)backItem { return _stack.count > 1 ? _stack[_stack.count - 2] : nil; }
- (NSArray *)items { return [_stack copy]; }
- (void)setItems:(NSArray *)items { _stack = [items mutableCopy] ?: [NSMutableArray array]; [self setNeedsLayout]; }
- (void)setItems:(NSArray *)items animated:(BOOL)a { self.items = items; }
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)a {
    id<UINavigationBarDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(navigationBar:shouldPushItem:)] && ![d navigationBar:self shouldPushItem:item]) return;
    [_stack addObject:item]; [self setNeedsLayout];
    if ([d respondsToSelector:@selector(navigationBar:didPushItem:)]) [d navigationBar:self didPushItem:item];
}
- (UINavigationItem *)popNavigationItemAnimated:(BOOL)a {
    UINavigationItem *i = _stack.lastObject;
    id<UINavigationBarDelegate> d = _delegate;
    if (i && [d respondsToSelector:@selector(navigationBar:shouldPopItem:)] && ![d navigationBar:self shouldPopItem:i]) return nil;
    if (i) [_stack removeLastObject];
    [self setNeedsLayout];
    if (i && [d respondsToSelector:@selector(navigationBar:didPopItem:)]) [d navigationBar:self didPopItem:i];
    return i;
}
/* the appearance in effect: the top item's, else the bar's; at the scroll edge the scroll-edge one (else the standard
   one made transparent); in compact height (iPhone landscape) the compact ones first */
- (UINavigationBarAppearance *)_isim_appearance {
    UINavigationItem *it = self.topItem;
    BOOL compact = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact;
    BOOL edge = !self._isim_scrolledEdge && self._isim_back != nil;      /* (a standalone bar has no scroll edge: standard) */
    UINavigationBarAppearance *standard = (compact ? (it.compactAppearance ?: _compactAppearance) : nil) ?: it.standardAppearance ?: _standardAppearance;
    if (!edge) return standard;
    UINavigationBarAppearance *e = (compact ? (it.compactScrollEdgeAppearance ?: _compactScrollEdgeAppearance) : nil) ?: it.scrollEdgeAppearance ?: _scrollEdgeAppearance;
    if (e) return e;
    UINavigationBarAppearance *t = [standard copy];
    [t configureWithTransparentBackground];
    return t;
}
/* the large title's band: 52, plus 22 for a large subtitle (iOS 26) */
- (CGFloat)_isim_largeHeight { return 52 + ([self.topItem _isim_hasLargeSubtitle] ? 22 : 0); }
- (void)setPrefersLargeTitles:(BOOL)p { _prefersLargeTitles = p; [self setNeedsLayout]; [self.superview setNeedsLayout]; }
/* large titles: Always/Never on the item, Automatic inherits from the item below (the root follows prefersLargeTitles) */
- (BOOL)_isim_topIsLarge {
    BOOL large = _prefersLargeTitles;
    for (UINavigationItem *i in _stack) {
        if (i.largeTitleDisplayMode == UINavigationItemLargeTitleDisplayModeAlways) large = _prefersLargeTitles || YES;
        else if (i.largeTitleDisplayMode == UINavigationItemLargeTitleDisplayModeNever || i.largeTitleDisplayMode == UINavigationItemLargeTitleDisplayModeInline) large = NO;
        if (!_prefersLargeTitles && i.largeTitleDisplayMode != UINavigationItemLargeTitleDisplayModeAlways) large = NO;
    }
    return large;
}
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, 44); }
- (NSDictionary *)_isim_titleAttrs:(BOOL)large {
    UINavigationBarAppearance *ap = [self _isim_appearance];
    return large ? (ap.largeTitleTextAttributes.count ? ap.largeTitleTextAttributes : _largeTitleTextAttributes) : (ap.titleTextAttributes.count ? ap.titleTextAttributes : _titleTextAttributes);
}
- (UIColor *)_isim_titleColor:(BOOL)large {
    UIColor *c = [self _isim_titleAttrs:large][NSForegroundColorAttributeName];
    return [c isKindOfClass:[UIColor class]] ? c : UIColor.labelColor;
}
- (UIFont *)_isim_titleFont:(BOOL)large {
    UIFont *f = [self _isim_titleAttrs:large][NSFontAttributeName];
    return [f isKindOfClass:[UIFont class]] ? f : large ? [UIFont systemFontOfSize:34 weight:UIFontWeightBold] : [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, top = self._isim_safeTop, extra = self._isim_largeExtra;
    BOOL large = [self _isim_topIsLarge];
    UINavigationItem *item = self.topItem, *prev = self.backItem;
    /* background: transparent at the scroll edge (iOS 15+), the standard appearance once content is under the bar */
    UINavigationBarAppearance *ap = [self _isim_appearance];
    if (_barTintColor && self._isim_scrolledEdge && !self.topItem.standardAppearance) { UINavigationBarAppearance *o = [ap copy]; o.backgroundColor = _barTintColor; ap = o; }
    _bg.frame = self.bounds; [_bg apply:ap]; [_bg setNeedsLayout];
    for (UIView *v in _itemViews) [v removeFromSuperview];
    [_itemViews removeAllObjects];
    CGFloat margin = W > 400 ? 20 : 16, y = top;
    /* back button or left items */
    CGFloat leftEnd = margin;
    BOOL showBack = prev && !item.hidesBackButton && (!item.leftBarButtonItems.count || item.leftItemsSupplementBackButton);
    _back.hidden = !showBack;
    if (showBack) {
        NSString *t = item.backButtonTitle ?: prev.backButtonTitle ?: prev.backBarButtonItem.title ?: prev.title ?: @"Back";
        if (isim_ui_measure(t, [UIFont systemFontOfSize:17], 1000, 1).width > W / 3) t = @"Back";
        _back.text = t; _back.tintColor = self.tintColor;
        _back.appearance = ap.backButtonAppearance; _back.indicator = ap.backIndicatorImage;
        CGSize bs = [_back sizeThatFits:CGSizeZero];
        _back.frame = CGRectMake(isim_ui_glass() ? margin : margin - 8 - 4, y, bs.width, 44); [_back setNeedsDisplay];
        leftEnd = CGRectGetMaxX(_back.frame) + 8;
    }
    NSArray *lv = place_items(self, item.leftBarButtonItems ?: @[], showBack ? leftEnd : margin, y, 44, NO, W / 2);
    for (UIView *v in lv) { leftEnd = fmax(leftEnd, CGRectGetMaxX(v.frame) + 8); }
    NSArray *rv = place_items(self, item.rightBarButtonItems ?: @[], W - margin, y, 44, YES, W / 2);
    CGFloat rightStart = W - margin;
    for (UIView *v in rv) rightStart = fmin(rightStart, v.frame.origin.x - 8);
    [_itemViews addObjectsFromArray:lv]; [_itemViews addObjectsFromArray:rv];
    /* inline title (centered), or the large title below the bar row */
    [_titleViewHost removeFromSuperview]; _titleViewHost = nil;
    CGFloat side = fmax(leftEnd, W - rightStart);
    if (item.titleView) {
        UIView *tv = item.titleView;
        CGSize ts = CGSizeEqualToSize(tv.bounds.size, CGSizeZero) ? [tv sizeThatFits:CGSizeMake(W - 2 * side, 44)] : tv.bounds.size;
        tv.frame = CGRectMake((W - ts.width) / 2, y + (44 - ts.height) / 2, ts.width, ts.height);
        [self addSubview:tv]; _titleViewHost = tv;
        _title.hidden = YES;
    } else {
        _title.hidden = NO;
        _title.text = item.title; _title.textColor = [self _isim_titleColor:NO]; _title.font = [self _isim_titleFont:NO];
        _title.frame = CGRectMake(side + ap.titlePositionAdjustment.horizontal, y + ap.titlePositionAdjustment.vertical, fmax(0, W - 2 * side), 44);
        _title.alpha = large ? (extra < 6 ? 1 : 0) : 1;
        BOOL sub = [item _isim_hasSubtitle];                    /* iOS 26: the subtitle under the inline title */
        [_subtitleHost removeFromSuperview]; _subtitleHost = nil;
        _subtitle.hidden = !sub || item.subtitleView;
        if (sub) {
            CGRect t = _title.frame;
            _title.frame = CGRectMake(t.origin.x, t.origin.y + 3, t.size.width, 22);
            CGRect sr = CGRectMake(t.origin.x, t.origin.y + 24, t.size.width, 16);
            if (item.subtitleView) {
                UIView *sv = item.subtitleView; CGSize ss = CGSizeEqualToSize(sv.bounds.size, CGSizeZero) ? [sv sizeThatFits:sr.size] : sv.bounds.size;
                sv.frame = CGRectMake(CGRectGetMidX(sr) - fmin(ss.width, sr.size.width) / 2, sr.origin.y, fmin(ss.width, sr.size.width), fmin(ss.height, 18));
                sv.alpha = _title.alpha; [self addSubview:sv]; _subtitleHost = sv;
            } else {
                if (item.attributedSubtitle.length) _subtitle.attributedText = item.attributedSubtitle;
                else { _subtitle.attributedText = nil; _subtitle.text = item.subtitle; _subtitle.textColor = UIColor.secondaryLabelColor; }
                _subtitle.frame = sr; _subtitle.alpha = _title.alpha;
            }
        }
    }
    /* the large title sits in the band below the bar row and slides up under it as content scrolls */
    _largeClip.hidden = !large || extra <= 0;
    if (large) {
        _largeClip.frame = CGRectMake(0, y + 44, W, extra);
        _large.text = item.title; _large.textColor = [self _isim_titleColor:YES]; _large.font = [self _isim_titleFont:YES];
        CGFloat LH = [self _isim_largeHeight];
        _large.frame = CGRectMake(margin, extra - LH, W - 2 * margin, 50);
        [_largeSubHost removeFromSuperview]; _largeSubHost = nil;
        BOOL lsub = [item _isim_hasLargeSubtitle];              /* iOS 26: the subtitle under the large title, leading */
        UIView *lv = item.largeSubtitleView ?: (item.largeSubtitle.length || item.largeAttributedSubtitle.length ? nil : item.subtitleView);
        _largeSub.hidden = !lsub || lv;
        CGRect lr = CGRectMake(margin, extra - LH + 48, W - 2 * margin, 20);
        if (lsub && lv) {
            CGSize ls = CGSizeEqualToSize(lv.bounds.size, CGSizeZero) ? [lv sizeThatFits:lr.size] : lv.bounds.size;
            lv.frame = CGRectMake(lr.origin.x, lr.origin.y, fmin(ls.width, lr.size.width), fmin(ls.height, 20));
            [_largeClip addSubview:lv]; _largeSubHost = lv;
        } else if (lsub) {
            NSAttributedString *la = item.largeAttributedSubtitle.length ? item.largeAttributedSubtitle : item.largeSubtitle.length ? nil : item.attributedSubtitle;
            if (la.length) _largeSub.attributedText = la;
            else { _largeSub.attributedText = nil; _largeSub.text = item.largeSubtitle.length ? item.largeSubtitle : item.subtitle; _largeSub.textColor = UIColor.secondaryLabelColor; }
            _largeSub.frame = lr;
        }
    }
    if ([self _isim_isRTL]) {                          /* right to left: back and leading items on the right */
        if (showBack) _back.frame = isim_ui_mirror_rect(_back.frame, W);
        for (UIView *v in _itemViews) v.frame = isim_ui_mirror_rect(v.frame, W);
        if (_titleViewHost) _titleViewHost.frame = isim_ui_mirror_rect(_titleViewHost.frame, W);
        _title.frame = isim_ui_mirror_rect(_title.frame, W);
    }
    [self bringSubviewToFront:_back];
    [self _isim_placeSearchBarAtY:y + 44 + (large ? extra : 0) visible:self._isim_searchExtra];   /* UISearch.m */
}
@end

/* ================= UIToolbar ================= */
static char k_toolbar_edge;
@implementation UIToolbar (IsimEdge)
- (UIScrollView *)_isim_edgeScrollView { return objc_getAssociatedObject(self, &k_toolbar_edge); }
- (void)set_isim_edgeScrollView:(UIScrollView *)sv { objc_setAssociatedObject(self, &k_toolbar_edge, sv, OBJC_ASSOCIATION_ASSIGN); }
@end
@implementation UIToolbar { __IsimBarBackground *_bg; NSMutableArray<UIView *> *_views; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _views = [NSMutableArray array]; _translucent = YES;
        _bg = [__IsimBarBackground new]; _bg.tag = 1; [self addSubview:_bg];
        _standardAppearance = [UIToolbarAppearance new];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(setNeedsLayout) name:BarItemChanged object:nil];
    }
    return self;
}
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, 44); }
- (void)setItems:(NSArray *)items { _items = [items copy]; [self setNeedsLayout]; }
- (void)setItems:(NSArray *)items animated:(BOOL)a { self.items = items; }
- (void)layoutSubviews {
    [super layoutSubviews];
    _bg.frame = self.bounds; [_bg apply:_standardAppearance];
    if (_barTintColor) { UIToolbarAppearance *o = [_standardAppearance copy]; o.backgroundColor = _barTintColor; [_bg apply:o]; }
    for (UIView *v in _views) [v removeFromSuperview];
    [_views removeAllObjects];
    /* fixed widths and buttons first, then flexible spaces share what is left */
    CGFloat W = self.bounds.size.width, margin = W > 400 ? 20 : 16, used = 0; NSUInteger flex = 0, n = 0;
    NSMutableArray *sizes = [NSMutableArray array];
    for (UIBarButtonItem *it in _items) {
        if (it.hidden) { [sizes addObject:@0]; continue; }
        if ([it _isim_isFlexible]) { flex++; [sizes addObject:@(-1)]; continue; }
        if ([it _isim_isFixed]) { used += it.width; [sizes addObject:@(it.width)]; continue; }
        UIView *v = it.customView ?: [__IsimBarButton buttonFor:it host:self];
        CGSize s = it.customView && !CGSizeEqualToSize(v.bounds.size, CGSizeZero) ? v.bounds.size : [v sizeThatFits:CGSizeMake(200, 44)];
        if (it.width > 0) s.width = it.width;
        v.bounds = CGRectMake(0, 0, s.width, s.height);
        [_views addObject:v]; [sizes addObject:@(s.width)]; used += s.width; n++;
    }
    CGFloat gap = isim_ui_glass() ? 8 : 16, gaps = n > 1 && !flex ? gap * (n - 1) : 0, free = fmax(0, W - 2 * margin - used - gaps);
    CGFloat x = margin; NSUInteger vi = 0;
    for (NSUInteger i = 0; i < _items.count; i++) {
        UIBarButtonItem *it = _items[i]; double w = [sizes[i] doubleValue];
        if (it.hidden) continue;
        if (w < 0) { x += free / flex; continue; }
        if ([it _isim_isFixed]) { x += w; continue; }
        UIView *v = _views[vi++];
        v.frame = CGRectMake(x, (44 - v.bounds.size.height) / 2, w, v.bounds.size.height);
        [self addSubview:v];
        x += w + (flex ? 0 : gap);
    }
}
@end

/* ================= UITabBar(Item) ================= */
@implementation UITabBarItem { BOOL _isSystem; UITabBarSystemItem _system; }
- (instancetype)init { return [super init]; }
- (instancetype)initWithTitle:(NSString *)t image:(UIImage *)i tag:(NSInteger)tag { if ((self = [self init])) { self.title = t; self.image = i; self.tag = tag; } return self; }
- (instancetype)initWithTitle:(NSString *)t image:(UIImage *)i selectedImage:(UIImage *)s { if ((self = [self init])) { self.title = t; self.image = i; _selectedImage = s; } return self; }
- (instancetype)initWithTabBarSystemItem:(UITabBarSystemItem)item tag:(NSInteger)tag {
    static NSString *const names[][2] = { { @"More", @"ellipsis" }, { @"Favorites", @"star.fill" }, { @"Featured", @"star" }, { @"Top Rated", @"star" },
        { @"Recents", @"clock" }, { @"Contacts", @"person.crop.circle" }, { @"History", @"clock" }, { @"Bookmarks", @"book" }, { @"Search", @"magnifyingglass" },
        { @"Downloads", @"arrow.down.circle" }, { @"Most Recent", @"clock" }, { @"Most Viewed", @"list.number" } };
    if ((self = [self init])) {
        _isSystem = YES; _system = item; self.tag = tag;
        if ((NSUInteger)item < sizeof names / sizeof *names) { self.title = names[item][0]; self.image = [UIImage systemImageNamed:names[item][1]]; }
    }
    return self;
}
- (void)setBadgeValue:(NSString *)b { _badgeValue = [b copy]; bar_item_changed(self); }
- (void)setSelectedImage:(UIImage *)i { _selectedImage = i; bar_item_changed(self); }
@end

@interface __IsimTabButton : UIControl
@property (nonatomic, strong) UITabBarItem *item;
@property (nonatomic) BOOL on;
@property (nonatomic) int mode;                /* tabbar_mode() */
@property (nonatomic) BOOL iconOnly;           /* iOS 26: the minimized tab bar's selected tab */
@property (nonatomic, strong) UIColor *onColor, *offColor;
@end
@interface UIBarItem (IsimAttrs)
- (NSDictionary *)_isim_attrs:(UIControlState)s;
@end
@implementation __IsimTabButton
- (UIFont *)_f:(UIFont *)def { UIFont *f = [self.item _isim_attrs:self.on ? UIControlStateSelected : UIControlStateNormal][NSFontAttributeName]; return [f isKindOfClass:[UIFont class]] ? f : def; }
- (UIColor *)_c:(UIColor *)def { UIColor *c = [self.item _isim_attrs:self.on ? UIControlStateSelected : UIControlStateNormal][NSForegroundColorAttributeName]; return [c isKindOfClass:[UIColor class]] ? c : def; }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; UIColor *c = self.on ? self.onColor : self.offColor; double a = self.highlighted ? 0.5 : 1;
    UIImage *img = self.on && self.item.selectedImage ? self.item.selectedImage : self.item.image;
    if (self.mode >= 2) {                     /* iPad top tab bar: titles in a capsule, the selected one on a pill */
        if (self.on) {
            if (self.mode == 3) isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), s.height / 2, nil, 4 | 8);
            else { double p[4]; isim_ui_rgba(isim_ui_style() == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.36 alpha:1] : UIColor.whiteColor, p); isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, p); }
        }
        UIFont *f = [self _f:[UIFont systemFontOfSize:15 weight:self.on ? UIFontWeightSemibold : UIFontWeightMedium]];
        CGSize ts = isim_ui_measure(self.item.title ?: @"", f, s.width - 8, 1);
        isim_ui_draw_text(self.item.title ?: @"", f, [self _c:self.on ? self.onColor : UIColor.labelColor], CGRectMake(4, (s.height - ts.height) / 2, s.width - 8, ts.height), NSTextAlignmentCenter, 1, a);
        return;
    }
    if (self.mode == 1 && self.iconOnly) {     /* the minimized bar: the selected tab's symbol in the circle */
        if (img) {
            CGSize i = img.size; double k = 26 / fmax(1, fmax(i.width, i.height));
            [img _isim_drawInRect:CGRectMake((s.width - i.width * k) / 2, (s.height - i.height * k) / 2, i.width * k, i.height * k) tint:c alpha:a];
        }
        return;
    }
    if (self.mode == 1) {                     /* iOS 26 floating tab bar: the selected tab sits on a lighter pill */
        if (self.on) { double p[4]; isim_ui_rgba(isim_ui_style() == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:1 alpha:0.14] : [UIColor colorWithWhite:0 alpha:0.07], p);
                       isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, p); }
        if (!self.on) c = UIColor.labelColor;
        if (img) {
            CGSize i = img.size; double k = 24 / fmax(1, fmax(i.width, i.height));
            [img _isim_drawInRect:CGRectMake((s.width - i.width * k) / 2, 5 + (24 - i.height * k) / 2, i.width * k, i.height * k) tint:c alpha:a];
        }
        UIFont *f = [self _f:[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold]];
        isim_ui_draw_text(self.item.title ?: @"", f, [self _c:c], CGRectMake(2, 32, s.width - 4, 13), NSTextAlignmentCenter, 1, a);
        if (self.item.badgeValue) {
            UIFont *bf = [UIFont systemFontOfSize:13]; NSString *b = self.item.badgeValue;
            double bw = fmax(18, isim_ui_measure(b, bf, 100, 1).width + 10), bx = s.width / 2 + 6;
            double rgba[4]; isim_ui_rgba(self.item.badgeColor ?: UIColor.systemRedColor, rgba);
            isim_gfx_fill_rounded(bx, 1, bw, 18, 9, rgba);
            isim_ui_draw_text(b, bf, UIColor.whiteColor, CGRectMake(bx, 1 + (18 - 16) / 2.0, bw, 16), NSTextAlignmentCenter, 1, 1);
        }
        return;
    }
    if (img) {
        CGSize i = img.size; double k = 24 / fmax(1, fmax(i.width, i.height));
        [img _isim_drawInRect:CGRectMake((s.width - i.width * k) / 2, 7 + (25 - i.height * k) / 2, i.width * k, i.height * k) tint:c alpha:a];
    }
    UIFont *f = [self _f:[UIFont systemFontOfSize:10 weight:UIFontWeightMedium]];
    isim_ui_draw_text(self.item.title ?: @"", f, [self _c:c], CGRectMake(2, 34, s.width - 4, 13), NSTextAlignmentCenter, 1, a);
    if (self.item.badgeValue) {
        UIFont *bf = [UIFont systemFontOfSize:13]; NSString *b = self.item.badgeValue;
        double bw = fmax(18, isim_ui_measure(b, bf, 100, 1).width + 10), bx = s.width / 2 + 6;
        double rgba[4]; isim_ui_rgba(self.item.badgeColor ?: UIColor.systemRedColor, rgba);
        isim_gfx_fill_rounded(bx, 3, bw, 18, 9, rgba);
        isim_ui_draw_text(b, bf, UIColor.whiteColor, CGRectMake(bx, 3 + (18 - 16) / 2.0, bw, 16), NSTextAlignmentCenter, 1, 1);
    }
}
@end

@interface UITabBar (IsimMinimized)
@property (nonatomic, setter=_isim_setMinimized:) BOOL _isim_minimized;
@end
@protocol __IsimTabBarExpanding
- (void)_isim_expandTabBar;
@end
@implementation UITabBar { __IsimBarBackground *_bg; NSMutableArray<__IsimTabButton *> *_buttons; BOOL _minimized; }
- (BOOL)_isim_minimized { return _minimized; }
- (void)_isim_setMinimized:(BOOL)m { if (m != _minimized) { _minimized = m; [self setNeedsLayout]; isim_ui_set_needs_display(); } }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _buttons = [NSMutableArray array]; _translucent = YES;
        _bg = [__IsimBarBackground new]; _bg.tag = 1; [self addSubview:_bg];
        _standardAppearance = [UITabBarAppearance new];
        self.accessibilityIdentifier = @"tab-bar";
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(setNeedsLayout) name:BarItemChanged object:nil];
    }
    return self;
}
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, 49); }
- (void)setItems:(NSArray *)items { _items = [items copy]; if (![_items containsObject:_selectedItem]) _selectedItem = _items.firstObject; [self setNeedsLayout]; }
- (void)setItems:(NSArray *)items animated:(BOOL)a { self.items = items; }
- (void)setSelectedItem:(UITabBarItem *)i { _selectedItem = i; [self setNeedsLayout]; isim_ui_set_needs_display(); }
- (void)layoutSubviews {
    [super layoutSubviews];
    _bg.frame = self.bounds; [_bg apply:_standardAppearance];
    if (_barTintColor) { UITabBarAppearance *o = [_standardAppearance copy]; o.backgroundColor = _barTintColor; [_bg apply:o]; }
    NSArray *items = _items.count > 5 ? [_items subarrayWithRange:NSMakeRange(0, 5)] : _items;   /* isim: no "More" tab yet */
    while (_buttons.count < items.count) {
        __IsimTabButton *b = [[__IsimTabButton alloc] initWithFrame:CGRectZero];
        [b addTarget:self action:@selector(_isim_tapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b]; [_buttons addObject:b];
    }
    while (_buttons.count > items.count) { [_buttons.lastObject removeFromSuperview]; [_buttons removeLastObject]; }
    int mode = tabbar_mode();
    _bg.hidden = mode != 0;
    CGRect area = mode == 1 ? [self _isim_capsule] : self.bounds;
    if (mode) area = CGRectInset(area, 4, 4);
    CGFloat w = area.size.width / fmax(1, items.count);
    BOOL mini = mode == 1 && _minimized;
    for (NSUInteger i = 0; i < items.count; i++) {
        __IsimTabButton *b = _buttons[i];
        isim_ui_apply_bar_item_appearance(items[i], self);    /* UITabBarItem.appearance() */
        b.item = items[i]; b.on = items[i] == _selectedItem; b.mode = mode;
        b.iconOnly = mini && b.on; b.hidden = mini && !b.on;
        if (mini) {                                         /* minimized: only the selected tab, in a circle */
            b.onColor = self.tintColor ?: UIColor.systemBlueColor;
            b.frame = area; b.accessibilityIdentifier = [@"tab-" stringByAppendingString:((UITabBarItem *)items[i]).title ?: [@(i) stringValue]];
            [b setNeedsDisplay];
            continue;
        }
        b.onColor = self.tintColor ?: UIColor.systemBlueColor; b.offColor = _unselectedItemTintColor ?: UIColor.systemGrayColor;
        b.frame = mode ? CGRectMake(area.origin.x + i * w, area.origin.y, w, area.size.height) : CGRectMake(i * w, 0, w, 49);
        b.accessibilityIdentifier = [@"tab-" stringByAppendingString:((UITabBarItem *)items[i]).title ?: [@(i) stringValue]];
        [b setNeedsDisplay];
    }
}
/* iOS 26 iPhone: the bar floats as a capsule inset from the screen edges, above the home indicator */
- (CGRect)_isim_capsule {
    CGSize s = self.bounds.size; CGFloat inset = s.width > 600 ? (s.width - 560) / 2 : 21;
    if (_minimized) return CGRectMake(inset, 0, 62, 62);      /* minimized: a circle at the leading edge */
    return CGRectMake(inset, 0, s.width - 2 * inset, 62);
}
- (void)_isim_drawContent {
    int mode = tabbar_mode();
    if (mode == 1) { CGRect c = [self _isim_capsule]; isim_ui_draw_glass(c, c.size.height / 2, nil, 0); }
    else if (mode == 3) isim_ui_draw_glass(self.bounds, self.bounds.size.height / 2, nil, 0);
    else if (mode == 2) {                     /* iPadOS 18: a thick-material capsule */
        CGSize s = self.bounds.size; double radius, tint[4];
        isim_ui_material(UIBlurEffectStyleSystemThickMaterial, isim_ui_style() == UIUserInterfaceStyleDark, &radius, tint);
        isim_gfx_backdrop_blur(0, 0, s.width, s.height, s.height / 2, radius);
        isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, tint);
        double edge[4]; isim_ui_rgba([UIColor colorWithWhite:0.5 alpha:0.18], edge);
        isim_gfx_stroke_rounded(0, 0, s.width, s.height, s.height / 2, 0.5, edge);
    }
}
- (void)_isim_tapped:(__IsimTabButton *)b {
    if (_minimized && tabbar_mode() == 1 && [self.delegate respondsToSelector:@selector(_isim_expandTabBar)]) {   /* a tap expands it */
        [(id<__IsimTabBarExpanding>)self.delegate _isim_expandTabBar];
        return;
    }
    self.selectedItem = b.item;
    if ([self.delegate respondsToSelector:@selector(tabBar:didSelectItem:)]) [self.delegate tabBar:self didSelectItem:b.item];
}
@end

/* ================= UIViewController containment additions ================= */
static char kToolbarItems, kTabBarItem, kHidesBottom, kEditing, kEditItem;
@implementation UIViewController (UIContainers)
- (UINavigationController *)navigationController {
    for (UIViewController *p = self; p; p = p.parentViewController) if ([p isKindOfClass:[UINavigationController class]] && p != self) return (UINavigationController *)p;
    return nil;
}
- (UITabBarController *)tabBarController {
    for (UIViewController *p = self.parentViewController; p; p = p.parentViewController) if ([p isKindOfClass:[UITabBarController class]]) return (UITabBarController *)p;
    return nil;
}
- (NSArray *)toolbarItems { return objc_getAssociatedObject(self, &kToolbarItems); }
- (void)setToolbarItems:(NSArray *)items { [self setToolbarItems:items animated:NO]; }
- (void)setToolbarItems:(NSArray *)items animated:(BOOL)a {
    objc_setAssociatedObject(self, &kToolbarItems, items, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self.navigationController.view setNeedsLayout]; isim_ui_set_needs_layout();
}
- (UITabBarItem *)tabBarItem {
    UITabBarItem *i = objc_getAssociatedObject(self, &kTabBarItem);
    if (!i) { i = [[UITabBarItem alloc] initWithTitle:self.title image:nil tag:0]; objc_setAssociatedObject(self, &kTabBarItem, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return i;
}
- (void)setTabBarItem:(UITabBarItem *)i { objc_setAssociatedObject(self, &kTabBarItem, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); bar_item_changed(i); }
- (BOOL)hidesBottomBarWhenPushed { return [objc_getAssociatedObject(self, &kHidesBottom) boolValue]; }
- (void)setHidesBottomBarWhenPushed:(BOOL)h { objc_setAssociatedObject(self, &kHidesBottom, @(h), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)isEditing { return [objc_getAssociatedObject(self, &kEditing) boolValue]; }
- (void)setEditing:(BOOL)e { [self setEditing:e animated:NO]; }
- (void)setEditing:(BOOL)e animated:(BOOL)a {
    objc_setAssociatedObject(self, &kEditing, @(e), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIBarButtonItem *b = objc_getAssociatedObject(self, &kEditItem);
    if (b) { b.title = e ? @"Done" : @"Edit"; b.style = e ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain; }
}
- (UIBarButtonItem *)editButtonItem {
    UIBarButtonItem *b = objc_getAssociatedObject(self, &kEditItem);
    if (!b) {
        b = [[UIBarButtonItem alloc] initWithTitle:self.isEditing ? @"Done" : @"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(_isim_toggleEditing)];
        objc_setAssociatedObject(self, &kEditItem, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return b;
}
- (void)_isim_toggleEditing { [self setEditing:!self.isEditing animated:YES]; }
- (BOOL)isMovingToParentViewController { return NO; }
- (BOOL)isMovingFromParentViewController { return NO; }
@end

/* ================= UINavigationController ================= */
@interface __IsimContainerView : UIView
@property (nonatomic, weak) UIViewController *owner;
@end
@implementation __IsimContainerView
- (void)layoutSubviews { [super layoutSubviews]; [(id)self.owner _isim_layoutContainer]; }
@end

@implementation UINavigationController { NSMutableArray<UIViewController *> *_stack; UINavigationBar *_bar; UIToolbar *_toolbar;
    UIPanGestureRecognizer *_popPan; BOOL _transitioning, _swiping; __weak UIScrollView *_tracked; UIView *_dim;
    NSUInteger _transitionGen; __weak UIViewController *_transitionFrom; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) {
        _stack = [NSMutableArray array];
        _bar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
        self.toolbarHidden = YES;
        __weak UINavigationController *ws = self;
        _bar._isim_back = ^{ [ws popViewControllerAnimated:YES]; };
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isim_scrolled:) name:@"_IsimScrollViewDidScroll" object:nil];
    }
    return self;
}
- (instancetype)initWithRootViewController:(UIViewController *)root { if ((self = [self initWithNibName:nil bundle:nil])) [self pushViewController:root animated:NO]; return self; }
- (instancetype)initWithNavigationBarClass:(Class)nb toolbarClass:(Class)tb {
    if ((self = [self initWithNibName:nil bundle:nil])) {
        if (nb) { _bar = [nb new]; __weak UINavigationController *ws = self; _bar._isim_back = ^{ [ws popViewControllerAnimated:YES]; }; }
        if (tb) _toolbar = [tb new];
    }
    return self;
}
- (void)loadView {
    __IsimContainerView *v = [[__IsimContainerView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.owner = self; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = UIColor.systemBackgroundColor;
    self.view = v;
    [v addSubview:_bar]; [v addSubview:_toolbar];
    _popPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_swipe:)];
    _popPan.cancelsTouchesInView = NO;
    [v addGestureRecognizer:_popPan];
    if (self.topViewController) [self _isim_install:self.topViewController];
}
- (UIGestureRecognizer *)interactivePopGestureRecognizer { return _popPan; }
- (UINavigationBar *)navigationBar { return _bar; }
- (UIToolbar *)toolbar { return _toolbar; }
- (NSArray *)viewControllers { return [_stack copy]; }
- (UIViewController *)topViewController { return _stack.lastObject; }
- (UIViewController *)visibleViewController { UIViewController *t = self.topViewController; return t.presentedViewController ?: t; }
- (NSArray<UIViewController *> *)_isim_visibleChildren { UIViewController *t = self.topViewController; return t ? @[t] : @[]; }
- (NSString *)title { return [super title] ?: self.topViewController.title; }
- (void)setNavigationBarHidden:(BOOL)h { [self setNavigationBarHidden:h animated:NO]; }
- (void)setNavigationBarHidden:(BOOL)h animated:(BOOL)a { _navigationBarHidden = h; _bar.hidden = h; [self.view setNeedsLayout]; [self _isim_updateInsets]; }
- (void)setToolbarHidden:(BOOL)h { [self setToolbarHidden:h animated:NO]; }
- (void)setToolbarHidden:(BOOL)h animated:(BOOL)a { _toolbarHidden = h; _toolbar.hidden = h; [self.viewIfLoaded setNeedsLayout]; [self _isim_updateInsets]; }

/* the bar's height below the status bar: 44, plus 52 for a large title */
- (CGFloat)_isim_barContent { return (_navigationBarHidden ? 0 : 44 + ([_bar _isim_topIsLarge] ? [_bar _isim_largeHeight] : 0)) + [self _isim_searchBarHeight]; }
- (CGFloat)_isim_toolbarContent { return _toolbarHidden ? 0 : 44; }
- (void)_isim_updateInsets {
    for (UIViewController *vc in _stack) vc.additionalSafeAreaInsets = UIEdgeInsetsMake([self _isim_barContent], 0, [self _isim_toolbarContent], 0);
}
- (void)_isim_install:(UIViewController *)vc {
    UIView *v = vc.view, *host = self.viewIfLoaded;
    if (!host) return;
    v.frame = host.bounds; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (v.superview != host) [host insertSubview:v belowSubview:_bar];
}
- (UIScrollView *)_isim_findScroll:(UIView *)v depth:(int)d {
    if ([v isKindOfClass:[UIScrollView class]]) return (UIScrollView *)v;
    if (d > 4) return nil;
    for (UIView *s in v.subviews) { UIScrollView *f = [self _isim_findScroll:s depth:d + 1]; if (f) return f; }
    return nil;
}
- (void)_isim_scrolled:(NSNotification *)n { if (n.object == _tracked) [self _isim_layoutBar]; }
- (void)_isim_layoutBar {
    UIView *host = self.viewIfLoaded; if (!host) return;
    CGFloat W = host.bounds.size.width, safeTop = isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).top;
    if (!host.window) safeTop = isim_ui_device()->safe_top;
    BOOL large = [_bar _isim_topIsLarge];
    UIScrollView *sv = _tracked;
    CGFloat y = sv ? sv.contentOffset.y + sv.adjustedContentInset.top : 0;   /* 0 = resting at the top */
    /* a search bar below the title collapses first (hidesSearchBarWhenScrolling), then the large title */
    CGFloat searchH = [self _isim_searchBarHeight], search = searchH;
    if (searchH > 0 && self.topViewController.navigationItem.hidesSearchBarWhenScrolling) { search = fmin(searchH, fmax(0, searchH - y)); y = fmax(0, y - searchH); }
    CGFloat LH = [_bar _isim_largeHeight], extra = large ? fmin(LH, fmax(0, LH - y)) : 0;
    _bar._isim_safeTop = safeTop; _bar._isim_largeExtra = extra; _bar._isim_searchExtra = search;
    _bar._isim_scrolledEdge = large ? y > LH - 0.5 : y > 0.5;
    _bar._isim_edgeScrollView = sv; if (_toolbar) _toolbar._isim_edgeScrollView = sv;
    _bar.frame = CGRectMake(0, 0, W, safeTop + 44 + extra + search);
    [_bar setNeedsLayout]; [_bar layoutIfNeeded];
}
- (void)_isim_layoutContainer {
    UIView *host = self.viewIfLoaded; if (!host) return;
    NSMutableArray *items = [NSMutableArray array]; for (UIViewController *vc in _stack) [items addObject:vc.navigationItem];
    _bar.items = items;
    _tracked = self.topViewController ? [self _isim_findScroll:self.topViewController.viewIfLoaded depth:0] : nil;
    [self _isim_updateInsets];
    [self _isim_layoutBar];
    CGFloat H = host.bounds.size.height, W = host.bounds.size.width;
    CGFloat safeBottom = isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).bottom;
    _toolbar.items = self.topViewController.toolbarItems;
    _toolbar.frame = CGRectMake(0, H - 44 - safeBottom, W, 44 + safeBottom);
    [host bringSubviewToFront:_bar]; [host bringSubviewToFront:_toolbar];
    if (!_transitioning && !_swiping) for (UIViewController *vc in _stack) if (vc == self.topViewController) vc.viewIfLoaded.frame = host.bounds;
}

/* ---- push / pop ---- */
- (void)_isim_transitionFrom:(UIViewController *)from to:(UIViewController *)to push:(BOOL)push animated:(BOOL)animated done:(void (^)(void))done {
    UIView *host = self.viewIfLoaded;
    if ([self.delegate respondsToSelector:@selector(navigationController:willShowViewController:animated:)]) [self.delegate navigationController:self willShowViewController:to animated:animated];
    BOOL visible = [self _isim_isVisible];
    if (to && host) [self _isim_install:to];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    [self.tabBarController _isim_updateTabBar];
    if (visible) { [to _isim_appear:YES]; }
    /* a push/pop that starts before this one has finished retargets its frames, which ends this one's animation
       (finished NO) while the newer transition runs: its completion must leave the views that one shows alone */
    NSUInteger gen = ++_transitionGen;
    _transitionFrom = from;
    __block UIView *dim = nil;
    void (^finish)(BOOL) = ^(BOOL f) {
        BOOL latest = gen == _transitionGen;
        BOOL shown = from == self.topViewController || (!latest && _transitioning && from == _transitionFrom);
        if (latest) _transitioning = NO;
        if (from && from != to && !shown) { [from.viewIfLoaded removeFromSuperview]; if (visible) [from _isim_appear:NO]; }
        [dim removeFromSuperview]; if (_dim == dim) _dim = nil;
        if (latest && to) to.viewIfLoaded.frame = host.bounds;
        if (visible && to == self.topViewController) [to _isim_didAppear];
        if (done) done();
        if (latest && [self.delegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) [self.delegate navigationController:self didShowViewController:to animated:animated];
        [self.view setNeedsLayout];
    };
    if (!animated || !host.window || !from || from == to) { finish(YES); return; }
    _transitioning = YES;
    CGFloat W = host.bounds.size.width;
    /* iOS 18 zoom (preferredTransition): the pushed view grows from its source view / shrinks back into it */
    extern BOOL isim_ui_zoom_transition(UIViewController *zoomed, UIViewController *source, UIView *zv, UIView *host, BOOL appearing, void (^done)(void));
    UIViewController *zoomed = push ? to : from;
    if ([zoomed.preferredTransition respondsToSelector:@selector(_isim_isZoom)] && [(id)zoomed.preferredTransition _isim_isZoom]) {
        to.view.frame = host.bounds;
        if (push) [host bringSubviewToFront:to.view]; else [host insertSubview:to.view belowSubview:from.view];
        if (isim_ui_zoom_transition(zoomed, push ? from : to, zoomed.view, host, push, ^{ finish(YES); })) {
            [host bringSubviewToFront:_bar]; [host bringSubviewToFront:_toolbar];
            return;
        }
    }
    UIView *fv = from.view, *tv = to.view;
    if (!push) [host insertSubview:tv belowSubview:fv];
    [_dim removeFromSuperview];
    dim = _dim = [[UIView alloc] initWithFrame:host.bounds]; _dim.backgroundColor = UIColor.blackColor; _dim.userInteractionEnabled = NO;
    [host insertSubview:_dim belowSubview:push ? tv : fv];
    [host bringSubviewToFront:_bar]; [host bringSubviewToFront:_toolbar];
    [UIView performWithoutAnimation:^{
        tv.frame = CGRectOffset(host.bounds, push ? W : -W * 0.3, 0);
        _dim.alpha = push ? 0 : 0.08;
    }];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
        tv.frame = host.bounds;
        fv.frame = CGRectOffset(host.bounds, push ? -W * 0.3 : W, 0);
        _dim.alpha = push ? 0.08 : 0;
    } completion:finish];
}
- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated {
    if (!vc || [_stack containsObject:vc] || [vc isKindOfClass:[UITabBarController class]]) return;
    UIViewController *from = self.topViewController;
    [self addChildViewController:vc];
    [_stack addObject:vc];
    [self _isim_updateInsets];
    [self _isim_transitionFrom:from to:vc push:YES animated:animated done:^{ [vc didMoveToParentViewController:self]; }];
}
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (_stack.count < 2) return nil;
    UIViewController *top = self.topViewController;
    [_stack removeLastObject];
    [top willMoveToParentViewController:nil];
    [self _isim_transitionFrom:top to:self.topViewController push:NO animated:animated done:^{ [top removeFromParentViewController]; }];
    return top;
}
- (NSArray *)popToViewController:(UIViewController *)vc animated:(BOOL)animated {
    NSUInteger i = [_stack indexOfObjectIdenticalTo:vc];
    if (i == NSNotFound || i == _stack.count - 1) return @[];
    NSArray *removed = [_stack subarrayWithRange:NSMakeRange(i + 1, _stack.count - i - 1)];
    UIViewController *top = self.topViewController;
    while (_stack.count > i + 1) [_stack removeLastObject];
    for (UIViewController *r in removed) if (r != top) { [r willMoveToParentViewController:nil]; [r removeFromParentViewController]; }
    [top willMoveToParentViewController:nil];
    [self _isim_transitionFrom:top to:vc push:NO animated:animated done:^{ [top removeFromParentViewController]; }];
    return removed;
}
- (NSArray *)popToRootViewControllerAnimated:(BOOL)a { return _stack.count ? [self popToViewController:_stack.firstObject animated:a] : @[]; }
- (void)setViewControllers:(NSArray *)vcs { [self setViewControllers:vcs animated:NO]; }
- (void)setViewControllers:(NSArray *)vcs animated:(BOOL)animated {
    UIViewController *from = self.topViewController;
    for (UIViewController *old in [_stack copy]) if (![vcs containsObject:old]) { [old willMoveToParentViewController:nil]; if (old != from) [old.viewIfLoaded removeFromSuperview]; [old removeFromParentViewController]; }
    for (UIViewController *n in vcs) if (n.parentViewController != self) [self addChildViewController:n];
    BOOL push = ![_stack containsObject:vcs.lastObject];
    _stack = [vcs mutableCopy];
    [self _isim_updateInsets];
    UIViewController *to = self.topViewController;
    if (from == to) { [self.viewIfLoaded setNeedsLayout]; return; }
    [self _isim_transitionFrom:from to:to push:push animated:animated done:^{ for (UIViewController *n in vcs) [n didMoveToParentViewController:self]; }];
}

/* ---- interactive pop: a swipe that starts at the left edge ---- */
- (void)_isim_swipe:(UIPanGestureRecognizer *)g {
    UIView *host = self.view;
    CGFloat W = host.bounds.size.width, dx = [g translationInView:host].x;
    if (g.state == UIGestureRecognizerStateBegan) {
        CGFloat startX = [g locationInView:host].x - dx;
        _swiping = startX < 30 && _stack.count > 1 && !_transitioning;
        if (!_swiping) return;
        UIViewController *below = _stack[_stack.count - 2];
        [self _isim_install:below];
        [host insertSubview:below.view belowSubview:self.topViewController.view];
        [UIView performWithoutAnimation:^{ below.view.frame = CGRectOffset(host.bounds, -W * 0.3, 0); }];
    }
    if (!_swiping) return;
    UIViewController *top = self.topViewController, *below = _stack[_stack.count - 2];
    CGFloat d = fmax(0, fmin(W, dx));
    if (g.state == UIGestureRecognizerStateChanged || g.state == UIGestureRecognizerStateBegan) {
        [UIView performWithoutAnimation:^{
            top.view.frame = CGRectOffset(host.bounds, d, 0);
            below.view.frame = CGRectOffset(host.bounds, -W * 0.3 * (1 - d / W), 0);
        }];
        return;
    }
    _swiping = NO;
    BOOL complete = g.state == UIGestureRecognizerStateEnded && (d > W / 3 || [g velocityInView:host].x > 600);
    if (complete) {
        [_stack removeLastObject];
        [top willMoveToParentViewController:nil];
        _transitioning = YES;
        BOOL visible = [self _isim_isVisible];
        if (visible) [below _isim_appear:YES];
        [self.view setNeedsLayout]; [self _isim_layoutBar];
        [self.tabBarController _isim_updateTabBar];
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            top.view.frame = CGRectOffset(host.bounds, W, 0); below.view.frame = host.bounds;
        } completion:^(BOOL f) {
            _transitioning = NO;
            [top.view removeFromSuperview]; if (visible) { [top _isim_appear:NO]; [below _isim_didAppear]; }
            [top removeFromParentViewController];
            if ([self.delegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) [self.delegate navigationController:self didShowViewController:below animated:YES];
            [self.view setNeedsLayout];
        }];
    } else {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
            top.view.frame = host.bounds; below.view.frame = CGRectOffset(host.bounds, -W * 0.3, 0);
        } completion:^(BOOL f) { [below.view removeFromSuperview]; }];
    }
}
@end

@interface UITabBarController (IsimTabs)
- (void)_isim_tabsChanged; - (void)_isim_groupSelectionChanged:(UITabGroup *)g; - (void)_isim_sidebarChanged;
@end
@interface UITab (IsimTabs)
- (UITabBarItem *)_isim_item;
@end
@interface UITabGroup (IsimTabs)
- (void)_isim_setSelectedChildQuiet:(UITab *)c;
@end
@interface UITabBarControllerSidebar ()
@property (nonatomic, weak) UITabBarController *tabBarController;
@end
/* ================= UITab, UITabGroup (iOS 18) ================= */
@interface UITab ()
@property (nonatomic, readwrite, weak) UITabGroup *parent;
@property (nonatomic, readwrite, weak) UITabBarController *tabBarController;
@property (nonatomic, copy) UIViewController * (^_isim_provider)(UITab *);
@end
@implementation UITab { UIViewController *_vc; UITabBarItem *_item; }
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier viewControllerProvider:(UIViewController *(^)(UITab *))provider {
    if ((self = [super init])) { _title = [title copy] ?: @""; _image = image; _identifier = [identifier copy] ?: @""; __isim_provider = [provider copy]; _allowsHiding = YES; }
    return self;
}
- (instancetype)init { return [self initWithTitle:@"" image:nil identifier:NSUUID.UUID.UUIDString viewControllerProvider:nil]; }
/* the tab's view controller: made once by its provider (UIKit asks for it when the tab is first shown) */
- (UIViewController *)viewController {
    if (!_vc && __isim_provider) { _vc = __isim_provider(self); _vc.tabBarItem = self._isim_item; }
    return _vc;
}
- (UIViewController *)_isim_loadedViewController { return _vc; }
- (UITabBarItem *)_isim_item {
    if (!_item) { _item = [[UITabBarItem alloc] initWithTitle:_title image:_image tag:0]; _item.badgeValue = _badgeValue; _item.accessibilityIdentifier = _identifier; }
    return _item;
}
- (void)_isim_changed { _item.title = _title; _item.image = _image; _item.badgeValue = _badgeValue; [_tabBarController _isim_tabsChanged]; }
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; [self _isim_changed]; }
- (void)setImage:(UIImage *)i { _image = i; [self _isim_changed]; }
- (void)setBadgeValue:(NSString *)b { _badgeValue = [b copy]; [self _isim_changed]; }
- (void)setHidden:(BOOL)h { if (h == _hidden) return; _hidden = h; [_tabBarController _isim_tabsChanged]; }
- (UITabGroup *)managingTabGroup { return _parent; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@ “%@”>", [self class], _identifier, _title]; }
@end
@implementation UISearchTab
- (instancetype)initWithViewControllerProvider:(UIViewController *(^)(UITab *))provider {
    return [super initWithTitle:@"Search" image:[UIImage systemImageNamed:@"magnifyingglass"] identifier:@"com.apple.UIKit.UISearchTab" viewControllerProvider:provider];
}
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier viewControllerProvider:(UIViewController *(^)(UITab *))provider {
    return [super initWithTitle:title image:image ?: [UIImage systemImageNamed:@"magnifyingglass"] identifier:identifier viewControllerProvider:provider];
}
@end
@implementation UITabGroup
- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier children:(NSArray<UITab *> *)children viewControllerProvider:(UIViewController *(^)(UITab *))provider {
    if ((self = [super initWithTitle:title image:image identifier:identifier viewControllerProvider:provider])) self.children = children;
    return self;
}
- (void)setChildren:(NSArray<UITab *> *)children {
    _children = [children copy] ?: @[];
    for (UITab *c in _children) { c.parent = self; c.tabBarController = self.tabBarController; }
    if (![_children containsObject:_selectedChild]) _selectedChild = nil;
    [self.tabBarController _isim_tabsChanged];
}
- (void)setSelectedChild:(UITab *)c { if (c && ![_children containsObject:c]) return; _selectedChild = c; [self.tabBarController _isim_groupSelectionChanged:self]; }
- (void)_isim_setSelectedChildQuiet:(UITab *)c { _selectedChild = c; }
- (NSArray<NSString *> *)displayOrderIdentifiers { if (!_displayOrderIdentifiers) { NSMutableArray *a = [NSMutableArray array]; for (UITab *t in _children) [a addObject:t.identifier]; return a; } return _displayOrderIdentifiers; }
- (UITab *)tabForIdentifier:(NSString *)identifier {
    for (UITab *t in _children) {
        if ([t.identifier isEqualToString:identifier]) return t;
        if ([t isKindOfClass:[UITabGroup class]]) { UITab *f = [(UITabGroup *)t tabForIdentifier:identifier]; if (f) return f; }
    }
    return nil;
}
/* what the group shows: its own controller, else its managing navigation controller over the selected child's */
- (UIViewController *)viewController {
    UIViewController *own = [super viewController];
    if (own) return own;
    UITab *child = _selectedChild ?: _children.firstObject;
    if (!child) return nil;
    if (!_managingNavigationController) { _managingNavigationController = [[UINavigationController alloc] initWithRootViewController:child.viewController]; _managingNavigationController.tabBarItem = self._isim_item; }
    else if (_managingNavigationController.viewControllers.firstObject != child.viewController) [_managingNavigationController setViewControllers:@[child.viewController] animated:NO];
    return _managingNavigationController;
}
@end
@implementation UITabBarControllerSidebar
- (void)setHidden:(BOOL)h { if (h == _hidden) return; _hidden = h; [self.tabBarController _isim_sidebarChanged]; }
@end

/* the sidebar (iPad, UITabBarController.Mode.tabSidebar): the tabs, groups with their children indented */
@interface __IsimSidebarRow : UIControl
@property (nonatomic, strong) UITab *tab;
@property (nonatomic) BOOL header, on;
@end
@implementation __IsimSidebarRow
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    if (self.on || self.highlighted) {
        double c[4]; isim_ui_rgba(self.on ? self.tintColor : UIColor.tertiarySystemFillColor, c);
        isim_gfx_fill_rounded(8, 2, s.width - 16, s.height - 4, 10, c);
    }
    UIColor *fg = self.on ? UIColor.whiteColor : self.header ? UIColor.secondaryLabelColor : UIColor.labelColor;
    CGFloat x = self.tab.parent && !self.header ? 40 : 20;
    if (self.tab.image && !self.header) {
        [self.tab.image _isim_drawInRect:CGRectMake(x, (s.height - 20) / 2, 20, 20) tint:self.on ? UIColor.whiteColor : self.tintColor alpha:1];
        x += 32;
    }
    UIFont *f = self.header ? [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:17];
    CGSize ts = isim_ui_measure(self.tab.title ?: @"", f, s.width - x - 50, 1);
    isim_ui_draw_text(self.tab.title ?: @"", f, fg, CGRectMake(x, (s.height - ts.height) / 2, s.width - x - 50, ts.height), NSTextAlignmentLeft, 1, 1);
    if (self.tab.badgeValue.length && !self.header) {
        UIFont *bf = [UIFont systemFontOfSize:15]; CGSize bs = isim_ui_measure(self.tab.badgeValue, bf, 80, 1);
        isim_ui_draw_text(self.tab.badgeValue, bf, self.on ? UIColor.whiteColor : UIColor.secondaryLabelColor, CGRectMake(s.width - 24 - bs.width, (s.height - bs.height) / 2, bs.width, bs.height), NSTextAlignmentRight, 1, 1);
    }
}
@end
@interface __IsimSidebar : UIView
@property (nonatomic, weak) UITabBarController *owner;
@end
@implementation __IsimSidebar
- (void)_isim_drawContent {
    if (isim_ui_glass()) { isim_ui_draw_glass(self.bounds, 24, nil, 0); return; }     /* iOS 26: a floating glass panel */
    double c[4]; isim_ui_rgba(UIColor.secondarySystemBackgroundColor, c);
    isim_gfx_fill_rounded(0, 0, self.bounds.size.width, self.bounds.size.height, 0, c);
    double l[4]; isim_ui_rgba(UIColor.separatorColor, l);
    isim_gfx_fill_rounded(self.bounds.size.width - 0.5, 0, 0.5, self.bounds.size.height, 0, l);
}
@end
/* ================= UITabBarController ================= */
/* iOS 18 tabs: tabs / UITabGroup build the bar (top-level tabs; a group shows its selected child in a managing
   navigation controller). On iPad with mode .tabSidebar the sidebar lists the tabs and the groups' children (iOS 26:
   a floating glass panel) and the tab bar hides; UIBackgroundExtensionView content reaches under it. */
/* ================= iOS 26 tab bar accessory ================= */
@implementation UITabAccessory
- (instancetype)initWithContentView:(UIView *)v { if ((self = [super init])) _contentView = v; return self; }
@end
/* the glass capsule that holds the accessory's content view */
@interface __IsimTabAccessoryView : UIView
@property (nonatomic, strong) UIView *content;
@end
@implementation __IsimTabAccessoryView
- (void)layoutSubviews { [super layoutSubviews]; self.content.frame = CGRectInset(self.bounds, 16, 0); }
- (void)_isim_drawContent { CGSize s = self.bounds.size; isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), s.height / 2, nil, 0); }
@end

@implementation UITabBarController { UITabBar *_bar; NSArray *_vcs; NSUInteger _sel; BOOL _barHidden;
    UITabBarMinimizeBehavior _minimizeBehavior; UITabAccessory *_accessory; __IsimTabAccessoryView *_accessoryView; BOOL _minimized;
    UILayoutGuide *_contentGuide; id _scrollObserver; NSMapTable *_lastScroll;
    NSArray<UITab *> *_tabs, *_barTabs; UITab *_selectedTab; UITabBarControllerSidebar *_sidebar; __IsimSidebar *_sidebarView;
    BOOL _tabBarHiddenFlag, _settingTabs; UITabBarControllerMode _mode; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) {
        _bar = [[UITabBar alloc] initWithFrame:CGRectZero]; _bar.delegate = self; _vcs = @[];
        _lastScroll = [NSMapTable weakToStrongObjectsMapTable];
        __weak UITabBarController *weakSelf = self;    /* iOS 26 minimizing: the selected tab's content scrolled by the user */
        _scrollObserver = [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimScrollViewDidScroll" object:nil queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf _isim_contentScrolled:note.object];
        }];
    }
    return self;
}
- (void)dealloc { if (_scrollObserver) [NSNotificationCenter.defaultCenter removeObserver:_scrollObserver]; }
/* ---- iOS 26: minimizing and the bottom accessory ---- */
- (UITabBarMinimizeBehavior)tabBarMinimizeBehavior { return _minimizeBehavior; }
- (void)setTabBarMinimizeBehavior:(UITabBarMinimizeBehavior)b {
    _minimizeBehavior = b;
    if (b != UITabBarMinimizeBehaviorOnScrollDown && b != UITabBarMinimizeBehaviorOnScrollUp) [self _isim_setMinimized:NO];
}
- (void)_isim_contentScrolled:(UIScrollView *)sv {
    UIView *content = self.selectedViewController.viewIfLoaded;
    if (![sv isKindOfClass:[UIScrollView class]] || !content || ![sv isDescendantOfView:content]) return;
    CGFloat y = sv.contentOffset.y; NSNumber *last = [_lastScroll objectForKey:sv];
    [_lastScroll setObject:@(y) forKey:sv];
    BOOL down = _minimizeBehavior == UITabBarMinimizeBehaviorOnScrollDown;
    if ((!down && _minimizeBehavior != UITabBarMinimizeBehaviorOnScrollUp) || tabbar_mode() != 1 || !last) return;
    CGFloat dy = y - last.doubleValue;
    if (fabs(dy) <= 0.5 || !(sv.isDragging || sv.isTracking)) return;   /* the user's scrolling, not momentum after an expand */
    [self _isim_setMinimized:down == (dy > 0) && y + sv.adjustedContentInset.top > 10];
}
- (void)_isim_setMinimized:(BOOL)m {
    if (m == _minimized) return;
    _minimized = m;
    NSLog(@"isim: tab bar %@", m ? @"minimized" : @"expanded");
    [self _isim_updateTabBar];                                     /* the accessory's safe-area inset */
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0 options:0 animations:^{
        self->_bar._isim_minimized = m;
        [self->_bar layoutIfNeeded];
        [self _isim_layoutContainer];
    } completion:nil];
}
- (void)_isim_expandTabBar { [self _isim_setMinimized:NO]; }
- (UITabAccessory *)bottomAccessory { return _accessory; }
- (void)setBottomAccessory:(UITabAccessory *)a { [self setBottomAccessory:a animated:NO]; }
- (void)setBottomAccessory:(UITabAccessory *)a animated:(BOOL)animated {
    if (a == _accessory) return;
    [_accessory.contentView removeFromSuperview];
    _accessory = a;
    if (a && !_accessoryView) { _accessoryView = [__IsimTabAccessoryView new]; _accessoryView.accessibilityIdentifier = @"isim-tab-accessory"; }
    _accessoryView.content = a.contentView;
    if (a.contentView) [_accessoryView addSubview:a.contentView];
    [self _isim_updateTabBar];
    if (animated && self.viewIfLoaded.window) {
        _accessoryView.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{ self->_accessoryView.alpha = 1; }];
    }
}
- (UILayoutGuide *)contentLayoutGuide {
    if (!_contentGuide) {
        _contentGuide = [UILayoutGuide new];
        __weak UITabBarController *weakSelf = self;
        [_contentGuide _isim_setFrameProvider:^CGRect {
            UITabBarController *c = weakSelf; UIView *v = c.viewIfLoaded;
            if (!v) return CGRectZero;
            CGFloat side = [c _isim_sidebarWidth];
            return CGRectMake(side, 0, v.bounds.size.width - side, v.bounds.size.height);
        }];
        [self.view addLayoutGuide:_contentGuide];
    }
    return _contentGuide;
}
/* the accessory's frame (expanded: a capsule above the bar; minimized: beside the bar's circle), or CGRectNull */
- (CGRect)_isim_accessoryFrame {
    UIView *host = self.viewIfLoaded;
    if (!_accessory || _barHidden || !host) return CGRectNull;
    CGFloat W = host.bounds.size.width, inset = W > 600 ? (W - 560) / 2 : 21;
    int mode = tabbar_mode();
    if (mode == 1) {
        CGFloat top = _bar.frame.origin.y;
        return _minimized ? CGRectMake(inset + 62 + 10, top + 7, W - 2 * inset - 62 - 10, 48) : CGRectMake(inset, top - 8 - 48, W - 2 * inset, 48);
    }
    CGFloat bottom = host.window ? isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).bottom : isim_ui_device()->safe_bottom;
    return CGRectMake(inset, host.bounds.size.height - bottom - (mode >= 2 ? 56 : 49 + 56), W - 2 * inset, 48);
}
- (void)loadView {
    __IsimContainerView *v = [[__IsimContainerView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.owner = self; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = UIColor.systemBackgroundColor;
    self.view = v;
    [v addSubview:_bar];
    [self _isim_showSelected];
}
- (UITabBar *)tabBar { return _bar; }
- (NSArray *)viewControllers { return _vcs; }
- (NSArray<UIViewController *> *)_isim_visibleChildren { UIViewController *s = self.selectedViewController; return s ? @[s] : @[]; }
- (void)setViewControllers:(NSArray *)vcs { [self setViewControllers:vcs animated:NO]; }
- (void)setViewControllers:(NSArray *)vcs animated:(BOOL)a {
    if (!_settingTabs) { _tabs = nil; _barTabs = nil; _selectedTab = nil; }     /* the classic API replaces tabs */
    for (UIViewController *old in _vcs) if (![vcs containsObject:old]) { [old willMoveToParentViewController:nil]; [old.viewIfLoaded removeFromSuperview]; [old removeFromParentViewController]; }
    _vcs = [vcs copy] ?: @[];
    for (UIViewController *n in _vcs) if (n.parentViewController != self) { [self addChildViewController:n]; [n didMoveToParentViewController:self]; }
    NSMutableArray *items = [NSMutableArray array]; for (UIViewController *c in _vcs) [items addObject:c.tabBarItem];
    _bar.items = items;
    if (_sel >= _vcs.count) _sel = 0;
    _bar.selectedItem = _vcs.count ? ((UIViewController *)_vcs[_sel]).tabBarItem : nil;
    [self _isim_showSelected];
}
- (UIViewController *)selectedViewController { return _sel < _vcs.count ? _vcs[_sel] : nil; }
- (void)setSelectedViewController:(UIViewController *)vc { NSUInteger i = [_vcs indexOfObjectIdenticalTo:vc]; if (i != NSNotFound) self.selectedIndex = i; }
- (NSUInteger)selectedIndex { return _sel; }
- (void)setSelectedIndex:(NSUInteger)i {
    if (i < _barTabs.count && _selectedTab.parent != _barTabs[i] && _selectedTab != _barTabs[i]) _selectedTab = _barTabs[i];
    if (i >= _vcs.count || i == _sel) { _sel = MIN(i, _vcs.count ? _vcs.count - 1 : 0); [self _isim_layoutSidebar]; return; }
    UIViewController *old = self.selectedViewController;
    BOOL visible = [self _isim_isVisible];
    _sel = i;
    _bar.selectedItem = ((UIViewController *)_vcs[i]).tabBarItem;
    if (visible) [old _isim_appear:NO];
    [old.viewIfLoaded removeFromSuperview];
    [self _isim_showSelected];
    if (visible) { [self.selectedViewController _isim_appear:YES]; [self.selectedViewController _isim_didAppear]; }
}
- (void)tabBar:(UITabBar *)tb didSelectItem:(UITabBarItem *)item {
    NSUInteger i = 0;
    for (; i < _vcs.count; i++) if (((UIViewController *)_vcs[i]).tabBarItem == item) break;
    if (i >= _vcs.count) return;
    if (i < _barTabs.count) { [self _isim_userSelectedTab:_barTabs[i]]; return; }
    UIViewController *vc = _vcs[i];
    if ([self.delegate respondsToSelector:@selector(tabBarController:shouldSelectViewController:)] && ![self.delegate tabBarController:self shouldSelectViewController:vc]) {
        _bar.selectedItem = self.selectedViewController.tabBarItem; return;
    }
    if (i == _sel && [vc isKindOfClass:[UINavigationController class]]) [(UINavigationController *)vc popToRootViewControllerAnimated:YES];   /* tap again: back to the root */
    self.selectedIndex = i;
    if ([self.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [self.delegate tabBarController:self didSelectViewController:vc];
}

/* ---- iOS 18 tabs ---- */
- (NSArray<UITab *> *)tabs { return _tabs ?: @[]; }
- (void)setTabs:(NSArray<UITab *> *)tabs { [self setTabs:tabs animated:NO]; }
static void adopt_tab(UITab *t, UITabBarController *c, UITabGroup *parent) {
    t.tabBarController = c; t.parent = parent;
    if ([t isKindOfClass:[UITabGroup class]]) for (UITab *k in ((UITabGroup *)t).children) adopt_tab(k, c, (UITabGroup *)t);
}
- (void)setTabs:(NSArray<UITab *> *)tabs animated:(BOOL)a {
    _tabs = [tabs copy] ?: @[];
    for (UITab *t in _tabs) adopt_tab(t, self, nil);
    if (_selectedTab && ![self tabForIdentifier:_selectedTab.identifier]) _selectedTab = nil;
    [self _isim_tabsChanged];
}
- (UITab *)tabForIdentifier:(NSString *)identifier {
    for (UITab *t in _tabs) {
        if ([t.identifier isEqualToString:identifier]) return t;
        if ([t isKindOfClass:[UITabGroup class]]) { UITab *f = [(UITabGroup *)t tabForIdentifier:identifier]; if (f) return f; }
    }
    return nil;
}
/* the bar: the visible top-level tabs (sidebar-only ones live in the sidebar); providers make their controllers */
- (void)_isim_tabsChanged {
    if (!_tabs) return;
    NSMutableArray *bar = [NSMutableArray array], *vcs = [NSMutableArray array];
    for (UITab *t in _tabs) {
        if (t.hidden || t.preferredPlacement == UITabPlacementSidebarOnly) continue;
        UIViewController *vc = t.viewController ?: [UIViewController new];
        vc.tabBarItem = t._isim_item;
        [bar addObject:t]; [vcs addObject:vc];
    }
    UITab *top = _selectedTab.parent ?: _selectedTab;
    NSUInteger sel = top ? [bar indexOfObjectIdenticalTo:top] : 0;
    _barTabs = bar;
    _settingTabs = YES;
    _sel = sel == NSNotFound ? 0 : sel;
    [self setViewControllers:vcs animated:NO];
    _settingTabs = NO;
    if (!_selectedTab && bar.count) _selectedTab = bar[_sel];
    [self _isim_layoutSidebar];
}
- (UITab *)selectedTab { return _selectedTab; }
- (void)setSelectedTab:(UITab *)t {
    if (!t || ![self tabForIdentifier:t.identifier]) return;
    _selectedTab = t;
    if (t.parent) { [t.parent _isim_setSelectedChildQuiet:t]; [self _isim_groupSelectionChanged:t.parent]; }
    UITab *top = t.parent ?: t;
    NSUInteger i = [_barTabs indexOfObjectIdenticalTo:top];
    if (i != NSNotFound) self.selectedIndex = i;
    [self _isim_layoutSidebar];
}
/* a group's selected child changed: its managing navigation controller shows that child */
- (void)_isim_groupSelectionChanged:(UITabGroup *)g {
    NSUInteger i = [_barTabs indexOfObjectIdenticalTo:g];
    if (i == NSNotFound || i >= _vcs.count) { [self _isim_layoutSidebar]; return; }
    UIViewController *vc = g.viewController;
    if (vc && vc != _vcs[i]) { NSMutableArray *a = [_vcs mutableCopy]; a[i] = vc; vc.tabBarItem = g._isim_item; _settingTabs = YES; [self setViewControllers:a animated:NO]; _settingTabs = NO; }
    [self _isim_layoutSidebar];
}
/* a tab chosen in the bar or the sidebar: the delegate may refuse it, then is told (with the previous tab) */
- (void)_isim_userSelectedTab:(UITab *)t {
    id<UITabBarControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(tabBarController:shouldSelectTab:)] && ![d tabBarController:self shouldSelectTab:t]) {
        _bar.selectedItem = self.selectedViewController.tabBarItem; return;
    }
    UITab *prev = _selectedTab;
    if (t == prev && !t.parent && [t.viewController isKindOfClass:[UINavigationController class]]) [(UINavigationController *)t.viewController popToRootViewControllerAnimated:YES];
    self.selectedTab = t;
    if ([d respondsToSelector:@selector(tabBarController:didSelectTab:previousTab:)]) [d tabBarController:self didSelectTab:t previousTab:prev];
    if ([d respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [d tabBarController:self didSelectViewController:self.selectedViewController];
}
- (UITabBarControllerMode)mode { return _mode; }
- (void)setMode:(UITabBarControllerMode)m { _mode = m; [self _isim_sidebarChanged]; }
- (UITabBarControllerSidebar *)sidebar {
    if (!_sidebar) { _sidebar = [UITabBarControllerSidebar new]; _sidebar.tabBarController = self; }
    return _sidebar;
}
- (BOOL)isTabBarHidden { return _tabBarHiddenFlag; }
- (void)setTabBarHidden:(BOOL)h { [self setTabBarHidden:h animated:NO]; }
- (void)setTabBarHidden:(BOOL)h animated:(BOOL)a { _tabBarHiddenFlag = h; [self _isim_updateTabBar]; }
/* the sidebar shows on iPad in tabSidebar mode while it is not hidden */
- (BOOL)_isim_sidebarShown {
    return _tabs.count && _mode == UITabBarControllerModeTabSidebar && !self.sidebar.hidden && UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && isim_ui_os_major() >= 18;
}
- (void)_isim_sidebarChanged { [self _isim_updateTabBar]; [self _isim_layoutSidebar]; [self.viewIfLoaded setNeedsLayout]; }
- (CGFloat)_isim_sidebarWidth { return [self _isim_sidebarShown] ? 320 : 0; }
- (void)_isim_layoutSidebar {
    UIView *host = self.viewIfLoaded;
    if (!host) return;
    if (![self _isim_sidebarShown]) { [_sidebarView removeFromSuperview]; _sidebarView = nil; return; }
    if (!_sidebarView) { _sidebarView = [__IsimSidebar new]; _sidebarView.owner = self; _sidebarView.accessibilityIdentifier = @"tab-sidebar"; }
    if (_sidebarView.superview != host) [host addSubview:_sidebarView];
    BOOL glass = isim_ui_glass();
    CGFloat safeTop = host.window ? isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).top : isim_ui_device()->safe_top;
    _sidebarView.frame = glass ? CGRectMake(8, safeTop + 8, 320 - 16, host.bounds.size.height - safeTop - 16) : CGRectMake(0, 0, 320, host.bounds.size.height);
    _sidebarView.layer.cornerRadius = glass ? 24 : 0;
    _sidebarView.backgroundColor = nil;
    for (UIView *s in _sidebarView.subviews) [s removeFromSuperview];
    __block CGFloat y = glass ? 12 : safeTop + 12; CGFloat w = _sidebarView.bounds.size.width;
    void (^row)(UITab *, BOOL) = ^(UITab *t, BOOL header) {
        __IsimSidebarRow *r = [[__IsimSidebarRow alloc] initWithFrame:CGRectMake(0, y, w, header ? 36 : 44)];
        r.tab = t; r.header = header; r.on = !header && (t == self->_selectedTab || (!t.parent && t == self->_selectedTab.parent && ![t isKindOfClass:[UITabGroup class]]));
        r.accessibilityIdentifier = [@"sidebar-" stringByAppendingString:t.identifier];
        r.accessibilityLabel = t.title;
        [r addTarget:self action:@selector(_isim_sidebarTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self->_sidebarView addSubview:r];
        y += r.frame.size.height;
    };
    for (UITab *t in _tabs) {
        if (t.hidden) continue;
        if ([t isKindOfClass:[UITabGroup class]]) {
            y += 8; row(t, YES);
            for (UITab *c in ((UITabGroup *)t).children) if (!c.hidden) row(c, NO);
        } else row(t, NO);
    }
    if (glass) isim_ui_set_needs_display();
}
- (void)_isim_sidebarTapped:(__IsimSidebarRow *)r {
    if (r.header) { if ([r.tab isKindOfClass:[UITabGroup class]] && [r.tab viewController]) [self _isim_userSelectedTab:r.tab]; return; }
    [self _isim_userSelectedTab:r.tab];
}
- (void)_isim_showSelected {
    UIView *host = self.viewIfLoaded; UIViewController *s = self.selectedViewController;
    if (!host || !s) return;
    UIView *v = s.view;
    CGFloat side = [self _isim_sidebarWidth];
    v.frame = CGRectMake(side, 0, host.bounds.size.width - side, host.bounds.size.height); v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (v.superview != host) [host insertSubview:v belowSubview:_bar];
    [self _isim_updateTabBar];
}
/* the bar hides under a pushed controller with hidesBottomBarWhenPushed, with isTabBarHidden, or for the sidebar */
- (void)_isim_updateTabBar {
    UIViewController *s = self.selectedViewController;
    BOOL hide = _tabBarHiddenFlag || [self _isim_sidebarShown];
    if ([s isKindOfClass:[UINavigationController class]]) for (UIViewController *c in ((UINavigationController *)s).viewControllers) if (c != ((UINavigationController *)s).viewControllers.firstObject && c.hidesBottomBarWhenPushed) hide = YES;
    _barHidden = hide;
    _bar.hidden = hide;
    int mode = tabbar_mode();                 /* iPad top bar (iOS 18+): sits in the navigation bar row, no bottom inset */
    CGFloat acc = _accessory && !hide && !_minimized ? 56 : 0;          /* iOS 26: content stays clear of the accessory */
    for (UIViewController *c in _vcs) c.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, (hide || mode >= 2 ? 0 : 49) + acc, 0);
    [self.viewIfLoaded setNeedsLayout];
}
- (void)_isim_layoutContainer {
    UIView *host = self.viewIfLoaded; if (!host) return;
    CGFloat H = host.bounds.size.height, W = host.bounds.size.width;
    CGFloat safeBottom = isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).bottom;
    if (!host.window) safeBottom = isim_ui_device()->safe_bottom;
    if (tabbar_mode() >= 2) {                 /* iPadOS 18+: a capsule centered at the top */
        CGFloat safeTop = host.window ? isim_ui_safe_insets_for_rect(host, [host convertRect:host.bounds toView:nil]).top : isim_ui_device()->safe_top;
        NSUInteger n = MAX(1, MIN(_bar.items.count, 5));
        CGFloat bw = fmin(W - 240, 8 + n * 112);
        _bar.frame = CGRectMake(round((W - bw) / 2), safeTop + 3, bw, 44);
    } else _bar.frame = CGRectMake(0, H - 49 - safeBottom, W, 49 + safeBottom);
    [host bringSubviewToFront:_bar];
    CGRect af = [self _isim_accessoryFrame];
    if (CGRectIsNull(af)) [_accessoryView removeFromSuperview];
    else {
        if (_accessoryView.superview != host) [host addSubview:_accessoryView];
        [host bringSubviewToFront:_accessoryView];
        _accessoryView.frame = af;
        UITabAccessoryEnvironment env = _minimized && tabbar_mode() == 1 ? UITabAccessoryEnvironmentInline : UITabAccessoryEnvironmentRegular;
        if (_accessory.contentView.traitCollection.tabAccessoryEnvironment != env)
            [_accessory.contentView.traitOverrides setNSIntegerValue:env forTrait:[UITraitTabAccessoryEnvironment class]];
    }
    CGFloat side = [self _isim_sidebarWidth];
    self.selectedViewController.viewIfLoaded.frame = CGRectMake(side, 0, W - side, H);
    [self _isim_layoutSidebar];
    if (_sidebarView) [host bringSubviewToFront:_sidebarView];
}
/* the sidebar's frame in window coordinates when shown (UIBackgroundExtensionView reaches under it) */
- (CGRect)_isim_sidebarFrameInWindow { return _sidebarView.window ? [_sidebarView convertRect:_sidebarView.bounds toView:nil] : CGRectNull; }
@end
