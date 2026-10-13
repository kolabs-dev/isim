// isim home screen: Control Center controls (iOS 18 ControlWidget) and Focus filters. Adapted.
//
// Controls: apps' widget extensions describe their controls (request mode "controls", WidgetKit's Controls.swift) and
// run them ("control-run"); the shell draws them in Control Center, on the Lock Screen and for the Action button
// ("cc-controls PATH FILE" to the shell, shell_controls.inc). The shell asks for "control-run PATH\x1fKIND\x1fVALUE"
// and "control-reload PATH\x1fKIND" (ControlCenter.reloadControls; PATH empty: every app).
// Focus filters: apps declaring SetFocusFilterIntent types are asked once, headless, to describe them (mode
// "focus-filters", AppIntents' Focus.swift) into <isim data>/Library/SpringBoard/FocusFilters/<bundle id>/
// focus-filters.plist, which Settings > Focus lists. When the shell says "focus-changed OLD NEW" (or "focus-apply
// MODE" after Settings changed a filter), the filters configured for those Focus modes (<isim data>/Library/isim/
// Focus/Focus.plist, written by Settings: { filters = { MODE = ( { app, type, params } ) } }) run in their apps:
// "focus-filter PATH EXE\x1fSIDECAR" to the shell, which delivers or launches the app in the background.
#import "SpringBoard.h"

