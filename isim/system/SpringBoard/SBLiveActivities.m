// isim home screen: Live Activities (ActivityKit). The app's ActivityKit writes an activity's record
// (<isim data>/Library/isim/LiveActivities/<id>.plist) and says "live-activity update|update-alert|end PATH"; the home
// screen asks the app's widget extension to render it (a snapshot of the record, so renders that finish out of order
// are told apart by its "updated" time) and hands the images to the shell ("la-set APP SIDECAR"), which draws them on
// the lock screen and around the Dynamic Island. An activity with a stale date is rendered again when it passes
// (context.isStale). "la-end APP ID\x1fDISMISS" takes an ended activity out of the island at once; the dismissal
// policy decides how long it stays on the lock screen.
// Push updates (adapted: isim stands in for APNs and apsd): a payload with "aps": { "event": "update" | "end" |
// "start", "content-state", "timestamp", "stale-date", "dismissal-date", "relevance-score", "alert",
// "attributes-type" / "attributes" (start) } given to `isim push BUNDLE FILE` (or the script's `push`) updates the
// record of the activity whose push token a top-level "apns-push-token" names (without it: the app's newest activity
// that has a push token). "start" needs the push-to-start token the app read (pushToStartTokenUpdates). A
// "timestamp" not newer than the last one is ignored, like APNs.
#import "SpringBoard.h"

