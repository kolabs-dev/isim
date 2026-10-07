// isim home screen: app metadata the system needs (icons incl. alternate icons, quick actions, URL handlers)
// and the shell's system requests (open a URL in an app, launch a background task, reload).
#import "SpringBoard.h"

@implementation HSApp
- (NSString *)containerPath { return [[isim_data_dir() stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:self.bundleID ?: @"unknown"]; }
@end

static NSString *largest_icon_file(NSString *app, NSArray *files) {
    NSString *best = nil; double bestScore = -1;
    for (NSDictionary *f in files) {
        if ([f[@"appearance"] isEqualToString:@"dark"] || [f[@"appearance"] isEqualToString:@"tinted"]) continue;
        NSString *size = f[@"size"] ?: @"1024x1024";
        double px = [[size componentsSeparatedByString:@"x"].firstObject doubleValue] * ([f[@"scale"] doubleValue] ?: 1);
        if (px > bestScore) { bestScore = px; best = f[@"file"]; }
    }
    return best ? [app stringByAppendingPathComponent:best] : nil;
}
/* CFBundleIconFiles names ("Icon-Dark", "Icon-Dark60x60") -> the largest matching file in the bundle */
static NSString *icon_file_named(NSString *app, NSArray *names) {
    NSString *best = nil; unsigned long long bestSize = 0;
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:app error:NULL];
    for (NSString *n in names) for (NSString *f in contents) {
        if (![f.pathExtension.lowercaseString isEqualToString:@"png"] || ![f hasPrefix:n]) continue;
        unsigned long long sz = [NSData dataWithContentsOfFile:[app stringByAppendingPathComponent:f]].length;
        if (sz > bestSize) { bestSize = sz; best = [app stringByAppendingPathComponent:f]; }
    }
    return best;
}
NSString *HSIconPath(NSString *app, NSDictionary *info, NSString *bundleID) {
    NSDictionary *assets = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"isim-assets.plist"]];
    NSDictionary *icons = assets[@"appIcons"];
    /* the alternate icon the app chose (UIApplication.setAlternateIconName) */
    NSString *container = [[isim_data_dir() stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:bundleID ?: @""];
    NSString *alt = [NSDictionary dictionaryWithContentsOfFile:[container stringByAppendingPathComponent:@"Library/isim/AlternateIcon.plist"]][@"name"];
    if (alt) {
        NSDictionary *spec = info[@"CFBundleIcons"][@"CFBundleAlternateIcons"][alt];
        NSString *setName = spec[@"CFBundleIconName"] ?: alt;
        NSString *f = icons[setName] ? largest_icon_file(app, icons[setName]) : nil;
        if (!f && [spec[@"CFBundleIconFiles"] isKindOfClass:[NSArray class]]) f = icon_file_named(app, spec[@"CFBundleIconFiles"]);
        if (f) return f;
    }
    NSString *name = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"] ?: @"AppIcon";
    NSString *best = largest_icon_file(app, icons[name] ?: icons.allValues.firstObject);
    if (best) return best;
    NSArray *files = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    if ([files isKindOfClass:[NSArray class]] && (best = icon_file_named(app, files))) return best;
    NSString *plain = [app stringByAppendingPathComponent:@"icon.png"];
    return [NSFileManager.defaultManager fileExistsAtPath:plain] ? plain : nil;
}

static NSString *symbol_for_type_name(NSString *n) {
    NSDictionary *m = @{ @"Compose": @"square.and.pencil", @"Play": @"play.fill", @"Pause": @"pause.fill", @"Add": @"plus", @"Location": @"location.fill",
        @"Search": @"magnifyingglass", @"Share": @"square.and.arrow.up", @"Prohibit": @"nosign", @"Contact": @"person.crop.circle", @"Home": @"house.fill",
        @"MarkLocation": @"mappin.and.ellipse", @"Favorite": @"star.fill", @"Love": @"heart.fill", @"Cloud": @"cloud.fill", @"Invitation": @"envelope.open.fill",
        @"Confirmation": @"checkmark.circle.fill", @"Mail": @"envelope.fill", @"Message": @"message.fill", @"Date": @"calendar", @"Time": @"clock.fill",
        @"CapturePhoto": @"camera.fill", @"CaptureVideo": @"video.fill", @"Task": @"circle", @"TaskCompleted": @"checkmark.circle", @"Alarm": @"alarm.fill",
        @"Bookmark": @"book.fill", @"Shuffle": @"shuffle", @"Audio": @"speaker.wave.2.fill", @"Update": @"arrow.clockwise" };
    if ([n hasPrefix:@"UIApplicationShortcutIconType"]) n = [n substringFromIndex:29];
    return m[n];
}
NSArray<NSDictionary *> *HSQuickActions(HSApp *app) {
    NSMutableArray *out = [NSMutableArray array];
    NSBundle *b = [NSBundle bundleWithPath:app.path];
    for (NSDictionary *d in app.info[@"UIApplicationShortcutItems"]) {
        if (![d isKindOfClass:[NSDictionary class]] || !d[@"UIApplicationShortcutItemType"]) continue;
        NSString *title = d[@"UIApplicationShortcutItemTitle"] ?: @"", *sub = d[@"UIApplicationShortcutItemSubtitle"];
        title = [b localizedStringForKey:title value:title table:@"InfoPlist"];
        if (sub) sub = [b localizedStringForKey:sub value:sub table:@"InfoPlist"];
        NSString *sym = d[@"UIApplicationShortcutItemIconSymbolName"] ?: (d[@"UIApplicationShortcutItemIconType"] ? symbol_for_type_name(d[@"UIApplicationShortcutItemIconType"]) : nil);
        NSMutableDictionary *e = [@{ @"type": d[@"UIApplicationShortcutItemType"], @"title": title } mutableCopy];
        if (sub) e[@"subtitle"] = sub;
        if (sym) e[@"symbol"] = sym;
        [out addObject:e];
    }
    NSDictionary *dyn = [NSDictionary dictionaryWithContentsOfFile:[app.containerPath stringByAppendingPathComponent:@"Library/isim/ShortcutItems.plist"]];
    for (NSDictionary *d in dyn[@"items"]) if (d[@"type"]) [out addObject:d];
    return out.count > 4 ? [out subarrayWithRange:NSMakeRange(0, 4)] : out;
}

