/* UIBarButtonItem, UINavigationItem, UINavigationBar, UIToolbar, UITabBar(Item), bar appearances,
 * UINavigationController (push/pop with parallax, back swipe from the left edge, large titles that collapse
 * as content scrolls, scroll-edge transparency) and UITabBarController — iOS 17/18 metrics; with --os 26/27 the
 * Liquid Glass look (floating glass tab bar, glass bar buttons and back button, scroll-edge fade instead of the
 * bar material). iPad, iOS 18+: the tab bar floats at the top (iPadOS 18 style). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <math.h>

@interface UIBarButtonItem (IsimNav)
- (BOOL)_isim_isFlexible; - (BOOL)_isim_isFixed; - (NSString *)_isim_displayTitle; - (UIImage *)_isim_displayImage; - (void)_isim_performFrom:(UIView *)sender;
@end
@interface UINavigationBar (IsimNav)
- (BOOL)_isim_topIsLarge;
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
@implementation UIBarItem
- (instancetype)init { if ((self = [super init])) _enabled = YES; return self; }
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

/* a bar button: text (17pt; Done style semibold) or a symbol, tinted */
@interface __IsimBarButton : UIControl
@property (nonatomic, strong) UIBarButtonItem *item;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) BOOL bold;
@end
@implementation __IsimBarButton
+ (instancetype)buttonFor:(UIBarButtonItem *)item {
    __IsimBarButton *b = [[self alloc] initWithFrame:CGRectZero];
    b.item = item; b.text = [item _isim_displayTitle]; b.icon = [item _isim_displayImage]; b.bold = item.style == UIBarButtonItemStyleDone;
    b.accessibilityIdentifier = item.accessibilityIdentifier ?: (b.text ? [@"bar-" stringByAppendingString:b.text] : nil);
    [b addTarget:b action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)fire { [self.item _isim_performFrom:self]; }
- (UIFont *)font { return [UIFont systemFontOfSize:17 weight:self.bold ? UIFontWeightSemibold : UIFontWeightRegular]; }
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
        isim_ui_draw_text(self.text, [self font], c, CGRectMake(0, (s.height - ts.height) / 2, s.width, ts.height), NSTextAlignmentCenter, 1, a);
    }
}
@end

