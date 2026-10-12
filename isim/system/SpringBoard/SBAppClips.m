// isim home screen: App Clips (adapted). An App Clip is an app whose Info.plist has NSAppClip; `isim install`ing it (or
// `isim run`) stands in for iOS caching it from the App Store (like Xcode running it on a device), and it stays off the
// home screen. An invocation is a URL:
//   - script `appclip URL [code|nfc]`: scanning an App Clip Code, QR code (code, the default) or NFC tag (nfc) for it;
//   - `openurl URL` (and links opened by apps): a link (Safari, Messages), when no app claims it as a universal link.
// The URL matches a local experience (Settings > Developer > Local Experiences, or `appclip register`; the longest URL
// prefix wins), else an installed App Clip's appclips: associated domain (its default experience; isim has no App Store
// Connect, so the card shows the App Clip's name and the URL's host). With a default experience, when the full app is
// installed (the App Clip's parent-application-identifiers entitlement) the full app opens instead, with the URL (iOS:
// the full app replaces the App Clip); local experiences always launch the App Clip, as on iOS. Otherwise the shell shows
// the App Clip card (runtime/shell_appclip.inc); its button launches the App Clip with an NSUserActivity of type
// NSUserActivityTypeBrowsingWeb and the URL. The invocation and the card's choices go to the App Clip's container
// (Library/isim/AppClip.plist: AppClip's location confirmation, UserNotifications' ephemeral authorization read them).
// Recently used App Clips are in the App Library (Recently Added); launched from there they get their last URL.
// `appclip expire BUNDLE_ID` plays iOS removing an App Clip after a period of inactivity: its data goes (container, app
// group containers no installed app still uses, App Library entry); the bundle stays as the App Store's copy.
#import "SpringBoard.h"

static NSArray<HSApp *> *installed_clips;

static NSString *isim_dir(void) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
static NSString *experiences_file(void) { return [isim_dir() stringByAppendingPathComponent:@"AppClipExperiences.plist"]; }
static NSString *recents_file(void) { return [isim_dir() stringByAppendingPathComponent:@"AppClipRecents.plist"]; }
static NSArray<NSDictionary *> *local_experiences(void) {
    NSArray *a = [NSDictionary dictionaryWithContentsOfFile:experiences_file()][@"experiences"];
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}
static void save_experiences(NSArray *a) { [@{ @"experiences": a } writeToFile:experiences_file() atomically:YES]; }
static NSMutableArray<NSDictionary *> *recents(void) {
    NSArray *a = [NSDictionary dictionaryWithContentsOfFile:recents_file()][@"clips"];
    return [a isKindOfClass:[NSArray class]] ? [a mutableCopy] : [NSMutableArray array];
}
static void save_recents(NSArray *a) { [@{ @"clips": a } writeToFile:recents_file() atomically:YES]; }
static NSDictionary *entitlements(HSApp *a) {
    return [NSDictionary dictionaryWithContentsOfFile:[a.path stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]] ?: @{};
}
/* the full app's bundle identifiers: com.apple.developer.parent-application-identifiers without the team prefix */
static NSArray<NSString *> *parent_ids(HSApp *clip) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in entitlements(clip)[@"com.apple.developer.parent-application-identifiers"]) {
        if (![p isKindOfClass:[NSString class]]) continue;
        NSRange dot = [p rangeOfString:@"."];
        NSString *team = dot.location == 10 ? [p substringToIndex:10] : nil;
        BOOL prefixed = team && [team rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"].invertedSet].location == NSNotFound;
        [out addObject:prefixed ? [p substringFromIndex:11] : p];
    }
    if (!out.count && [clip.bundleID containsString:@"."]) [out addObject:clip.bundleID.stringByDeletingPathExtension];   /* com.example.app.Clip */
    return out;
}
static BOOL clip_claims_host(HSApp *clip, NSString *host) {
    for (NSString *d in entitlements(clip)[@"com.apple.developer.associated-domains"]) {
        if (![d isKindOfClass:[NSString class]] || ![d hasPrefix:@"appclips:"]) continue;
        NSString *h = [[d substringFromIndex:9] componentsSeparatedByString:@"?"].firstObject.lowercaseString;
        if ([h hasPrefix:@"*."] ? ([host hasSuffix:[h substringFromIndex:1]] || [host isEqualToString:[h substringFromIndex:2]]) : [h isEqualToString:host]) return YES;
    }
    return NO;
}
static NSString *requested(HSApp *clip, NSString *key) { return [clip.info[@"NSAppClip"][key] boolValue] ? @"1" : @"0"; }
static NSString *one_line(NSString *s) { return [[s ?: @"" componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] componentsJoinedByString:@" "]; }

