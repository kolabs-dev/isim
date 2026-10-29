// isim home screen: Screen Time (FamilyControls, ManagedSettings, DeviceActivity; issue #409), like iOS's system.
//
// Shields: launching an app that a Screen Time-authorized app's active store shields (shield.applications, or
// shield.applicationCategories by the app's Screen Time category) shows the shield instead. Its look comes from the
// shielding app's Shield Configuration extension (com.apple.ManagedSettingsUI.shield-configuration-service), its
// buttons go to its Shield Action extension (com.apple.ManagedSettings.shield-action-service): close returns to the
// Home Screen, none keeps the shield, defer asks for the configuration again. Without the extensions it is iOS's
// default shield and its button closes it.
//
// Monitoring: the authorized apps' activities (DeviceActivityCenter: …/ScreenTime/Monitoring/<bundle id>.json) are
// followed on Screen Time's clock (now, plus `isim screentime clock` 's offset); the app's Device Activity Monitor
// extension (com.apple.deviceactivity.monitor-extension) runs at an interval's start and end, at the schedule's warning
// time before them, and when the usage an event counts (…/ScreenTime/usage.json, `isim screentime usage`) reaches its
// threshold or its warning. A schedule that does not repeat stops after its interval. Each extension is a helper
// process ("ext-run EXE REQUEST", answered by "ext-done CODE REQUEST"), one at a time.
// The data files are ManagedSettings' (swift/overlays/ManagedSettings: tokens.json maps token identifiers to bundle
// identifiers and categories; the categories of app types follow its category(ofAppType:)).
#import "SpringBoard.h"
#include <time.h>

static NSString *st_dir(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/ScreenTime"]; }
static id st_read(NSString *name) {
    NSData *d = [NSData dataWithContentsOfFile:[st_dir() stringByAppendingPathComponent:name]];
    return d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;
}
static void st_write(id obj, NSString *name) {
    NSString *p = [st_dir() stringByAppendingPathComponent:name];
    [NSFileManager.defaultManager createDirectoryAtPath:p.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:p atomically:YES];
}
static double st_now(void) { return NSDate.date.timeIntervalSince1970 + [st_read(@"clock.json")[@"offset"] doubleValue]; }
static BOOL st_authorized(NSString *bundle) { return [st_read(@"authorization.json")[bundle] hasPrefix:@"approved"]; }
/* a token as JSON (base64 of its identifier) -> its identifier */
static NSString *st_token_id(id t) {
    NSData *d = [t isKindOfClass:[NSString class]] ? [[NSData alloc] initWithBase64EncodedString:t options:0] : nil;
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}
static NSString *st_lookup(NSString *kind, id token) { NSString *i = st_token_id(token); return i ? st_read(@"tokens.json")[kind][i] : nil; }
static NSString *st_token_for(NSString *kind, NSString *value) {
    NSDictionary *m = st_read(@"tokens.json")[kind];
    for (NSString *k in m) if ([m[k] isEqual:value]) return k;
    return nil;
}
/* Screen Time's category of an app (LSApplicationCategoryType), like ManagedSettings' category(ofAppType:) */
static NSString *st_category(HSApp *a) {
    NSString *t = [a.info[@"LSApplicationCategoryType"] stringByReplacingOccurrencesOfString:@"public.app-category." withString:@""] ?: @"";
    if ([t isEqual:@"games"] || [t hasSuffix:@"-games"]) return @"games";
    NSDictionary *map = @{ @"social-networking": @"social", @"entertainment": @"entertainment", @"music": @"entertainment",
                           @"photography": @"creativity", @"graphics-design": @"creativity", @"video": @"creativity",
                           @"productivity": @"productivity-finance", @"finance": @"productivity-finance", @"business": @"productivity-finance",
                           @"education": @"education", @"kids": @"education", @"news": @"information-reading", @"books": @"information-reading",
                           @"reference": @"information-reading", @"magazines-and-newspapers": @"information-reading",
                           @"healthcare-fitness": @"health-fitness", @"medical": @"health-fitness", @"sports": @"health-fitness",
                           @"utilities": @"utilities", @"developer-tools": @"utilities", @"shopping": @"shopping-food",
                           @"food-and-drink": @"shopping-food", @"lifestyle": @"shopping-food", @"travel": @"travel",
                           @"navigation": @"travel", @"weather": @"travel" };
    return map[t] ?: @"other";
}
/* an app's extension of an extension point: its executable */
static NSString *st_extension(HSApp *a, NSString *point) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        if ([info[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:point])
            return [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension];
    }
    return nil;
}
static double st_seconds(NSDictionary *c) {
    if (![c isKindOfClass:[NSDictionary class]]) return 0;
    return [c[@"day"] doubleValue] * 86400 + [c[@"hour"] doubleValue] * 3600 + [c[@"minute"] doubleValue] * 60 + [c[@"second"] doubleValue];
}
/* a schedule's daily interval in progress at t, else the next one (DeviceActivitySchedule's) */
static BOOL st_interval(NSDictionary *schedule, double t, double *start, double *end) {
    NSDictionary *s = schedule[@"intervalStart"], *e = schedule[@"intervalEnd"];
    for (int off = -1; off <= 2; off++) {
        time_t day = (time_t)(t + off * 86400.0);
        struct tm tm; localtime_r(&day, &tm);
        tm.tm_isdst = -1;
        tm.tm_hour = [s[@"hour"] intValue]; tm.tm_min = [s[@"minute"] intValue]; tm.tm_sec = [s[@"second"] intValue];
        double a = (double)mktime(&tm);
        localtime_r(&day, &tm); tm.tm_isdst = -1;
        tm.tm_hour = [e[@"hour"] intValue]; tm.tm_min = [e[@"minute"] intValue]; tm.tm_sec = [e[@"second"] intValue];
        double b = (double)mktime(&tm);
        if (b <= a) b += 86400;
        if (b > t) { *start = a; *end = b; return YES; }
    }
    return NO;
}

