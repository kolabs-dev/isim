// isim home screen ("SpringBoard"): installed apps as icons; tapping one asks the isim shell to
// launch (or resume) it. Runs as an isim system app under `isim boot`.
// The look follows the emulated iOS version (isim --os):
//   iOS 17     translucent dock, light icons.
//   iOS 18+    icon appearance (Home Screen > Customize): ISIM_ICON_STYLE=light|dark|tinted (and, iOS 26+, clear),
//              ISIM_ICON_TINT=#RRGGBB for tinted. An app's own dark/tinted icon variants are used when it has them;
//              otherwise isim derives them (adapted: darkened / luminance-tinted / see-through copies of the icon).
//   iOS 26+    Liquid Glass: a glass dock with larger corners, a specular glass rim on every icon.
#import <UIKit/UIKit.h>
#include <isim_host.h>
#import <objc/runtime.h>

NSString *isim_ui_system_apps_dir(void);
NSString *isim_ui_installed_apps_dir(void);

@interface HSApp : NSObject
@property (nonatomic, copy) NSString *path, *executable, *name, *bundleID, *iconPath;
@property (nonatomic) BOOL system;
@end
@implementation HSApp @end

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
static NSString *icon_variant(NSString *app, NSDictionary *info, NSString *appearance);
/* the best icon file in an app: asset-catalog app icon (largest), else icon.png */
static NSString *icon_path(NSString *app, NSDictionary *info) {
    NSString *styled = icon_style() == 1 ? icon_variant(app, info, @"dark") : icon_style() == 2 ? icon_variant(app, info, @"tinted") : nil;
    if (styled) return styled;
    NSDictionary *assets = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"isim-assets.plist"]];
    NSDictionary *icons = assets[@"appIcons"];
    NSString *name = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"] ?: @"AppIcon";
    NSArray *files = icons[name] ?: icons.allValues.firstObject;
    NSString *best = nil; double bestScore = -1;
    for (NSDictionary *f in files) {
        if ([f[@"appearance"] isEqualToString:@"dark"] || [f[@"appearance"] isEqualToString:@"tinted"]) continue;
        NSString *size = f[@"size"] ?: @"1024x1024";
        double px = [[size componentsSeparatedByString:@"x"].firstObject doubleValue] * ([f[@"scale"] doubleValue] ?: 1);
        if (px > bestScore) { bestScore = px; best = f[@"file"]; }
    }
    if (best) return [app stringByAppendingPathComponent:best];
    NSString *plain = [app stringByAppendingPathComponent:@"icon.png"];
    return [NSFileManager.defaultManager fileExistsAtPath:plain] ? plain : nil;
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
        a.iconPath = icon_path(path, info);
        [out addObject:a];
    }
    [out sortUsingComparator:^NSComparisonResult(HSApp *x, HSApp *y) { return [x.name localizedCaseInsensitiveCompare:y.name]; }];
    return out;
}

/* icon + label, tappable */
@interface HSIcon : UIControl
@property (nonatomic, strong) HSApp *app;
@property (nonatomic) BOOL showLabel;
@property (nonatomic) BOOL editing;
@property (nonatomic, readonly) UIButton *badge;
- (UIImageView *)iconView;
@end
@implementation HSIcon { UIImageView *_image; UILabel *_label, *_letter; }
@synthesize badge = _badge;
- (void)setEditing:(BOOL)e { _editing = e; _badge.hidden = !e || _app.system; [self bringSubviewToFront:_badge]; }
- (instancetype)initWithApp:(HSApp *)app size:(CGFloat)s label:(BOOL)label {
    if ((self = [super initWithFrame:CGRectZero])) {
        _app = app; _showLabel = label;
        _image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, s, s)];
        _image.layer.cornerRadius = s * 0.225; _image.clipsToBounds = YES;
        _image.contentMode = UIViewContentModeScaleToFill;
        _image.userInteractionEnabled = NO;
        UIImage *img = app.iconPath ? [UIImage imageWithContentsOfFile:app.iconPath] : nil;
        BOOL ownVariant = [app.iconPath containsString:@"dark"] || [app.iconPath containsString:@"tinted"];
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
    }
    return self;
}
- (UIImageView *)iconView { return _image; }
- (void)layoutSubviews {
    CGFloat s = _image.bounds.size.width, w = self.bounds.size.width;
    _image.frame = CGRectMake((w - s) / 2, 0, s, s);
    _badge.frame = CGRectMake((w - s) / 2 - 8, -8, 22, 22);
    _label.frame = CGRectMake(-10, s + 5, w + 20, 16);
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; _image.alpha = h ? 0.6 : 1; }
@end