/* lays out bar items left to right from x; returns the views */
static NSArray<UIView *> *place_items(UIView *host, NSArray<UIBarButtonItem *> *items, CGFloat x0, CGFloat y, CGFloat h, BOOL rightAligned, CGFloat limit) {
    NSMutableArray *views = [NSMutableArray array];
    CGFloat x = x0;
    for (UIBarButtonItem *it in rightAligned ? items.reverseObjectEnumerator.allObjects : items) {
        if (it.hidden || [it _isim_isFlexible]) continue;
        UIView *v = it.customView;
        if ([it _isim_isFixed]) { x += rightAligned ? -it.width : it.width; continue; }
        if (!v) v = [__IsimBarButton buttonFor:it];
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
- (void)setTitleView:(UIView *)v { _titleView = v; bar_item_changed(self); }
- (void)setPrompt:(NSString *)p { _prompt = [p copy]; bar_item_changed(self); }
- (void)setBackButtonTitle:(NSString *)t { _backButtonTitle = [t copy]; bar_item_changed(self); }
- (void)setHidesBackButton:(BOOL)h { _hidesBackButton = h; bar_item_changed(self); }
- (void)setLargeTitleDisplayMode:(UINavigationItemLargeTitleDisplayMode)m { _largeTitleDisplayMode = m; bar_item_changed(self); }
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

@implementation UIBarAppearance { int _kind; }   /* 0 default (material), 1 opaque, 2 transparent */
- (instancetype)init { if ((self = [super init])) [self configureWithDefaultBackground]; return self; }
- (id)copyWithZone:(NSZone *)z {
    UIBarAppearance *c = [[[self class] alloc] init];
    c->_kind = _kind; c.backgroundEffect = self.backgroundEffect; c.backgroundColor = self.backgroundColor;
    c.backgroundImage = self.backgroundImage; c.shadowColor = self.shadowColor;
    if ([self isKindOfClass:[UINavigationBarAppearance class]]) {
        ((UINavigationBarAppearance *)c).titleTextAttributes = ((UINavigationBarAppearance *)self).titleTextAttributes;
        ((UINavigationBarAppearance *)c).largeTitleTextAttributes = ((UINavigationBarAppearance *)self).largeTitleTextAttributes;
    }
    return c;
}
- (void)configureWithDefaultBackground { _kind = 0; self.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]; self.backgroundColor = nil; self.shadowColor = UIColor.separatorColor; }
- (void)configureWithOpaqueBackground { _kind = 1; self.backgroundEffect = nil; self.backgroundColor = UIColor.systemBackgroundColor; self.shadowColor = UIColor.separatorColor; }
- (void)configureWithTransparentBackground { _kind = 2; self.backgroundEffect = nil; self.backgroundColor = nil; self.shadowColor = nil; }
@end
@implementation UINavigationBarAppearance
- (instancetype)init { if ((self = [super init])) { _titleTextAttributes = @{}; _largeTitleTextAttributes = @{}; } return self; }
@end
@implementation UIToolbarAppearance @end
@implementation UITabBarAppearance @end

/* shared bar chrome: an appearance's background + hairline */
@interface __IsimBarBackground : UIView
- (void)apply:(UIBarAppearance *)a;
@end
@implementation __IsimBarBackground { UIVisualEffectView *_fx; UIView *_color, *_line; BOOL _fade; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        _fx = [[UIVisualEffectView alloc] initWithEffect:nil]; _color = [UIView new]; _line = [UIView new];
        for (UIView *v in @[_fx, _color, _line]) [self addSubview:v];
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
    _line.backgroundColor = a.shadowColor; _line.hidden = !a.shadowColor;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds; _fx.frame = b; _color.frame = b;
    _line.frame = self.tag == 1 ? CGRectMake(0, 0, b.size.width, 1.0 / 3) : CGRectMake(0, b.size.height - 1.0 / 3, b.size.width, 1.0 / 3);   /* tag 1: top hairline */
}
- (void)_isim_drawContent { if (_fade) draw_edge_fade(self.bounds.size, self.tag == 1); }
@end

/* ================= UINavigationBar ================= */
@interface __IsimBackButton : UIControl
@property (nonatomic, copy) NSString *text;
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
        CGSize i = chev.size; double k = 20 / fmax(1, i.height);
        [chev _isim_drawInRect:CGRectMake((44 - i.width * k) / 2 - 1, (s.height - i.height * k) / 2, i.width * k, i.height * k) tint:UIColor.labelColor alpha:1];
        return;
    }
    UIImage *chev = [UIImage systemImageNamed:@"chevron.left"];
    CGSize i = chev.size; double k = 22 / fmax(1, i.height);
    [chev _isim_drawInRect:CGRectMake(8, (s.height - i.height * k) / 2, i.width * k, i.height * k) tint:c alpha:a];
    UIFont *f = [UIFont systemFontOfSize:17]; CGSize ts = isim_ui_measure(self.text ?: @"", f, s.width, 1);
    isim_ui_draw_text(self.text ?: @"", f, c, CGRectMake(8 + i.width * k + 6, (s.height - ts.height) / 2, s.width - 8 - i.width * k - 6, ts.height), NSTextAlignmentLeft, 1, a);
}
@end

@interface UINavigationBar ()
@property (nonatomic) CGFloat _isim_safeTop, _isim_largeExtra, _isim_searchExtra;
@property (nonatomic) BOOL _isim_scrolledEdge;
@property (nonatomic, copy) void (^_isim_back)(void);
@end
@implementation UINavigationBar { NSMutableArray<UINavigationItem *> *_stack; __IsimBarBackground *_bg; UILabel *_title, *_large; __IsimBackButton *_back; UIView *_largeClip;
                                  NSMutableArray<UIView *> *_itemViews; UIView *_titleViewHost; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _stack = [NSMutableArray array]; _itemViews = [NSMutableArray array]; _translucent = YES;
        _bg = [__IsimBarBackground new]; [self addSubview:_bg];
        _largeClip = [UIView new]; _largeClip.clipsToBounds = YES; _largeClip.userInteractionEnabled = NO; [self addSubview:_largeClip];
        _large = [UILabel new]; _large.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold]; [_largeClip addSubview:_large];
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _title.textAlignment = NSTextAlignmentCenter; [self addSubview:_title];
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
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)a { [_stack addObject:item]; [self setNeedsLayout]; }
- (UINavigationItem *)popNavigationItemAnimated:(BOOL)a { UINavigationItem *i = _stack.lastObject; if (i) [_stack removeLastObject]; [self setNeedsLayout]; return i; }
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
- (UIColor *)_isim_titleColor:(BOOL)large {
    UINavigationBarAppearance *ap = _standardAppearance;
    NSDictionary *attrs = large ? (ap.largeTitleTextAttributes.count ? ap.largeTitleTextAttributes : _largeTitleTextAttributes) : (ap.titleTextAttributes.count ? ap.titleTextAttributes : _titleTextAttributes);
    UIColor *c = attrs[@"NSColor"];
    return [c isKindOfClass:[UIColor class]] ? c : UIColor.labelColor;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, top = self._isim_safeTop, extra = self._isim_largeExtra;
    BOOL large = [self _isim_topIsLarge];
    UINavigationItem *item = self.topItem, *prev = self.backItem;
    /* background: transparent at the scroll edge (iOS 15+), the standard appearance once content is under the bar */
    UINavigationBarAppearance *ap = (!self._isim_scrolledEdge && (self.scrollEdgeAppearance || YES)) ? (self.scrollEdgeAppearance ?: ({ UINavigationBarAppearance *t = [UINavigationBarAppearance new]; [t configureWithTransparentBackground]; t; })) : _standardAppearance;
    if (_barTintColor && ap == _standardAppearance) { UINavigationBarAppearance *o = [_standardAppearance copy]; o.backgroundColor = _barTintColor; ap = o; }
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
        _title.text = item.title; _title.textColor = [self _isim_titleColor:NO];
        _title.frame = CGRectMake(side, y, fmax(0, W - 2 * side), 44);
        _title.alpha = large ? (extra < 6 ? 1 : 0) : 1;
    }
    /* the large title sits in the band below the bar row and slides up under it as content scrolls */
    _largeClip.hidden = !large || extra <= 0;
    if (large) {
        _largeClip.frame = CGRectMake(0, y + 44, W, extra);
        _large.text = item.title; _large.textColor = [self _isim_titleColor:YES];
        _large.frame = CGRectMake(margin, extra - 52, W - 2 * margin, 50);
    }
    [self bringSubviewToFront:_back];
    [self _isim_placeSearchBarAtY:y + 44 + (large ? extra : 0) visible:self._isim_searchExtra];   /* UISearch.m */
}
@end

