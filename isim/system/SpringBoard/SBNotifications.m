// isim home screen: remote notifications and badges (the home screen stands in for apsd and SpringBoard's bulletins).
//
// Pushes arrive as "push BUNDLE FILE" (script command), "push-drop FILE" (a .apns file dropped on the device, with a
// "Simulator Target Bundle" key) or files in <isim data>/Library/isim/PushQueue (`isim push BUNDLE FILE|-`, named
// <time>-<bundle>.apns). The payload needs an "aps" dictionary, like `xcrun simctl push`; a top-level
// "apns-collapse-id" stands in for that APNs header (the notification's identifier). With "mutable-content": 1 and
// an alert, the app's Notification Service extension runs first (a helper process the shell starts: "ext-run"). The
// result goes to <isim data>/Library/isim/Push/<id>.plist and the shell delivers it ("push-deliver"): to the running
// app, else by launching it in the background (content-available with UIBackgroundModes remote-notification), else by
// showing the alert itself when the app may show alerts. The badge is applied here when the app may badge.
// Expanded notifications ("nc-expand"): the category's actions from the app's NotificationCategories.plist and the
// view of the app's Notification Content extension for that category ("ext-run" in content mode).
#import "SpringBoard.h"

static NSString *push_dir(void) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/Push"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
static NSString *queue_dir(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/PushQueue"]; }
static NSString *flat(NSString *s) { return [[[s ?: @"" componentsSeparatedByString:@"\n"] componentsJoinedByString:@"\x1e"] stringByReplacingOccurrencesOfString:@"\r" withString:@""]; }

/* the app's notification settings, from its preferences (UserNotifications keeps them there) */
static NSDictionary *app_prefs(HSApp *a) {
    return [NSDictionary dictionaryWithContentsOfFile:[a.containerPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", a.bundleID]]];
}
static NSInteger auth_status(HSApp *a) { return [app_prefs(a)[@"_ISIMNotificationAuthorization"] integerValue]; }
static NSInteger auth_options(HSApp *a) { return [app_prefs(a)[@"_ISIMNotificationOptions"] integerValue]; }
/* an extension of the app for an extension point (and, for content extensions, a category) */
static NSDictionary *app_extension(HSApp *a, NSString *point, NSString *category) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *ext = info[@"NSExtension"];
        if (![ext[@"NSExtensionPointIdentifier"] isEqual:point]) continue;
        if (category) {
            id cats = ext[@"NSExtensionAttributes"][@"UNNotificationExtensionCategory"];
            BOOL match = [cats isKindOfClass:[NSString class]] ? [cats isEqualToString:category] : [cats isKindOfClass:[NSArray class]] && [cats containsObject:category];
            if (!match) continue;
        }
        return @{ @"path": p, @"exe": [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension],
                  @"name": info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: n.stringByDeletingPathExtension };
    }
    return nil;
}
static NSUInteger ext_seq;
static NSMutableDictionary<NSString *, void (^)(NSDictionary *)> *ext_pending;    /* request path -> what to do with the result */
static void run_extension(NSDictionary *ext, NSDictionary *request, void (^done)(NSDictionary *result)) {
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Library/SpringBoard/Notifications"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *base = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"ext-%lu-%u", (unsigned long)++ext_seq, arc4random() % 100000]];
    NSString *req = [base stringByAppendingPathExtension:@"plist"], *out = [base stringByAppendingString:@"-result.plist"];
    NSMutableDictionary *r = [request mutableCopy]; r[@"out"] = out;
    [r writeToFile:req atomically:YES];
    if (!ext_pending) ext_pending = [NSMutableDictionary dictionary];
    ext_pending[req] = ^(NSDictionary *unused) { done([NSDictionary dictionaryWithContentsOfFile:out]); };
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [ext[@"exe"] UTF8String], req.UTF8String);
}
NSInteger HSBadgeCount(HSApp *a) {
    if (a.system) return 0;
    return [[NSDictionary dictionaryWithContentsOfFile:[a.containerPath stringByAppendingPathComponent:@"Library/isim/Badge.plist"]][@"count"] integerValue];
}
static void collect_icons(UIView *v, NSMutableArray *out) {
    if ([v isKindOfClass:[HSIcon class]]) [out addObject:v];
    for (UIView *s in v.subviews) collect_icons(s, out);
}

