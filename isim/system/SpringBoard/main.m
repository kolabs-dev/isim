// isim home screen ("SpringBoard"): installed apps as icons on pages (with folders), the dock, the App Library
// page and Spotlight. Tapping an icon asks the isim shell to launch (or resume) the app. Runs as an isim system app
// under `isim boot`. The arrangement is saved in <isim data>/Library/SpringBoard/IconState.plist.
// The look follows the emulated iOS version (isim --os):
//   iOS 17     translucent dock, light icons.
//   iOS 18+    icon appearance (Home Screen > Customize): ISIM_ICON_STYLE=light|dark|tinted (and, iOS 26+, clear),
//              ISIM_ICON_TINT=#RRGGBB for tinted. An app's own dark/tinted icon variants are used when it has them;
//              otherwise isim derives them (adapted: darkened / luminance-tinted / see-through copies of the icon).
//   iOS 26+    Liquid Glass: a glass dock with larger corners, a specular glass rim on every icon.
#import <UIKit/UIKit.h>
#import "SpringBoard.h"
#import <objc/runtime.h>

static int os_major(void) { return isim_os_version() / 10000; }
/* Home Screen icon appearance (iOS 18+): 0 light, 1 dark, 2 tinted, 3 clear (iOS 26+) */
static int icon_style(void) {
    static int s = -1;
    if (s >= 0) return s;
    const char *e = getenv("ISIM_ICON_STYLE"); s = 0;
    if (e && !strcmp(e, "dark")) s = 1; else if (e && !strcmp(e, "tinted")) s = 2; else if (e && !strcmp(e, "clear")) s = 3;
    if (s && os_major() < 18) { NSLog(@"SpringBoard: icon appearance '%s' needs iOS 18 or later (running iOS %d): light icons", e, os_major()); s = 0; }
    if (s == 3 && os_major() < 26) { NSLog(@"SpringBoard: clear icons need iOS 26 or later: light icons"); s = 0; }
    return s;
}
/* the app's own dark/tinted icon (asset catalog appearance variant), if it has one */
static NSString *icon_variant(NSString *app, NSDictionary *info, NSString *appearance) {
    NSDictionary *assets = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"isim-assets.plist"]];
    NSDictionary *icons = assets[@"appIcons"];
    NSString *name = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"] ?: @"AppIcon";
    NSArray *files = icons[name] ?: icons.allValues.firstObject;
    for (NSDictionary *f in files) if ([f[@"appearance"] isEqualToString:appearance]) return [app stringByAppendingPathComponent:f[@"file"]];
    return nil;
}
/* derived icon appearances (no variant in the app): dark = the artwork darkened toward black; tinted = the
   artwork's luminance in the tint colour on black; clear = a faint see-through copy */
static UIImage *restyle_icon(UIImage *img, int style, BOOL ownVariant) {
    if (!img || style == 0 || (ownVariant && style != 3)) return img;
    CGImageRef src = img.CGImage; if (!src) return img;
    size_t w = CGImageGetWidth(src), h = CGImageGetHeight(src);
    if (w == 0 || h == 0 || w > 2048 || h > 2048) return img;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return img;
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), src);
    uint8_t *px = CGBitmapContextGetData(ctx);
    double tr = 0.35, tg = 0.6, tb = 1.0;
    const char *t = getenv("ISIM_ICON_TINT"); unsigned rgb;
    if (t && sscanf(t[0] == '#' ? t + 1 : t, "%6x", &rgb) == 1) { tr = (rgb >> 16 & 255) / 255.0; tg = (rgb >> 8 & 255) / 255.0; tb = (rgb & 255) / 255.0; }
    for (size_t i = 0; px && i < w * h; i++) {
        uint8_t *p = px + i * 4; double r = p[0], g = p[1], b = p[2], a = p[3];
        double lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if (style == 1) { double k = 0.42; p[0] = (uint8_t)(r * k + 14 * (a / 255)); p[1] = (uint8_t)(g * k + 14 * (a / 255)); p[2] = (uint8_t)(b * k + 16 * (a / 255)); }
        else if (style == 2) { double l = lum / 255; l = l * l; p[0] = (uint8_t)(tr * l * a); p[1] = (uint8_t)(tg * l * a); p[2] = (uint8_t)(tb * l * a); }
        else { double k = 0.35; p[0] = (uint8_t)(r * k); p[1] = (uint8_t)(g * k); p[2] = (uint8_t)(b * k); p[3] = (uint8_t)(a * k); }
    }
    CGImageRef out = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    UIImage *res = out ? [UIImage imageWithCGImage:out scale:img.scale orientation:UIImageOrientationUp] : img;
    if (out) CGImageRelease(out);
    return res;
}
/* iOS 26: the dock is a clear glass platter */
@interface HSDock : UIView
@end
@implementation HSDock
- (void)drawRect:(CGRect)r {
    if (os_major() < 26) return;
    CGSize s = self.bounds.size;
    isim_gfx_glass(0, 0, s.width, s.height, self.layer.cornerRadius, NULL, 2);
}
@end
/* iOS 26: icons get a glass edge — a specular rim, brighter at the top left */
@interface HSIconRim : UIView
@end
@implementation HSIconRim
- (void)drawRect:(CGRect)r {
    CGSize s = self.bounds.size; double rad = self.layer.cornerRadius;
    double hi[4] = { 1, 1, 1, 0.75 }, lo[4] = { 1, 1, 1, 0.22 };
    isim_gfx_stroke_rounded(0, 0, s.width, s.height, rad, 1.2, lo);
    isim_gfx_save(); isim_gfx_clip_rounded(0, 0, s.width * 0.6, s.height * 0.6, 0);
    isim_gfx_stroke_rounded(0, 0, s.width, s.height, rad, 1.2, hi);
    isim_gfx_restore();
}
@end