static NSString *const kFocusNames[] = { @"off", @"Do Not Disturb", @"Personal", @"Work", @"Sleep" };
static NSString *focus_name(NSString *ident) {
    NSArray *ids = @[@"off", @"dnd", @"personal", @"work", @"sleep"];
    NSUInteger i = [ids indexOfObject:ident];
    return i == NSNotFound ? ident : kFocusNames[i];
}
static NSString *sb_dir(NSString *sub) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:sub];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
/* the app's widget extension's executable */
static NSString *control_extension(HSApp *a) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        if (![info[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:@"com.apple.widgetkit-extension"]) continue;
        return [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension];
    }
    return nil;
}
static NSMutableDictionary<NSString *, NSArray *> *pending;     /* request path -> @[kind ("controls"|"filters"), HSApp, out dir] */
static NSUInteger seq;
static void run_helper(NSString *exe, HSApp *a, NSString *kind, NSDictionary *request, NSString *out) {
    if (!pending) pending = [NSMutableDictionary dictionary];
    NSString *req = [sb_dir(@"Library/SpringBoard/Requests") stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@-%lu-%u.plist", kind, (unsigned long)++seq, arc4random() % 100000]];
    NSMutableDictionary *r = [request mutableCopy]; r[@"out"] = out; r[@"bundle"] = a.bundleID;
    [r writeToFile:req atomically:YES];
    pending[req] = @[kind, a, out];
    isim_shell_request(ISIM_SHELL_SYSTEM, "widget-run", exe.UTF8String, req.UTF8String);
}
static BOOL controls_available(void) { return isim_os_version() >= 180000; }      /* ControlWidget: iOS 18 */

@implementation HomeViewController (Controls)
- (HSApp *)_controlsAppAtPath:(NSString *)path {
    for (HSApp *a in self.apps) if ([a.path isEqualToString:path] || [a.path.lastPathComponent isEqualToString:path.lastPathComponent]) return a;
    return nil;
}
- (void)_listControls:(HSApp *)a {
    NSString *exe = control_extension(a);
    if (!exe) return;
    run_helper(exe, a, @"controls", @{ @"mode": @"controls" }, sb_dir([@"Library/SpringBoard/Controls" stringByAppendingPathComponent:a.bundleID]));
}
- (void)discoverControls {
    if (controls_available()) for (HSApp *a in self.apps) [self _listControls:a];
    [self discoverFocusFilters];
}
/* apps whose binary refers to SetFocusFilterIntent describe their filters once (again when the binary changes) */
- (void)discoverFocusFilters {
    NSData *needle = [@"20SetFocusFilterIntent" dataUsingEncoding:NSUTF8StringEncoding];
    for (HSApp *a in self.apps) {
        if (a.system) continue;
        NSString *out = sb_dir([@"Library/SpringBoard/FocusFilters" stringByAppendingPathComponent:a.bundleID]);
        NSString *list = [out stringByAppendingPathComponent:@"focus-filters.plist"];
        NSDate *built = [NSFileManager.defaultManager attributesOfItemAtPath:a.executable error:NULL].fileModificationDate;
        NSDate *listed = [NSFileManager.defaultManager attributesOfItemAtPath:list error:NULL].fileModificationDate;
        if (listed && built && [listed compare:built] != NSOrderedAscending) continue;
        NSData *bin = [NSData dataWithContentsOfFile:a.executable options:NSDataReadingMappedIfSafe error:NULL];
        if (!bin || [bin rangeOfData:needle options:0 range:NSMakeRange(0, bin.length)].location == NSNotFound) continue;
        NSLog(@"SpringBoard: asking %@ for its Focus filters", a.name);
        run_helper(a.executable, a, @"filters", @{ @"mode": @"focus-filters" }, out);
    }
}
- (void)_helperDone:(NSString *)args {
    NSRange sp = [args rangeOfString:@" "];
    NSString *req = sp.location == NSNotFound ? args : [args substringFromIndex:sp.location + 1];
    NSArray *p = pending[req];
    if (!p) return;
    [pending removeObjectForKey:req];
    [NSFileManager.defaultManager removeItemAtPath:req error:NULL];
    HSApp *a = p[1];
    if ([p[0] isEqual:@"controls"]) {
        NSString *file = [p[2] stringByAppendingPathComponent:@"controls.txt"];
        if ([NSFileManager.defaultManager fileExistsAtPath:file]) isim_shell_request(ISIM_SHELL_SYSTEM, "cc-controls", a.path.UTF8String, file.UTF8String);
    } else {
        NSDictionary *l = [NSDictionary dictionaryWithContentsOfFile:[p[2] stringByAppendingPathComponent:@"focus-filters.plist"]];
        NSLog(@"SpringBoard: %@ has %lu Focus filter(s)", a.name, (unsigned long)[l[@"filters"] count]);
    }
}
- (void)_runControl:(NSString *)args {                  /* PATH \x1f KIND \x1f VALUE (-1: a button) */
    NSArray *f = [args componentsSeparatedByString:@"\x1f"];
    if (f.count < 3) return;
    HSApp *a = [self _controlsAppAtPath:f[0]];
    NSString *exe = a ? control_extension(a) : nil;
    if (!exe) { NSLog(@"SpringBoard: no widget extension for the control %@", f[1]); return; }
    NSMutableDictionary *r = [@{ @"mode": @"control-run", @"control": f[1] } mutableCopy];
    if ([f[2] intValue] >= 0) r[@"value"] = @([f[2] intValue] != 0);
    NSLog(@"SpringBoard: running control %@ of %@", f[1], a.name);
    run_helper(exe, a, @"controls", r, sb_dir([@"Library/SpringBoard/Controls" stringByAppendingPathComponent:a.bundleID]));
}
- (void)_reloadControls:(NSString *)args {             /* PATH \x1f KIND (PATH empty: every app) */
    if (!controls_available()) return;
    NSArray *f = [args componentsSeparatedByString:@"\x1f"];
    NSString *path = f.firstObject ?: @"";
    if ([path containsString:@".app/PlugIns/"]) path = [[path componentsSeparatedByString:@".app/PlugIns/"].firstObject stringByAppendingString:@".app"];
    NSLog(@"SpringBoard: reloading controls (%@)", f.count > 1 ? f[1] : @"*");
    for (HSApp *a in self.apps) if (!path.length || [a.path.lastPathComponent isEqualToString:path.lastPathComponent]) [self _listControls:a];
}

/* ---- Focus filters ---- */
- (void)_applyFocusFilters:(NSString *)mode active:(BOOL)active except:(NSArray *)keep {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:[isim_data_dir() stringByAppendingPathComponent:@"Library/isim/Focus/Focus.plist"]];
    for (NSDictionary *f in cfg[@"filters"][mode]) {
        NSString *key = [NSString stringWithFormat:@"%@\x1f%@", f[@"app"], f[@"type"]];
        if ([keep containsObject:key]) continue;
        HSApp *a = [self appForFocusFilter:f[@"app"]];
        if (!a) { NSLog(@"SpringBoard: Focus filter of %@: the app is not installed", f[@"app"]); continue; }
        NSString *side = [sb_dir(@"Library/SpringBoard/FocusFilters") stringByAppendingPathComponent:[NSString stringWithFormat:@"apply-%lu-%u.plist", (unsigned long)++seq, arc4random() % 100000]];
        [@{ @"type": f[@"type"] ?: @"", @"params": active ? (f[@"params"] ?: @{}) : @{}, @"active": @(active), @"focus": focus_name(mode) } writeToFile:side atomically:YES];
        NSLog(@"SpringBoard: Focus %@ %@: running the Focus filter %@ of %@", focus_name(mode), active ? @"on" : @"off", f[@"title"] ?: f[@"type"], a.name);
        NSString *c = [NSString stringWithFormat:@"%@\x1f%@", a.executable, side];
        isim_shell_request(ISIM_SHELL_SYSTEM, "focus-filter", a.path.UTF8String, c.UTF8String);
    }
}
- (HSApp *)appForFocusFilter:(NSString *)bundleID { for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:bundleID]) return a; return nil; }
- (void)_focusChanged:(NSString *)args {               /* OLD NEW */
    NSArray *f = [args componentsSeparatedByString:@" "];
    if (f.count < 2) return;
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:[isim_data_dir() stringByAppendingPathComponent:@"Library/isim/Focus/Focus.plist"]];
    NSMutableArray *next = [NSMutableArray array];
    for (NSDictionary *x in cfg[@"filters"][f[1]]) [next addObject:[NSString stringWithFormat:@"%@\x1f%@", x[@"app"], x[@"type"]]];
    if (![f[0] isEqual:@"off"]) [self _applyFocusFilters:f[0] active:NO except:next];   /* the defaults again, unless the next Focus sets it */
    if (![f[1] isEqual:@"off"]) [self _applyFocusFilters:f[1] active:YES except:@[]];
}
- (void)installControlObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if ([t hasPrefix:@"widget-done "]) [self _helperDone:[t substringFromIndex:12]];
        else if ([t hasPrefix:@"control-run "]) [self _runControl:[t substringFromIndex:12]];
        else if ([t hasPrefix:@"control-reload "]) [self _reloadControls:[t substringFromIndex:15]];
        else if ([t hasPrefix:@"focus-changed "]) [self _focusChanged:[t substringFromIndex:14]];
        else if ([t hasPrefix:@"focus-apply "]) { NSString *m = [t substringFromIndex:12]; if (![m isEqual:@"off"]) [self _applyFocusFilters:m active:YES except:@[]]; }
    }];
}
@end