@interface IsimShieldView : UIView
@property (nonatomic, copy) void (^onButton)(NSInteger action);
- (void)apply:(NSDictionary *)config appName:(NSString *)name;
@end

static NSMutableDictionary<NSString *, void (^)(NSDictionary *)> *st_pending;   /* request path -> what to do with the answer */
static NSMutableArray<NSArray *> *st_queue;                                      /* waiting runs: (exe, request, done) */
static BOOL st_running;
static IsimShieldView *st_shield;

@implementation HomeViewController (ScreenTime)
- (void)installScreenTimeObservers {
    st_pending = [NSMutableDictionary dictionary];
    st_queue = [NSMutableArray array];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if (![t hasPrefix:@"ext-done "]) return;
        NSString *args = [t substringFromIndex:9];
        NSRange sp = [args rangeOfString:@" "];
        NSString *req = sp.location == NSNotFound ? args : [args substringFromIndex:sp.location + 1];
        void (^done)(NSDictionary *) = st_pending[req];
        if (!done) return;                                             /* another kind of extension's */
        [st_pending removeObjectForKey:req];
        NSDictionary *answer = [NSDictionary dictionaryWithContentsOfFile:[[req stringByDeletingPathExtension] stringByAppendingString:@"-out.plist"]] ?: @{};
        st_running = NO;
        done(answer);
        [self screenTimeRunNext];
    }];
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) { [self screenTimeTick]; }];
}

/* runs a Screen Time extension with a request; one at a time */
- (void)screenTimeRun:(NSString *)exe request:(NSDictionary *)request then:(void (^)(NSDictionary *answer))done {
    NSString *dir = [st_dir() stringByAppendingPathComponent:@"Requests"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    static NSUInteger seq;
    NSString *base = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu-%u", (unsigned long)++seq, arc4random() % 100000]];
    NSMutableDictionary *r = [request mutableCopy];
    r[@"out"] = [base stringByAppendingString:@"-out.plist"];
    NSString *req = [base stringByAppendingPathExtension:@"plist"];
    [r writeToFile:req atomically:YES];
    [st_queue addObject:@[exe, req, [done copy]]];
    [self screenTimeRunNext];
}
- (void)screenTimeRunNext {
    if (st_running || !st_queue.count) return;
    NSArray *next = st_queue.firstObject;
    [st_queue removeObjectAtIndex:0];
    st_running = YES;
    st_pending[next[1]] = next[2];
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [next[0] UTF8String], [next[1] UTF8String]);
}

// ---- shields ----