static NSArray<HSApp *> *scan(NSString *dir, BOOL system) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL]) {
        if (![n hasSuffix:@".app"]) continue;
        NSString *path = [dir stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
        if (!info || [info[@"ISIMHidden"] boolValue]) continue;
        HSApp *a = [HSApp new];
        a.path = path; a.system = system;
        a.executable = [path stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension];
        NSBundle *b = [NSBundle bundleWithPath:path];          /* localized names (InfoPlist.strings), as on iOS */
        a.name = [b objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [b objectForInfoDictionaryKey:@"CFBundleName"] ?: n.stringByDeletingPathExtension;
        a.bundleID = info[@"CFBundleIdentifier"] ?: n;
        a.info = info;
        a.category = system ? @"public.app-category.utilities" : info[@"LSApplicationCategoryType"];
        a.iconPath = HSIconPath(path, info, a.bundleID);
        [out addObject:a];
    }
    [out sortUsingComparator:^NSComparisonResult(HSApp *x, HSApp *y) { return [x.name localizedCaseInsensitiveCompare:y.name]; }];
    return out;
}

NSString *HSCategoryName(NSString *c) {
    NSDictionary *m = @{ @"utilities": @"Utilities", @"productivity": @"Productivity", @"games": @"Games", @"social-networking": @"Social",
        @"entertainment": @"Entertainment", @"education": @"Education", @"finance": @"Finance", @"healthcare-fitness": @"Health & Fitness",
        @"lifestyle": @"Lifestyle", @"music": @"Music", @"news": @"News", @"photography": @"Photo & Video", @"video": @"Photo & Video",
        @"travel": @"Travel", @"weather": @"Weather", @"developer-tools": @"Developer Tools", @"business": @"Business", @"reference": @"Reference",
        @"medical": @"Medical", @"navigation": @"Navigation", @"sports": @"Sports", @"food-and-drink": @"Food & Drink", @"shopping": @"Shopping",
        @"graphics-design": @"Graphics & Design" };
    NSString *k = [c hasPrefix:@"public.app-category."] ? [c substringFromIndex:20] : c;
    if ([k hasSuffix:@"-games"]) return @"Games";
    return k ? m[k] : nil;
}

/* icon + label, tappable */
@implementation HSIcon { UIImageView *_image; UILabel *_label, *_letter, *_count; }
- (void)setBadgeCount:(NSInteger)n {
    if (n <= 0) { _count.hidden = YES; _count.text = nil; return; }
    if (!_count) {
        _count = [UILabel new];
        _count.backgroundColor = UIColor.systemRedColor; _count.textColor = UIColor.whiteColor;
        _count.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular]; _count.textAlignment = NSTextAlignmentCenter;
        _count.clipsToBounds = YES; _count.userInteractionEnabled = NO;
        _count.accessibilityIdentifier = [@"badge-" stringByAppendingString:_app.bundleID ?: @""];
        [self addSubview:_count];
    }
    _count.hidden = NO; _count.text = n > 99999 ? @"99999+" : [NSString stringWithFormat:@"%ld", (long)n];
    [self setNeedsLayout];
}
@synthesize badge = _badge;
- (void)setEditing:(BOOL)e { _editing = e; _badge.hidden = !e || _app.system; [self bringSubviewToFront:_badge]; }
- (instancetype)initWithApp:(HSApp *)app size:(CGFloat)s label:(BOOL)label {
    if ((self = [super initWithFrame:CGRectZero])) {
        _app = app; _showLabel = label;
        _image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, s, s)];
        _image.layer.cornerRadius = s * 0.225; _image.clipsToBounds = YES;
        _image.contentMode = UIViewContentModeScaleToFill;
        _image.userInteractionEnabled = NO;
        NSString *variant = icon_style() == 1 || icon_style() == 2 ? icon_variant(app.path, app.info, icon_style() == 1 ? @"dark" : @"tinted") : nil;
        UIImage *img = (variant ?: app.iconPath) ? [UIImage imageWithContentsOfFile:variant ?: app.iconPath] : nil;
        BOOL ownVariant = variant != nil;
        if (img && icon_style()) img = restyle_icon(img, icon_style(), ownVariant);
        if (img) _image.image = img;
        else {  /* placeholder: initial on a color derived from the bundle id */
            NSUInteger h = app.bundleID.hash;
            _image.backgroundColor = [UIColor colorWithRed:0.25 + (h % 7) / 12.0 green:0.35 + (h / 7 % 5) / 10.0 blue:0.55 + (h / 35 % 4) / 10.0 alpha:1];
            _letter = [[UILabel alloc] initWithFrame:_image.bounds];
            _letter.text = [app.name substringToIndex:MIN((NSUInteger)1, app.name.length)].uppercaseString;
            _letter.textAlignment = NSTextAlignmentCenter; _letter.textColor = UIColor.whiteColor;
            _letter.font = [UIFont systemFontOfSize:s * 0.45 weight:UIFontWeightSemibold];
            [_image addSubview:_letter];
        }
        [self addSubview:_image];
        if (os_major() >= 26) {
            HSIconRim *rim = [[HSIconRim alloc] initWithFrame:_image.bounds];
            rim.layer.cornerRadius = _image.layer.cornerRadius; rim.userInteractionEnabled = NO; rim.backgroundColor = nil;
            [_image addSubview:rim];
        }
        if (label) {
            _label = [[UILabel alloc] initWithFrame:CGRectZero];
            _label.text = app.name; _label.font = [UIFont systemFontOfSize:12]; _label.textColor = UIColor.whiteColor;
            _label.textAlignment = NSTextAlignmentCenter; _label.userInteractionEnabled = NO;
            [self addSubview:_label];
        }
        self.accessibilityIdentifier = [@"app-" stringByAppendingString:app.bundleID];
        self.accessibilityLabel = app.name;
        _badge = [UIButton buttonWithType:UIButtonTypeCustom];
        [_badge setImage:[UIImage systemImageNamed:@"minus.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]] forState:UIControlStateNormal];
        _badge.tintColor = [UIColor colorWithWhite:0.25 alpha:0.95];
        _badge.backgroundColor = UIColor.whiteColor; _badge.layer.cornerRadius = 11;
        _badge.hidden = YES;
        _badge.accessibilityIdentifier = [@"remove-" stringByAppendingString:app.bundleID];
        [self addSubview:_badge];
        [self setBadgeCount:HSBadgeCount(app)];
    }
    return self;
}
- (UIImageView *)iconView { return _image; }
- (void)layoutSubviews {
    CGFloat s = _image.bounds.size.width, w = self.bounds.size.width;
    _image.frame = CGRectMake((w - s) / 2, 0, s, s);
    _badge.frame = CGRectMake((w - s) / 2 - 8, -8, 22, 22);
    if (_count && !_count.hidden) {                 /* the badge: a red capsule over the top-right corner */
        CGFloat h = 24, bw = MAX(h, [_count sizeThatFits:CGSizeMake(200, h)].width + 14);
        _count.frame = CGRectMake((w - s) / 2 + s - bw + 10, -8, bw, h); _count.layer.cornerRadius = h / 2;
        [self bringSubviewToFront:_count];
    }
    _label.frame = CGRectMake(-10, s + 5, w + 20, 16);
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; _image.alpha = h ? 0.6 : 1; }
@end

/* ---- the arrangement: a list of items (bundle id, or { folder, apps }) split into pages ---- */
static NSString *icon_state_file(void) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:@"IconState.plist"];
}

