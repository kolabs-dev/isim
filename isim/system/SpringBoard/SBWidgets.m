// isim home screen: widgets (WidgetKit). Live Activities: SBLiveActivities.m; Lock Screen widgets, StandBy: SBLockScreen.m.
// Widget extensions (<App>.app/PlugIns/*.appex with NSExtensionPointIdentifier com.apple.widgetkit-extension) run as
// helper processes started by the shell ("widget-run EXE REQUEST"); a request plist says what to do
// (list | render | tap | placeholder | snapshot | params | activity) and where to write the PNGs/plists
// (<isim data>/Library/SpringBoard/Widgets/<bundle id>).
// The home screen shows the timeline entry for the current date and asks for a new timeline when the policy says so,
// on WidgetCenter.reloadTimelines(ofKind:), or after a tap on an interactive widget ran an App Intent. A new widget
// shows its placeholder (placeholder(in:), redacted) until the first timeline arrives; the gallery shows snapshots
// (isPreview). A long press on a widget opens its menu: Edit Widget (the configuration intent's parameters, for
// AppIntentConfiguration widgets; the timeline reloads with the chosen values), Edit Home Screen, Remove Widget.
// A tap outside the widget's buttons opens the app with its widgetURL (a Link: with the Link's URL).
#import "SpringBoard.h"
#import <objc/message.h>

static int os_major(void) { return isim_os_version() / 10000; }

static NSString *const kWidgetPoint = @"com.apple.widgetkit-extension";
NSString *HSWidgetsDir(NSString *bundle) {
    NSString *d = [[isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard/Widgets"] stringByAppendingPathComponent:bundle];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
static NSString *widgets_dir(NSString *bundle) { return HSWidgetsDir(bundle); }
/* the app's widget extension: { path, exe } */
NSDictionary *HSWidgetExtension(HSApp *a) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        if (![info[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:kWidgetPoint]) continue;
        return @{ @"path": p, @"exe": [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension] };
    }
    return nil;
}
static NSDictionary *widget_extension(HSApp *a) { return HSWidgetExtension(a); }
static NSUInteger req_seq;
void HSRunWidgetExtension(NSDictionary *ext, NSString *bundle, NSDictionary *request) {
    NSString *dir = widgets_dir(bundle);
    NSString *req = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"request-%lu-%u.plist", (unsigned long)++req_seq, arc4random() % 100000]];
    NSMutableDictionary *r = [request mutableCopy]; if (!r[@"out"]) r[@"out"] = dir;
    r[@"bundle"] = bundle;
    [r writeToFile:req atomically:YES];
    isim_shell_request(ISIM_SHELL_SYSTEM, "widget-run", [ext[@"exe"] UTF8String], req.UTF8String);
}
static void run_extension(NSDictionary *ext, NSString *bundle, NSDictionary *request) { HSRunWidgetExtension(ext, bundle, request); }
CGSize HSWidgetFamilySize(NSString *f) {
    NSDictionary *sizes = @{ @"systemSmall": @[@170, @170], @"systemMedium": @[@364, @170], @"systemLarge": @[@364, @382],
                             @"accessoryCircular": @[@72, @72], @"accessoryRectangular": @[@160, @72], @"accessoryInline": @[@234, @26] };
    CGSize screen = UIScreen.mainScreen.bounds.size;                 /* the 6.7" class: Apple's larger accessory sizes */
    if (MIN(screen.width, screen.height) >= 428 && [f hasPrefix:@"accessory"])
        sizes = @{ @"accessoryCircular": @[@76, @76], @"accessoryRectangular": @[@172, @76], @"accessoryInline": @[@257, @26] };
    NSArray *s = sizes[f] ?: @[@170, @170];
    return CGSizeMake([s[0] doubleValue], [s[1] doubleValue]);
}
/* the tinted Home Screen (iOS 18+, Edit > Customize > Tinted): widgets render accented in the tint, on a dark tinted
   background instead of their own */
static BOOL tinted(void) { return os_major() >= 18 && HSIconStyle() == 2; }
static void add_look(NSMutableDictionary *r) {
    if (!tinted()) return;
    r[@"renderingMode"] = @"accented"; r[@"background"] = @NO; r[@"tint"] = HSIconTintHex();
}
static NSString *family_title(NSString *f) {
    return [f isEqual:@"systemSmall"] ? @"Small" : [f isEqual:@"systemMedium"] ? @"Medium" : [f isEqual:@"systemLarge"] ? @"Large" : nil;
}

