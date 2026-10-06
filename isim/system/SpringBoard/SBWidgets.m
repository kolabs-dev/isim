// isim home screen: widgets (WidgetKit) and Live Activities (ActivityKit).
// Widget extensions (<App>.app/PlugIns/*.appex with NSExtensionPointIdentifier com.apple.widgetkit-extension) run as
// helper processes started by the shell ("widget-run EXE REQUEST"); a request plist says what to do
// (list | render | tap | activity) and where to write the PNGs/plists (<isim data>/Library/SpringBoard/Widgets/<bundle id>).
// The home screen shows the timeline entry for the current date and asks for a new timeline when the policy says so,
// on WidgetCenter.reloadTimelines(ofKind:), or after a tap on an interactive widget ran an App Intent.
#import "SpringBoard.h"

static NSString *const kWidgetPoint = @"com.apple.widgetkit-extension";
static NSString *widgets_dir(NSString *bundle) {
    NSString *d = [[isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard/Widgets"] stringByAppendingPathComponent:bundle];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
/* the app's widget extension: { path, exe } */
static NSDictionary *widget_extension(HSApp *a) {
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
static NSUInteger req_seq;
static void run_extension(NSDictionary *ext, NSString *bundle, NSDictionary *request) {
    NSString *dir = widgets_dir(bundle);
    NSString *req = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"request-%lu-%u.plist", (unsigned long)++req_seq, arc4random() % 100000]];
    NSMutableDictionary *r = [request mutableCopy]; if (!r[@"out"]) r[@"out"] = dir;
    r[@"bundle"] = bundle;
    [r writeToFile:req atomically:YES];
    isim_shell_request(ISIM_SHELL_SYSTEM, "widget-run", [ext[@"exe"] UTF8String], req.UTF8String);
}

/* ---- a widget on the home screen ---- */
@interface HSWidgetView : UIControl
@property (nonatomic, strong) NSMutableDictionary *item;
@property (nonatomic, strong) NSArray *entries;          /* { date, file } */
@property (nonatomic, strong) NSDate *reloadAt;
@property (nonatomic, weak) HomeViewController *home;
@property (nonatomic, copy) NSString *shownFile;
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
- (void)layoutSubviews { CGSize b = self.bounds.size; _image.frame = CGRectMake(0, 0, b.width, b.height - 22); _label.frame = CGRectMake(0, b.height - 17, b.width, 16); }
- (NSString *)_isim_dumpText { return self.shownFile.lastPathComponent; }
- (void)showCurrent {
    NSDictionary *cur = nil; NSDate *now = [NSDate date];
    for (NSDictionary *e in self.entries) if ([e[@"date"] compare:now] != NSOrderedDescending) cur = e;
    if (!cur) cur = self.entries.firstObject;
    if (!cur || [cur[@"file"] isEqual:self.shownFile]) return;
    self.shownFile = cur[@"file"];
    _image.image = [UIImage imageWithContentsOfFile:cur[@"file"]];
    NSLog(@"SpringBoard: widget %@ shows %@", self.item[@"widget"], [cur[@"file"] lastPathComponent]);
}
@end

static NSMutableArray<HSWidgetView *> *widget_views(void) { static NSMutableArray *a; if (!a) a = [NSMutableArray array]; return a; }
static NSMutableDictionary *pending_taps;      /* request path -> widget view (tap requests) */

@implementation HomeViewController (Widgets)
- (HSApp *)_appNamed:(NSString *)bundle { for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:bundle]) return a; return nil; }
- (UIControl *)makeWidgetView:(NSMutableDictionary *)item {
    HSApp *a = [self _appNamed:item[@"app"]];
    HSWidgetView *w = [[HSWidgetView alloc] initWithItem:item home:self appName:a.name ?: @""];
    [w addTarget:self action:@selector(widgetTapped:forEvent:) forControlEvents:UIControlEventTouchUpInside];
    /* keep the last timeline across rebuilds */
    HSWidgetView *previous = nil;
    for (HSWidgetView *old in widget_views()) if (!old.window && [old.item[@"widget"] isEqual:item[@"widget"]] && [old.item[@"family"] isEqual:item[@"family"]] && [old.item[@"app"] isEqual:item[@"app"]]) previous = old;
    if (previous) {                                     /* the same widget after a rebuild: keep its timeline (or the render in flight) */
        w.entries = previous.entries; w.reloadAt = previous.reloadAt; [w showCurrent];
        [widget_views() removeObjectIdenticalTo:previous];
    }
    [widget_views() addObject:w];
    if (!previous) [self renderWidget:w tapAt:nil];
    return w;
}
- (void)renderWidget:(HSWidgetView *)w tapAt:(NSValue *)point {
    HSApp *a = [self _appNamed:w.item[@"app"]];
    NSDictionary *ext = a ? widget_extension(a) : nil;
    if (!ext) { NSLog(@"SpringBoard: no widget extension in %@", w.item[@"app"]); return; }
    NSMutableDictionary *r = [@{ @"mode": point ? @"tap" : @"render", @"kind": w.item[@"widget"], @"family": w.item[@"family"] } mutableCopy];
    if (point) { CGPoint p = point.CGPointValue; r[@"x"] = @(p.x); r[@"y"] = @(p.y); }
    run_extension(ext, a.bundleID, r);
}
- (void)widgetTapped:(HSWidgetView *)w forEvent:(UIEvent *)e {
    if ([self _isEditing]) return;
    UITouch *t = e.allTouches.anyObject;
    CGPoint p = t ? [t locationInView:w.iconView] : CGPointMake(w.iconView.bounds.size.width / 2, w.iconView.bounds.size.height / 2);
    /* widget coordinates: the extension renders at the family's size */
    NSDictionary *sizes = @{ @"systemSmall": @[@170, @170], @"systemMedium": @[@364, @170], @"systemLarge": @[@364, @382] };
    NSArray *sz = sizes[w.item[@"family"]] ?: @[@170, @170];
    CGSize v = w.iconView.bounds.size;
    CGPoint q = CGPointMake(p.x * [sz[0] doubleValue] / MAX(1, v.width), p.y * [sz[1] doubleValue] / MAX(1, v.height));
    NSLog(@"SpringBoard: tap on widget %@ at %.0f,%.0f", w.item[@"widget"], q.x, q.y);
    if (!pending_taps) pending_taps = [NSMutableDictionary dictionary];
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
    if ([mode isEqual:@"activity"]) {
        HSApp *a = [self _appNamed:req[@"bundle"]];
        if (a && [NSFileManager.defaultManager fileExistsAtPath:[out stringByAppendingPathComponent:@"lock.png"]])
            isim_shell_request(ISIM_SHELL_SYSTEM, "la-show", a.path.UTF8String, out.UTF8String);
        return;
    }
    if ([mode isEqual:@"list"]) return;
    NSDictionary *tl = [NSDictionary dictionaryWithContentsOfFile:[out stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.plist", req[@"kind"], req[@"family"]]]];
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
        for (NSDictionary *w in list[@"widgets"]) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, sheet.bounds.size.width - 32, 96)];
            row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; row.layer.cornerRadius = 12;
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, row.bounds.size.width - 28, 22)];
            l.text = [NSString stringWithFormat:@"%@ — %@", a.name, w[@"name"]]; l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(14, 30, row.bounds.size.width - 28, 18)];
            d.text = w[@"description"]; d.font = [UIFont systemFontOfSize:13]; d.textColor = UIColor.secondaryLabelColor;
            [row addSubview:l]; [row addSubview:d];
            CGFloat x = 14;
            for (NSString *f in w[@"families"]) {
                NSString *t = [f isEqual:@"systemSmall"] ? @"Small" : [f isEqual:@"systemMedium"] ? @"Medium" : [f isEqual:@"systemLarge"] ? @"Large" : nil;
                if (!t) continue;
                UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
                [b setTitle:[@"+ " stringByAppendingString:t] forState:UIControlStateNormal];
                b.frame = CGRectMake(x, 56, 90, 30); x += 98;
                b.backgroundColor = [UIColor colorWithRed:0 green:0.48 blue:1 alpha:0.12]; b.layer.cornerRadius = 15;
                b.accessibilityIdentifier = [NSString stringWithFormat:@"widget-add-%@-%@", w[@"kind"], f];
                b.accessibilityValue = [NSString stringWithFormat:@"%@\x1f%@\x1f%@", a.bundleID, w[@"kind"], f];
                [b addTarget:self action:@selector(addWidget:) forControlEvents:UIControlEventTouchUpInside];
                [row addSubview:b];
            }
            [sheet addSubview:row];
            y += 106; n++;
        }
    }
    if (!n) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, y, sheet.bounds.size.width - 40, 22)]; l.text = NSLocalizedString(@"No widgets", nil); l.textColor = UIColor.secondaryLabelColor; [sheet addSubview:l]; }
    [self.view addSubview:ov];
    NSLog(@"SpringBoard: widget gallery (%lu widget kind(s))", (unsigned long)n);
}
- (void)addWidget:(UIButton *)b {
    NSArray *parts = [b.accessibilityValue componentsSeparatedByString:@"\x1f"];
    [b.superview.superview.superview removeFromSuperview];
    NSMutableDictionary *item = [@{ @"widget": parts[1], @"app": parts[0], @"family": parts[2] } mutableCopy];
    [[self _layoutItems] insertObject:item atIndex:0];
    NSLog(@"SpringBoard: added widget %@ (%@)", parts[1], parts[2]);
    [self _layoutChanged];
}
/* ask each app's widget extension what it offers (cached per app) */
- (void)discoverWidgets {
    for (HSApp *a in self.apps) {
        NSDictionary *ext = widget_extension(a);
        if (!ext) continue;
        NSString *list = [widgets_dir(a.bundleID) stringByAppendingPathComponent:@"widgets.plist"];
        if (![NSFileManager.defaultManager fileExistsAtPath:list]) run_extension(ext, a.bundleID, @{ @"mode": @"list" });
    }
}

/* ---- Live Activities: render with the app's widget extension, the shell shows them ---- */
- (void)liveActivity:(NSString *)args {
    NSRange sp = [args rangeOfString:@" "];
    if (sp.location == NSNotFound) return;
    NSString *what = [args substringToIndex:sp.location], *path = [args substringFromIndex:sp.location + 1];
    NSDictionary *rec = [NSDictionary dictionaryWithContentsOfFile:path];
    HSApp *a = [self _appNamed:rec[@"bundle"]];
    if (!a) return;
    if ([what isEqual:@"end"]) { isim_shell_request(ISIM_SHELL_SYSTEM, "la-hide", a.path.UTF8String, NULL); return; }
    NSDictionary *ext = widget_extension(a);
    if (!ext) { NSLog(@"SpringBoard: %@ has no widget extension for its Live Activity", a.name); return; }
    NSString *out = [widgets_dir(a.bundleID) stringByAppendingPathComponent:[@"activity-" stringByAppendingString:rec[@"id"] ?: @"x"]];
    run_extension(ext, a.bundleID, @{ @"mode": @"activity", @"activity": path, @"out": out });
}
@end