@interface HomeViewController () <HSPagerDelegate, HSPageDotsDelegate, UIGestureRecognizerDelegate>
@end
@implementation HomeViewController {
    NSArray<HSApp *> *_apps;
    NSMutableArray<NSMutableDictionary *> *_homePages;        /* { items = (bundle id | folder | widget); hidden } */
    NSMutableSet<NSString *> *_known;                         /* apps the home screen has seen (App Library Only apps stay off pages) */
    NSMutableArray<NSNumber *> *_visible;                     /* pager page -> model page */
    HSPager *_pager; HSPageDots *_dots;
    UIView *_dock; UIImageView *_wallpaper; UIView *_menu; BOOL _editing; UIButton *_done, *_searchPill;
    NSMutableArray<UIView *> *_pageViews; UIView *_library;
    NSMutableDictionary<NSNumber *, NSArray *> *_place;       /* model page -> placements [col, row, cw, ch] */
    UIView *_dragging; NSInteger _dragPage, _dragIndex; CGPoint _dragOffset, _dragPoint; NSTimer *_edgeTimer; double _edgeSince, _lastFlip;
    UIButton *_addWidget;
}
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (CGFloat)iconSize { return self.view.bounds.size.width >= 700 ? 74 : 60; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _wallpaper = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _wallpaper.image = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"wallpaper.png"]];
    _wallpaper.contentMode = UIViewContentModeScaleAspectFill;
    _wallpaper.backgroundColor = [UIColor colorWithRed:0.16 green:0.2 blue:0.42 alpha:1];
    [self.view addSubview:_wallpaper];
    _pager = [HSPager new]; _pager.delegate = self; _pager.scrollEnabled = YES;
    _pager.accessibilityIdentifier = @"home-pages";
    [self.view addSubview:_pager];
    _dock = [HSDock new];
    BOOL glass = os_major() >= 26;
    _dock.backgroundColor = glass ? nil : [UIColor colorWithWhite:1 alpha:0.28];
    _dock.layer.cornerRadius = glass ? 38 : 32;
    _dock.accessibilityIdentifier = @"home-dock";
    NSLog(@"SpringBoard: iOS %d look%s", os_major(), glass ? " (Liquid Glass)" : "");
    [self.view addSubview:_dock];
    _searchPill = [UIButton buttonWithType:UIButtonTypeCustom];             /* one page: the Search button (iOS 16+) */
    _searchPill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25]; _searchPill.layer.cornerRadius = 14;
    [_searchPill setTitle:NSLocalizedString(@"Search", nil) forState:UIControlStateNormal];
    [_searchPill setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11]] forState:UIControlStateNormal];
    _searchPill.tintColor = UIColor.whiteColor; _searchPill.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _searchPill.accessibilityIdentifier = @"home-search";
    [_searchPill addTarget:self action:@selector(showSpotlight) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_searchPill];
    _dots = [HSPageDots new]; _dots.delegate = self;                       /* several pages: the page dots */
    [self.view addSubview:_dots];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:UIApplicationWillEnterForegroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(launchByID:) name:@"_IsimShellLaunch" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(showSpotlight) name:@"_SBShowSpotlight" object:nil];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if ([t hasPrefix:@"homepage "]) [self goToPage:[t substringFromIndex:9]];
    }];
    [self installSystemObservers];
    [self installWidgetObservers];
    [self installNotificationObservers];
    [self reload];
}
- (void)pagerPulledDown:(HSPager *)pager { if (!_editing) [self showSpotlight]; }
- (void)reload {
    NSMutableArray *apps = [NSMutableArray array];
    [apps addObjectsFromArray:scan(isim_ui_system_apps_dir(), YES)];
    [apps addObjectsFromArray:scan(isim_ui_installed_apps_dir(), NO)];
    _apps = apps;
    NSMutableArray *names = [NSMutableArray array]; for (HSApp *a in apps) [names addObject:a.name];
    if (apps.count <= 12) NSLog(@"SpringBoard: %lu app(s): %@", (unsigned long)apps.count, [names componentsJoinedByString:@", "]);
    else NSLog(@"SpringBoard: %lu app(s)", (unsigned long)apps.count);
    [self reconcileLayout];
    [self.view setNeedsLayout];
    [self rebuild];
    [self publishAppInfo];
    [self discoverWidgets];
}
- (NSArray<HSApp *> *)apps { return _apps; }
- (HSApp *)appWithIdentifier:(NSString *)ident {
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) return a;
    [self reload];
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) return a;
    return nil;
}
- (HSApp *)appForID:(NSString *)ident { for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident]) return a; return nil; }