/* the shield over `a` (YES: the app does not open) */
- (BOOL)screenTimeShield:(HSApp *)a {
    if (a.system) return NO;
    NSString *appToken = st_token_for(@"applications", a.bundleID), *category = st_category(a), *catToken = st_token_for(@"categories", category);
    NSString *stores = [st_dir() stringByAppendingPathComponent:@"Stores"];
    for (NSString *owner in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:stores error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (!st_authorized(owner)) continue;
        for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:[stores stringByAppendingPathComponent:owner] error:NULL]) {
            NSDictionary *s = st_read([NSString stringWithFormat:@"Stores/%@/%@", owner, f]);
            if (![f hasSuffix:@".json"] || (s[@"active"] && ![s[@"active"] boolValue])) continue;
            NSDictionary *shield = s[@"shield"];
            BOOL hit = NO;
            for (id t in shield[@"applications"]) if (appToken && [st_token_id(t) isEqual:appToken]) hit = YES;
            NSDictionary *pol = shield[@"applicationCategories"];
            if ([pol isKindOfClass:[NSDictionary class]]) {
                NSDictionary *all = pol[@"all"], *specific = pol[@"specific"];
                NSArray *except = (all ?: specific)[@"except"];
                BOOL excepted = NO;
                for (id t in except) if ([st_token_id(t) isEqual:appToken]) excepted = YES;
                if (all && !excepted) hit = YES;
                for (id t in specific[@"_0"]) if (catToken && [st_token_id(t) isEqual:catToken] && !excepted) hit = YES;
            }
            if (!hit) continue;
            HSApp *ownerApp = [self appWithIdentifier:owner];
            NSLog(@"SpringBoard: Screen Time shields %@ (store “%@” of %@)", a.bundleID, f.stringByDeletingPathExtension, owner);
            [self screenTimeShowShield:a owner:ownerApp token:appToken category:category];
            return YES;
        }
    }
    return NO;
}
- (void)screenTimeShowShield:(HSApp *)a owner:(HSApp *)owner token:(NSString *)token category:(NSString *)category {
    isim_shell_request(ISIM_SHELL_HOME, NULL, NULL, NULL);                /* over the Home Screen (the app does not open) */
    [st_shield removeFromSuperview];
    IsimShieldView *v = [[IsimShieldView alloc] initWithFrame:self.view.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v apply:@{} appName:a.name];
    st_shield = v;
    [self.view addSubview:v];
    NSDictionary *request = @{ @"target": @"application", @"token": token ?: @"", @"category": category ?: @"other" };
    __weak HomeViewController *w = self;
    void (^configure)(void) = ^{
        NSString *conf = owner ? st_extension(owner, @"com.apple.ManagedSettingsUI.shield-configuration-service") : nil;
        if (!conf) return;
        [w screenTimeRun:conf request:request then:^(NSDictionary *c) {
            NSLog(@"SpringBoard: Screen Time shield configured by %@", owner.bundleID);
            [v apply:c appName:a.name];
        }];
    };
    configure();
    v.onButton = ^(NSInteger action) {
        NSString *act = owner ? st_extension(owner, @"com.apple.ManagedSettings.shield-action-service") : nil;
        void (^respond)(NSInteger) = ^(NSInteger response) {
            NSLog(@"SpringBoard: Screen Time shield action %ld: %@", (long)action, response == 1 ? @"close" : response == 2 ? @"defer" : @"none");
            if (response == 1) { [st_shield removeFromSuperview]; st_shield = nil; }
            else if (response == 2) configure();
        };
        if (!act) { respond(1); return; }
        NSMutableDictionary *r = [request mutableCopy];
        r[@"action"] = @(action);
        [w screenTimeRun:act request:r then:^(NSDictionary *answer) { respond(answer[@"response"] ? [answer[@"response"] integerValue] : 1); }];
    };
}

// ---- monitoring ----