/* associated domains: <App>.app/archived-expanded-entitlements.xcent (like Xcode simulator builds; isim build writes
   it from CODE_SIGN_ENTITLEMENTS); "applinks:host" entries make https://host/... universal links for that app. isim does not
   fetch apple-app-site-association files (offline), so every path on the domain opens the app. */
static BOOL app_claims_host(HSApp *a, NSString *host) {
    NSDictionary *ent = [NSDictionary dictionaryWithContentsOfFile:[a.path stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
    for (NSString *d in ent[@"com.apple.developer.associated-domains"]) {
        if (![d hasPrefix:@"applinks:"]) continue;
        NSString *h = [[d substringFromIndex:9] componentsSeparatedByString:@"?"].firstObject.lowercaseString;
        if ([h hasPrefix:@"*."] ? ([host hasSuffix:[h substringFromIndex:1]] || [host isEqualToString:[h substringFromIndex:2]]) : [h isEqualToString:host]) return YES;
    }
    return NO;
}
HSApp *HSAppForURL(NSArray<HSApp *> *apps, NSURL *url, BOOL *universal) {
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    *universal = NO;
    if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) {
        NSString *host = url.host.lowercaseString ?: @"";
        for (HSApp *a in apps) if ([scheme isEqualToString:@"https"] && app_claims_host(a, host)) { *universal = YES; return a; }
        return nil;
    }
    for (HSApp *a in apps) for (NSDictionary *t in a.info[@"CFBundleURLTypes"])
        for (NSString *s in t[@"CFBundleURLSchemes"]) if ([s.lowercaseString isEqualToString:scheme]) return a;
    return nil;
}

@implementation HomeViewController (System)
- (void)installSystemObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object, *verb = t, *args = @"";
        NSRange sp = [t rangeOfString:@" "];
        if (sp.location != NSNotFound) { verb = [t substringToIndex:sp.location]; args = [t substringFromIndex:sp.location + 1]; }
        if ([verb isEqualToString:@"reload"]) [self reload];
        else if ([verb isEqualToString:@"openurl"]) [self openURLString:args];
        else if ([verb isEqualToString:@"launchtask"]) [self backgroundTask:args];
        else if ([verb isEqualToString:@"set-appearance"]) {          /* Control Center's Dark Mode: the same setting as Settings */
            NSUserDefaults *g = [[NSUserDefaults alloc] initWithSuiteName:@".GlobalPreferences"];
            if ([args isEqualToString:@"dark"]) [g setObject:@"Dark" forKey:@"AppleInterfaceStyle"]; else [g removeObjectForKey:@"AppleInterfaceStyle"];
            NSLog(@"SpringBoard: appearance %@", args);
        }
        else if ([verb isEqualToString:@"spotlight"]) [NSNotificationCenter.defaultCenter postNotificationName:@"_SBShowSpotlight" object:nil];
    }];
}
- (void)openURLString:(NSString *)s {
    NSURL *url = [NSURL URLWithString:s];
    if (!url) { NSLog(@"SpringBoard: not a URL: %@", s); return; }
    BOOL universal = NO;
    HSApp *a = HSAppForURL(self.apps, url, &universal);
    if (!a) {
        BOOL host = isim_open_url(s.UTF8String);
        NSLog(@"SpringBoard: no app handles %@%@", s, host ? @" (opened on the host)" : @" (no browser on isim)");
        return;
    }
    NSLog(@"SpringBoard: %@ opens %@%@", a.name, s, universal ? @" (universal link)" : @"");
    [self launch:a url:universal ? [@"isim-universal:" stringByAppendingString:s] : s];
}
/* "bgtask BUNDLE-ID TASK-ID": start the app in the background if needed and launch the task */
- (void)backgroundTask:(NSString *)args {
    NSArray *parts = [args componentsSeparatedByString:@" "];
    HSApp *a = parts.count >= 2 ? [self appWithIdentifier:parts[0]] : nil;
    if (!a) { NSLog(@"SpringBoard: bgtask: no installed app '%@' (usage: bgtask BUNDLE-ID TASK-ID)", parts.firstObject ?: @""); return; }
    NSString *exeURL = [NSString stringWithFormat:@"%@\x1fisim-bgtask:%@", a.executable, parts[1]];
    NSLog(@"SpringBoard: background task %@ for %@", parts[1], a.name);
    isim_shell_request(ISIM_SHELL_SYSTEM, "launch-bg", a.path.UTF8String, exeURL.UTF8String);
}
- (void)publishAppInfo {
    for (HSApp *a in self.apps) {
        NSString *v = [NSString stringWithFormat:@"%@\x1f%@", a.name, a.iconPath ?: @""];
        isim_shell_request(ISIM_SHELL_SYSTEM, "appinfo", a.path.UTF8String, v.UTF8String);
    }
}
@end