/* ---- the arrangement: pages of items, saved in IconState.plist { pages = ({ items; hidden }); known = (bundle ids) } ---- */
- (id)_validItem:(id)it {
    if ([it isKindOfClass:[NSString class]]) { HSApp *a = [self appForID:it]; return a && !a.system ? it : nil; }
    if (![it isKindOfClass:[NSDictionary class]]) return nil;
    if (it[@"widget"]) return [self appForID:it[@"app"]] ? [it mutableCopy] : nil;
    NSMutableArray *ids = [NSMutableArray array];
    for (NSString *i in it[@"apps"]) if ([self appForID:i]) [ids addObject:i];
    return ids.count ? [@{ @"folder": it[@"folder"] ?: @"Folder", @"apps": ids } mutableCopy] : nil;
}
- (void)reconcileLayout {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:icon_state_file()];
    _homePages = [NSMutableArray array];
    _known = [NSMutableSet setWithArray:state[@"known"] ?: @[]];
    if (state[@"pages"]) {
        for (NSDictionary *p in state[@"pages"]) {
            NSMutableArray *items = [NSMutableArray array];
            for (id it in p[@"items"]) { id v = [self _validItem:it]; if (v) [items addObject:v]; }
            [_homePages addObject:[@{ @"items": items, @"hidden": @([p[@"hidden"] boolValue]) } mutableCopy]];
        }
    } else if (state[@"items"]) {                                       /* the first format: one list */
        NSMutableArray *items = [NSMutableArray array];
        for (id it in state[@"items"]) { id v = [self _validItem:it]; if (v) [items addObject:v]; }
        [_homePages addObject:[@{ @"items": items, @"hidden": @NO } mutableCopy]];
        for (id it in items) { if ([it isKindOfClass:[NSString class]]) [_known addObject:it]; else for (NSString *i in it[@"apps"]) [_known addObject:i]; }
    }
    if (!_homePages.count) [_homePages addObject:[@{ @"items": [NSMutableArray array], @"hidden": @NO } mutableCopy]];
    NSMutableSet *placed = [NSMutableSet set];
    for (NSDictionary *p in _homePages) for (id it in p[@"items"]) {
        if ([it isKindOfClass:[NSString class]]) [placed addObject:it]; else if (it[@"apps"]) [placed addObjectsFromArray:it[@"apps"]];
    }
    /* newly installed apps: the first page with space (or a new page), unless Settings says App Library Only */
    NSUserDefaults *global = [[NSUserDefaults alloc] initWithSuiteName:@".GlobalPreferences"];
    BOOL toHome = [global objectForKey:@"SBNewAppsToHomeScreen"] ? [global boolForKey:@"SBNewAppsToHomeScreen"] : YES;
    for (HSApp *a in _apps) {
        if (a.system || [placed containsObject:a.bundleID] || [_known containsObject:a.bundleID]) continue;
        [_known addObject:a.bundleID];
        if (!toHome) { NSLog(@"SpringBoard: %@ added to the App Library only", a.name); continue; }
        [self _placeNewItem:a.bundleID];
    }
    for (NSUInteger i = 0; i < _homePages.count; i++) [self normalizePage:i];
    [self saveLayout];
}
- (void)_placeNewItem:(id)item {
    for (NSMutableDictionary *p in _homePages) {
        if ([p[@"hidden"] boolValue]) continue;
        NSMutableArray *trial = [p[@"items"] mutableCopy]; [trial addObject:item];
        if ([self placementsFor:trial overflow:NULL]) { [p[@"items"] addObject:item]; return; }
    }
    [_homePages addObject:[@{ @"items": [NSMutableArray arrayWithObject:item], @"hidden": @NO } mutableCopy]];
}
- (void)saveLayout {
    NSMutableArray *known = [[_known allObjects] mutableCopy]; [known sortUsingSelector:@selector(compare:)];
    [@{ @"pages": _homePages, @"known": known } writeToFile:icon_state_file() atomically:YES];
}
- (NSInteger)columns { return self.view.bounds.size.width >= 700 ? 6 : 4; }
- (NSInteger)rows {
    CGRect b = self.view.bounds; BOOL pad = b.size.width >= 700;
    CGFloat rowH = pad ? 120 : 102, avail = b.size.height - self.view.safeAreaInsets.top - (pad ? 40 : 14) - 150;
    return MAX(1, MIN(pad ? 5 : 6, (NSInteger)(avail / rowH)));
}
- (NSInteger)perPage { return [self columns] * [self rows]; }
/* grid placement: icons take one cell; widgets 2x2 (small, at column 0 or 2), 4x2 (medium), 4x4 (large) */
static void item_span(id it, NSInteger cols, NSInteger *cw, NSInteger *ch) {
    *cw = *ch = 1;
    if (![it isKindOfClass:[NSDictionary class]] || !it[@"widget"]) return;
    NSString *f = it[@"family"];
    if ([f isEqual:@"systemMedium"]) { *cw = cols; *ch = 2; } else if ([f isEqual:@"systemLarge"]) { *cw = cols; *ch = 4; } else { *cw = 2; *ch = 2; }
}
/* placements [col, row, cw, ch] of the items on one page; nil if they do not all fit (overflow: the first that does not) */
- (NSArray *)placementsFor:(NSArray *)items overflow:(NSInteger *)overflow {
    NSInteger cols = [self columns], rows = [self rows];
    NSMutableData *grid = [NSMutableData dataWithLength:(NSUInteger)(rows * cols)];
    char *g = grid.mutableBytes;
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < items.count; i++) {
        NSInteger cw, ch; item_span(items[i], cols, &cw, &ch);
        BOOL done = NO;
        for (NSInteger r = 0; r + ch <= rows && !done; r++) for (NSInteger c = 0; c + cw <= cols && !done; c += (cw > 1 ? 2 : 1)) {
            BOOL free = YES;
            for (NSInteger y = r; y < r + ch && free; y++) for (NSInteger x = c; x < c + cw; x++) if (g[y * cols + x]) { free = NO; break; }
            if (!free) continue;
            for (NSInteger y = r; y < r + ch; y++) for (NSInteger x = c; x < c + cw; x++) g[y * cols + x] = 1;
            [out addObject:@[@(c), @(r), @(cw), @(ch)]]; done = YES;
        }
        if (!done) { if (overflow) *overflow = (NSInteger)i; return nil; }
    }
    return out;
}
/* a page holds what fits; the rest moves to the start of the next page (made if needed) */
- (void)normalizePage:(NSUInteger)i {
    if (i >= _homePages.count) return;
    NSMutableArray *items = _homePages[i][@"items"];
    NSInteger over = 0;
    if ([self placementsFor:items overflow:&over]) return;
    NSArray *moving = [items subarrayWithRange:NSMakeRange((NSUInteger)over, items.count - (NSUInteger)over)];
    [items removeObjectsInRange:NSMakeRange((NSUInteger)over, items.count - (NSUInteger)over)];
    if (i + 1 >= _homePages.count) [_homePages addObject:[@{ @"items": [NSMutableArray array], @"hidden": _homePages[i][@"hidden"] } mutableCopy]];
    NSMutableArray *next = _homePages[i + 1][@"items"];
    [next insertObjects:moving atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, moving.count)]];
    NSLog(@"SpringBoard: page %lu is full: %lu item(s) moved to page %lu", (unsigned long)i + 1, (unsigned long)moving.count, (unsigned long)i + 2);
    [self normalizePage:i + 1];
}
- (UIControl *)makeIcon:(id)it page:(NSInteger)page index:(NSInteger)idx {
    CGFloat s = self.iconSize; UIControl *icon;
    if ([it isKindOfClass:[NSDictionary class]] && it[@"widget"]) icon = [self makeWidgetView:it];
    else if ([it isKindOfClass:[NSString class]]) {
        HSIcon *ai = [[HSIcon alloc] initWithApp:[self appForID:it] size:s label:YES];
        [ai addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [ai addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(held:)]];
        [ai.badge addTarget:self action:@selector(badgeTapped:) forControlEvents:UIControlEventTouchUpInside];
        ai.editing = _editing;
        icon = ai;
    } else {
        NSMutableArray *fa = [NSMutableArray array]; for (NSString *x in it[@"apps"]) { HSApp *a = [self appForID:x]; if (a) [fa addObject:a]; }
        HSFolderIcon *fi = [[HSFolderIcon alloc] initWithFolder:it apps:fa size:s];
        [fi addTarget:self action:@selector(folderTapped:) forControlEvents:UIControlEventTouchUpInside];
        [fi addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(folderHeld:)]];
        icon = fi;
    }
    icon.tag = page * 1000 + idx;                                      /* model page, index on it */
    if (_editing) [icon addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(iconPanned:)]];
    return icon;
}
- (UIView *)makePageView:(NSUInteger)m {
    UIView *pv = [UIView new];
    pv.accessibilityIdentifier = [NSString stringWithFormat:@"home-page-%lu", (unsigned long)m + 1];
    NSArray *items = _homePages[m][@"items"];
    for (NSUInteger i = 0; i < items.count; i++) [pv addSubview:[self makeIcon:items[i] page:(NSInteger)m index:(NSInteger)i]];
    return pv;
}
- (void)rebuild {
    for (UIView *v in _dock.subviews) [v removeFromSuperview];
    _pageViews = [NSMutableArray array]; _visible = [NSMutableArray array]; _place = [NSMutableDictionary dictionary];
    for (NSUInteger m = 0; m < _homePages.count; m++) {
        _place[@(m)] = [self placementsFor:_homePages[m][@"items"] overflow:NULL] ?: @[];
        if ([_homePages[m][@"hidden"] boolValue]) continue;
        [_visible addObject:@(m)];
        [_pageViews addObject:[self makePageView:m]];
    }
    for (HSApp *a in _apps) if (a.system) {                 /* system apps (Settings) live in the dock */
        HSIcon *icon = [[HSIcon alloc] initWithApp:a size:self.iconSize label:NO];
        [icon addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [icon addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(held:)]];
        [_dock addSubview:icon];
    }
    _library = [self makeLibraryPage:CGRectZero];
    NSInteger keep = _pager.currentPage;
    _pager.pages = [_pageViews arrayByAddingObject:_library];
    if (keep >= (NSInteger)_pageViews.count) keep = MAX(0, (NSInteger)_pageViews.count - 1);
    [_pager setCurrentPage:keep animated:NO];
    _pager.scrollEnabled = !_editing;
    _dots.numberOfPages = (NSInteger)_pageViews.count; _dots.editMode = _editing;
    [self.view setNeedsLayout];
}
- (CGRect)frameForPlacement:(NSArray *)pl {
    CGRect b = self.view.bounds; BOOL pad = b.size.width >= 700;
    NSInteger cols = [self columns];
    CGFloat s = self.iconSize, margin = pad ? 60 : 28, rowH = pad ? 120 : 102, top = self.view.safeAreaInsets.top + (pad ? 40 : 14);
    CGFloat colW = (b.size.width - 2 * margin) / cols;
    NSInteger c = [pl[0] integerValue], r = [pl[1] integerValue], cw = [pl[2] integerValue], ch = [pl[3] integerValue];
    return CGRectMake(margin + c * colW + (colW - s) / 2, top + r * rowH, (cw - 1) * colW + s, (ch - 1) * rowH + s + 22);
}
- (void)layoutPageView:(UIView *)pv {
    for (UIView *icon in pv.subviews) {
        if (icon == _dragging) continue;
        NSArray *pls = _place[@(icon.tag / 1000)]; NSInteger i = icon.tag % 1000;
        if (i < (NSInteger)pls.count) icon.frame = [self frameForPlacement:pls[i]];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds; UIEdgeInsets safe = self.view.safeAreaInsets;
    BOOL pad = b.size.width >= 700;
    CGFloat s = self.iconSize;
    CGFloat dockH = pad ? 100 : 92, dockInset = pad ? (b.size.width - 420) / 2 : 12;
    _dock.frame = CGRectMake(dockInset, b.size.height - MAX(safe.bottom, 12) - dockH + (safe.bottom > 0 ? 18 : 0) - 4, b.size.width - 2 * dockInset, dockH);
    _pager.frame = CGRectMake(0, 0, b.size.width, _dock.frame.origin.y - 36);
    for (UIView *pv in _pageViews) [self layoutPageView:pv];
    _searchPill.frame = CGRectMake((b.size.width - 86) / 2, _dock.frame.origin.y - 30, 86, 26);
    _dots.frame = CGRectMake(40, _dock.frame.origin.y - 32, b.size.width - 80, 30);
    [self updateIndicator];
    NSInteger n = _dock.subviews.count; CGFloat dColW = _dock.bounds.size.width / MAX(4, n);
    CGFloat start = (_dock.bounds.size.width - dColW * n) / 2;
    NSInteger i = 0;
    for (HSIcon *icon in _dock.subviews) { icon.frame = CGRectMake(start + i * dColW + (dColW - s) / 2, (dockH - s) / 2, s, s); i++; }
    _done.frame = CGRectMake(b.size.width - 82, safe.top + 2, 66, 30);
    _addWidget.frame = CGRectMake(16, safe.top + 2, 40, 30);
    [self publishIconRects];
}
/* tell the shell where each app's icon is (app open/close animations zoom from/to it; apps in folders: the folder) */
- (void)publishIconRects {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect b = self.view.bounds;
        NSInteger cur = self->_pager.currentPage;
        NSMutableArray *containers = [NSMutableArray array];
        for (NSUInteger p = 0; p < self->_pageViews.count; p++) [containers addObject:self->_pageViews[p]];
        [containers addObject:self->_dock];
        for (NSUInteger k = 0; k < containers.count; k++) for (UIView *v in ((UIView *)containers[k]).subviews) {
            UIView *iv = [v respondsToSelector:@selector(iconView)] ? [(id)v iconView] : nil;
            if (!iv) continue;
            CGRect r = [v convertRect:iv.frame toView:self.view];
            if (k < self->_pageViews.count && (NSInteger)k != cur) r = CGRectMake(b.size.width / 2 - 30, b.size.height / 2 - 30, 60, 60);
            char geo[128];
            snprintf(geo, sizeof geo, "%g %g %g %g %g", r.origin.x, r.origin.y, r.size.width, r.size.height, iv.layer.cornerRadius);
            NSArray *ids = [v isKindOfClass:[HSFolderIcon class]] ? ((HSFolderIcon *)v).folder[@"apps"] : [v isKindOfClass:[HSIcon class]] ? @[((HSIcon *)v).app.bundleID ?: @""] : @[];
            for (NSString *ident in ids) { HSApp *a = [self appForID:ident]; if (a.path) isim_shell_request(ISIM_SHELL_ICON, a.path.UTF8String, geo, NULL); }
        }
    });
}
/* the page dots (several pages) or the Search button; both fade out with the dock on the App Library */
- (void)updateIndicator {
    CGFloat pos = _pager.pagePosition, lib = (CGFloat)_pageViews.count;
    CGFloat a = 1 - MIN(1, MAX(0, pos - (lib - 1)));
    _dock.alpha = a;
    BOOL several = _pageViews.count > 1 || _editing;
    _dots.hidden = !several; _searchPill.hidden = several;
    _dots.alpha = a; _searchPill.alpha = a;
    _dots.currentPage = MIN((NSInteger)_pageViews.count - 1, (NSInteger)lround(pos));
}
- (void)pagerDidScroll:(HSPager *)pager { [self updateIndicator]; }
- (void)pagerDidSettle:(HSPager *)pager {
    [self updateIndicator];
    NSInteger p = pager.currentPage;
    BOOL lib = p == (NSInteger)_pageViews.count;
    NSLog(@"SpringBoard: page %ld%@", (long)(lib ? p : p + 1), lib ? @" (App Library)" : [NSString stringWithFormat:@" of %lu", (unsigned long)_pageViews.count]);
    [self publishIconRects];
}
- (void)pageDots:(HSPageDots *)dots selectPage:(NSInteger)page { [_pager setCurrentPage:page animated:YES]; }
- (void)pageDotsWantEditPages:(HSPageDots *)dots { [self showEditPages]; }
/* script `homepage N` (1-based) / `homepage library` */
- (void)goToPage:(NSString *)arg {
    NSInteger p = [arg isEqualToString:@"library"] ? (NSInteger)_pageViews.count : arg.integerValue - 1;
    [_pager setCurrentPage:p animated:YES];
}