- (void)screenTimeTick {
    NSString *dir = [st_dir() stringByAppendingPathComponent:@"Monitoring"];
    double now = st_now();
    for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL]) {
        if (![f hasSuffix:@".json"] || [f hasSuffix:@".state.json"]) continue;
        NSString *bundle = f.stringByDeletingPathExtension;
        if (!st_authorized(bundle)) continue;
        HSApp *a = [self appWithIdentifier:bundle];
        NSString *exe = a ? st_extension(a, @"com.apple.deviceactivity.monitor-extension") : nil;
        NSMutableDictionary *activities = [st_read([@"Monitoring" stringByAppendingPathComponent:f]) mutableCopy];
        NSString *stateName = [NSString stringWithFormat:@"Monitoring/%@.state.json", bundle];
        NSMutableDictionary *state = [st_read(stateName) mutableCopy] ?: [NSMutableDictionary dictionary];
        BOOL changed = NO, removed = NO;
        for (NSString *name in activities.allKeys) {
            NSDictionary *act = activities[name], *schedule = act[@"schedule"];
            NSMutableDictionary *s = [state[name] mutableCopy] ?: [NSMutableDictionary dictionary];
            void (^call)(NSString *, NSString *) = ^(NSString *callback, NSString *event) {
                NSLog(@"SpringBoard: Screen Time: %@ %@%@%@ for %@", callback, name, event ? @" " : @"", event ?: @"", bundle);
                if (exe) [self screenTimeRun:exe request:@{ @"callback": callback, @"activity": name, @"event": event ?: @"" } then:^(NSDictionary *r) {}];
            };
            double warning = st_seconds(schedule[@"warningTime"]);
            /* the interval being followed ended: intervalDidEnd (a schedule that does not repeat stops) */
            if ([s[@"started"] boolValue] && ![s[@"ended"] boolValue] && now >= [s[@"end"] doubleValue]) {
                call(@"intervalDidEnd", nil);
                s[@"ended"] = @YES; changed = YES;
                if (![schedule[@"repeats"] boolValue]) { [activities removeObjectForKey:name]; [state removeObjectForKey:name]; removed = YES; continue; }
            }
            double start, end;
            if (!st_interval(schedule, now, &start, &end)) continue;
            if ([s[@"start"] doubleValue] != start) {                   /* a new interval */
                s = [@{ @"start": @(start), @"end": @(end), @"events": @{} } mutableCopy]; changed = YES;
            }
            if (now < start) {
                if (warning > 0 && now >= start - warning && ![s[@"startWarned"] boolValue]) { call(@"intervalWillStartWarning", nil); s[@"startWarned"] = @YES; changed = YES; }
            } else {
                if (![s[@"started"] boolValue]) { call(@"intervalDidStart", nil); s[@"started"] = @YES; changed = YES; }
                if (warning > 0 && now >= end - warning && ![s[@"endWarned"] boolValue]) { call(@"intervalWillEndWarning", nil); s[@"endWarned"] = @YES; changed = YES; }
                NSMutableDictionary *ev = [s[@"events"] mutableCopy] ?: [NSMutableDictionary dictionary];
                for (NSString *en in act[@"events"]) {
                    NSDictionary *e = act[@"events"][en];
                    double threshold = st_seconds(e[@"threshold"]);
                    double from = [e[@"includesPastActivity"] boolValue] ? start : MAX(start, [act[@"started"] doubleValue]);
                    double used = [self screenTimeUsage:e from:from to:now];
                    NSMutableDictionary *es = [ev[en] mutableCopy] ?: [NSMutableDictionary dictionary];
                    if (warning > 0 && used >= threshold - warning && ![es[@"warned"] boolValue]) { call(@"eventWillReachThresholdWarning", en); es[@"warned"] = @YES; }
                    if (used >= threshold && ![es[@"reached"] boolValue]) { call(@"eventDidReachThreshold", en); es[@"reached"] = @YES; }
                    if (![ev[en] isEqual:es]) { ev[en] = es; changed = YES; }
                }
                s[@"events"] = ev;
            }
            state[name] = s;
        }
        if (changed || removed) st_write(state, stateName);
        if (removed) st_write(activities, [@"Monitoring" stringByAppendingPathComponent:f]);
    }
}
/* the recorded usage of the apps an event counts, between two times */
- (double)screenTimeUsage:(NSDictionary *)event from:(double)from to:(double)to {
    NSMutableSet *apps = [NSMutableSet set], *cats = [NSMutableSet set];
    for (id t in event[@"applications"]) { NSString *b = st_lookup(@"applications", t); if (b) [apps addObject:b]; }
    for (id t in event[@"categories"]) { NSString *c = st_lookup(@"categories", t); if (c) [cats addObject:c]; }
    BOOL everything = ![event[@"applications"] count] && ![event[@"categories"] count] && ![event[@"webDomains"] count];
    double total = 0;
    for (NSDictionary *u in st_read(@"usage.json")) {
        double end = [u[@"end"] doubleValue];
        if (end <= from || end > to) continue;
        NSString *b = u[@"bundle"];
        HSApp *a = [self appWithIdentifier:b];
        if (everything || [apps containsObject:b] || (a && [cats containsObject:st_category(a)])) total += [u[@"seconds"] doubleValue];
    }
    return total;
}
@end

// ---- the shield (iOS's look: the icon, the title and subtitle, a primary and a secondary button) ----

