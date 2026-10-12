// isim home screen: Lock Screen widgets and StandBy (WidgetKit), drawn by the shell from images the apps' widget
// extensions render.
// Lock Screen: the accessory widgets chosen in the Lock Screen editor (<isim data>/Library/SpringBoard/
// LockScreenWidgets.plist { inline = { app; widget; family }; widgets = ({ app; widget; family }) }), rendered
// vibrant without their container background ("location" lock) and sent to the shell ("lw-set SIDECAR"). The editor
// opens from a long press on the Lock Screen (the shell sends "lock-customize"; script `lockscreen customize`): the
// date box takes one inline widget, the box under the clock up to four units of circular (1) and rectangular (2)
// widgets, added from the Add Widgets sheet (previews: the widgets' snapshots) and removed with their minus badges.
// Adapted: iOS first shows the wallpaper gallery with a Customize button; isim opens the editor at once.
// StandBy ("standby on"): the first two small widgets of the home screen, full colour without their backgrounds,
// rendered large ("location" standby) and sent to the shell ("sb-set SIDECAR").
#import "SpringBoard.h"
#import <objc/runtime.h>

static int os_major(void) { return isim_os_version() / 10000; }
static NSString *lock_file(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard/LockScreenWidgets.plist"]; }
static NSString *icon_state(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard/IconState.plist"]; }
/* a slot: { item = { app; widget; family; config? }; entries; reloadAt } */
static NSMutableArray<NSMutableDictionary *> *lock_slots, *standby_slots;
static BOOL standby_on;
static UIView *editor, *gallery;
static NSMutableDictionary *edit_cfg;                          /* the editor's working copy: { inline; widgets } */
BOOL HSLockEditorShown(void) { return editor != nil; }
static NSInteger units(NSString *family) { return [family isEqual:@"accessoryRectangular"] ? 2 : 1; }
static NSString *family_name(NSString *f) {
    return [f isEqual:@"accessoryCircular"] ? NSLocalizedString(@"Circular", nil) : [f isEqual:@"accessoryRectangular"] ? NSLocalizedString(@"Rectangular", nil) : NSLocalizedString(@"Inline", nil);
}
static NSString *current_file(NSDictionary *slot) {
    NSDictionary *cur = nil; NSDate *now = [NSDate date];
    for (NSDictionary *e in slot[@"entries"]) if ([e[@"date"] compare:now] != NSOrderedDescending) cur = e;
    return (cur ?: [slot[@"entries"] firstObject])[@"file"];
}
static NSString *current_url(NSDictionary *slot) {
    NSDictionary *cur = nil; NSDate *now = [NSDate date];
    for (NSDictionary *e in slot[@"entries"]) if ([e[@"date"] compare:now] != NSOrderedDescending) cur = e;
    return (cur ?: [slot[@"entries"] firstObject])[@"url"];
}

@implementation HomeViewController (LockScreen)
- (HSApp *)_lockApp:(NSString *)b { for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:b]) return a; return nil; }
- (void)installLockScreenObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if ([t isEqual:@"lock-customize"]) [self showLockEditor];
        else if ([t isEqual:@"lock-customize-done"]) { if (editor) [self lockEditorDone:nil]; }
        else if ([t isEqual:@"lock-customize-cancel"]) { [editor removeFromSuperview]; editor = nil; gallery = nil; edit_cfg = nil; }
        else if ([t isEqual:@"standby on"]) { standby_on = YES; [self renderStandBy]; }
        else if ([t isEqual:@"standby off"]) { standby_on = NO; standby_slots = nil; }
        else if ([t hasPrefix:@"lw-open "]) [self openLockWidget:[[t substringFromIndex:8] integerValue]];
        else if ([t hasPrefix:@"la-open "]) [self performSelector:@selector(openLiveActivityApp:) withObject:[t substringFromIndex:8]];
    }];
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) { [self lockTick]; }];
    [self reloadLockWidgets];
}
/* ---- the Lock Screen's widgets ---- */
- (void)reloadLockWidgets {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:lock_file()];
    lock_slots = [NSMutableArray array];
    if (cfg[@"inline"]) [lock_slots addObject:[@{ @"item": cfg[@"inline"] } mutableCopy]];
    for (NSDictionary *w in cfg[@"widgets"]) [lock_slots addObject:[@{ @"item": w } mutableCopy]];
    for (NSMutableDictionary *s in lock_slots) [self renderSlot:s location:@"lock"];
    [self sendLockWidgets];
}
- (void)renderSlot:(NSMutableDictionary *)slot location:(NSString *)location {
    NSDictionary *item = slot[@"item"];
    HSApp *a = [self _lockApp:item[@"app"]];
    NSDictionary *ext = a ? HSWidgetExtension(a) : nil;
    if (!ext) return;
    BOOL lock = [location isEqual:@"lock"];
    NSMutableDictionary *r = [@{ @"mode": @"render", @"kind": item[@"widget"], @"family": lock ? item[@"family"] : @"systemSmall", @"location": location,
                                 @"background": @NO, @"out": [HSWidgetsDir(a.bundleID) stringByAppendingPathComponent:location] } mutableCopy];
    if (lock) r[@"renderingMode"] = @"vibrant"; else r[@"scale"] = @6;    /* StandBy: small widgets drawn about twice their size */
    if (item[@"config"]) r[@"config"] = item[@"config"];
    HSRunWidgetExtension(ext, a.bundleID, r);
}
- (void)lockWidgetRendered:(NSDictionary *)req {
    BOOL lock = [req[@"location"] isEqual:@"lock"];
    NSDictionary *tl = [NSDictionary dictionaryWithContentsOfFile:[req[@"out"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.plist", req[@"kind"], req[@"family"]]]];
    for (NSMutableDictionary *s in lock ? lock_slots : standby_slots) {
        NSDictionary *it = s[@"item"];
        if (![it[@"widget"] isEqual:req[@"kind"]] || ![it[@"app"] isEqual:req[@"bundle"]] || (lock && ![it[@"family"] isEqual:req[@"family"]])) continue;
        s[@"entries"] = tl[@"entries"] ?: @[];
        NSDate *last = [[tl[@"entries"] lastObject] objectForKey:@"date"];
        if ([tl[@"policy"] isEqual:@"after"]) s[@"reloadAt"] = tl[@"after"];
        else if ([tl[@"policy"] isEqual:@"atEnd"]) s[@"reloadAt"] = last && [last timeIntervalSinceNow] > 1 ? last : [NSDate dateWithTimeIntervalSinceNow:300];
        else [s removeObjectForKey:@"reloadAt"];
    }
    if (lock) [self sendLockWidgets]; else [self sendStandBy];
}
- (void)sendLockWidgets {
    NSMutableString *t = [NSMutableString string];
    for (NSMutableDictionary *s in lock_slots) {
        NSDictionary *it = s[@"item"];
        NSString *file = current_file(s) ?: @"";
        s[@"shown"] = file;
        if ([it[@"family"] isEqual:@"accessoryInline"]) [t appendFormat:@"inline=%@\x1f%@\x1f%@\n", file, it[@"app"], it[@"widget"]];
        else [t appendFormat:@"widget=%@\x1f%@\x1f%@\x1f%@\n", it[@"family"], file, it[@"app"], it[@"widget"]];
    }
    NSString *side = [[isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard"] stringByAppendingPathComponent:@"lock-widgets.txt"];
    [t writeToFile:side atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    isim_shell_request(ISIM_SHELL_SYSTEM, "lw-set", NULL, side.UTF8String);
}
- (void)lockTick {
    BOOL lockChanged = NO, sbChanged = NO;
    for (int pass = 0; pass < 2; pass++) for (NSMutableDictionary *s in pass ? standby_slots : lock_slots) {
        NSString *f = current_file(s);
        if (f && ![f isEqual:s[@"shown"]]) { if (pass) sbChanged = YES; else lockChanged = YES; }
        NSDate *at = s[@"reloadAt"];
        if (at && [at timeIntervalSinceNow] <= 0) { [s removeObjectForKey:@"reloadAt"]; [self renderSlot:s location:pass ? @"standby" : @"lock"]; }
    }
    if (lockChanged) [self sendLockWidgets];
    if (sbChanged) [self sendStandBy];
}
- (void)openLockWidget:(NSInteger)i {
    if (i < 0 || i >= (NSInteger)lock_slots.count) return;
    NSDictionary *s = lock_slots[(NSUInteger)i];
    HSApp *a = [self _lockApp:s[@"item"][@"app"]];
    NSString *url = current_url(s);
    NSLog(@"SpringBoard: Lock Screen widget %@ opens %@%@%@", s[@"item"][@"widget"], a.name, url ? @" with " : @"", url ?: @"");
    if (a) [self launch:a url:url];
}

/* ---- StandBy: the first two small widgets of the home screen ---- */
- (void)renderStandBy {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:icon_state()];
    standby_slots = [NSMutableArray array];
    for (NSDictionary *p in state[@"pages"]) for (NSDictionary *it in p[@"items"]) {
        if (standby_slots.count >= 2 || ![it isKindOfClass:[NSDictionary class]] || ![it[@"family"] isEqual:@"systemSmall"]) continue;
        [standby_slots addObject:[@{ @"item": it } mutableCopy]];
    }
    NSLog(@"SpringBoard: StandBy with %lu widget(s)", (unsigned long)standby_slots.count);
    for (NSMutableDictionary *s in standby_slots) [self renderSlot:s location:@"standby"];
    [self sendStandBy];
}
- (void)sendStandBy {
    if (!standby_on) return;
    NSMutableString *t = [NSMutableString string];
    for (NSUInteger i = 0; i < standby_slots.count; i++) {
        NSMutableDictionary *s = standby_slots[i];
        NSString *file = current_file(s);
        s[@"shown"] = file ?: @"";
        if (file) [t appendFormat:@"%@=%@\x1f%@\x1f%@\n", i ? @"right" : @"left", file, s[@"item"][@"app"], s[@"item"][@"widget"]];
    }
    NSString *side = [[isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard"] stringByAppendingPathComponent:@"standby.txt"];
    [t writeToFile:side atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    isim_shell_request(ISIM_SHELL_SYSTEM, "sb-set", NULL, side.UTF8String);
}

/* ---- the Lock Screen editor ---- */
/* where the shell draws the date line and the widget row (shell_system.inc lw_row_top) */
- (CGFloat)_lockTop { return MAX(self.view.safeAreaInsets.top, 20); }
- (CGFloat)_lockRowTop { return [self _lockTop] + (os_major() >= 26 ? 206 : 162); }
- (void)showLockEditor {
    if (!edit_cfg) {
        NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:lock_file()];
        edit_cfg = [NSMutableDictionary dictionary];
        if (cfg[@"inline"]) edit_cfg[@"inline"] = cfg[@"inline"];
        edit_cfg[@"widgets"] = [cfg[@"widgets"] ?: @[] mutableCopy];
        /* the galleries' previews: every app's accessory widgets, drawn as on the Lock Screen */
        for (HSApp *a in self.apps) {
            NSDictionary *ext = HSWidgetExtension(a);
            if (ext) HSRunWidgetExtension(ext, a.bundleID, @{ @"mode": @"snapshot", @"renderingMode": @"vibrant", @"background": @NO,
                                                              @"families": @[@"accessoryCircular", @"accessoryRectangular", @"accessoryInline"] });
        }
        NSLog(@"SpringBoard: Lock Screen editor");
    }
    BOOL showGallery = gallery != nil; NSString *galleryKind = gallery.accessibilityValue;
    [editor removeFromSuperview];
    CGRect b = self.view.bounds;
    UIView *ed = [[UIView alloc] initWithFrame:b];
    ed.accessibilityIdentifier = @"lock-editor";
    ed.backgroundColor = [UIColor colorWithRed:0.16 green:0.2 blue:0.42 alpha:1];
    UIImageView *wp = [[UIImageView alloc] initWithFrame:b];
    wp.image = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"wallpaper.png"]];
    wp.contentMode = UIViewContentModeScaleAspectFill;
    [ed addSubview:wp];
    UIView *dim = [[UIView alloc] initWithFrame:b]; dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2]; dim.userInteractionEnabled = NO;
    [ed addSubview:dim];
    BOOL glass = os_major() >= 26;
    for (int i = 0; i < 2; i++) {                                     /* Cancel / Done, either side of the island */
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:i ? NSLocalizedString(@"Done", nil) : NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:17 weight:i ? UIFontWeightSemibold : UIFontWeightRegular];
        [btn setTitleColor:i && !glass ? UIColor.whiteColor : UIColor.whiteColor forState:UIControlStateNormal];
        btn.backgroundColor = i ? (glass ? [UIColor colorWithWhite:1 alpha:0.28] : UIColor.systemBlueColor) : [UIColor colorWithWhite:1 alpha:glass ? 0.22 : 0.18];
        btn.layer.cornerRadius = 17;
        btn.frame = CGRectMake(i ? b.size.width - 16 - 76 : 16, 12, 76, 34);
        btn.accessibilityIdentifier = i ? @"lock-edit-done" : @"lock-edit-cancel";
        [btn addTarget:self action:i ? @selector(lockEditorDone:) : @selector(lockEditorCancel:) forControlEvents:UIControlEventTouchUpInside];
        [ed addSubview:btn];
    }
    CGFloat top = [self _lockTop], W = b.size.width;
    /* the date box: the inline widget */
    UIControl *dateBox = [[UIControl alloc] initWithFrame:CGRectMake(W / 2 - 130, top + 22, 260, 34)];
    dateBox.layer.cornerRadius = 12; dateBox.layer.borderWidth = 1.5; dateBox.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.6].CGColor;
    dateBox.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    dateBox.accessibilityIdentifier = @"lock-edit-inline";
    [dateBox addTarget:self action:@selector(lockEditInline:) forControlEvents:UIControlEventTouchUpInside];
    NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = edit_cfg[@"inline"] ? @"EEE d" : @"EEEE, MMMM d";
    UILabel *dl = [UILabel new]; dl.text = [df stringFromDate:[NSDate date]]; dl.textColor = UIColor.whiteColor; dl.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    dl.userInteractionEnabled = NO; [dl sizeToFit];
    UIImageView *ip = nil;
    if (edit_cfg[@"inline"]) {
        NSDictionary *it = edit_cfg[@"inline"];
        ip = [[UIImageView alloc] initWithFrame:CGRectMake(0, 4, MIN(234, 260 - dl.bounds.size.width - 18), 26)];
        UIImage *img = [UIImage imageWithContentsOfFile:[HSWidgetsDir(it[@"app"]) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-accessoryInline-snapshot.png", it[@"widget"]]]];
        if (img.CGImage) img = [UIImage imageWithCGImage:img.CGImage scale:3 orientation:UIImageOrientationUp];      /* rendered at 3x */
        ip.image = img;
        ip.contentMode = UIViewContentModeCenter; ip.clipsToBounds = YES; ip.userInteractionEnabled = NO;   /* the content is centred in its 234 pt line */
        ip.accessibilityIdentifier = [NSString stringWithFormat:@"lock-preview-%@-accessoryInline", it[@"widget"]];
    }
    CGFloat tw = dl.bounds.size.width + (ip ? 6 + ip.bounds.size.width : 0), x0 = (260 - tw) / 2;
    dl.frame = CGRectMake(x0, (34 - dl.bounds.size.height) / 2, dl.bounds.size.width, dl.bounds.size.height);
    [dateBox addSubview:dl];
    if (ip) {
        CGRect f = ip.frame; f.origin.x = x0 + dl.bounds.size.width + 6; f.origin.y = (34 - f.size.height) / 2; ip.frame = f;
        [dateBox addSubview:ip];
        UIButton *rm = [self _removeBadge:@"lock-edit-remove-inline" at:CGPointMake(dateBox.frame.origin.x - 6, dateBox.frame.origin.y - 8)];
        [rm addTarget:self action:@selector(lockRemoveInline:) forControlEvents:UIControlEventTouchUpInside];
        [ed addSubview:dateBox]; [ed addSubview:rm];
    } else [ed addSubview:dateBox];
    /* the clock */
    NSDateFormatter *tf = [NSDateFormatter new]; tf.dateFormat = @"h:mm";
    UILabel *clock = [[UILabel alloc] initWithFrame:CGRectMake(0, top + (glass ? 40 : 50), W, glass ? W * 0.46 : 110)];
    NSString *fixed = NSProcessInfo.processInfo.environment[@"ISIM_LOCK_TIME"];
    clock.text = fixed.length ? fixed : [tf stringFromDate:[NSDate date]];
    clock.font = glass ? [UIFont systemFontOfSize:W * 0.40 weight:UIFontWeightHeavy] : [UIFont systemFontOfSize:92 weight:UIFontWeightBold];
    clock.textColor = [UIColor colorWithWhite:1 alpha:glass ? 0.6 : 0.95]; clock.textAlignment = NSTextAlignmentCenter; clock.userInteractionEnabled = NO;
    [ed addSubview:clock];
    /* the widget box under the clock */
    CGFloat rowTop = [self _lockRowTop];
    UIControl *box = [[UIControl alloc] initWithFrame:CGRectMake(W / 2 - 176, rowTop - 8, 352, 88)];
    box.layer.cornerRadius = 20; box.layer.borderWidth = 1.5; box.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.6].CGColor;
    box.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    box.accessibilityIdentifier = @"lock-edit-widgets";
    [box addTarget:self action:@selector(lockEditWidgets:) forControlEvents:UIControlEventTouchUpInside];
    [ed addSubview:box];
    NSArray *ws = edit_cfg[@"widgets"];
    if (!ws.count) {
        UILabel *add = [[UILabel alloc] initWithFrame:box.bounds]; add.text = NSLocalizedString(@"Add Widgets", nil); add.textColor = UIColor.whiteColor;
        add.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; add.textAlignment = NSTextAlignmentCenter; add.userInteractionEnabled = NO;
        [box addSubview:add];
    }
    CGFloat total = 0; for (NSDictionary *w in ws) total += units(w[@"family"]) == 2 ? 160 : 72;
    total += 16 * MAX(0, (NSInteger)ws.count - 1);
    CGFloat x = (W - total) / 2;
    for (NSUInteger i = 0; i < ws.count; i++) {
        NSDictionary *w = ws[i];
        CGFloat ww = units(w[@"family"]) == 2 ? 160 : 72;
        UIImageView *pv = [[UIImageView alloc] initWithFrame:CGRectMake(x, rowTop, ww, 72)];
        NSString *snap = [HSWidgetsDir(w[@"app"]) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-snapshot.png", w[@"widget"], w[@"family"]]];
        pv.image = [UIImage imageWithContentsOfFile:snap]; pv.userInteractionEnabled = NO;
        pv.accessibilityIdentifier = [NSString stringWithFormat:@"lock-preview-%@-%@", w[@"widget"], w[@"family"]];
        objc_setAssociatedObject(pv, "hssnapshot", snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [ed addSubview:pv];
        UIButton *rm = [self _removeBadge:[NSString stringWithFormat:@"lock-edit-remove-%lu", (unsigned long)i + 1] at:CGPointMake(x - 8, rowTop - 8)];
        rm.tag = (NSInteger)i;
        [rm addTarget:self action:@selector(lockRemoveWidget:) forControlEvents:UIControlEventTouchUpInside];
        [ed addSubview:rm];
        x += ww + 16;
    }
    editor = ed; gallery = nil;
    [self.view addSubview:ed];
    if (showGallery) [self showLockGallery:[galleryKind isEqual:@"inline"]];
}
- (UIButton *)_removeBadge:(NSString *)ident at:(CGPoint)p {
    UIButton *rm = [UIButton buttonWithType:UIButtonTypeCustom];
    rm.frame = CGRectMake(p.x, p.y, 24, 24); rm.layer.cornerRadius = 12;
    rm.backgroundColor = [UIColor colorWithWhite:0.55 alpha:0.95];
    [rm setTitle:@"−" forState:UIControlStateNormal]; rm.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    rm.accessibilityIdentifier = ident;
    return rm;
}
- (void)lockEditInline:(id)s { [self showLockGallery:YES]; }
- (void)lockEditWidgets:(id)s { [self showLockGallery:NO]; }
- (void)lockRemoveInline:(id)s { [edit_cfg removeObjectForKey:@"inline"]; NSLog(@"SpringBoard: Lock Screen editor: removed the inline widget"); [self showLockEditor]; }
- (void)lockRemoveWidget:(UIButton *)b {
    NSMutableArray *ws = edit_cfg[@"widgets"];
    if (b.tag < (NSInteger)ws.count) { NSLog(@"SpringBoard: Lock Screen editor: removed %@", ws[(NSUInteger)b.tag][@"widget"]); [ws removeObjectAtIndex:(NSUInteger)b.tag]; }
    [self showLockEditor];
}
/* the Add Widgets sheet: the apps' accessory widgets (inline: the date box's) */
- (void)showLockGallery:(BOOL)inlineOnly {
    [gallery removeFromSuperview];
    CGRect b = self.view.bounds;
    BOOL glass = os_major() >= 26;
    CGFloat h = inlineOnly ? 300 : 420;
    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(glass ? 8 : 0, b.size.height - h - (glass ? 8 : 0), b.size.width - (glass ? 16 : 0), h + (glass ? 0 : 30))];
    sheet.backgroundColor = [UIColor colorWithWhite:glass ? 0.96 : 0.95 alpha:glass ? 0.9 : 0.98];
    sheet.layer.cornerRadius = glass ? 34 : 14;
    sheet.accessibilityIdentifier = @"lock-widget-gallery";
    sheet.accessibilityValue = inlineOnly ? @"inline" : @"widgets";
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, sheet.bounds.size.width - 80, 28)];
    title.text = NSLocalizedString(@"Add Widgets", nil); title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; title.textColor = UIColor.blackColor;
    [sheet addSubview:title];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(sheet.bounds.size.width - 50, 14, 32, 32); close.layer.cornerRadius = 16; close.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    [close setTitle:@"✕" forState:UIControlStateNormal]; [close setTitleColor:UIColor.darkGrayColor forState:UIControlStateNormal];
    close.accessibilityIdentifier = @"lock-gallery-close";
    [close addTarget:self action:@selector(closeLockGallery) forControlEvents:UIControlEventTouchUpInside];
    [sheet addSubview:close];
    CGFloat y = 58; NSUInteger n = 0;
    for (HSApp *a in self.apps) {
        NSDictionary *list = [NSDictionary dictionaryWithContentsOfFile:[HSWidgetsDir(a.bundleID) stringByAppendingPathComponent:@"widgets.plist"]];
        NSMutableArray *tiles = [NSMutableArray array];
        for (NSDictionary *w in list[@"widgets"]) for (NSString *f in w[@"families"]) {
            BOOL isInline = [f isEqual:@"accessoryInline"];
            if (![f hasPrefix:@"accessory"] || isInline != inlineOnly) continue;
            [tiles addObject:@[w, f]];
        }
        if (!tiles.count) continue;
        UILabel *an = [[UILabel alloc] initWithFrame:CGRectMake(20, y, sheet.bounds.size.width - 40, 20)];
        an.text = a.name; an.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; an.textColor = [UIColor colorWithWhite:0.35 alpha:1];
        [sheet addSubview:an]; y += 26;
        CGFloat x = 20, rowH = inlineOnly ? 56 : 112;
        for (NSArray *t in tiles) {
            NSDictionary *w = t[0]; NSString *f = t[1];
            CGSize fs = HSWidgetFamilySize(f);
            CGFloat tw = inlineOnly ? sheet.bounds.size.width - 40 : fs.width + 16;
            if (x + tw > sheet.bounds.size.width - 12) { x = 20; y += rowH; }
            UIControl *tile = [[UIControl alloc] initWithFrame:CGRectMake(x, y, tw, rowH - 10)];
            tile.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1]; tile.layer.cornerRadius = 16;   /* dark, so the vibrant preview shows */
            tile.accessibilityIdentifier = [NSString stringWithFormat:@"lock-add-%@-%@", w[@"kind"], f];
            tile.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", w[@"name"], family_name(f)];
            tile.accessibilityValue = [NSString stringWithFormat:@"%@\x1f%@\x1f%@", a.bundleID, w[@"kind"], f];
            [tile addTarget:self action:@selector(lockAddWidget:) forControlEvents:UIControlEventTouchUpInside];
            CGFloat pw = inlineOnly ? MIN(fs.width, tw - 16) : fs.width, ph = inlineOnly ? fs.height : fs.height;
            UIImageView *pv = [[UIImageView alloc] initWithFrame:CGRectMake((tw - pw) / 2, inlineOnly ? 10 : 6, pw, ph)];
            NSString *snap = [HSWidgetsDir(a.bundleID) stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-snapshot.png", w[@"kind"], f]];
            pv.image = [UIImage imageWithContentsOfFile:snap]; pv.userInteractionEnabled = NO; pv.contentMode = UIViewContentModeScaleAspectFit;
            pv.accessibilityIdentifier = [NSString stringWithFormat:@"lock-preview-%@-%@", w[@"kind"], f];
            objc_setAssociatedObject(pv, "hssnapshot", snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [tile addSubview:pv];
            if (!inlineOnly) {
                UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(4, rowH - 34, tw - 8, 16)];
                l.text = w[@"name"]; l.textColor = UIColor.whiteColor; l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]; l.textAlignment = NSTextAlignmentCenter; l.userInteractionEnabled = NO;
                [tile addSubview:l];
            }
            [sheet addSubview:tile];
            x += tw + 10; n++;
        }
        y += rowH + 4;
    }
    if (!n) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, y, sheet.bounds.size.width - 40, 22)]; l.text = NSLocalizedString(@"No widgets", nil); l.textColor = UIColor.grayColor; [sheet addSubview:l]; }
    gallery = sheet;
    [editor addSubview:sheet];
    NSLog(@"SpringBoard: Lock Screen widget gallery (%@, %lu widget(s))", inlineOnly ? @"inline" : @"under the clock", (unsigned long)n);
}
- (void)closeLockGallery { [gallery removeFromSuperview]; gallery = nil; }
- (void)lockAddWidget:(UIControl *)tile {
    NSArray *p = [tile.accessibilityValue componentsSeparatedByString:@"\x1f"];
    NSDictionary *item = @{ @"app": p[0], @"widget": p[1], @"family": p[2] };
    if ([p[2] isEqual:@"accessoryInline"]) {
        edit_cfg[@"inline"] = item;
        NSLog(@"SpringBoard: Lock Screen editor: inline widget %@", p[1]);
        gallery = nil; [self showLockEditor];
        return;
    }
    NSInteger used = 0; for (NSDictionary *w in edit_cfg[@"widgets"]) used += units(w[@"family"]);
    if (used + units(p[2]) > 4) { NSLog(@"SpringBoard: Lock Screen editor: no room for %@ (%@)", p[1], p[2]); return; }
    [edit_cfg[@"widgets"] addObject:item];
    NSLog(@"SpringBoard: Lock Screen editor: added %@ (%@)", p[1], p[2]);
    [self showLockEditor];                                            /* the sheet stays open */
}
- (void)lockEditorCancel:(id)s {
    [editor removeFromSuperview]; editor = nil; gallery = nil; edit_cfg = nil;
    NSLog(@"SpringBoard: Lock Screen editor cancelled");
    isim_shell_request(ISIM_SHELL_SYSTEM, "lock-edit-done", NULL, "");
}
- (void)lockEditorDone:(id)s {
    NSMutableDictionary *cfg = [NSMutableDictionary dictionary];
    if (edit_cfg[@"inline"]) cfg[@"inline"] = edit_cfg[@"inline"];
    cfg[@"widgets"] = edit_cfg[@"widgets"] ?: @[];
    [cfg writeToFile:lock_file() atomically:YES];
    NSMutableArray *names = [NSMutableArray array];
    if (cfg[@"inline"]) [names addObject:[NSString stringWithFormat:@"%@ (accessoryInline)", cfg[@"inline"][@"widget"]]];
    for (NSDictionary *w in cfg[@"widgets"]) [names addObject:[NSString stringWithFormat:@"%@ (%@)", w[@"widget"], w[@"family"]]];
    NSLog(@"SpringBoard: Lock Screen widgets saved: %@", names.count ? [names componentsJoinedByString:@", "] : @"none");
    [editor removeFromSuperview]; editor = nil; gallery = nil; edit_cfg = nil;
    [self reloadLockWidgets];
    isim_shell_request(ISIM_SHELL_SYSTEM, "lock-edit-done", NULL, "");
}
@end