/* ---- Edit Pages (edit mode, tap the page dots): hide or show pages ---- */
- (UIImage *)thumbnailOfPage:(NSUInteger)m {
    CGRect b = self.view.bounds;
    BOOL editing = _editing; _editing = NO;                   /* thumbnails without the remove badges */
    UIView *pv = [self makePageView:m];
    _editing = editing;
    pv.frame = CGRectMake(0, 0, b.size.width, _pager.bounds.size.height);
    [self layoutPageView:pv];
    for (UIView *icon in pv.subviews) [icon layoutIfNeeded];
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat]; fmt.scale = 1;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:b.size format:fmt] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [self->_wallpaper drawViewHierarchyInRect:b afterScreenUpdates:NO];
        [pv drawViewHierarchyInRect:pv.frame afterScreenUpdates:YES];
    }];
}
- (void)showEditPages {
    NSMutableArray *thumbs = [NSMutableArray array], *hidden = [NSMutableArray array];
    for (NSUInteger m = 0; m < _homePages.count; m++) { [thumbs addObject:[self thumbnailOfPage:m]]; [hidden addObject:_homePages[m][@"hidden"]]; }
    HSEditPagesView *v = [[HSEditPagesView alloc] initWithFrame:self.view.bounds thumbnails:thumbs hidden:hidden];
    __weak HomeViewController *weakSelf = self;
    v.onDone = ^(NSArray<NSNumber *> *h) {
        HomeViewController *s = weakSelf; if (!s) return;
        for (NSUInteger m = 0; m < h.count && m < s->_homePages.count; m++) s->_homePages[m][@"hidden"] = h[m];
        [s saveLayout]; [s rebuild];
        NSLog(@"SpringBoard: Edit Pages done (%lu visible)", (unsigned long)s->_pageViews.count);
    };
    [self.view addSubview:v];
    NSLog(@"SpringBoard: Edit Pages (%lu pages)", (unsigned long)_homePages.count);
}