/* ---- a widget on the home screen ---- */
@interface HSWidgetView : UIControl
@property (nonatomic, strong) NSMutableDictionary *item;
@property (nonatomic, strong) NSArray *entries;          /* { date, file, url } */
@property (nonatomic, strong) NSDate *reloadAt;
@property (nonatomic, weak) HomeViewController *home;
@property (nonatomic, copy) NSString *shownFile, *placeholderFile;
@property (nonatomic) BOOL tinted;                       /* rendered accented */
- (UIView *)iconView;
@end
@implementation HSWidgetView { UIImageView *_image; UILabel *_label; }
- (instancetype)initWithItem:(NSMutableDictionary *)item home:(HomeViewController *)home appName:(NSString *)name {
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item; _home = home;
        _image = [UIImageView new]; _image.layer.cornerRadius = 22; _image.clipsToBounds = YES; _image.userInteractionEnabled = NO;
        _image.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3]; _image.contentMode = UIViewContentModeScaleToFill;
        [self addSubview:_image];
        _label = [UILabel new]; _label.text = name; _label.textColor = UIColor.whiteColor; _label.font = [UIFont systemFontOfSize:12];
        _label.textAlignment = NSTextAlignmentCenter; _label.userInteractionEnabled = NO;
        [self addSubview:_label];
        self.accessibilityIdentifier = [NSString stringWithFormat:@"widget-%@-%@", item[@"widget"], item[@"family"]];
    }
    return self;
}
- (UIView *)iconView { return _image; }
- (UIImage *)currentImage { return _image.image; }
- (void)layoutSubviews { CGSize b = self.bounds.size; _image.frame = CGRectMake(0, 0, b.width, b.height - 22); _label.frame = CGRectMake(0, b.height - 17, b.width, 16); }
- (NSString *)_isim_dumpText { return self.shownFile.lastPathComponent; }
- (void)showCurrent {
    NSDictionary *cur = nil; NSDate *now = [NSDate date];
    for (NSDictionary *e in self.entries) if ([e[@"date"] compare:now] != NSOrderedDescending) cur = e;
    if (!cur) cur = self.entries.firstObject;
    NSString *file = cur[@"file"];
    if (!cur && self.placeholderFile) file = self.placeholderFile;            /* the first timeline is loading */
    if (!file || [file isEqual:self.shownFile]) return;
    self.shownFile = file;
    _image.image = [UIImage imageWithContentsOfFile:file];
    UIColor *t = nil;
    if (self.tinted) { unsigned v = 0; [[NSScanner scannerWithString:[HSIconTintHex() substringFromIndex:1]] scanHexInt:&v];
        t = [UIColor colorWithRed:((v >> 16) & 255) / 255.0 * 0.22 green:((v >> 8) & 255) / 255.0 * 0.22 blue:(v & 255) / 255.0 * 0.22 alpha:0.92]; }
    _image.backgroundColor = t ?: [UIColor colorWithWhite:1 alpha:0.3];
    if (file == self.placeholderFile) NSLog(@"SpringBoard: widget %@ shows its placeholder", self.item[@"widget"]);
    else NSLog(@"SpringBoard: widget %@ shows %@", self.item[@"widget"], [file lastPathComponent]);
}
@end

static NSString *widget_key(NSDictionary *it) { return [NSString stringWithFormat:@"%@|%@|%@", it[@"app"], it[@"widget"], it[@"family"]]; }
static NSMutableDictionary *rendered_tint(void) { static NSMutableDictionary *d; if (!d) d = [NSMutableDictionary dictionary]; return d; }   /* last render: accented? */
static NSMutableArray<HSWidgetView *> *widget_views(void) { static NSMutableArray *a; if (!a) a = [NSMutableArray array]; return a; }
static UIView *widget_menu, *widget_config;                     /* the widget's menu; the Edit Widget sheet */
static NSMutableDictionary *config_edit;                        /* { item, view, params, values } while editing */