/* ================= UIToolbar ================= */
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
        UIView *v = it.customView ?: [__IsimBarButton buttonFor:it];
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
@property (nonatomic, strong) UIColor *onColor, *offColor;
@end
@implementation __IsimTabButton
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; UIColor *c = self.on ? self.onColor : self.offColor; double a = self.highlighted ? 0.5 : 1;
    UIImage *img = self.on && self.item.selectedImage ? self.item.selectedImage : self.item.image;
    if (self.mode >= 2) {                     /* iPad top tab bar: titles in a capsule, the selected one on a pill */
        if (self.on) {
            if (self.mode == 3) isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), s.height / 2, nil, 4 | 8);
            else { double p[4]; isim_ui_rgba(isim_ui_style() == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.36 alpha:1] : UIColor.whiteColor, p); isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, p); }
        }
        UIFont *f = [UIFont systemFontOfSize:15 weight:self.on ? UIFontWeightSemibold : UIFontWeightMedium];
        CGSize ts = isim_ui_measure(self.item.title ?: @"", f, s.width - 8, 1);
        isim_ui_draw_text(self.item.title ?: @"", f, self.on ? self.onColor : UIColor.labelColor, CGRectMake(4, (s.height - ts.height) / 2, s.width - 8, ts.height), NSTextAlignmentCenter, 1, a);
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
        UIFont *f = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        isim_ui_draw_text(self.item.title ?: @"", f, c, CGRectMake(2, 32, s.width - 4, 13), NSTextAlignmentCenter, 1, a);
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
    UIFont *f = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    isim_ui_draw_text(self.item.title ?: @"", f, c, CGRectMake(2, 34, s.width - 4, 13), NSTextAlignmentCenter, 1, a);
    if (self.item.badgeValue) {
        UIFont *bf = [UIFont systemFontOfSize:13]; NSString *b = self.item.badgeValue;
        double bw = fmax(18, isim_ui_measure(b, bf, 100, 1).width + 10), bx = s.width / 2 + 6;
        double rgba[4]; isim_ui_rgba(self.item.badgeColor ?: UIColor.systemRedColor, rgba);
        isim_gfx_fill_rounded(bx, 3, bw, 18, 9, rgba);
        isim_ui_draw_text(b, bf, UIColor.whiteColor, CGRectMake(bx, 3 + (18 - 16) / 2.0, bw, 16), NSTextAlignmentCenter, 1, 1);
    }
}
@end