@implementation HomeViewController (Notifications)
- (void)installNotificationObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object, *verb = t, *args = @"";
        NSRange sp = [t rangeOfString:@" "];
        if (sp.location != NSNotFound) { verb = [t substringToIndex:sp.location]; args = [t substringFromIndex:sp.location + 1]; }
        if ([verb isEqualToString:@"push"]) {
            NSRange s2 = [args rangeOfString:@" "];
            if (s2.location == NSNotFound) { NSLog(@"SpringBoard: push: usage: push BUNDLE-ID FILE"); return; }
            [self deliverPushFile:[args substringFromIndex:s2.location + 1] bundle:[args substringToIndex:s2.location]];
        } else if ([verb isEqualToString:@"push-drop"]) {
            if (![args.pathExtension.lowercaseString isEqualToString:@"apns"]) { NSLog(@"SpringBoard: dropped %@: only .apns payload files can be dropped", args.lastPathComponent); return; }
            [self deliverPushFile:args bundle:nil];
        } else if ([verb isEqualToString:@"badge"]) {
            NSRange s2 = [args rangeOfString:@" " options:NSBackwardsSearch];
            if (s2.location != NSNotFound) [self showBadge:[[args substringFromIndex:s2.location + 1] integerValue] forPath:[args substringToIndex:s2.location]];
        } else if ([verb isEqualToString:@"ext-done"]) {
            NSRange s2 = [args rangeOfString:@" "];
            NSString *req = s2.location == NSNotFound ? args : [args substringFromIndex:s2.location + 1];
            void (^done)(NSDictionary *) = ext_pending[req];
            if (done) { [ext_pending removeObjectForKey:req]; done(nil); }
        } else if ([verb isEqualToString:@"nc-expand"]) [self expandNotification:args];
    }];
    /* `isim push` drops payloads here */
    [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *timer) { [self scanPushQueue]; }];
}
- (void)scanPushQueue {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *files = [[fm contentsOfDirectoryAtPath:queue_dir() error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *f in files) {
        if (![f hasSuffix:@".apns"]) continue;
        NSString *src = [queue_dir() stringByAppendingPathComponent:f];
        NSRange dash = [f rangeOfString:@"-"];
        NSString *bundle = dash.location == NSNotFound ? nil : [f.stringByDeletingPathExtension substringFromIndex:dash.location + 1];
        NSString *dst = [push_dir() stringByAppendingPathComponent:f];
        NSData *bytes = [NSData dataWithContentsOfFile:src];
        [fm removeItemAtPath:src error:NULL];
        if (!bytes || ![bytes writeToFile:dst atomically:YES]) continue;
        [self deliverPushFile:dst bundle:bundle.length ? bundle : nil];
    }
}
/* a payload file for an app: validate, run the service extension, hand it to the shell */
- (void)deliverPushFile:(NSString *)file bundle:(NSString *)bundle {
    NSData *data = [NSData dataWithContentsOfFile:file];
    NSError *err = nil;
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&err] : nil;
    if (![json isKindOfClass:[NSDictionary class]]) { NSLog(@"SpringBoard: push: %@ is not a JSON payload%@", file.lastPathComponent, data ? @"" : @" (cannot read it)"); return; }
    NSMutableDictionary *payload = [json mutableCopy];
    NSString *target = payload[@"Simulator Target Bundle"];
    [payload removeObjectForKey:@"Simulator Target Bundle"];
    if (!bundle.length) bundle = [target isKindOfClass:[NSString class]] ? target : nil;
    if (!bundle.length) { NSLog(@"SpringBoard: push: no bundle identifier (give one, or add \"Simulator Target Bundle\" to the payload)"); return; }
    if (![payload[@"aps"] isKindOfClass:[NSDictionary class]]) { NSLog(@"SpringBoard: push: the payload has no \"aps\" dictionary"); return; }
    HSApp *a = nil;
    for (HSApp *x in self.apps) if ([x.bundleID isEqualToString:bundle]) a = x;
    if (!a) { NSLog(@"SpringBoard: push: no installed app '%@'", bundle); return; }
    NSDictionary *aps = payload[@"aps"];
    /* the APNs apns-collapse-id header becomes the request identifier on iOS; a payload file has no headers, so isim reads
       it from a top-level "apns-collapse-id" key */
    NSString *collapse = [payload[@"apns-collapse-id"] isKindOfClass:[NSString class]] ? payload[@"apns-collapse-id"] : nil;
    [payload removeObjectForKey:@"apns-collapse-id"];
    NSString *ident = collapse.length ? collapse : NSUUID.UUID.UUIDString;
    id alert = aps[@"alert"];
    BOOL hasAlert = ([alert isKindOfClass:[NSString class]] && [alert length]) || ([alert isKindOfClass:[NSDictionary class]] && [alert count]);
    BOOL mutable = [aps[@"mutable-content"] respondsToSelector:@selector(intValue)] && [aps[@"mutable-content"] intValue] == 1;
    NSMutableArray *what = [NSMutableArray array];
    if (hasAlert) [what addObject:@"alert"];
    if (aps[@"badge"]) [what addObject:[NSString stringWithFormat:@"badge %@", aps[@"badge"]]];
    if (aps[@"sound"]) [what addObject:@"sound"];
    if ([aps[@"content-available"] intValue] == 1) [what addObject:@"content-available"];
    if (mutable) [what addObject:@"mutable-content"];
    NSLog(@"SpringBoard: push %@ for %@ (%@)", ident, a.name, what.count ? [what componentsJoinedByString:@", "] : @"empty aps");
    NSDictionary *service = mutable && hasAlert ? app_extension(a, @"com.apple.usernotifications.service", nil) : nil;
    if (service) {
        NSLog(@"SpringBoard: running the Notification Service extension %@", service[@"name"]);
        run_extension(service, @{ @"mode": @"service", @"push": @{ @"id": ident, @"payload": payload } }, ^(NSDictionary *result) {
            [self finishPush:payload id:ident app:a content:[result[@"content"] isKindOfClass:[NSDictionary class]] ? result[@"content"] : nil];
        });
        return;
    }
    [self finishPush:payload id:ident app:a content:nil];
}
- (void)finishPush:(NSDictionary *)payload id:(NSString *)ident app:(HSApp *)a content:(NSDictionary *)content {
    NSDictionary *aps = payload[@"aps"];
    NSMutableDictionary *w = [@{ @"id": ident, @"payload": payload } mutableCopy];
    if (content) w[@"content"] = content;
    NSString *file = [push_dir() stringByAppendingPathComponent:[ident stringByAppendingPathExtension:@"json"]];
    if ([NSJSONSerialization isValidJSONObject:w]) [[NSJSONSerialization dataWithJSONObject:w options:0 error:NULL] writeToFile:file atomically:YES];
    else { file = [file.stringByDeletingPathExtension stringByAppendingPathExtension:@"plist"]; [w writeToFile:file atomically:YES]; }
    /* what the user sees: the extension's content, else the payload's alert */
    NSString *title = @"", *subtitle = @"", *body = @"";
    id alert = aps[@"alert"];
    if ([alert isKindOfClass:[NSString class]]) body = alert;
    else if ([alert isKindOfClass:[NSDictionary class]]) {
        title = [alert[@"title"] isKindOfClass:[NSString class]] ? alert[@"title"] : alert[@"title-loc-key"] ?: @"";
        subtitle = [alert[@"subtitle"] isKindOfClass:[NSString class]] ? alert[@"subtitle"] : @"";
        body = [alert[@"body"] isKindOfClass:[NSString class]] ? alert[@"body"] : alert[@"loc-key"] ?: @"";
    }
    NSArray *attachments = @[];
    if (content) { title = content[@"title"] ?: @""; subtitle = content[@"subtitle"] ?: @""; body = content[@"body"] ?: @""; attachments = content[@"attachments"] ?: @[]; }
    NSNumber *badge = content[@"badge"] ?: ([aps[@"badge"] isKindOfClass:[NSNumber class]] ? aps[@"badge"] : nil);
    NSInteger status = auth_status(a), opts = auth_options(a);
    BOOL authorized = status == 2 || status == 3 || status == 4;
    BOOL mayAlert = authorized && ((opts & 4) || status == 3), mayBadge = (status == 2 || status == 4) && (opts & 1);
    BOOL hasAlert = title.length || subtitle.length || body.length;
    NSArray *modes = a.info[@"UIBackgroundModes"];
    BOOL contentAvailable = [aps[@"content-available"] respondsToSelector:@selector(intValue)] && [aps[@"content-available"] intValue] == 1;
    BOOL launch = contentAvailable && [modes isKindOfClass:[NSArray class]] && [modes containsObject:@"remote-notification"];
    if (badge && mayBadge) {                                   /* the system applies the badge, like iOS */
        NSString *bf = [a.containerPath stringByAppendingPathComponent:@"Library/isim/Badge.plist"];
        [NSFileManager.defaultManager createDirectoryAtPath:bf.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
        [@{ @"count": badge } writeToFile:bf atomically:YES];
        [self showBadge:badge.integerValue forPath:a.path];
    } else if (badge) NSLog(@"SpringBoard: badge %@ for %@ not shown (no badge permission)", badge, a.name);
    if (hasAlert && !authorized) NSLog(@"SpringBoard: push %@ for %@: notifications are not allowed for the app", ident, a.name);
    /* the record the shell's Notification Center item points to (expanding it, opening it after a relaunch) */
    NSString *record = [[a.containerPath stringByAppendingPathComponent:@"Library/isim/Notifications"] stringByAppendingPathComponent:[ident stringByAppendingPathExtension:@"plist"]];
    [NSFileManager.defaultManager createDirectoryAtPath:record.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *category = content[@"category"] ?: ([aps[@"category"] isKindOfClass:[NSString class]] ? aps[@"category"] : @"");
    NSMutableDictionary *rec = [@{ @"id": ident, @"title": title, @"subtitle": subtitle, @"body": body, @"category": category,
        @"thread": content[@"thread"] ?: aps[@"thread-id"] ?: @"", @"userInfo": content[@"userInfo"] ?: payload, @"date": [NSDate date],
        @"attachments": attachments, @"push": @YES, @"app": a.bundleID } mutableCopy];
    if (badge) rec[@"badge"] = badge;
    if (![rec writeToFile:record atomically:YES]) { rec[@"userInfo"] = @{}; [rec writeToFile:record atomically:YES]; }
    NSString *thumb = @"";
    for (NSDictionary *x in attachments) if ([@[@"public.png", @"public.jpeg", @"com.compuserve.gif", @"public.heic"] containsObject:x[@"type"] ?: @""]) { thumb = x[@"path"]; break; }
    NSString *flags = [NSString stringWithFormat:@"%@%@", hasAlert && mayAlert ? @"a" : @"", launch ? @"c" : @""];
    NSString *bodyText = subtitle.length ? [NSString stringWithFormat:@"%@\n%@", subtitle, body] : body;
    NSString *side = [push_dir() stringByAppendingPathComponent:[ident stringByAppendingPathExtension:@"txt"]];
    NSString *sidecar = [NSString stringWithFormat:@"file=%@\nflags=%@\nid=%@\ntitle=%@\nbody=%@\nicon=%@\nrecord=%@\nthumb=%@\n",
                         file, flags, ident, flat(title.length ? title : a.name), flat(bodyText), a.iconPath ?: @"", record, thumb];
    [sidecar writeToFile:side atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *c = [NSString stringWithFormat:@"%@\x1f%@", a.executable, side];
    isim_shell_request(ISIM_SHELL_SYSTEM, "push-deliver", a.path.UTF8String, c.UTF8String);
}
- (void)showBadge:(NSInteger)n forPath:(NSString *)path {
    NSMutableArray *icons = [NSMutableArray array];
    collect_icons(self.view, icons);
    for (HSIcon *i in icons) if ([i.app.path.stringByStandardizingPath isEqualToString:path.stringByStandardizingPath]) [i setBadgeCount:n];
    NSLog(@"SpringBoard: badge %ld on %@", (long)n, path.lastPathComponent.stringByDeletingPathExtension);
}
/* "PATH\x1fRECORD\x1fID": the category's actions and the Content extension's view, answered with "nc-expanded" */
- (void)expandNotification:(NSString *)args {
    NSArray *p = [args componentsSeparatedByString:@"\x1f"];
    if (p.count < 3) return;
    NSString *path = p[0], *recordPath = p[1];
    HSApp *a = nil;
    for (HSApp *x in self.apps) if ([x.path.stringByStandardizingPath isEqualToString:[path stringByStandardizingPath]]) a = x;
    NSDictionary *rec = [NSDictionary dictionaryWithContentsOfFile:recordPath];
    NSString *category = rec[@"category"] ?: @"";
    NSDictionary *cat = nil;
    for (NSDictionary *c in [NSDictionary dictionaryWithContentsOfFile:[a.containerPath stringByAppendingPathComponent:@"Library/isim/NotificationCategories.plist"]][@"categories"])
        if ([c[@"id"] isEqual:category]) cat = c;
    NSDictionary *ext = a && category.length && rec ? app_extension(a, @"com.apple.usernotifications.content-extension", category) : nil;
    void (^answer)(NSDictionary *) = ^(NSDictionary *result) {
        NSMutableString *s = [NSMutableString string];
        if (result[@"image"]) [s appendFormat:@"image=%@\nheight=%@\nhidden=%d\n", result[@"image"], result[@"height"], [result[@"defaultContentHidden"] boolValue]];
        [s appendFormat:@"dismiss=%d\n", ([cat[@"options"] integerValue] & 1) != 0];
        for (NSDictionary *x in cat[@"actions"])
            [s appendFormat:@"action=%@\x1e%@\x1e%@\x1e%d\x1e%@\x1e%@\n", flat(x[@"id"]), flat(x[@"title"]), x[@"options"] ?: @0, [x[@"textInput"] boolValue], flat(x[@"button"]), flat(x[@"placeholder"])];
        NSString *side = [push_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"expand-%u.txt", arc4random()]];
        [s writeToFile:side atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSLog(@"SpringBoard: expanded notification %@ (category %@: %lu action(s)%@)", p[2], category.length ? category : @"none",
              (unsigned long)[cat[@"actions"] count], result[@"image"] ? @", content extension" : @"");
        isim_shell_request(ISIM_SHELL_SYSTEM, "nc-expanded", recordPath.UTF8String, side.UTF8String);
    };
    if (!ext) { answer(nil); return; }
    NSLog(@"SpringBoard: running the Notification Content extension %@", ext[@"name"]);
    CGFloat width = MIN(self.view.bounds.size.width - 16, 400);
    run_extension(ext, @{ @"mode": @"content", @"record": recordPath, @"width": @(width) }, ^(NSDictionary *result) { answer(result[@"image"] ? result : nil); });
}
@end