@implementation HomeViewController (Widgets)
- (HSApp *)_appNamed:(NSString *)bundle { for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:bundle]) return a; return nil; }
- (UIControl *)makeWidgetView:(NSMutableDictionary *)item {
    HSApp *a = [self _appNamed:item[@"app"]];
    HSWidgetView *w = [[HSWidgetView alloc] initWithItem:item home:self appName:a.name ?: @""];
    [w addTarget:self action:@selector(widgetTapped:forEvent:) forControlEvents:UIControlEventTouchUpInside];
    if (![self _isEditing]) [w addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(widgetHeld:)]];
    /* keep the last timeline across rebuilds */
    HSWidgetView *previous = nil;
    for (HSWidgetView *old in widget_views()) if (!old.window && [old.item[@"widget"] isEqual:item[@"widget"]] && [old.item[@"family"] isEqual:item[@"family"]] && [old.item[@"app"] isEqual:item[@"app"]]) previous = old;
    if (previous) {                                     /* the same widget after a rebuild: keep its timeline (or the render in flight) */
        w.entries = previous.entries; w.reloadAt = previous.reloadAt; w.placeholderFile = previous.placeholderFile;
        w.tinted = [rendered_tint()[widget_key(item)] boolValue]; [w showCurrent];
        for (HSWidgetView *old in [widget_views() copy]) if (!old.window && [widget_key(old.item) isEqual:widget_key(item)]) [widget_views() removeObjectIdenticalTo:old];
        if (w.tinted != tinted()) { NSLog(@"SpringBoard: widget %@ renders %@", item[@"widget"], tinted() ? @"accented" : @"in full colour"); [self renderWidget:w tapAt:nil]; }
    }
    [widget_views() addObject:w];
    if (!previous) {                                    /* new: the placeholder while the first timeline loads */
        NSDictionary *ext = a ? widget_extension(a) : nil;
        NSMutableDictionary *pr = [@{ @"mode": @"placeholder", @"kind": item[@"widget"], @"family": item[@"family"] } mutableCopy];
        add_look(pr);
        if (ext) run_extension(ext, a.bundleID, pr);
        [self renderWidget:w tapAt:nil];
    }
    return w;
}
- (void)renderWidget:(HSWidgetView *)w tapAt:(NSValue *)point {
    HSApp *a = [self _appNamed:w.item[@"app"]];
    NSDictionary *ext = a ? widget_extension(a) : nil;
    if (!ext) { NSLog(@"SpringBoard: no widget extension in %@", w.item[@"app"]); return; }
    NSMutableDictionary *r = [@{ @"mode": point ? @"tap" : @"render", @"kind": w.item[@"widget"], @"family": w.item[@"family"] } mutableCopy];
    if (w.item[@"config"]) r[@"config"] = w.item[@"config"];
    add_look(r); w.tinted = tinted(); rendered_tint()[widget_key(w.item)] = @(w.tinted);
    if (point) { CGPoint p = point.CGPointValue; r[@"x"] = @(p.x); r[@"y"] = @(p.y); }
    run_extension(ext, a.bundleID, r);
}
- (void)widgetTapped:(HSWidgetView *)w forEvent:(UIEvent *)e {
    if ([self _isEditing]) return;
    UITouch *t = e.allTouches.anyObject;
    CGPoint p = t ? [t locationInView:w.iconView] : CGPointMake(w.iconView.bounds.size.width / 2, w.iconView.bounds.size.height / 2);
    /* widget coordinates: the extension renders at the family's size */
    CGSize sz = HSWidgetFamilySize(w.item[@"family"]), v = w.iconView.bounds.size;
    CGPoint q = CGPointMake(p.x * sz.width / MAX(1, v.width), p.y * sz.height / MAX(1, v.height));
    NSLog(@"SpringBoard: tap on widget %@ at %.0f,%.0f", w.item[@"widget"], q.x, q.y);
    [self renderWidget:w tapAt:[NSValue valueWithCGPoint:q]];
}
- (void)installWidgetObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if ([t hasPrefix:@"widget-done "]) [self widgetDone:[t substringFromIndex:12]];
        else if ([t hasPrefix:@"widget-reload "]) {
            NSString *kind = [t substringFromIndex:14];
            for (HSWidgetView *w in [widget_views() copy]) if (w.window && ([kind isEqual:@"*"] || [w.item[@"widget"] isEqual:kind])) {
                NSLog(@"SpringBoard: reloading widget %@", w.item[@"widget"]);
                [self renderWidget:w tapAt:nil];
            }
        } else if ([t hasPrefix:@"live-activity "]) [self liveActivity:[t substringFromIndex:14]];
    }];
    [self installLockScreenObservers];
    /* entries by date; reloads by policy */
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        for (HSWidgetView *w in [widget_views() copy]) {
            if (!w.window) continue;
            [w showCurrent];
            if (w.reloadAt && [w.reloadAt timeIntervalSinceNow] <= 0) { w.reloadAt = nil; NSLog(@"SpringBoard: timeline of %@ ended; reloading", w.item[@"widget"]); [self renderWidget:w tapAt:nil]; }
        }
    }];
}
- (void)widgetDone:(NSString *)args {
    NSRange sp = [args rangeOfString:@" "];
    NSString *reqPath = sp.location == NSNotFound ? args : [args substringFromIndex:sp.location + 1];
    NSDictionary *req = [NSDictionary dictionaryWithContentsOfFile:reqPath];
    [NSFileManager.defaultManager removeItemAtPath:reqPath error:NULL];
    NSString *mode = req[@"mode"], *out = req[@"out"];
    if ([mode isEqual:@"activity"]) { [self liveActivityRendered:req]; return; }
    if (req[@"location"]) { [self lockWidgetRendered:req]; return; }          /* the Lock Screen, StandBy */
    if ([mode isEqual:@"list"]) return;
    if ([mode isEqual:@"snapshot"]) { [self galleryPreviewsDone:req]; return; }
    if ([mode isEqual:@"params"]) { [self widgetParamsDone:req]; return; }
    NSString *base = [out stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", req[@"kind"], req[@"family"]]];
    if ([mode isEqual:@"placeholder"]) {
        NSString *file = [base stringByAppendingString:@"-placeholder.png"];
        if (![NSFileManager.defaultManager fileExistsAtPath:file]) return;
        for (HSWidgetView *w in [widget_views() copy])
            if ([w.item[@"widget"] isEqual:req[@"kind"]] && [w.item[@"family"] isEqual:req[@"family"]] && [w.item[@"app"] isEqual:req[@"bundle"]]) { w.placeholderFile = file; [w showCurrent]; }
        return;
    }
    if ([mode isEqual:@"tap"]) {                       /* no control ran: open the app (with the widget's URL or the Link's) */
        NSDictionary *tap = [NSDictionary dictionaryWithContentsOfFile:[base stringByAppendingString:@"-tap.plist"]];
        if (tap[@"open"]) {
            HSApp *a = [self _appNamed:req[@"bundle"]];
            NSString *url = tap[@"open"];
            NSLog(@"SpringBoard: widget %@ opens %@%@%@", req[@"kind"], a.name, [url length] ? @" with " : @"", url);
            if (a) [self launch:a url:[url length] ? url : nil];
            return;
        }
    }
    NSDictionary *tl = [NSDictionary dictionaryWithContentsOfFile:[base stringByAppendingPathExtension:@"plist"]];
    for (HSWidgetView *w in [widget_views() copy]) {
        if (![w.item[@"widget"] isEqual:req[@"kind"]] || ![w.item[@"family"] isEqual:req[@"family"]] || ![w.item[@"app"] isEqual:req[@"bundle"]]) continue;
        w.entries = tl[@"entries"]; w.shownFile = nil;
        NSDate *last = [w.entries.lastObject objectForKey:@"date"];
        if ([tl[@"policy"] isEqual:@"after"]) w.reloadAt = tl[@"after"];
        else if ([tl[@"policy"] isEqual:@"atEnd"]) w.reloadAt = last && [last timeIntervalSinceNow] > 1 ? last : [NSDate dateWithTimeIntervalSinceNow:300];
        else w.reloadAt = nil;
        [w showCurrent];
    }
}

/* ---- the widget's menu (long press) ---- */
- (void)widgetHeld:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || [self _isEditing]) return;
    HSWidgetView *w = (HSWidgetView *)g.view;
    HSApp *a = [self _appNamed:w.item[@"app"]];
    NSDictionary *list = [NSDictionary dictionaryWithContentsOfFile:[widgets_dir(w.item[@"app"]) stringByAppendingPathComponent:@"widgets.plist"]];
    NSDictionary *info = nil; for (NSDictionary *x in list[@"widgets"]) if ([x[@"kind"] isEqual:w.item[@"widget"]]) info = x;
    [widget_menu removeFromSuperview];
    UIControl *overlay = [[UIControl alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    overlay.accessibilityIdentifier = @"widget-menu";
    [overlay addTarget:self action:@selector(dismissWidgetMenu) forControlEvents:UIControlEventTouchUpInside];
    widget_menu = overlay;
    CGRect r = [w.iconView convertRect:w.iconView.bounds toView:self.view];
    UIImageView *lifted = [[UIImageView alloc] initWithFrame:CGRectInset(r, -4, -4)];
    lifted.image = w.currentImage; lifted.layer.cornerRadius = 24; lifted.clipsToBounds = YES;
    [overlay addSubview:lifted];
    NSString *name = info[@"name"] ?: w.item[@"widget"];
    NSMutableArray *items = [NSMutableArray array];
    if ([info[@"configurable"] boolValue]) [items addObject:@[[NSString stringWithFormat:NSLocalizedString(@"Edit “%@”", nil), name], @"info.circle", @"widget-edit"]];
    [items addObject:@[NSLocalizedString(@"Edit Home Screen", nil), @"apps.iphone", @"edit"]];
    [items addObject:@[NSLocalizedString(@"Remove Widget", nil), @"minus.circle", @"widget-remove"]];
    CGFloat W = 250, rowH = 44, H = rowH * items.count;
    UIView *card = [UIView new];
    BOOL glass = os_major() >= 26;
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.2 alpha:0.96] : [UIColor colorWithWhite:0.97 alpha:glass ? 0.9 : 0.96]; }];
    card.layer.cornerRadius = glass ? 22 : 13; card.clipsToBounds = YES;
    CGFloat x = MIN(MAX(12, r.origin.x), self.view.bounds.size.width - W - 12);
    BOOL below = CGRectGetMaxY(r) + 12 + H < self.view.bounds.size.height - 40;
    card.frame = CGRectMake(x, below ? CGRectGetMaxY(r) + 12 : r.origin.y - 12 - H, W, H);
    for (NSUInteger i = 0; i < items.count; i++) {
        NSArray *it = items[i];
        BOOL destructive = [it[2] isEqual:@"widget-remove"];
        UIColor *c = destructive ? UIColor.systemRedColor : UIColor.labelColor;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(0, i * rowH, W, rowH);
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, W - 60, rowH)]; l.text = it[0]; l.textColor = c; l.font = [UIFont systemFontOfSize:17]; l.userInteractionEnabled = NO;
        [b addSubview:l];
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:it[1] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]]];
        iv.tintColor = c; iv.frame = CGRectMake(W - 38, (rowH - 22) / 2, 22, 22); iv.contentMode = UIViewContentModeCenter; iv.userInteractionEnabled = NO;
        [b addSubview:iv];
        if (i) { UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, i * rowH, W, 0.5)]; h.backgroundColor = UIColor.separatorColor; [card addSubview:h]; }
        b.accessibilityIdentifier = [@"menu-" stringByAppendingString:it[2]];
        b.accessibilityLabel = it[0];
        objc_setAssociatedObject(b, "hswidget", w, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [b addTarget:self action:destructive ? @selector(menuRemoveWidget:) : [it[2] isEqual:@"edit"] ? @selector(menuWidgetEditHome:) : @selector(menuEditWidget:)
            forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:b];
    }
    [overlay addSubview:card];
    [self.view addSubview:overlay];
    NSLog(@"SpringBoard: menu for widget %@ (%@)", w.item[@"widget"], a.name);
}
- (void)dismissWidgetMenu { [widget_menu removeFromSuperview]; widget_menu = nil; }
- (void)menuWidgetEditHome:(UIButton *)b {
    [self dismissWidgetMenu];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, sel_registerName("setEditingMode:"), YES);
}
- (void)menuRemoveWidget:(UIButton *)b {
    HSWidgetView *w = objc_getAssociatedObject(b, "hswidget");
    [self dismissWidgetMenu];
    NSMutableArray *items = [self _layoutItems];
    NSUInteger i = [items indexOfObjectIdenticalTo:w.item];
    if (i == NSNotFound) return;
    [items removeObjectAtIndex:i];
    [widget_views() removeObjectIdenticalTo:w];
    NSLog(@"SpringBoard: removed widget %@ (%@)", w.item[@"widget"], w.item[@"family"]);
    [self _layoutChanged];
}
/* Edit Widget: the extension lists the configuration intent's parameters ("params"), then the sheet shows them */
- (void)menuEditWidget:(UIButton *)b {
    HSWidgetView *w = objc_getAssociatedObject(b, "hswidget");
    [self dismissWidgetMenu];
    HSApp *a = [self _appNamed:w.item[@"app"]];
    NSDictionary *ext = a ? widget_extension(a) : nil;
    if (!ext) return;
    config_edit = [@{ @"item": w.item, @"view": w, @"values": [w.item[@"config"] ?: @{} mutableCopy] } mutableCopy];
    NSLog(@"SpringBoard: editing widget %@", w.item[@"widget"]);
    run_extension(ext, a.bundleID, @{ @"mode": @"params", @"kind": w.item[@"widget"], @"family": w.item[@"family"], @"config": config_edit[@"values"] });
}
- (void)widgetParamsDone:(NSDictionary *)req {
    if (!config_edit || ![config_edit[@"item"][@"widget"] isEqual:req[@"kind"]]) return;
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:[req[@"out"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-params.plist", req[@"kind"]]]];
    if (!p) { config_edit = nil; return; }
    config_edit[@"params"] = p;
    config_edit[@"initial"] = [config_edit[@"values"] copy];
    for (NSDictionary *x in p[@"params"]) if (x[@"value"] && !config_edit[@"values"][x[@"name"]]) config_edit[@"values"][x[@"name"]] = x[@"value"];
    config_edit[@"initial"] = [config_edit[@"values"] copy];
    [self showWidgetConfig:nil];
}
/* the sheet (iOS: the widget lifts, its configuration card below it); choosing: the list of an enum's values */
- (void)showWidgetConfig:(NSString *)choosing {
    [widget_config removeFromSuperview];
    CGRect bounds = self.view.bounds;
    UIControl *ov = [[UIControl alloc] initWithFrame:bounds];
    ov.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    ov.accessibilityIdentifier = @"widget-config-done";               /* a tap outside: done (iOS applies the choices then) */
    [ov addTarget:self action:@selector(widgetConfigDone) forControlEvents:UIControlEventTouchUpInside];
    widget_config = ov;
    HSWidgetView *w = config_edit[@"view"];
    NSDictionary *p = config_edit[@"params"];
    CGSize fs = HSWidgetFamilySize(config_edit[@"item"][@"family"]);
    CGFloat cw = MIN(bounds.size.width - 32, 380);
    CGRect wr = w.window ? [w.iconView convertRect:w.iconView.bounds toView:self.view] : CGRectMake((bounds.size.width - fs.width) / 2, self.view.safeAreaInsets.top + 24, fs.width, fs.height);
    CGFloat top = wr.origin.y; fs = wr.size;                           /* the widget lifts where it is; the card below */
    UIImageView *preview = [[UIImageView alloc] initWithFrame:wr];
    preview.image = w.currentImage; preview.layer.cornerRadius = 22; preview.clipsToBounds = YES;
    [ov addSubview:preview];
    BOOL glass = os_major() >= 26;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((bounds.size.width - cw) / 2, top + fs.height + 20, cw, 100)];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.15 alpha:0.97] : [UIColor colorWithWhite:0.98 alpha:glass ? 0.92 : 0.98]; }];
    card.layer.cornerRadius = glass ? 32 : 20; card.clipsToBounds = YES;
    card.accessibilityIdentifier = @"widget-config";
    UIControl *absorb = [[UIControl alloc] initWithFrame:card.bounds]; absorb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [card addSubview:absorb];                                           /* taps on the card stay on it */
    CGFloat y = 18;
    NSDictionary *chosen = nil; for (NSDictionary *x in p[@"params"]) if ([x[@"name"] isEqual:choosing]) chosen = x;
    if (chosen) {                                                      /* an enum's values, the current one checked */
        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20, y, cw - 40, 24)]; t.text = chosen[@"title"]; t.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t]; y += 36;
        for (NSArray *c in chosen[@"choices"]) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.frame = CGRectMake(0, y, cw, 44);
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, cw - 70, 44)]; l.text = c[1]; l.font = [UIFont systemFontOfSize:17]; l.userInteractionEnabled = NO;
            [b addSubview:l];
            if ([config_edit[@"values"][chosen[@"name"]] isEqual:c[0]]) {
                UIImageView *ck = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]]; ck.tintColor = UIColor.systemBlueColor;
                ck.frame = CGRectMake(cw - 44, 11, 22, 22); ck.userInteractionEnabled = NO; [b addSubview:ck];
            }
            b.accessibilityIdentifier = [NSString stringWithFormat:@"widget-choice-%@", c[0]];
            b.accessibilityLabel = c[1];
            objc_setAssociatedObject(b, "hsparam", @[chosen[@"name"], c[0]], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [b addTarget:self action:@selector(widgetChoice:) forControlEvents:UIControlEventTouchUpInside];
            [card addSubview:b]; y += 44;
        }
    } else {
        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20, y, cw - 40, 24)]; t.text = p[@"title"]; t.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        [card addSubview:t]; y += 28;
        if ([p[@"description"] length]) {
            UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(20, y, cw - 40, 20)]; d.text = p[@"description"]; d.font = [UIFont systemFontOfSize:15]; d.textColor = UIColor.secondaryLabelColor;
            [card addSubview:d]; y += 26;
        }
        y += 8;
        for (NSDictionary *x in p[@"params"]) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, cw - 32, 46)];
            row.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) { return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.25 alpha:1] : [UIColor colorWithWhite:0.92 alpha:1]; }];
            row.layer.cornerRadius = glass ? 23 : 10;
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, row.bounds.size.width * 0.5, 46)]; l.text = x[@"title"]; l.font = [UIFont systemFontOfSize:17]; l.userInteractionEnabled = NO;
            [row addSubview:l];
            NSString *name = x[@"name"], *kind = x[@"kind"], *value = config_edit[@"values"][name];
            if ([kind isEqual:@"bool"]) {
                UISwitch *sw = [UISwitch new];
                sw.on = [value isEqual:@"true"];
                CGSize ss = [sw sizeThatFits:CGSizeZero];
                sw.frame = CGRectMake(row.bounds.size.width - ss.width - 12, (46 - ss.height) / 2, ss.width, ss.height);
                sw.accessibilityIdentifier = [@"widget-param-" stringByAppendingString:name];
                objc_setAssociatedObject(sw, "hsparam", name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [sw addTarget:self action:@selector(widgetSwitch:) forControlEvents:UIControlEventValueChanged];
                [row addSubview:sw];
            } else if ([kind isEqual:@"enum"]) {
                NSString *shown = value;
                for (NSArray *c in x[@"choices"]) if ([c[0] isEqual:value]) shown = c[1];
                UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
                b.frame = row.bounds;
                UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width * 0.45, 0, row.bounds.size.width * 0.55 - 34, 46)];
                v.text = shown ?: NSLocalizedString(@"Choose", nil); v.textColor = UIColor.systemBlueColor; v.textAlignment = NSTextAlignmentRight; v.font = [UIFont systemFontOfSize:17]; v.userInteractionEnabled = NO;
                [b addSubview:v];
                UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"]]; chev.tintColor = UIColor.systemBlueColor;
                chev.frame = CGRectMake(row.bounds.size.width - 28, 14, 16, 18); chev.contentMode = UIViewContentModeScaleAspectFit; chev.userInteractionEnabled = NO;
                [b addSubview:chev];
                b.accessibilityIdentifier = [@"widget-param-" stringByAppendingString:name];
                b.accessibilityLabel = x[@"title"]; b.accessibilityValue = shown;
                objc_setAssociatedObject(b, "hsparam", name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [b addTarget:self action:@selector(widgetChoose:) forControlEvents:UIControlEventTouchUpInside];
                [row addSubview:b];
            } else {                                                   /* text, numbers: a field (type, then return) */
                UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(row.bounds.size.width * 0.45, 0, row.bounds.size.width * 0.55 - 12, 46)];
                f.text = value; f.textAlignment = NSTextAlignmentRight; f.textColor = UIColor.systemBlueColor;
                f.keyboardType = [kind isEqual:@"int"] || [kind isEqual:@"double"] ? UIKeyboardTypeDecimalPad : UIKeyboardTypeDefault;
                f.accessibilityIdentifier = [@"widget-param-" stringByAppendingString:name];
                objc_setAssociatedObject(f, "hsparam", name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [f addTarget:self action:@selector(widgetText:) forControlEvents:UIControlEventEditingChanged];
                [f addTarget:f action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];   /* return: the keyboard goes */
                [row addSubview:f];
            }
            [card addSubview:row];
            y += 54;
        }
    }
    CGRect cf = card.frame; cf.size.height = y + 10; card.frame = cf;
    [ov addSubview:card];
    [self.view addSubview:ov];
    NSLog(@"SpringBoard: Edit Widget %@%@ (%lu parameter(s))", config_edit[@"item"][@"widget"], choosing ? [@": choose " stringByAppendingString:choosing] : @"", (unsigned long)[p[@"params"] count]);
}
- (void)widgetChoose:(UIButton *)b { [self showWidgetConfig:objc_getAssociatedObject(b, "hsparam")]; }
- (void)widgetChoice:(UIButton *)b {
    NSArray *nv = objc_getAssociatedObject(b, "hsparam");
    config_edit[@"values"][nv[0]] = nv[1];
    NSLog(@"SpringBoard: widget parameter %@ = %@", nv[0], nv[1]);
    [self showWidgetConfig:nil];
}
- (void)widgetSwitch:(UISwitch *)sw {
    NSString *name = objc_getAssociatedObject(sw, "hsparam");
    config_edit[@"values"][name] = sw.on ? @"true" : @"false";
    NSLog(@"SpringBoard: widget parameter %@ = %@", name, config_edit[@"values"][name]);
}
- (void)widgetText:(UITextField *)f { config_edit[@"values"][objc_getAssociatedObject(f, "hsparam")] = f.text ?: @""; }
- (void)widgetConfigDone {
    [widget_config endEditing:YES];
    [widget_config removeFromSuperview]; widget_config = nil;
    if (!config_edit) return;
    NSMutableDictionary *item = config_edit[@"item"];
    NSDictionary *values = [config_edit[@"values"] copy];
    BOOL changed = ![values isEqual:config_edit[@"initial"] ?: @{}];
    config_edit = nil;
    if (!changed) { NSLog(@"SpringBoard: widget %@ configuration unchanged", item[@"widget"]); return; }
    item[@"config"] = values;
    NSMutableArray *desc = [NSMutableArray array];
    for (NSString *k in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) [desc addObject:[NSString stringWithFormat:@"%@=%@", k, values[k]]];
    NSLog(@"SpringBoard: widget %@ configured: %@", item[@"widget"], [desc componentsJoinedByString:@", "]);
    [self _layoutChanged];                                             /* saves the configuration with the arrangement */
    for (HSWidgetView *w in [widget_views() copy]) if (w.item == item && w.window) [self renderWidget:w tapAt:nil];
}

