// isim home screen ("SpringBoard"): installed apps as icons; tapping one asks the isim shell to
// launch (or resume) it. Runs as an isim system app under `isim boot`.
#import "SpringBoard.h"
#import <objc/runtime.h>

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
        a.category = info[@"LSApplicationCategoryType"];
        a.iconPath = HSIconPath(path, info, a.bundleID);
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
    _dock = [UIView new];
    _dock.backgroundColor = [UIColor colorWithWhite:1 alpha:0.28];
    _dock.layer.cornerRadius = 32;
    [self.view addSubview:_dock];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:UIApplicationWillEnterForegroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(launchByID:) name:@"_IsimShellLaunch" object:nil];
    [self installSystemObservers];
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
    [self publishAppInfo];
}
- (NSArray<HSApp *> *)apps { return _apps; }
- (HSApp *)appWithIdentifier:(NSString *)ident {
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) return a;
    [self reload];
    for (HSApp *a in _apps) if ([a.bundleID isEqualToString:ident] || [a.name isEqualToString:ident]) return a;
    return nil;
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
- (void)launch:(HSApp *)a { [self launch:a url:nil]; }
- (void)launch:(HSApp *)a url:(NSString *)url {
    NSLog(@"SpringBoard: launching %@ (%@)%@%@", a.name, a.bundleID, url ? @" with " : @"", url ?: @"");
    isim_shell_request(ISIM_SHELL_LAUNCH, a.path.UTF8String, a.executable.UTF8String, url.UTF8String);
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