@implementation HomeViewController (AppClips)
- (void)setInstalledAppClips:(NSArray<HSApp *> *)clips { installed_clips = [clips copy]; }
- (HSApp *)appClipWithIdentifier:(NSString *)ident {
    for (HSApp *c in installed_clips) if ([c.bundleID isEqualToString:ident] || [c.name isEqualToString:ident]) return c;
    return nil;
}
- (HSApp *)fullAppOf:(HSApp *)clip {
    for (NSString *pid in parent_ids(clip)) for (HSApp *a in self.apps) if (!a.system && [a.bundleID isEqualToString:pid]) return a;
    return nil;
}
- (NSArray<HSApp *> *)recentAppClips {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *r in recents()) {
        HSApp *c = [self appClipWithIdentifier:r[@"bundleID"]];
        if (c && ![self fullAppOf:c]) [out addObject:c];               /* replaced by its full app: gone from the library */
    }
    return out;
}

/* the experience for a URL: a local one (longest prefix), else an installed App Clip's appclips: domain */
- (NSDictionary *)experienceForURL:(NSURL *)url {
    NSString *s = url.absoluteString;
    NSDictionary *best = nil;
    for (NSDictionary *e in local_experiences()) {
        NSString *prefix = e[@"url"];
        if (![prefix isKindOfClass:[NSString class]] || !prefix.length) continue;
        BOOL match = [s hasPrefix:prefix] || [[s stringByAppendingString:@"/"] isEqualToString:prefix];
        if (match && (!best || prefix.length > [best[@"url"] length])) best = e;
    }
    if (best) return best;
    NSString *host = url.host.lowercaseString;
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || !host.length) return nil;
    for (HSApp *c in installed_clips) if (clip_claims_host(c, host)) return @{ @"bundleID": c.bundleID, @"default": @YES };
    return nil;
}