/* ---- the widget gallery (Edit Home Screen > +) ---- */
- (void)showWidgetGallery {
    UIView *ov = [[UIView alloc] initWithFrame:self.view.bounds];
    ov.accessibilityIdentifier = @"widget-gallery";
    ov.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(0, 80, self.view.bounds.size.width, self.view.bounds.size.height - 80)];
    sheet.backgroundColor = UIColor.systemGroupedBackgroundColor; sheet.layer.cornerRadius = 12;
    [ov addSubview:sheet];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, sheet.bounds.size.width - 40, 36)];
    title.text = NSLocalizedString(@"Widgets", nil); title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    [sheet addSubview:title];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal]; close.frame = CGRectMake(sheet.bounds.size.width - 80, 16, 64, 36);
    close.accessibilityIdentifier = @"widget-gallery-done";
    [close addTarget:ov action:@selector(removeFromSuperview) forControlEvents:UIControlEventTouchUpInside];
    [sheet addSubview:close];
    CGFloat y = 70; NSUInteger n = 0;
    for (HSApp *a in self.apps) {
        NSDictionary *ext = widget_extension(a);
        if (!ext) continue;
        NSDictionary *list = [NSDictionary dictionaryWithContentsOfFile:[widgets_dir(a.bundleID) stringByAppendingPathComponent:@"widgets.plist"]];
        BOOL any = NO;
        for (NSDictionary *w in list[@"widgets"]) {
            NSString *first = nil; for (NSString *f in w[@"families"]) if (!first && family_title(f)) first = f;
            if (!first) continue;                                    /* Lock Screen only: the Lock Screen's gallery offers it */
            any = YES;
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, sheet.bounds.size.width - 32, 96)];
            row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; row.layer.cornerRadius = 12;
            CGFloat textW = row.bounds.size.width - 28 - 86;
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, textW, 22)];
            l.text = [NSString stringWithFormat:@"%@ — %@", a.name, w[@"name"]]; l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(14, 30, textW, 18)];
            d.text = w[@"description"]; d.font = [UIFont systemFontOfSize:13]; d.textColor = UIColor.secondaryLabelColor;
            [row addSubview:l]; [row addSubview:d];
            /* the snapshot (getSnapshot / snapshot(for:in:), isPreview), scaled into the row */
            CGSize fs = HSWidgetFamilySize(first); CGFloat pw = MIN(80, 80 * fs.width / fs.height), ph = pw * fs.height / fs.width;
            UIImageView *pv = [[UIImageView alloc] initWithFrame:CGRectMake(row.bounds.size.width - pw - 8, (96 - ph) / 2, pw, ph)];
            pv.layer.cornerRadius = 12; pv.clipsToBounds = YES; pv.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.15];
            pv.accessibilityIdentifier = [NSString stringWithFormat:@"widget-preview-%@", w[@"kind"]];
            NSString *snap = [widgets_dir(a.bundleID) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-snapshot.png", w[@"kind"], first]];
            pv.image = [UIImage imageWithContentsOfFile:snap];
            objc_setAssociatedObject(pv, "hssnapshot", snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [row addSubview:pv];
            CGFloat x = 14;
            for (NSString *f in w[@"families"]) {
                NSString *t = family_title(f);
                if (!t) continue;
                UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
                [b setTitle:[@"+ " stringByAppendingString:t] forState:UIControlStateNormal];
                b.frame = CGRectMake(x, 56, 84, 30); x += 90;
                b.backgroundColor = [UIColor colorWithRed:0 green:0.48 blue:1 alpha:0.12]; b.layer.cornerRadius = 15;
                b.accessibilityIdentifier = [NSString stringWithFormat:@"widget-add-%@-%@", w[@"kind"], f];
                b.accessibilityValue = [NSString stringWithFormat:@"%@\x1f%@\x1f%@", a.bundleID, w[@"kind"], f];
                [b addTarget:self action:@selector(addWidget:) forControlEvents:UIControlEventTouchUpInside];
                [row addSubview:b];
            }
            [sheet addSubview:row];
            y += 106; n++;
        }
        if (any) run_extension(ext, a.bundleID, @{ @"mode": @"snapshot", @"families": @[@"systemSmall", @"systemMedium", @"systemLarge"] });
    }
    if (!n) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, y, sheet.bounds.size.width - 40, 22)]; l.text = NSLocalizedString(@"No widgets", nil); l.textColor = UIColor.secondaryLabelColor; [sheet addSubview:l]; }
    [self.view addSubview:ov];
    NSLog(@"SpringBoard: widget gallery (%lu widget kind(s))", (unsigned long)n);
}
static void collect_previews(UIView *v, NSMutableArray *out) {
    if ([v.accessibilityIdentifier hasPrefix:@"widget-preview-"] || [v.accessibilityIdentifier hasPrefix:@"lock-preview-"]) [out addObject:v];
    for (UIView *s in v.subviews) collect_previews(s, out);
}
/* snapshots arrived: the galleries' previews (home screen and Lock Screen) */
- (void)galleryPreviewsDone:(NSDictionary *)req {
    NSMutableArray *pvs = [NSMutableArray array];
    collect_previews(self.view, pvs);
    NSUInteger shown = 0;
    for (UIImageView *pv in pvs) {
        NSString *snap = objc_getAssociatedObject(pv, "hssnapshot");
        UIImage *img = snap ? [UIImage imageWithContentsOfFile:snap] : nil;
        if (img.CGImage) img = [UIImage imageWithCGImage:img.CGImage scale:3 orientation:UIImageOrientationUp];    /* rendered at 3x */
        if (img) { pv.image = img; shown++; }
    }
    NSLog(@"SpringBoard: gallery previews from snapshots (%lu)", (unsigned long)shown);
}
- (void)addWidget:(UIButton *)b {
    NSArray *parts = [b.accessibilityValue componentsSeparatedByString:@"\x1f"];
    [b.superview.superview.superview removeFromSuperview];
    NSMutableDictionary *item = [@{ @"widget": parts[1], @"app": parts[0], @"family": parts[2] } mutableCopy];
    [[self _layoutItems] insertObject:item atIndex:0];       /* on the current page; what no longer fits moves on */
    NSLog(@"SpringBoard: added widget %@ (%@)", parts[1], parts[2]);
    [self _layoutChanged];
}
/* ask each app's widget extension what it offers (cached per app) */
/* a widget push (iOS 26, "apns-push-type": "widgets"): the app's widgets whose configuration has a WidgetPushHandler
   reload their timelines */