@interface HomeViewController : UIViewController
@end
@implementation HomeViewController { NSArray<HSApp *> *_apps; UIView *_grid, *_dock; UIImageView *_wallpaper; UIView *_menu; BOOL _editing; UIButton *_done; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _wallpaper = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _wallpaper.image = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"wallpaper.png"]];
    _wallpaper.contentMode = UIViewContentModeScaleAspectFill;
    _wallpaper.backgroundColor = [UIColor colorWithRed:0.16 green:0.2 blue:0.42 alpha:1];
    [self.view addSubview:_wallpaper];
    _grid = [UIView new]; [self.view addSubview:_grid];
    _dock = [HSDock new];
    BOOL glass = os_major() >= 26;
    _dock.backgroundColor = glass ? nil : [UIColor colorWithWhite:1 alpha:0.28];
    _dock.layer.cornerRadius = glass ? 38 : 32;
    _dock.accessibilityIdentifier = @"home-dock";
    NSLog(@"SpringBoard: iOS %d look%s", os_major(), glass ? " (Liquid Glass)" : "");
    [self.view addSubview:_dock];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:UIApplicationWillEnterForegroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(launchByID:) name:@"_IsimShellLaunch" object:nil];
    [self reload];
}
- (void)reload {
    NSMutableArray *apps = [NSMutableArray array];
    [apps addObjectsFromArray:scan(isim_ui_system_apps_dir(), YES)];
    [apps addObjectsFromArray:scan(isim_ui_installed_apps_dir(), NO)];
    _apps = apps;
    NSMutableArray *names = [NSMutableArray array]; for (HSApp *a in apps) [names addObject:a.name];
    NSLog(@"SpringBoard: %lu app(s): %@", (unsigned long)apps.count, [names componentsJoinedByString:@", "]);
    [self.view setNeedsLayout];
    [self rebuild];
}
- (void)rebuild {
    for (UIView *v in _grid.subviews) [v removeFromSuperview];
    for (UIView *v in _dock.subviews) [v removeFromSuperview];
    BOOL pad = UIScreen.mainScreen.bounds.size.width >= 700;
    CGFloat s = pad ? 74 : 60;
    for (HSApp *a in _apps) {
        BOOL inDock = a.system;                   /* system apps (Settings) live in the dock */
        HSIcon *icon = [[HSIcon alloc] initWithApp:a size:s label:!inDock];
        [icon addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [icon addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(held:)]];
        [icon.badge addTarget:self action:@selector(badgeTapped:) forControlEvents:UIControlEventTouchUpInside];
        icon.editing = _editing;
        [inDock ? _dock : _grid addSubview:icon];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds; UIEdgeInsets safe = self.view.safeAreaInsets;
    BOOL pad = b.size.width >= 700;
    NSInteger cols = pad ? 6 : 4;
    CGFloat s = pad ? 74 : 60, margin = pad ? 60 : 28, rowH = pad ? 120 : 102;
    CGFloat colW = (b.size.width - 2 * margin) / cols;
    _grid.frame = CGRectMake(margin, safe.top + (pad ? 40 : 14), b.size.width - 2 * margin, b.size.height);
    NSInteger i = 0;
    for (HSIcon *icon in _grid.subviews) {
        icon.frame = CGRectMake((i % cols) * colW + (colW - s) / 2, (i / cols) * rowH, s, s + 22);
        i++;
    }
    CGFloat dockH = pad ? 100 : 92, dockInset = pad ? (b.size.width - 420) / 2 : 12;
    _dock.frame = CGRectMake(dockInset, b.size.height - MAX(safe.bottom, 12) - dockH + (safe.bottom > 0 ? 18 : 0) - 4, b.size.width - 2 * dockInset, dockH);
    NSInteger n = _dock.subviews.count; CGFloat dColW = _dock.bounds.size.width / MAX(4, n);
    CGFloat start = (_dock.bounds.size.width - dColW * n) / 2;
    i = 0;
    for (HSIcon *icon in _dock.subviews) { icon.frame = CGRectMake(start + i * dColW + (dColW - s) / 2, (dockH - s) / 2, s, s); i++; }
    _done.frame = CGRectMake(b.size.width - 82, safe.top + 2, 66, 30);
    /* tell the shell where each app's icon is (app open/close animations zoom from/to it) */
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *container in @[self->_grid, self->_dock]) for (HSIcon *icon in container.subviews) {
            if (![icon isKindOfClass:[HSIcon class]] || !icon.app.path) continue;
            CGRect r = [icon convertRect:icon.iconView.frame toView:self.view];
            char geo[128];
            snprintf(geo, sizeof geo, "%g %g %g %g %g", r.origin.x, r.origin.y, r.size.width, r.size.height, icon.iconView.layer.cornerRadius);
            isim_shell_request(ISIM_SHELL_ICON, icon.app.path.UTF8String, geo, NULL);
        }
    });
}
- (void)launch:(HSApp *)a {
    NSLog(@"SpringBoard: launching %@ (%@)", a.name, a.bundleID);
    isim_shell_request(ISIM_SHELL_LAUNCH, a.path.UTF8String, a.executable.UTF8String, NULL);
}
- (void)tapped:(HSIcon *)icon { if (!_editing) [self launch:icon.app]; }

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
    NSMutableArray *items = [NSMutableArray arrayWithObject:@[NSLocalizedString(@"Edit Home Screen", nil), @"square.grid.2x2", @"edit"]];
    if (!icon.app.system) [items addObject:@[NSLocalizedString(@"Remove App", nil), @"minus.circle", @"remove"]];
    CGFloat W = 250, rowH = 44, H = rowH * items.count;
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.2 alpha:0.96] : [UIColor colorWithWhite:0.97 alpha:0.96]; }];
    card.layer.cornerRadius = 13; card.clipsToBounds = YES;
    CGFloat x = MIN(MAX(12, r.origin.x), self.view.bounds.size.width - W - 12);
    BOOL below = CGRectGetMaxY(r) + 12 + H < self.view.bounds.size.height - 40;
    card.frame = CGRectMake(x, below ? CGRectGetMaxY(r) + 12 : r.origin.y - 12 - H, W, H);
    for (NSUInteger i = 0; i < items.count; i++) {
        NSArray *it = items[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(0, i * rowH, W, rowH);
        BOOL destructive = [it[2] isEqual:@"remove"];
        UIColor *c = destructive ? UIColor.systemRedColor : UIColor.labelColor;
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, W - 60, rowH)]; l.text = it[0]; l.textColor = c; l.font = [UIFont systemFontOfSize:17]; l.userInteractionEnabled = NO;
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:it[1] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]]];
        iv.tintColor = c; iv.frame = CGRectMake(W - 38, (rowH - 22) / 2, 22, 22); iv.contentMode = UIViewContentModeCenter; iv.userInteractionEnabled = NO;
        [b addSubview:l]; [b addSubview:iv];
        b.accessibilityIdentifier = [@"menu-" stringByAppendingString:it[2]];
        b.tag = (NSInteger)i;
        objc_setAssociatedObject(b, "hsapp", icon.app, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [b addTarget:self action:destructive ? @selector(menuRemove:) : @selector(menuEdit:) forControlEvents:UIControlEventTouchUpInside];
        if (i > 0) { UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, i * rowH, W, 0.5)]; h.backgroundColor = UIColor.separatorColor; [card addSubview:h]; }
        [card addSubview:b];
    }
    [overlay addSubview:card];
    [self.view addSubview:overlay];
    NSLog(@"SpringBoard: menu for %@", icon.app.name);
}
- (void)dismissMenu { [_menu removeFromSuperview]; _menu = nil; }
- (void)menuEdit:(UIButton *)b { [self dismissMenu]; [self setEditingMode:YES]; }
- (void)menuRemove:(UIButton *)b { HSApp *a = objc_getAssociatedObject(b, "hsapp"); [self dismissMenu]; [self confirmDelete:a]; }
- (void)badgeTapped:(UIButton *)badge { [self confirmDelete:((HSIcon *)badge.superview).app]; }
- (void)setEditingMode:(BOOL)e {
    _editing = e;
    for (HSIcon *i in _grid.subviews) i.editing = e;
    for (HSIcon *i in _dock.subviews) i.editing = e;
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
    [self.view setNeedsLayout];
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
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) { [self launch:a]; return; }
    [self reload];
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) { [self launch:a]; return; }
    NSLog(@"SpringBoard: no installed app '%@'", ident);
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