- (void)launch:(HSApp *)a { [self launch:a url:nil]; }
- (void)launch:(HSApp *)a url:(NSString *)url {
    NSLog(@"SpringBoard: launching %@ (%@)%@%@", a.name, a.bundleID, url ? @" with " : @"", url ?: @"");
    isim_shell_request(ISIM_SHELL_LAUNCH, a.path.UTF8String, a.executable.UTF8String, url.UTF8String);
}
- (void)tapped:(HSIcon *)icon { if (!_editing) { [self closeFolder]; [self hideSpotlight]; [self launch:icon.app]; } }
- (void)folderTapped:(HSFolderIcon *)f { if (!_editing) [self openFolder:f]; }
- (void)folderHeld:(UILongPressGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan && !_editing) [self setEditingMode:YES]; }

/* ---- edit mode: drag icons to rearrange them, across pages (hold at the screen edge), or onto another to make a folder ---- */
- (void)iconPanned:(UIPanGestureRecognizer *)g {
    UIView *icon = g.view;
    CGPoint p = [g locationInView:self.view];
    _dragPoint = p;
    if (g.state == UIGestureRecognizerStateBegan) {
        _dragging = icon; _dragPage = icon.tag / 1000; _dragIndex = icon.tag % 1000;
        CGPoint c = [icon.superview convertPoint:icon.center toView:self.view];
        _dragOffset = CGPointMake(c.x - p.x, c.y - p.y);
        [self.view addSubview:icon];                                     /* above the pages while it moves between them */
        icon.center = c;
        icon.transform = CGAffineTransformMakeScale(1.12, 1.12);
        _edgeSince = 0; _lastFlip = 0;
        __weak HomeViewController *weakSelf = self;
        _edgeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) { [weakSelf edgeCheck]; }];
        return;
    }
    if (g.state == UIGestureRecognizerStateChanged) { icon.center = CGPointMake(p.x + _dragOffset.x, p.y + _dragOffset.y); return; }
    if (g.state != UIGestureRecognizerStateEnded && g.state != UIGestureRecognizerStateCancelled) return;
    [_edgeTimer invalidate]; _edgeTimer = nil;
    _dragging = nil; icon.transform = CGAffineTransformIdentity;
    [icon removeFromSuperview];
    [self dropItemAt:p];
}
/* holding a dragged icon at the left/right edge turns the page; past the last page a new empty page appears */
- (void)edgeCheck {
    CGFloat W = self.view.bounds.size.width, x = _dragPoint.x;
    int dir = x < 26 ? -1 : x > W - 26 ? 1 : 0;
    if (!dir) { _edgeSince = 0; return; }
    double now = isim_time();
    if (!_edgeSince) { _edgeSince = now; return; }
    if (now - _edgeSince < 0.6 || now - _lastFlip < 0.9) return;
    NSInteger target = _pager.currentPage + dir;
    if (target < 0) return;
    if (target >= (NSInteger)_pageViews.count) {                       /* a new page after the last one */
        [_homePages addObject:[@{ @"items": [NSMutableArray array], @"hidden": @NO } mutableCopy]];
        NSUInteger m = _homePages.count - 1;
        _place[@(m)] = @[];
        [_visible addObject:@(m)];
        UIView *pv = [self makePageView:m];
        [_pageViews addObject:pv];
        _pager.pages = [_pageViews arrayByAddingObject:_library];
        _dots.numberOfPages = (NSInteger)_pageViews.count;
        NSLog(@"SpringBoard: new page %lu", (unsigned long)_pageViews.count);
    }
    _lastFlip = now; _edgeSince = now;
    NSLog(@"SpringBoard: dragging to page %ld", (long)target + 1);
    [_pager setCurrentPage:target animated:YES];
}
- (void)dropItemAt:(CGPoint)p {
    NSInteger visible = MIN(_pager.currentPage, (NSInteger)_pageViews.count - 1);
    NSUInteger to = (NSUInteger)[_visible[(NSUInteger)visible] integerValue], from = (NSUInteger)_dragPage;
    NSMutableArray *src = _homePages[from][@"items"], *dst = _homePages[to][@"items"];
    if (_dragIndex >= (NSInteger)src.count) { [self rebuild]; return; }
    id moving = src[(NSUInteger)_dragIndex];
    UIView *page = _pageViews[(NSUInteger)visible];
    CGPoint q = [self.view convertPoint:p toView:page];
    /* dropped on another icon: a folder (or into the folder) */
    for (UIView *other in page.subviews) {
        if (![other respondsToSelector:@selector(iconView)] || [moving isKindOfClass:[NSDictionary class]]) continue;
        if ((NSUInteger)(other.tag / 1000) == from && other.tag % 1000 == _dragIndex) continue;
        UIView *iv = [(id)other iconView];
        CGPoint oc = [iv convertPoint:CGPointMake(iv.bounds.size.width / 2, iv.bounds.size.height / 2) toView:page];
        if (hypot(oc.x - q.x, oc.y - q.y) > 24) continue;
        id target = dst[(NSUInteger)(other.tag % 1000)];
        if ([target isKindOfClass:[NSString class]]) {
            HSApp *ta = [self appForID:target], *ma = [self appForID:moving];
            NSString *name = HSCategoryName(ta.category) ?: HSCategoryName(ma.category) ?: NSLocalizedString(@"Folder", nil);
            dst[(NSUInteger)(other.tag % 1000)] = [@{ @"folder": name, @"apps": [@[target, moving] mutableCopy] } mutableCopy];
            NSLog(@"SpringBoard: folder “%@” with %@, %@", name, ta.name, ma.name);
        } else if (target[@"apps"]) {
            [target[@"apps"] addObject:moving];
            NSLog(@"SpringBoard: %@ added to folder “%@”", [self appForID:moving].name, target[@"folder"]);
        } else continue;
        [src removeObjectAtIndex:(NSUInteger)_dragIndex];
        [self saveLayout]; [self rebuild];
        return;
    }
    /* otherwise: the slot under the finger — insert before the first item placed at or after that cell */
    CGRect b = self.view.bounds; BOOL pad = b.size.width >= 700;
    NSInteger cols = [self columns]; CGFloat margin = pad ? 60 : 28, rowH = pad ? 120 : 102, top = self.view.safeAreaInsets.top + (pad ? 40 : 14);
    CGFloat colW = (b.size.width - 2 * margin) / cols;
    NSInteger col = MIN(cols - 1, MAX(0, (NSInteger)((q.x - margin) / colW))), row = MIN([self rows] - 1, MAX(0, (NSInteger)((q.y - top) / rowH)));
    NSInteger cell = row * cols + col;
    [src removeObjectAtIndex:(NSUInteger)_dragIndex];
    NSArray *pls = [self placementsFor:dst overflow:NULL] ?: @[];
    NSUInteger at = dst.count;
    for (NSUInteger i = 0; i < pls.count && i < dst.count; i++) if ([pls[i][1] integerValue] * cols + [pls[i][0] integerValue] >= cell) { at = i; break; }
    [dst insertObject:moving atIndex:at];
    NSString *name = [moving isKindOfClass:[NSString class]] ? [self appForID:moving].name : moving[@"folder"] ?: moving[@"widget"];
    NSLog(@"SpringBoard: moved %@ to page %ld position %lu", name, (long)visible + 1, (unsigned long)at);
    [self normalizePage:to];
    [self saveLayout]; [self rebuild];
}
/* the first visible page's items (widgets are added there, SBWidgets.m) */
- (NSMutableArray *)_layoutItems {
    NSInteger cur = MIN(_pager.currentPage, (NSInteger)_visible.count - 1);
    return _homePages[(NSUInteger)[_visible[(NSUInteger)MAX(0, cur)] integerValue]][@"items"];
}
- (BOOL)_isEditing { return _editing; }
- (UIButton *)_doneButton { return _done; }
- (void)_layoutChanged {
    NSInteger cur = MIN(_pager.currentPage, (NSInteger)_visible.count - 1);
    [self normalizePage:(NSUInteger)[_visible[(NSUInteger)MAX(0, cur)] integerValue]];
    [self saveLayout]; [self rebuild];
}
/* leaving edit mode: empty pages go away, like iOS */
- (void)removeEmptyPages {
    NSUInteger before = _homePages.count;
    [_homePages filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *p, NSDictionary *b) { return [p[@"items"] count] > 0; }]];
    if (!_homePages.count) [_homePages addObject:[@{ @"items": [NSMutableArray array], @"hidden": @NO } mutableCopy]];
    BOOL anyVisible = NO; for (NSDictionary *p in _homePages) if (![p[@"hidden"] boolValue]) anyVisible = YES;
    if (!anyVisible) _homePages[0][@"hidden"] = @NO;
    if (_homePages.count != before) NSLog(@"SpringBoard: removed %lu empty page(s)", (unsigned long)(before - _homePages.count));
    [self saveLayout];
}