static NSString *la_dir(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/LiveActivities"]; }
static NSMutableDictionary<NSString *, NSTimer *> *stale_timers;     /* activity id -> the re-render at its stale date */
static NSMutableDictionary<NSString *, NSMutableArray *> *renders;   /* activity id -> its render directories */
static NSString *json_string(id obj) {
    if (!obj || ![NSJSONSerialization isValidJSONObject:@[obj]]) return nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:@[obj] options:0 error:NULL];      /* wrapped: fragments too */
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    return s.length >= 2 ? [s substringWithRange:NSMakeRange(1, s.length - 2)] : nil;
}
static NSString *new_token(void) {
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < 32; i++) [s appendFormat:@"%02x", arc4random() % 256];
    return s;
}
static double number(id v, double fallback) { return [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : fallback; }

@implementation HomeViewController (LiveActivities)
- (HSApp *)_appWithBundle:(NSString *)b { for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:b]) return a; return nil; }
- (void)liveActivity:(NSString *)args {
    NSRange sp = [args rangeOfString:@" "];
    if (sp.location == NSNotFound) return;
    NSString *what = [args substringToIndex:sp.location], *path = [args substringFromIndex:sp.location + 1];
    NSDictionary *rec = [NSDictionary dictionaryWithContentsOfFile:path];
    HSApp *a = [self _appWithBundle:rec[@"bundle"]];
    if (!a || !rec[@"id"]) return;
    NSString *ident = rec[@"id"];
    if ([what isEqual:@"end"] || [rec[@"ended"] boolValue]) {
        [stale_timers[ident] invalidate]; [stale_timers removeObjectForKey:ident];
        NSString *c = [NSString stringWithFormat:@"%@\x1f%f", ident, number(rec[@"dismiss"], 0)];
        isim_shell_request(ISIM_SHELL_SYSTEM, "la-end", a.path.UTF8String, c.UTF8String);
    }
    [self renderLiveActivity:path app:a alert:[what isEqual:@"update-alert"]];
    /* the stale date: render again when it passes (the extension then gets isStale) */
    double stale = number(rec[@"stale"], 0), now = [NSDate date].timeIntervalSince1970;
    if (!stale_timers) stale_timers = [NSMutableDictionary dictionary];
    [stale_timers[ident] invalidate]; [stale_timers removeObjectForKey:ident];
    if (stale > now && ![rec[@"ended"] boolValue]) {
        stale_timers[ident] = [NSTimer scheduledTimerWithTimeInterval:stale - now + 0.05 repeats:NO block:^(NSTimer *t) {
            [stale_timers removeObjectForKey:ident];
            NSLog(@"SpringBoard: Live Activity %@ is stale; rendering it again", ident);
            [self renderLiveActivity:path app:a alert:NO];
        }];
    }
}
- (void)renderLiveActivity:(NSString *)path app:(HSApp *)a alert:(BOOL)alert {
    NSDictionary *ext = HSWidgetExtension(a);
    if (!ext) { NSLog(@"SpringBoard: %@ has no widget extension for its Live Activity", a.name); return; }
    NSDictionary *rec = [NSDictionary dictionaryWithContentsOfFile:path];
    static NSUInteger seq;
    NSString *ident = rec[@"id"] ?: @"x";
    NSString *out = [HSWidgetsDir(a.bundleID) stringByAppendingPathComponent:[NSString stringWithFormat:@"activity-%@/r%lu", ident, (unsigned long)++seq]];
    [NSFileManager.defaultManager createDirectoryAtPath:out withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *snap = [out stringByAppendingPathComponent:@"record.plist"];
    [rec writeToFile:snap atomically:YES];
    HSRunWidgetExtension(ext, a.bundleID, @{ @"mode": @"activity", @"activity": snap, @"out": out, @"alert": @(alert) });
}
- (void)liveActivityRendered:(NSDictionary *)req {
    NSString *out = req[@"out"];
    NSDictionary *rec = [NSDictionary dictionaryWithContentsOfFile:req[@"activity"]];
    NSDictionary *files = [NSDictionary dictionaryWithContentsOfFile:[out stringByAppendingPathComponent:@"activity.plist"]];
    HSApp *a = [self _appWithBundle:req[@"bundle"]];
    if (!a || !rec || ![NSFileManager.defaultManager fileExistsAtPath:[out stringByAppendingPathComponent:@"lock.png"]]) return;
    NSString *ident = rec[@"id"];
    NSString *side = [out stringByAppendingPathComponent:@"la.txt"];
    NSString *text = [NSString stringWithFormat:@"id=%@\ndir=%@\nrelevance=%f\nseq=%f\nended=%d\ndismiss=%f\nalert=%d\nstale=%d\nurl=%@\n",
                      ident, out, number(rec[@"relevance"], 0), number(rec[@"updated"], 0), [rec[@"ended"] boolValue], number(rec[@"dismiss"], 0),
                      [req[@"alert"] boolValue], [files[@"stale"] length] > 0, files[@"url"] ?: @""];
    [text writeToFile:side atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    isim_shell_request(ISIM_SHELL_SYSTEM, "la-set", a.path.UTF8String, side.UTF8String);
    /* keep this render and the previous one (the shell may still be loading it); older ones go */
    if (!renders) renders = [NSMutableDictionary dictionary];
    NSMutableArray *dirs = renders[ident] ?: [NSMutableArray array];
    renders[ident] = dirs;
    [dirs addObject:out];
    while (dirs.count > 2) { [NSFileManager.defaultManager removeItemAtPath:dirs[0] error:NULL]; [dirs removeObjectAtIndex:0]; }
}
/* a tap on a Live Activity (lock screen, banner) from the shell: "la-open APP\x1fURL" */
- (void)openLiveActivityApp:(NSString *)args {
    NSArray *p = [args componentsSeparatedByString:@"\x1f"];
    for (HSApp *a in self.apps) if ([a.path.stringByStandardizingPath isEqual:[p[0] stringByStandardizingPath]]) {
        NSString *url = p.count > 1 && [p[1] length] ? p[1] : nil;
        NSLog(@"SpringBoard: Live Activity opens %@%@%@", a.name, url ? @" with " : @"", url ?: @"");
        [self launch:a url:url];
        return;
    }
}

/* ---- pushes (aps.event) ---- */
- (BOOL)deliverLiveActivityPush:(NSDictionary *)payload app:(HSApp *)a {
    NSDictionary *aps = payload[@"aps"];
    NSString *event = [aps[@"event"] isKindOfClass:[NSString class]] ? aps[@"event"] : nil;
    if (!event) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:la_dir() withIntermediateDirectories:YES attributes:nil error:NULL];
    double now = [NSDate date].timeIntervalSince1970;
    NSString *token = [payload[@"apns-push-token"] isKindOfClass:[NSString class]] ? [payload[@"apns-push-token"] lowercaseString] : nil;
    id alert = aps[@"alert"];
    BOOL hasAlert = ([alert isKindOfClass:[NSDictionary class]] && [alert count]) || ([alert isKindOfClass:[NSString class]] && [alert length]);
    NSMutableDictionary *rec = nil; NSString *path = nil;
    if ([event isEqual:@"start"]) {                         /* push-to-start (iOS 17.2) */
        NSString *type = [aps[@"attributes-type"] isKindOfClass:[NSString class]] ? aps[@"attributes-type"] : nil;
        NSString *attrs = json_string(aps[@"attributes"]), *state = json_string(aps[@"content-state"]);
        if (!type || !attrs || !state) { NSLog(@"SpringBoard: Live Activity push start for %@ needs attributes-type, attributes and content-state", a.name); return YES; }
        NSDictionary *starts = [NSDictionary dictionaryWithContentsOfFile:[la_dir() stringByAppendingPathComponent:@"PushToStart.plist"]];
        NSString *known = starts[a.bundleID][type];
        if (!known) { NSLog(@"SpringBoard: Live Activity push start for %@: no push-to-start token for %@ (the app reads Activity<%@>.pushToStartTokenUpdates first)", a.name, type, type); return YES; }
        if (token && ![token isEqual:known]) { NSLog(@"SpringBoard: Live Activity push start for %@: the token is not the push-to-start token of %@", a.name, type); return YES; }
        NSString *ident = NSUUID.UUID.UUIDString;
        rec = [@{ @"id": ident, @"type": type, @"bundle": a.bundleID, @"app": a.path, @"attributes": attrs, @"state": state, @"ended": @NO,
                  @"token": new_token(), @"pushStarted": @YES } mutableCopy];
        path = [la_dir() stringByAppendingPathComponent:[ident stringByAppendingPathExtension:@"plist"]];
        NSLog(@"SpringBoard: Live Activity push start %@ for %@: %@", type, a.name, ident);
    } else {
        NSString *best = nil; double bestT = -1;
        for (NSString *f in [fm contentsOfDirectoryAtPath:la_dir() error:NULL]) {
            if (![f hasSuffix:@".plist"] || [f isEqual:@"PushToStart.plist"]) continue;
            NSString *p = [la_dir() stringByAppendingPathComponent:f];
            NSDictionary *r = [NSDictionary dictionaryWithContentsOfFile:p];
            if (![r[@"bundle"] isEqual:a.bundleID] || [r[@"ended"] boolValue] || ![r[@"token"] length]) continue;
            if (token) { if ([[r[@"token"] lowercaseString] isEqual:token]) { best = p; break; } continue; }
            if (number(r[@"updated"], 0) > bestT) { bestT = number(r[@"updated"], 0); best = p; }
        }
        if (!best) { NSLog(@"SpringBoard: Live Activity push %@ for %@: no activity with %@", event, a.name, token ? @"that push token" : @"a push token"); return YES; }
        path = best;
        rec = [[NSDictionary dictionaryWithContentsOfFile:best] mutableCopy];
        double ts = number(aps[@"timestamp"], 0), last = number(rec[@"timestamp"], 0);
        if (ts > 0 && last > 0 && ts <= last) { NSLog(@"SpringBoard: Live Activity push %@ for %@ ignored: timestamp %.0f is not newer than %.0f", event, rec[@"id"], ts, last); return YES; }
        if (aps[@"content-state"]) {
            NSString *state = json_string(aps[@"content-state"]);
            if (state) rec[@"state"] = state;
        }
        if ([event isEqual:@"end"]) {
            rec[@"ended"] = @YES;
            double d = number(aps[@"dismissal-date"], 0);
            rec[@"dismiss"] = @(d > 0 ? MIN(MAX(d, now), now + 4 * 3600) : now + 4 * 3600);     /* the default: up to four hours */
        } else if (![event isEqual:@"update"]) { NSLog(@"SpringBoard: Live Activity push: unknown event '%@'", event); return YES; }
        NSLog(@"SpringBoard: Live Activity push %@ for %@ (%@)", event, rec[@"id"], a.name);
    }
    rec[@"stale"] = @(number(aps[@"stale-date"], 0));
    if (aps[@"relevance-score"]) rec[@"relevance"] = @(number(aps[@"relevance-score"], 0));
    if (aps[@"timestamp"]) rec[@"timestamp"] = @(number(aps[@"timestamp"], 0));
    if (hasAlert) {
        rec[@"alert"] = [alert isKindOfClass:[NSDictionary class]] ? alert : @{ @"body": alert };
        rec[@"alertSeq"] = @([rec[@"alertSeq"] integerValue] + 1);
        if (aps[@"sound"]) NSLog(@"SpringBoard: Live Activity alert sound %@", aps[@"sound"]);
    }
    rec[@"updated"] = @(now); rec[@"source"] = @"push";
    [rec writeToFile:path atomically:YES];
    [self liveActivity:[NSString stringWithFormat:@"%@ %@", [event isEqual:@"end"] ? @"end" : hasAlert ? @"update-alert" : @"update", path]];
    return YES;
}
@end