static UIColor *st_color(NSArray *c, UIColor *fallback) {
    return [c isKindOfClass:[NSArray class]] && c.count == 4 ? [UIColor colorWithRed:[c[0] doubleValue] green:[c[1] doubleValue] blue:[c[2] doubleValue] alpha:[c[3] doubleValue]] : fallback;
}
@implementation IsimShieldView { UIImageView *_icon; UILabel *_title, *_subtitle; UIButton *_primary, *_secondary; UIVisualEffectView *_blur; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.accessibilityIdentifier = @"shield";
        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
        _blur.frame = self.bounds; _blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_blur];
        _icon = [UIImageView new]; _icon.contentMode = UIViewContentModeScaleAspectFit; _icon.accessibilityIdentifier = @"shield-icon";
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold]; _title.textAlignment = NSTextAlignmentCenter;
        _title.numberOfLines = 0; _title.accessibilityIdentifier = @"shield-title";
        _subtitle = [UILabel new]; _subtitle.font = [UIFont systemFontOfSize:17]; _subtitle.textAlignment = NSTextAlignmentCenter;
        _subtitle.numberOfLines = 0; _subtitle.accessibilityIdentifier = @"shield-subtitle";
        _primary = [UIButton buttonWithType:UIButtonTypeSystem]; _primary.accessibilityIdentifier = @"shield-primary";
        _primary.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _primary.layer.cornerRadius = 14;
        [_primary addTarget:self action:@selector(primaryTapped) forControlEvents:UIControlEventTouchUpInside];
        _secondary = [UIButton buttonWithType:UIButtonTypeSystem]; _secondary.accessibilityIdentifier = @"shield-secondary";
        _secondary.titleLabel.font = [UIFont systemFontOfSize:17];
        [_secondary addTarget:self action:@selector(secondaryTapped) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *v in @[_icon, _title, _subtitle, _primary, _secondary]) [self addSubview:v];
    }
    return self;
}
- (void)apply:(NSDictionary *)c appName:(NSString *)name {
    _blur.hidden = c[@"background"] != nil && !c[@"blur"];
    self.backgroundColor = st_color(c[@"background"], UIColor.clearColor);
    UIImage *icon = c[@"icon"] ? [UIImage imageWithContentsOfFile:c[@"icon"]] : nil;
    _icon.image = icon ?: [UIImage systemImageNamed:@"hourglass"];
    _icon.tintColor = UIColor.systemIndigoColor;
    _title.text = c[@"title"][@"text"] ?: @"Restricted";
    _title.textColor = st_color(c[@"title"][@"color"], UIColor.labelColor);
    _subtitle.text = c[@"subtitle"][@"text"] ?: [NSString stringWithFormat:@"You cannot use %@ because it is restricted.", name];
    _subtitle.textColor = st_color(c[@"subtitle"][@"color"], UIColor.secondaryLabelColor);
    [_primary setTitle:c[@"primary"][@"text"] ?: @"OK" forState:UIControlStateNormal];
    [_primary setTitleColor:st_color(c[@"primary"][@"color"], UIColor.whiteColor) forState:UIControlStateNormal];
    _primary.backgroundColor = st_color(c[@"primaryBackground"], UIColor.systemBlueColor);
    NSString *sec = c[@"secondary"][@"text"];
    _secondary.hidden = sec == nil;
    [_secondary setTitle:sec forState:UIControlStateNormal];
    [_secondary setTitleColor:st_color(c[@"secondary"][@"color"], UIColor.systemBlueColor) forState:UIControlStateNormal];
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, m = 32;
    _icon.frame = CGRectMake((W - 64) / 2, H * 0.30, 64, 64);
    CGFloat y = CGRectGetMaxY(_icon.frame) + 24;
    CGSize t = [_title sizeThatFits:CGSizeMake(W - 2 * m, 200)];
    _title.frame = CGRectMake(m, y, W - 2 * m, t.height); y += t.height + 12;
    CGSize s = [_subtitle sizeThatFits:CGSizeMake(W - 2 * m, 200)];
    _subtitle.frame = CGRectMake(m, y, W - 2 * m, s.height);
    CGFloat by = H - 60 - (_secondary.hidden ? 0 : 50) - 50;
    _primary.frame = CGRectMake(m, by, W - 2 * m, 50);
    _secondary.frame = CGRectMake(m, by + 58, W - 2 * m, 44);
}
- (void)primaryTapped { if (self.onButton) self.onButton(0); }
- (void)secondaryTapped { if (self.onButton) self.onButton(1); }
@end