- (void)deliverWidgetsPush:(NSDictionary *)payload app:(HSApp *)a {
    NSDictionary *list = [NSDictionary dictionaryWithContentsOfFile:[widgets_dir(a.bundleID) stringByAppendingPathComponent:@"widgets.plist"]];
    NSMutableSet *kinds = [NSMutableSet set];
    for (NSDictionary *w in list[@"widgets"]) if ([w[@"push"] boolValue]) [kinds addObject:w[@"kind"]];
    if (os_major() < 26 || !kinds.count) {
        NSLog(@"SpringBoard: widgets push for %@ dropped (%@)", a.name, os_major() < 26 ? @"widget pushes are iOS 26+" : @"no widget has a WidgetPushHandler");
        return;
    }
    NSUInteger n = 0;
    for (HSWidgetView *w in [widget_views() copy])
        if (w.window && [w.item[@"app"] isEqual:a.bundleID] && [kinds containsObject:w.item[@"widget"]]) { [self renderWidget:w tapAt:nil]; n++; }
    NSLog(@"SpringBoard: widgets push for %@ (%@): reloading %lu widget(s)", a.name, [kinds.allObjects componentsJoinedByString:@", "], (unsigned long)n);
}
- (void)discoverWidgets {
    for (HSApp *a in self.apps) {
        NSDictionary *ext = widget_extension(a);
        if (!ext) continue;
        NSString *list = [widgets_dir(a.bundleID) stringByAppendingPathComponent:@"widgets.plist"];
        if (![NSFileManager.defaultManager fileExistsAtPath:list]) run_extension(ext, a.bundleID, @{ @"mode": @"list" });
    }
}
@end