/* ---- long press: context menu (iOS 17/18), edit mode, delete ---- */
- (void)held:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || _editing) return;
    [self showMenuFor:(HSIcon *)g.view];
}
- (void)showMenuFor:(HSIcon *)icon {
    [_menu removeFromSuperview];
    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    overlay.accessibilityIdentifier = @"home-menu";
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissMenu)];
    [overlay addGestureRecognizer:tap];
    _menu = overlay;
    /* the lifted icon */
    CGRect r = [icon.iconView convertRect:icon.iconView.bounds toView:self.view];
    UIImageView *lifted = [[UIImageView alloc] initWithFrame:CGRectInset(r, -3, -3)];
    lifted.image = icon.iconView.image; lifted.backgroundColor = icon.iconView.backgroundColor;
    lifted.layer.cornerRadius = icon.iconView.layer.cornerRadius * 1.1; lifted.clipsToBounds = YES;
    for (UIView *sv in icon.iconView.subviews) if ([sv isKindOfClass:[UILabel class]]) {
        UILabel *l = [UILabel new]; l.text = ((UILabel *)sv).text; l.font = ((UILabel *)sv).font; l.textColor = UIColor.whiteColor;
        l.textAlignment = NSTextAlignmentCenter; l.frame = lifted.bounds; [lifted addSubview:l];
    }
    [overlay addSubview:lifted];
    /* the menu */
    /* quick actions (UIApplicationShortcutItem) first, then the system items */
    NSArray *quick = HSQuickActions(icon.app);
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *q in quick) [items addObject:@[q[@"title"], q[@"symbol"] ?: @"", [@"shortcut:" stringByAppendingString:q[@"type"]], q[@"subtitle"] ?: @""]];
    [items addObject:@[NSLocalizedString(@"Edit Home Screen", nil), @"square.grid.2x2", @"edit"]];
    if (!icon.app.system) [items addObject:@[NSLocalizedString(@"Remove App", nil), @"minus.circle", @"remove"]];
    CGFloat W = 250, rowH = 44, gap = quick.count ? 8 : 0, H = rowH * items.count + gap;
    NSLog(@"SpringBoard: %lu quick action(s) for %@", (unsigned long)quick.count, icon.app.name);
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.2 alpha:0.96] : [UIColor colorWithWhite:0.97 alpha:0.96]; }];
    card.layer.cornerRadius = 13; card.clipsToBounds = YES;
    CGFloat x = MIN(MAX(12, r.origin.x), self.view.bounds.size.width - W - 12);
    BOOL below = CGRectGetMaxY(r) + 12 + H < self.view.bounds.size.height - 40;
    card.frame = CGRectMake(x, below ? CGRectGetMaxY(r) + 12 : r.origin.y - 12 - H, W, H);
    CGFloat y = 0;
    for (NSUInteger i = 0; i < items.count; i++) {
        NSArray *it = items[i];
        BOOL shortcut = [it[2] hasPrefix:@"shortcut:"];
        if (i == quick.count && quick.count) {           /* a thick separator between the app's actions and the system's */
            UIView *g = [[UIView alloc] initWithFrame:CGRectMake(0, y, W, gap)];
            g.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.08 alpha:0.6] : [UIColor colorWithWhite:0.82 alpha:0.6]; }];
            [card addSubview:g]; y += gap;
        }
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(0, y, W, rowH);
        BOOL destructive = [it[2] isEqual:@"remove"];
        UIColor *c = destructive ? UIColor.systemRedColor : UIColor.labelColor;
        NSString *sub = it.count > 3 ? it[3] : @"";
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, sub.length ? 3 : 0, W - 60, sub.length ? 22 : rowH)]; l.text = it[0]; l.textColor = c; l.font = [UIFont systemFontOfSize:sub.length ? 16 : 17]; l.userInteractionEnabled = NO;
        [b addSubview:l];
        if (sub.length) {
            UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(16, 23, W - 60, 17)]; sl.text = sub; sl.textColor = UIColor.secondaryLabelColor; sl.font = [UIFont systemFontOfSize:13]; sl.userInteractionEnabled = NO;
            [b addSubview:sl];
        }
        UIImage *img = [it[1] length] ? [UIImage systemImageNamed:it[1] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]] : nil;
        if (img) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            iv.tintColor = c; iv.frame = CGRectMake(W - 38, (rowH - 22) / 2, 22, 22); iv.contentMode = UIViewContentModeCenter; iv.userInteractionEnabled = NO;
            [b addSubview:iv];
        }
        b.accessibilityIdentifier = [@"menu-" stringByAppendingString:it[2]];
        b.accessibilityLabel = it[0];
        b.tag = (NSInteger)i;
        objc_setAssociatedObject(b, "hsapp", icon.app, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(b, "hsaction", it[2], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [b addTarget:self action:destructive ? @selector(menuRemove:) : shortcut ? @selector(menuShortcut:) : @selector(menuEdit:) forControlEvents:UIControlEventTouchUpInside];
        if (i > 0 && i != quick.count) { UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, y, W, 0.5)]; h.backgroundColor = UIColor.separatorColor; [card addSubview:h]; }
        [card addSubview:b];
        y += rowH;
    }
    [overlay addSubview:card];
    [self.view addSubview:overlay];
    NSLog(@"SpringBoard: menu for %@", icon.app.name);
}
- (void)dismissMenu { [_menu removeFromSuperview]; _menu = nil; }
- (void)menuEdit:(UIButton *)b { [self dismissMenu]; [self setEditingMode:YES]; }
- (void)menuShortcut:(UIButton *)b {
    HSApp *a = objc_getAssociatedObject(b, "hsapp"); NSString *action = objc_getAssociatedObject(b, "hsaction");
    [self dismissMenu];
    NSString *type = [action substringFromIndex:9];
    NSLog(@"SpringBoard: quick action %@ for %@", type, a.name);
    [self launch:a url:[@"isim-shortcut:" stringByAppendingString:type]];
}
- (void)menuRemove:(UIButton *)b { HSApp *a = objc_getAssociatedObject(b, "hsapp"); [self dismissMenu]; [self confirmDelete:a]; }
- (void)badgeTapped:(UIButton *)badge { [self confirmDelete:((HSIcon *)badge.superview).app]; }
- (void)setEditingMode:(BOOL)e {
    _editing = e;
    if (e && !_done) {
        _done = [UIButton buttonWithType:UIButtonTypeSystem];
        [_done setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
        _done.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [_done setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        _done.backgroundColor = [UIColor colorWithWhite:1 alpha:0.75]; _done.layer.cornerRadius = 15;
        _done.accessibilityIdentifier = @"home-done";
        [_done addTarget:self action:@selector(doneEditing) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_done];
    }
    _done.hidden = !e;
    if (e && !_addWidget) {                                  /* + : the widget gallery */
        _addWidget = [UIButton buttonWithType:UIButtonTypeSystem];
        [_addWidget setTitle:@"+" forState:UIControlStateNormal];
        _addWidget.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
        [_addWidget setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        _addWidget.backgroundColor = [UIColor colorWithWhite:1 alpha:0.75]; _addWidget.layer.cornerRadius = 15;
        _addWidget.accessibilityIdentifier = @"home-add-widget";
        [_addWidget addTarget:self action:@selector(showWidgetGallery) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_addWidget];
    }
    _addWidget.hidden = !e;
    NSLog(@"SpringBoard: %@ edit mode", e ? @"entered" : @"left");
    if (!e) [self removeEmptyPages];
    [self rebuild];
}
- (void)doneEditing { [self setEditingMode:NO]; }
- (void)confirmDelete:(HSApp *)a {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Delete “%@”?", nil), a.name]
                                                                   message:NSLocalizedString(@"Deleting this app will also delete its data.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) { [self deleteApp:a]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)deleteApp:(HSApp *)a {
    NSLog(@"SpringBoard: deleting %@ (%@)", a.name, a.bundleID);
    isim_shell_request(ISIM_SHELL_TERMINATE_APP, a.path.UTF8String, NULL, NULL);
    extern NSString *isim_data_dir(void);
    NSFileManager *fm = NSFileManager.defaultManager;
    /* keyboards it provided are no longer available */
    NSUserDefaults *global = [[NSUserDefaults alloc] initWithSuiteName:@".GlobalPreferences"];
    NSArray *kbs = [global objectForKey:@"AppleKeyboards"];
    NSMutableArray *keep = [NSMutableArray array];
    for (NSString *k in kbs) if (![k hasPrefix:[a.bundleID stringByAppendingString:@"."]]) [keep addObject:k];
    if (kbs && keep.count != kbs.count) [global setObject:keep forKey:@"AppleKeyboards"];
    [fm removeItemAtPath:a.path error:NULL];
    [fm removeItemAtPath:[[isim_data_dir() stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:a.bundleID] error:NULL];
    [self reload];
    if (_editing) [self setEditingMode:YES];
}
- (void)launchByID:(NSNotification *)n {
    NSString *ident = n.object;
    HSApp *a = [self appWithIdentifier:ident];
    if (a) [self launch:a]; else NSLog(@"SpringBoard: no installed app '%@'", ident);
}
@end



@interface HSDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation HSDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [HomeViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([HSDelegate class])); }
}