@implementation UITabBar { __IsimBarBackground *_bg; NSMutableArray<__IsimTabButton *> *_buttons; }
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
    for (NSUInteger i = 0; i < items.count; i++) {
        __IsimTabButton *b = _buttons[i];
        b.item = items[i]; b.on = items[i] == _selectedItem; b.mode = mode;
        b.onColor = self.tintColor ?: UIColor.systemBlueColor; b.offColor = _unselectedItemTintColor ?: UIColor.systemGrayColor;
        b.frame = mode ? CGRectMake(area.origin.x + i * w, area.origin.y, w, area.size.height) : CGRectMake(i * w, 0, w, 49);
        b.accessibilityIdentifier = [@"tab-" stringByAppendingString:((UITabBarItem *)items[i]).title ?: [@(i) stringValue]];
        [b setNeedsDisplay];
    }
}
/* iOS 26 iPhone: the bar floats as a capsule inset from the screen edges, above the home indicator */
- (CGRect)_isim_capsule { CGSize s = self.bounds.size; CGFloat inset = s.width > 600 ? (s.width - 560) / 2 : 21; return CGRectMake(inset, 0, s.width - 2 * inset, 62); }
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
    UIPanGestureRecognizer *_popPan; BOOL _transitioning, _swiping; __weak UIScrollView *_tracked; UIView *_dim; }
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
- (CGFloat)_isim_barContent { return (_navigationBarHidden ? 0 : 44 + ([_bar _isim_topIsLarge] ? 52 : 0)) + [self _isim_searchBarHeight]; }
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
    CGFloat extra = large ? fmin(52, fmax(0, 52 - y)) : 0;
    _bar._isim_safeTop = safeTop; _bar._isim_largeExtra = extra; _bar._isim_searchExtra = search;
    _bar._isim_scrolledEdge = large ? y > 52 - 0.5 : y > 0.5;
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
    void (^finish)(BOOL) = ^(BOOL f) {
        _transitioning = NO;
        if (from && from != to) { [from.viewIfLoaded removeFromSuperview]; if (visible) [from _isim_appear:NO]; }
        [_dim removeFromSuperview]; _dim = nil;
        if (to) to.viewIfLoaded.frame = host.bounds;
        if (visible) [to _isim_didAppear];
        if (done) done();
        if ([self.delegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) [self.delegate navigationController:self didShowViewController:to animated:animated];
        [self.view setNeedsLayout];
    };
    if (!animated || !host.window || !from || from == to) { finish(YES); return; }
    _transitioning = YES;
    CGFloat W = host.bounds.size.width;
    UIView *fv = from.view, *tv = to.view;
    if (!push) [host insertSubview:tv belowSubview:fv];
    _dim = [[UIView alloc] initWithFrame:host.bounds]; _dim.backgroundColor = UIColor.blackColor; _dim.userInteractionEnabled = NO;
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

/* ================= UITabBarController ================= */
@implementation UITabBarController { UITabBar *_bar; NSArray *_vcs; NSUInteger _sel; BOOL _barHidden; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) { _bar = [[UITabBar alloc] initWithFrame:CGRectZero]; _bar.delegate = self; _vcs = @[]; }
    return self;
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
    if (i >= _vcs.count || i == _sel) { _sel = MIN(i, _vcs.count ? _vcs.count - 1 : 0); return; }
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
    UIViewController *vc = _vcs[i];
    if ([self.delegate respondsToSelector:@selector(tabBarController:shouldSelectViewController:)] && ![self.delegate tabBarController:self shouldSelectViewController:vc]) {
        _bar.selectedItem = self.selectedViewController.tabBarItem; return;
    }
    if (i == _sel && [vc isKindOfClass:[UINavigationController class]]) [(UINavigationController *)vc popToRootViewControllerAnimated:YES];   /* tap again: back to the root */
    self.selectedIndex = i;
    if ([self.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [self.delegate tabBarController:self didSelectViewController:vc];
}
- (void)_isim_showSelected {
    UIView *host = self.viewIfLoaded; UIViewController *s = self.selectedViewController;
    if (!host || !s) return;
    UIView *v = s.view;
    v.frame = host.bounds; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (v.superview != host) [host insertSubview:v belowSubview:_bar];
    [self _isim_updateTabBar];
}
/* the bar hides under a pushed controller with hidesBottomBarWhenPushed */
- (void)_isim_updateTabBar {
    UIViewController *s = self.selectedViewController;
    UIViewController *top = [s isKindOfClass:[UINavigationController class]] ? ((UINavigationController *)s).topViewController : s;
    BOOL hide = NO;
    if ([s isKindOfClass:[UINavigationController class]]) for (UIViewController *c in ((UINavigationController *)s).viewControllers) if (c != ((UINavigationController *)s).viewControllers.firstObject && c.hidesBottomBarWhenPushed) hide = YES;
    (void)top;
    _barHidden = hide;
    _bar.hidden = hide;
    int mode = tabbar_mode();                 /* iPad top bar (iOS 18+): sits in the navigation bar row, no bottom inset */
    for (UIViewController *c in _vcs) c.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, hide || mode >= 2 ? 0 : 49, 0);
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
    self.selectedViewController.viewIfLoaded.frame = host.bounds;
}
@end