- (BOOL)openAppClipURL:(NSURL *)url source:(NSString *)source {
    if (!url) return NO;
    NSDictionary *e = [self experienceForURL:url];
    if (!e) {
        if (![source isEqualToString:@"link"]) NSLog(@"SpringBoard: no App Clip experience for %@ (no local experience, no installed App Clip with an appclips: domain for it)", url.absoluteString);
        return ![source isEqualToString:@"link"];
    }
    BOOL local = ![e[@"default"] boolValue];
    HSApp *clip = [self appClipWithIdentifier:e[@"bundleID"]];
    if (!clip) {
        NSLog(@"SpringBoard: the App Clip %@ of the local experience %@ is not on the device (isim install it, as Xcode caches it by running it)", e[@"bundleID"], e[@"url"]);
        return YES;
    }
    HSApp *full = nil;
    if (!local) {                                     /* an app installed since the last scan counts too */
        full = [self fullAppOf:clip];
        for (NSString *pid in parent_ids(clip)) if (!full) { HSApp *a = [self appWithIdentifier:pid]; if (a && !a.system && !a.appClip) full = a; }
    }
    if (full) {                                       /* the full app replaces its App Clip: it gets the invocation */
        NSLog(@"SpringBoard: %@ is installed: it opens %@ instead of its App Clip", full.name, url.absoluteString);
        [self launch:full url:[self activityMarkerForURL:url]];
        return YES;
    }
    /* the App Clip card */
    NSString *title = e[@"title"], *subtitle = e[@"subtitle"];
    if (!local) { title = clip.name; subtitle = url.host; }        /* default experience: App Store Connect's metadata is not available */
    NSString *sidecar = [isim_dir() stringByAppendingPathComponent:[NSString stringWithFormat:@"appclip-card-%@.txt", NSUUID.UUID.UUIDString]];
    NSString *card = [NSString stringWithFormat:@"clip=%@\nbundle=%@\nurl=%@\nsource=%@\nlocal=%d\ntitle=%@\nsubtitle=%@\naction=%@\nimage=%@\nicon=%@\nname=%@\nnotifications=%@\nlocation=%@\n",
        clip.path, clip.bundleID, url.absoluteString, source, local, one_line(title.length ? title : clip.name), one_line(subtitle),
        one_line([e[@"action"] length] ? e[@"action"] : @"Open"), e[@"image"] ?: @"", clip.iconPath ?: @"", one_line(clip.name),
        requested(clip, @"NSAppClipRequestEphemeralUserNotification"), requested(clip, @"NSAppClipRequestLocationConfirmation")];
    [card writeToFile:sidecar atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSLog(@"SpringBoard: App Clip card for %@ (%@, %@ experience, from %@)", clip.bundleID, url.absoluteString, local ? @"local" : @"default",
          [source isEqualToString:@"link"] ? @"a link" : [source isEqualToString:@"nfc"] ? @"an NFC tag" : @"a code");
    isim_shell_request(ISIM_SHELL_SYSTEM, "appclip-card", sidecar.UTF8String, "");
    return YES;
}
- (NSString *)activityMarkerForURL:(NSURL *)url {
    NSString *dir = [isim_dir() stringByAppendingPathComponent:@"Activities"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *path = [dir stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"plist"]];
    [@{ @"activityType": NSUserActivityTypeBrowsingWeb, @"webpageURL": url.absoluteString } writeToFile:path atomically:YES];
    return [@"isim-activity:" stringByAppendingString:path];
}
/* the invocation for the App Clip: Library/isim/AppClip.plist in its container */
- (void)recordInvocation:(HSApp *)clip url:(NSString *)url source:(NSString *)source registered:(BOOL)registered
           notifications:(NSNumber *)notifications location:(NSNumber *)location {
    NSString *dir = [clip.containerPath stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *f = [dir stringByAppendingPathComponent:@"AppClip.plist"];
    NSMutableDictionary *st = [[NSDictionary dictionaryWithContentsOfFile:f] mutableCopy] ?: [NSMutableDictionary dictionary];
    st[@"invocationURL"] = url; st[@"source"] = source; st[@"registered"] = @(registered);
    st[@"invokedAt"] = @([NSDate date].timeIntervalSince1970);
    if (notifications) st[@"notifications"] = notifications;
    if (location) st[@"locationConfirmation"] = location;
    [st writeToFile:f atomically:YES];
    NSMutableArray *r = recents();
    for (NSUInteger i = r.count; i-- > 0;) if ([r[i][@"bundleID"] isEqualToString:clip.bundleID]) [r removeObjectAtIndex:i];
    [r insertObject:@{ @"bundleID": clip.bundleID, @"url": url, @"date": [NSDate date] } atIndex:0];
    save_recents(r);
}
- (void)appClipCardAnswer:(NSString *)verb args:(NSString *)args {
    NSArray *parts = [args componentsSeparatedByString:@"\x1f"];
    NSString *sidecar = parts.firstObject;
    NSMutableDictionary *card = [NSMutableDictionary dictionary];
    for (NSString *line in [[NSString stringWithContentsOfFile:sidecar encoding:NSUTF8StringEncoding error:NULL] ?: @"" componentsSeparatedByString:@"\n"]) {
        NSRange eq = [line rangeOfString:@"="];
        if (eq.location != NSNotFound) card[[line substringToIndex:eq.location]] = [line substringFromIndex:eq.location + 1];
    }
    [NSFileManager.defaultManager removeItemAtPath:sidecar error:NULL];
    if (![verb isEqualToString:@"appclip-open"]) { NSLog(@"SpringBoard: App Clip card dismissed (%@ not launched)", card[@"bundle"]); return; }
    HSApp *clip = [self appClipWithIdentifier:card[@"bundle"] ?: @""];
    NSURL *url = [NSURL URLWithString:card[@"url"] ?: @""];
    if (!clip || !url) { NSLog(@"SpringBoard: App Clip card: %@ is gone", card[@"bundle"]); return; }
    BOOL notifReq = [card[@"notifications"] isEqualToString:@"1"], locReq = [card[@"location"] isEqualToString:@"1"];
    [self recordInvocation:clip url:url.absoluteString source:card[@"source"] ?: @"code" registered:YES
             notifications:notifReq ? @([parts.count > 1 ? parts[1] : @"1" boolValue]) : nil
                  location:locReq ? @([parts.count > 2 ? parts[2] : @"1" boolValue]) : nil];
    NSLog(@"SpringBoard: App Clip %@ opens %@", clip.name, url.absoluteString);
    [self launch:clip url:[self activityMarkerForURL:url]];
    [self reload];                                                 /* the App Library's Recently Added */
}
- (NSString *)appClipRelaunchURL:(HSApp *)clip {
    NSDictionary *last = nil;
    for (NSDictionary *r in recents()) if ([r[@"bundleID"] isEqualToString:clip.bundleID]) { last = r; break; }
    NSURL *url = last ? [NSURL URLWithString:last[@"url"]] : nil;
    if (!url) return nil;
    NSLog(@"SpringBoard: App Clip %@ from the App Library, with its last invocation %@", clip.name, url.absoluteString);
    NSString *f = [clip.containerPath stringByAppendingPathComponent:@"Library/isim/AppClip.plist"];
    NSMutableDictionary *st = [[NSDictionary dictionaryWithContentsOfFile:f] mutableCopy] ?: [NSMutableDictionary dictionary];
    st[@"source"] = @"library"; st[@"invocationURL"] = url.absoluteString;
    [st writeToFile:f atomically:YES];
    return [self activityMarkerForURL:url];
}

/* iOS removes an App Clip that was not used for a while, with its data */
- (void)expireAppClip:(NSString *)ident {
    HSApp *clip = [self appClipWithIdentifier:ident];
    if (!clip) { NSLog(@"SpringBoard: appclip expire: no App Clip '%@' on the device", ident); return; }
    isim_shell_request(ISIM_SHELL_TERMINATE_APP, clip.path.UTF8String, NULL, NULL);
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm removeItemAtPath:clip.containerPath error:NULL];
    NSMutableArray *gone = [NSMutableArray arrayWithObject:@"container"];
    for (NSString *g in entitlements(clip)[@"com.apple.security.application-groups"]) {
        BOOL used = NO;                                /* an app group stays while an installed app belongs to it */
        for (HSApp *a in self.apps) if ([entitlements(a)[@"com.apple.security.application-groups"] containsObject:g]) used = YES;
        if (used) continue;
        [fm removeItemAtPath:[[isim_data_dir() stringByAppendingPathComponent:@"Shared/AppGroup"] stringByAppendingPathComponent:g] error:NULL];
        [gone addObject:[NSString stringWithFormat:@"app group %@", g]];
    }
    NSMutableArray *r = recents();
    for (NSUInteger i = r.count; i-- > 0;) if ([r[i][@"bundleID"] isEqualToString:clip.bundleID]) [r removeObjectAtIndex:i];
    save_recents(r);
    NSLog(@"SpringBoard: App Clip %@ removed after inactivity: its data is deleted (%@)", clip.bundleID, [gone componentsJoinedByString:@", "]);
    [self reload];
}

/* script `appclip URL [code|nfc]`, `appclip register PREFIX BUNDLE_ID ACTION|TITLE|SUBTITLE[|IMAGE]`,
   `appclip unregister PREFIX|all`, `appclip expire BUNDLE_ID`, `appclip list` */
- (void)appClipCommand:(NSString *)args {
    NSMutableArray *w = [[args componentsSeparatedByString:@" "] mutableCopy];
    [w removeObject:@""];
    NSString *verb = w.firstObject ?: @"";
    if ([verb isEqualToString:@"register"] && w.count >= 4) {
        NSString *rest = [[w subarrayWithRange:NSMakeRange(3, w.count - 3)] componentsJoinedByString:@" "];
        NSArray *f = [rest componentsSeparatedByString:@"|"];
        NSMutableDictionary *e = [@{ @"url": w[1], @"bundleID": w[2], @"action": f[0], @"title": f.count > 1 ? f[1] : @"",
                                     @"subtitle": f.count > 2 ? f[2] : @"" } mutableCopy];
        if (f.count > 3 && [f[3] length]) e[@"image"] = f[3];
        NSMutableArray *all = [local_experiences() mutableCopy];
        for (NSUInteger i = all.count; i-- > 0;) if ([all[i][@"url"] isEqualToString:w[1]]) [all removeObjectAtIndex:i];
        [all addObject:e];
        save_experiences(all);
        NSLog(@"SpringBoard: local App Clip experience %@ -> %@ (%@ “%@”)", w[1], w[2], e[@"action"], e[@"title"]);
    } else if ([verb isEqualToString:@"unregister"] && w.count >= 2) {
        NSMutableArray *all = [local_experiences() mutableCopy];
        NSUInteger before = all.count;
        if ([w[1] isEqualToString:@"all"]) [all removeAllObjects];
        else for (NSUInteger i = all.count; i-- > 0;) if ([all[i][@"url"] isEqualToString:w[1]]) [all removeObjectAtIndex:i];
        save_experiences(all);
        NSLog(@"SpringBoard: %lu local App Clip experience(s) removed", (unsigned long)(before - all.count));
    } else if ([verb isEqualToString:@"expire"] && w.count >= 2) {
        [self expireAppClip:w[1]];
    } else if ([verb isEqualToString:@"list"]) {
        for (HSApp *c in installed_clips) {
            HSApp *full = [self fullAppOf:c];
            NSLog(@"SpringBoard: App Clip %@ (%@)%@", c.bundleID, c.name, full ? [NSString stringWithFormat:@", replaced by its full app %@", full.bundleID] : @"");
        }
        for (NSDictionary *e in local_experiences()) NSLog(@"SpringBoard: local experience %@ -> %@ (%@ “%@”)", e[@"url"], e[@"bundleID"], e[@"action"], e[@"title"]);
        NSLog(@"SpringBoard: %lu App Clip(s), %lu local experience(s)", (unsigned long)installed_clips.count, (unsigned long)local_experiences().count);
    } else if (w.count >= 1 && [verb containsString:@"://"]) {
        NSString *source = w.count > 1 && [w[1] isEqualToString:@"nfc"] ? @"nfc" : @"code";
        [self openAppClipURL:[NSURL URLWithString:verb] source:source];
    } else NSLog(@"SpringBoard: usage: appclip URL [code|nfc] | register PREFIX BUNDLE_ID ACTION|TITLE|SUBTITLE[|IMAGE] | unregister PREFIX|all | expire BUNDLE_ID | list");
}
@end
