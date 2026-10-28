// isim home screen: Siri, App Shortcuts and SiriKit (adapted).
//
// App Shortcuts: an app that links AppIntents is started once in a metadata mode (ext-run with ISIM_EXTENSION_REQUEST
// { mode = appintents-list }, the AppIntents overlay's System.swift) and its App Shortcuts and intents are cached in
// <isim data>/Library/SpringBoard/AppIntents/<bundle id>.plist (again when the executable changes). The Shortcuts
// app, Spotlight and Siri read that cache.
//
// Siri (simulated; isim has no speech recognition): the script command `siri PHRASE` (or Type to Siri in the Siri UI)
// is matched against App Shortcut phrases (${applicationName}: the app's name; ${parameter}: one of the AppEnum
// cases or of the entities the app suggested / gave in updateAppShortcutParameters()), then voice shortcuts
// (INVoiceShortcutCenter), then a few English SiriKit phrasings (siri_parse below); `siri intent CLASS key=value ...`
// builds a SiriKit intent directly. The Siri UI is drawn by the shell (shell_siri.inc) from "siri-ui FILE" sidecars;
// its taps and typed text come back as "siri-answer ...".
//
// The intent run protocol (reusable by other system features: HSRunIntentRequest below): a run directory
// <isim data>/Library/SpringBoard/Intents/run-N with request.plist; App Intents run in the app (launched in the
// background, or in the foreground for openAppWhenRun / OpenIntent) through the isim-intent:<request> launch marker;
// SiriKit intents run in the app's Intents extension (a helper process) or in the app. The runner writes step-N.plist
// (value / choice / confirm questions, then the result), this file answers with answer-N.plist (see
// frameworks/Intents/INSiriRunner.m for the keys).
#import "SpringBoard.h"
#include <sys/stat.h>

static int sb_os(void) { return isim_os_version() / 10000; }
static NSString *dir_named(NSString *sub) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:sub];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
static NSString *meta_file(HSApp *a) { return [dir_named(@"Library/SpringBoard/AppIntents") stringByAppendingPathComponent:[a.bundleID stringByAppendingPathExtension:@"plist"]]; }
static NSString *exe_stamp(HSApp *a) {
    struct stat st;
    if (stat(a.executable.fileSystemRepresentation, &st) != 0) return @"";
    return [NSString stringWithFormat:@"%lld-%lld", (long long)st.st_mtime, (long long)st.st_size];
}
/* the executable links the AppIntents library (its load commands name it) */
static BOOL links_app_intents(HSApp *a) {
    NSFileHandle *h = [NSFileHandle fileHandleForReadingAtPath:a.executable];
    NSData *head = [h readDataOfLength:65536];
    [h closeFile];
    return head && [head rangeOfData:[@"libswiftAppIntents.dylib" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, head.length)].location != NSNotFound;
}
NSDictionary *HSAppIntentsMetadata(HSApp *a) {
    if (a.system) return nil;
    NSDictionary *m = [NSDictionary dictionaryWithContentsOfFile:meta_file(a)];
    return [m[@"stamp"] isEqual:exe_stamp(a)] ? m : nil;
}
static NSString *norm(NSString *s) {
    s = [[s lowercaseString] stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" .!?,\t\n"]];
    while ([s containsString:@"  "]) s = [s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    return s;
}
/* a phrase with the app's name in it, for people (Shortcuts, Spotlight, logs) */
NSString *HSPhraseText(NSString *template, HSApp *a) {
    NSMutableString *s = [[template stringByReplacingOccurrencesOfString:@"${applicationName}" withString:a.name] mutableCopy];
    NSRange r;
    while ((r = [s rangeOfString:@"${"]).location != NSNotFound) {
        NSRange e = [s rangeOfString:@"}" options:0 range:NSMakeRange(r.location, s.length - r.location)];
        if (e.location == NSNotFound) break;
        [s replaceCharactersInRange:NSMakeRange(r.location, e.location - r.location + 1) withString:@"…"];
    }
    return s;
}
static NSDictionary *container_plist(HSApp *a, NSString *file) {
    return [NSDictionary dictionaryWithContentsOfFile:[[a.containerPath stringByAppendingPathComponent:@"Library/isim"] stringByAppendingPathComponent:file]];
}
static id app_default(HSApp *a, NSString *key) {
    NSString *f = [a.containerPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", a.bundleID]];
    return [NSDictionary dictionaryWithContentsOfFile:f][key];
}
static NSDictionary *entitlements(HSApp *a) {
    NSData *d = [NSData dataWithContentsOfFile:[a.path stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
    id p = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    return [p isKindOfClass:[NSDictionary class]] ? p : @{};
}

/* ---------------- SiriKit: which app handles an intent class ---------------- */
static NSDictionary *extension_for_point(HSApp *a, NSString *point, NSString *cls) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *ext = info[@"NSExtension"];
        if (![ext[@"NSExtensionPointIdentifier"] isEqual:point]) continue;
        NSArray *supported = ext[@"NSExtensionAttributes"][@"IntentsSupported"];
        if (cls && ![supported containsObject:cls]) continue;
        return @{ @"path": p, @"exe": [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension], @"info": info };
    }
    return nil;
}
static BOOL app_handles(HSApp *a, NSString *cls) {
    return extension_for_point(a, @"com.apple.intents-service", cls) || [a.info[@"INIntentsSupported"] containsObject:cls];
}
static NSArray<NSString *> *app_sirikit_classes(HSApp *a) {
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSetWithArray:a.info[@"INIntentsSupported"] ?: @[]];
    NSDictionary *ext = extension_for_point(a, @"com.apple.intents-service", nil);
    [s addObjectsFromArray:ext[@"info"][@"NSExtension"][@"NSExtensionAttributes"][@"IntentsSupported"] ?: @[]];
    return s.array;
}

/* ---------------- SiriKit: the phrasings isim understands ---------------- */
static NSDictionary *person_plist(NSString *name) {
    name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSRange sp = [name rangeOfString:@" "];
    NSMutableDictionary *nc = [@{ @"$class": @"NSPersonNameComponents", @"givenName": sp.location == NSNotFound ? name : [name substringToIndex:sp.location] } mutableCopy];
    if (sp.location != NSNotFound) nc[@"familyName"] = [name substringFromIndex:sp.location + 1];
    return @{ @"$class": @"INPerson", @"displayName": name, @"nameComponents": nc,
              @"personHandle": @{ @"$class": @"INPersonHandle", @"value": name, @"type": @0 } };
}
static NSArray *people_plist(NSString *names) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *n in [[names stringByReplacingOccurrencesOfString:@" and " withString:@","] componentsSeparatedByString:@","])
        if ([n stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) [a addObject:person_plist(n)];
    return a;
}
static NSDictionary *speakable(NSString *s) { return @{ @"$class": @"INSpeakableString", @"spokenPhrase": [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] }; }
/* an intent plist from structured values (the script form, and the phrasings below) */
static NSDictionary *intent_plist(NSString *cls, NSDictionary<NSString *, NSString *> *v) {
    NSMutableDictionary *p = [@{ @"$class": cls, @"identifier": NSUUID.UUID.UUIDString } mutableCopy];
    if ([cls isEqualToString:@"INSendMessageIntent"]) {
        if (v[@"recipients"]) p[@"recipients"] = people_plist(v[@"recipients"]);
        if (v[@"content"]) p[@"content"] = v[@"content"];
        if (v[@"group"]) p[@"speakableGroupName"] = speakable(v[@"group"]);
        p[@"outgoingMessageType"] = @1;
    } else if ([cls isEqualToString:@"INStartCallIntent"]) {
        if (v[@"contacts"]) p[@"contacts"] = people_plist(v[@"contacts"]);
        p[@"callCapability"] = [v[@"video"] boolValue] ? @2 : @1; p[@"destinationType"] = @1;
    } else if ([cls isEqualToString:@"INSearchForMessagesIntent"]) {
        if (v[@"senders"]) p[@"senders"] = people_plist(v[@"senders"]);
        if (v[@"recipients"]) p[@"recipients"] = people_plist(v[@"recipients"]);
        if (v[@"terms"]) p[@"searchTerms"] = [v[@"terms"] componentsSeparatedByString:@","];
    } else if ([cls isEqualToString:@"INPlayMediaIntent"]) {
        if (v[@"media"]) p[@"mediaSearch"] = @{ @"$class": @"INMediaSearch", @"mediaName": v[@"media"], @"mediaType": @0 };
        if (v[@"shuffle"]) p[@"playShuffled"] = @([v[@"shuffle"] boolValue]);
    } else if ([cls isEqualToString:@"INEditMessageIntent"]) {
        if (v[@"message"]) p[@"messageIdentifier"] = v[@"message"];
        if (v[@"content"]) p[@"editedContent"] = v[@"content"];
    } else if ([cls isEqualToString:@"INUnsendMessagesIntent"]) {
        if (v[@"messages"]) p[@"messageIdentifiers"] = [v[@"messages"] componentsSeparatedByString:@","];
    } else if ([cls isEqualToString:@"INAddMediaIntent"] || [cls isEqualToString:@"INSearchForMediaIntent"]) {
        NSString *m = v[@"media"];
        if ([m.lowercaseString isEqualToString:@"this"] || [m.lowercaseString hasPrefix:@"this "] || [m.lowercaseString isEqualToString:@"what's playing"])
            p[@"mediaSearch"] = @{ @"$class": @"INMediaSearch", @"mediaType": @0, @"reference": @1 };          /* INMediaReferenceCurrentlyPlaying */
        else if (m) p[@"mediaSearch"] = @{ @"$class": @"INMediaSearch", @"mediaName": m, @"mediaType": @0 };
        if (v[@"playlist"]) p[@"mediaDestination"] = @{ @"$class": @"INMediaDestination", @"mediaDestinationType": @2, @"playlistName": v[@"playlist"] };
        else if ([v[@"library"] boolValue]) p[@"mediaDestination"] = @{ @"$class": @"INMediaDestination", @"mediaDestinationType": @1 };
    } else if ([cls isEqualToString:@"INAddTasksIntent"]) {
        if (v[@"tasks"]) { NSMutableArray *t = [NSMutableArray array]; for (NSString *s in [v[@"tasks"] componentsSeparatedByString:@","]) [t addObject:speakable(s)]; p[@"taskTitles"] = t; }
        if (v[@"list"]) p[@"targetTaskList"] = @{ @"$class": @"INTaskList", @"title": speakable(v[@"list"]), @"tasks": @[] };
    } else if ([cls isEqualToString:@"INCreateNoteIntent"]) {
        if (v[@"title"]) p[@"title"] = speakable(v[@"title"]);
        if (v[@"content"]) p[@"content"] = @{ @"$class": @"INTextNoteContent", @"text": v[@"content"] };
        if (v[@"folder"]) p[@"groupName"] = speakable(v[@"folder"]);
    } else if (![cls hasPrefix:@"IN"]) {                   /* a custom intent (.intentdefinition): the values as typed;
                                                              the app converts them to the parameters' types */
        for (NSString *k in v) p[k] = v[k];
    } else return nil;
    return p;
}
static NSString *rx(NSString *pattern, NSString *text, NSArray **groups) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m) return nil;
    NSMutableArray *g = [NSMutableArray array];
    for (NSUInteger i = 1; i < m.numberOfRanges; i++) [g addObject:[m rangeAtIndex:i].location == NSNotFound ? @"" : [text substringWithRange:[m rangeAtIndex:i]]];
    *groups = g;
    return @"";
}
/* "send a message to Anna saying Hello", "message Anna Hello", "tell Anna that ...", "call Anna", "facetime Anna",
   "show my messages [from Anna]", "edit my last message to say TEXT", "unsend my last message", "play NAME", "shuffle NAME",
   "add NAME to my library", "add NAME to my PLAYLIST playlist", "search for NAME", "add TASK to [my] LIST [list]", "remind me to TASK",
   "create / make / take a note [saying TEXT]", "note TEXT"; each may end with "using|with|in|on APP" */
static NSDictionary *siri_parse(NSString *text, NSString **cls) {
    NSArray *g = nil;
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" .!?"]];
    if (rx(@"^(?:send|text) (?:a )?(?:new )?(?:message|text|imessage) to (.+?)(?: (?:saying|that says|that|with|says|:) (.+))?$", t, &g) ||
        rx(@"^(?:message|text) (.+?)(?: (?:saying|that says|that|with)) (.+)$", t, &g) || rx(@"^tell (.+?) (?:that )?(.+)$", t, &g)) {
        *cls = @"INSendMessageIntent";
        NSMutableDictionary *v = [@{ @"recipients": g[0] } mutableCopy];
        if (g.count > 1 && [g[1] length]) v[@"content"] = g[1];
        return v;
    }
    if (rx(@"^(?:send|text) (?:a )?message$", t, &g)) { *cls = @"INSendMessageIntent"; return @{}; }
    if (rx(@"^(facetime|call|ring|phone|video call) (.+)$", t, &g)) {
        *cls = @"INStartCallIntent";
        return @{ @"contacts": g[1], @"video": [[g[0] lowercaseString] containsString:@"video"] || [[g[0] lowercaseString] isEqual:@"facetime"] ? @"1" : @"0" };
    }
    if (rx(@"^(?:make a call|call someone)$", t, &g)) { *cls = @"INStartCallIntent"; return @{}; }
    if (rx(@"^(?:show|read|search|find|check|search for) (?:me )?(?:my )?(?:new |latest |recent |unread )?messages(?: from (.+))?$", t, &g)) {
        *cls = @"INSearchForMessagesIntent";
        return [g[0] length] ? @{ @"senders": g[0] } : @{};
    }
    if (rx(@"^(?:edit|change|fix) my (?:last )?message to (?:say |read )?(.+)$", t, &g)) { *cls = @"INEditMessageIntent"; return @{ @"content": g[0] }; }
    if (rx(@"^(?:edit|change|fix) my (?:last )?message$", t, &g)) { *cls = @"INEditMessageIntent"; return @{}; }
    if (rx(@"^(?:unsend|undo send|take back) my (?:last )?message$", t, &g)) { *cls = @"INUnsendMessagesIntent"; return @{}; }
    if (rx(@"^add (.+?) to (?:my |the )?library$", t, &g)) { *cls = @"INAddMediaIntent"; return @{ @"media": g[0], @"library": @"1" }; }
    if (rx(@"^add (.+?) to (?:my |the )?(.+?) playlist$", t, &g)) { *cls = @"INAddMediaIntent"; return @{ @"media": g[0], @"playlist": g[1] }; }
    if (rx(@"^(?:search for|look for|look up|find) (.+)$", t, &g)) { *cls = @"INSearchForMediaIntent"; return @{ @"media": g[0] }; }
    if (rx(@"^(play|shuffle) (.+)$", t, &g)) {
        *cls = @"INPlayMediaIntent";
        return @{ @"media": g[1], @"shuffle": [[g[0] lowercaseString] isEqual:@"shuffle"] ? @"1" : @"0" };
    }
    if (rx(@"^add (.+?) to (?:my |the )?(.+?)(?: list)?$", t, &g)) { *cls = @"INAddTasksIntent"; return @{ @"tasks": g[0], @"list": g[1] }; }
    if (rx(@"^remind me to (.+)$", t, &g)) { *cls = @"INAddTasksIntent"; return @{ @"tasks": g[0] }; }
    if (rx(@"^(?:create|make|take|new) (?:a )?note(?: (?:saying|that says|called|titled|:) (.+))?$", t, &g)) {
        *cls = @"INCreateNoteIntent";
        return [g[0] length] ? @{ @"title": g[0], @"content": g[0] } : @{};
    }
    if (rx(@"^note (?:that )?(.+)$", t, &g)) { *cls = @"INCreateNoteIntent"; return @{ @"title": g[0], @"content": g[0] }; }
    return nil;
}
/* `siri intent CLASS key=value key="two words" ...` */
static NSDictionary *structured(NSString *args, NSString **cls) {
    NSMutableArray *tok = [NSMutableArray array]; NSMutableString *cur = [NSMutableString string]; BOOL q = NO;
    for (NSUInteger i = 0; i < args.length; i++) {
        unichar c = [args characterAtIndex:i];
        if (c == '"') { q = !q; continue; }
        if (c == ' ' && !q) { if (cur.length) [tok addObject:[cur copy]]; [cur setString:@""]; continue; }
        [cur appendFormat:@"%C", c];
    }
    if (cur.length) [tok addObject:cur];
    if (!tok.count) return nil;
    *cls = tok[0];
    if (![*cls hasPrefix:@"IN"]) {                         /* SendMessage -> INSendMessageIntent; a custom intent's class stays */
        NSString *system = [NSString stringWithFormat:@"IN%@%@", tok[0], [tok[0] hasSuffix:@"Intent"] ? @"" : @"Intent"];
        if (intent_plist(system, @{})) *cls = system;
    }
    NSMutableDictionary *v = [NSMutableDictionary dictionary];
    for (NSString *t in [tok subarrayWithRange:NSMakeRange(1, tok.count - 1)]) {
        NSRange eq = [t rangeOfString:@"="];
        if (eq.location != NSNotFound) v[[t substringToIndex:eq.location]] = [t substringFromIndex:eq.location + 1];
    }
    return v;
}

/* ---------------- a run ---------------- */
@interface HSIntentRun : NSObject
@property (nonatomic, copy) NSString *dir, *kind, *source;
@property (nonatomic, strong) HSApp *app;
@property (nonatomic, strong) NSDictionary *request;
@property (nonatomic) NSInteger seen;                       /* the last step read */
@property (nonatomic) NSInteger pending;                    /* the step waiting for an answer (0: none) */
@property (nonatomic, copy) NSDictionary *pendingStep;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) double lastActivity;
@property (nonatomic) BOOL finished, helperExited;
@property (nonatomic, strong) NSDictionary *uiExtension;    /* an Intents UI extension for this intent */
@property (nonatomic, copy) NSString *carryDialog;          /* handleInApp: what Siri said before the app played it */
@end
@implementation HSIntentRun
- (void)answer:(NSDictionary *)a {
    if (!self.pending) return;
    [a writeToFile:[self.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"answer-%ld.plist", (long)self.pending]] atomically:YES];
    NSLog(@"SpringBoard: Siri answer %@%@", a[@"kind"], a[@"text"] ? [NSString stringWithFormat:@" “%@”", a[@"text"]] : a[@"index"] ? [NSString stringWithFormat:@" %@", a[@"index"]] : @"");
    self.pending = 0; self.pendingStep = nil;
    self.lastActivity = isim_time();
}
@end

/* ---------------- Siri's state ---------------- */
static HSIntentRun *current;
static NSString *ui_mode = @"hidden", *ui_source = @"siri";
static void (^local_choice)(NSInteger index, NSString *text);     /* a question Siri itself asks (which app?) */
static NSUInteger run_seq;
static NSMutableDictionary *helpers;                               /* ext-run request -> block */
static NSTimer *dismiss_timer;
static BOOL refreshing; static NSMutableArray *after_refresh;
static NSString *last_heard;

static NSString *enc(NSString *s) { return [[s ?: @"" stringByReplacingOccurrencesOfString:@"\n" withString:@"\x1e"] stringByReplacingOccurrencesOfString:@"\r" withString:@""]; }
/* what the shell shows (shell_siri.inc): mode = listening | working | value | choice | confirm | result | visual | hidden */
static void siri_ui(NSDictionary *d) {
    static NSUInteger n;
    ui_mode = d[@"mode"] ?: @"hidden";
    if (d[@"source"]) ui_source = d[@"source"];
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"mode=%@\nsource=%@\n", ui_mode, ui_source];
    for (NSString *k in @[@"heard", @"text", @"detail", @"app", @"appname", @"snippet", @"action", @"cancel", @"input", @"placeholder"])
        if ([d[k] length]) [s appendFormat:@"%@=%@\n", k, enc(d[k])];
    for (NSString *t in d[@"tabs"]) [s appendFormat:@"tab=%@\n", enc(t)];
    for (NSDictionary *o in d[@"options"]) [s appendFormat:@"option=%@\x1e%@%@\n", enc(o[@"title"]), enc(o[@"subtitle"]),
                                            o[@"tab"] ? [NSString stringWithFormat:@"\x1e%@", o[@"tab"]] : @""];
    NSString *f = [dir_named(@"Library/SpringBoard/Siri") stringByAppendingPathComponent:[NSString stringWithFormat:@"ui-%lu.txt", (unsigned long)(++n % 8)]];
    [s writeToFile:f atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    isim_shell_request(ISIM_SHELL_SYSTEM, "siri-ui", f.UTF8String, "");
    [dismiss_timer invalidate]; dismiss_timer = nil;
    if ([ui_mode isEqualToString:@"result"]) {
        const char *e = getenv("ISIM_SIRI_RESULT_SECONDS");
        double secs = e && atof(e) > 0 ? atof(e) : 8;
        dismiss_timer = [NSTimer scheduledTimerWithTimeInterval:secs repeats:NO block:^(NSTimer *t) { dismiss_timer = nil; if ([ui_mode isEqualToString:@"result"]) siri_ui(@{ @"mode": @"hidden" }); }];
    }
}
static void siri_say(NSString *text, HSApp *app, NSDictionary *extra) {
    NSMutableDictionary *d = [@{ @"mode": @"result", @"text": text ?: @"" } mutableCopy];
    if (app) { d[@"app"] = app.path; d[@"appname"] = app.name; }
    [d addEntriesFromDictionary:extra ?: @{}];
    if (last_heard) d[@"heard"] = last_heard;
    NSLog(@"SpringBoard: Siri says “%@”", text);
    siri_ui(d);
}

@implementation HomeViewController (Siri)
/* ---- App Shortcuts metadata ---- */
- (void)refreshAppIntents:(void (^)(void))done {
    if (done) { if (!after_refresh) after_refresh = [NSMutableArray array]; [after_refresh addObject:[done copy]]; }
    if (refreshing) return;
    NSMutableArray *stale = [NSMutableArray array];
    for (HSApp *a in self.apps) if (!a.system && !HSAppIntentsMetadata(a) && links_app_intents(a)) [stale addObject:a];
    if (!stale.count) { NSArray *blocks = after_refresh; after_refresh = nil; for (void (^b)(void) in blocks) b(); return; }
    refreshing = YES;
    __block NSUInteger left = stale.count;
    for (HSApp *a in stale)
        [self readAppIntentsOf:a attempt:1 done:^{
            if (--left == 0) {
                refreshing = NO;
                NSArray *blocks = after_refresh; after_refresh = nil;
                for (void (^b)(void) in blocks) b();
            }
        }];
}
/* runs the app's executable in its metadata mode; a helper that has not answered after a while (a loaded machine, a
 * helper that failed to start) is asked again, then the app is given no metadata, so a refresh always finishes */
- (void)readAppIntentsOf:(HSApp *)a attempt:(int)attempt done:(void (^)(void))done {
    NSString *dir = dir_named(@"Library/SpringBoard/AppIntents");
    NSString *req = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"list-%@-%u.plist", a.bundleID, arc4random() % 100000]];
    NSString *out = [req stringByReplacingOccurrencesOfString:@".plist" withString:@"-out.plist"];
    [@{ @"mode": @"appintents-list", @"out": out } writeToFile:req atomically:YES];
    NSString *stamp = exe_stamp(a);
    if (!helpers) helpers = [NSMutableDictionary dictionary];
    helpers[req] = ^{
        NSMutableDictionary *m = [[NSDictionary dictionaryWithContentsOfFile:out] mutableCopy] ?: [@{ @"shortcuts": @[], @"intents": @{}, @"error": @"no metadata" } mutableCopy];
        m[@"stamp"] = stamp; m[@"app"] = a.bundleID; m[@"appName"] = a.name; m[@"appPath"] = a.path;
        if (a.iconPath) m[@"icon"] = a.iconPath;
        [m writeToFile:meta_file(a) atomically:YES];
        [NSFileManager.defaultManager removeItemAtPath:req error:NULL]; [NSFileManager.defaultManager removeItemAtPath:out error:NULL];
        NSLog(@"SpringBoard: %@: %lu App Shortcut(s), %lu intent(s)", a.name, (unsigned long)[m[@"shortcuts"] count], (unsigned long)[m[@"intents"] count]);
        NSMutableArray *schemas = [NSMutableArray array];                 /* @AssistantIntent(schema:) / @AppIntent(schema:) */
        for (NSString *k in m[@"intents"]) if (m[@"intents"][k][@"schema"]) [schemas addObject:[NSString stringWithFormat:@"%@ (%@)", m[@"intents"][k][@"schema"], k]];
        if (schemas.count) NSLog(@"SpringBoard: %@: schema intents: %@", a.name, [[schemas sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]);
        done();
    };
    NSLog(@"SpringBoard: reading %@'s App Intents metadata (attempt %d)", a.name, attempt);
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", a.executable.UTF8String, req.UTF8String);
    const char *e = getenv("ISIM_WAIT_SCALE");
    double wait = 5 * (e && atof(e) > 0 ? atof(e) : 1);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!helpers[req]) return;                                  /* answered */
        [helpers removeObjectForKey:req];
        [NSFileManager.defaultManager removeItemAtPath:req error:NULL]; [NSFileManager.defaultManager removeItemAtPath:out error:NULL];
        NSLog(@"SpringBoard: %@'s App Intents metadata: no answer after %.0f s%@", a.name, wait, attempt < 3 ? @", asking again" : @"");
        if (attempt < 3) [self readAppIntentsOf:a attempt:attempt + 1 done:done];
        else {
            NSLog(@"SpringBoard: %@: 0 App Shortcut(s), 0 intent(s)", a.name);
            done();
        }
    });
}
/* every App Shortcut: { app (HSApp), shortcut (metadata), phrases (with the app's name) } */
- (NSArray<NSDictionary *> *)allAppShortcuts {
    NSMutableArray *out = [NSMutableArray array];
    for (HSApp *a in self.apps) {
        NSDictionary *m = HSAppIntentsMetadata(a);
        for (NSDictionary *s in m[@"shortcuts"]) {
            NSMutableArray *ph = [NSMutableArray array];
            for (NSString *p in s[@"phrases"]) [ph addObject:HSPhraseText(p, a)];
            [out addObject:@{ @"app": a, @"shortcut": s, @"phrases": ph, @"meta": m }];
        }
    }
    return out;
}

/* ---- messages from the shell and the Shortcuts app ---- */
- (void)installSiriObservers {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object, *verb = t, *args = @"";
        NSRange sp = [t rangeOfString:@" "];
        if (sp.location != NSNotFound) { verb = [t substringToIndex:sp.location]; args = [t substringFromIndex:sp.location + 1]; }
        if ([verb isEqualToString:@"siri"]) [self siriCommand:args];
        else if ([verb isEqualToString:@"siri-answer"]) [self siriAnswer:args];
        else if ([verb isEqualToString:@"intent-run"]) [self shortcutsRun:args];
        else if ([verb isEqualToString:@"intents-refresh"]) [self refreshAppIntents:nil];
        else if ([verb isEqualToString:@"visualintelligence"]) [self visualIntelligence:args];
        else if ([verb isEqualToString:@"ext-done"]) {
            NSRange s2 = [args rangeOfString:@" "];
            NSString *req = s2.location == NSNotFound ? args : [args substringFromIndex:s2.location + 1];
            void (^done)(void) = helpers[req];
            if (done) { [helpers removeObjectForKey:req]; done(); }
        } else if ([verb isEqualToString:@"reload"]) [self refreshAppIntents:nil];
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self refreshAppIntents:nil]; });
}
/* "siri L ARGS" from the shell: L = 1 when the device is locked */
static BOOL siri_locked;
- (void)siriCommand:(NSString *)args {
    siri_locked = [args hasPrefix:@"1"];
    args = args.length > 2 ? [args substringFromIndex:2] : @"";
    args = [args stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!args.length) { [self siriListen]; return; }
    if ([args isEqualToString:@"dismiss"] || [args isEqualToString:@"cancel"]) { [self siriAnswer:@"dismiss"]; return; }
    if ((current && current.pending) || local_choice) { [self siriAnswer:[@"text " stringByAppendingString:args]]; return; }
    if ([args hasPrefix:@"intent "]) { [self siriStructured:[args substringFromIndex:7]]; return; }
    [self siriHeard:args source:@"siri"];
}
- (void)siriListen {
    last_heard = nil; current = nil; local_choice = nil;
    NSLog(@"SpringBoard: Siri is listening (iOS %d look)", sb_os());
    siri_ui(@{ @"mode": @"listening", @"source": @"siri", @"text": sb_os() >= 18 ? @"" : @"What can I help you with?", @"input": @"1",
               @"placeholder": @"Ask Siri…" });
}
- (void)siriAnswer:(NSString *)args {
    NSString *kind = args, *rest = @"";
    NSRange sp = [args rangeOfString:@" "];
    if (sp.location != NSNotFound) { kind = [args substringToIndex:sp.location]; rest = [args substringFromIndex:sp.location + 1]; }
    if ([kind isEqualToString:@"dismiss"]) {
        if (current.pending) [current answer:@{ @"kind": @"cancel" }];
        local_choice = nil;
        siri_ui(@{ @"mode": @"hidden" });
        NSLog(@"SpringBoard: Siri dismissed");
        return;
    }
    if (local_choice) {
        void (^c)(NSInteger, NSString *) = local_choice; local_choice = nil;
        if ([kind isEqualToString:@"option"]) c(rest.integerValue, nil);
        else if ([kind isEqualToString:@"text"]) c(-1, rest);
        else c(-2, nil);
        return;
    }
    if (current.pending) {
        if ([kind isEqualToString:@"option"]) [current answer:@{ @"kind": @"option", @"index": @(rest.integerValue) }];
        else if ([kind isEqualToString:@"confirm"]) [current answer:@{ @"kind": @"confirm" }];
        else if ([kind isEqualToString:@"cancel"]) [current answer:@{ @"kind": @"cancel" }];
        else if ([kind isEqualToString:@"text"]) {
            NSString *type = current.pendingStep[@"type"];
            if ([type isEqualToString:@"confirm"]) {        /* "yes", "send", ... */
                NSString *l = norm(rest), *action = norm(current.pendingStep[@"action"] ?: @"");
                BOOL yes = [@[@"yes", @"yeah", @"ok", @"okay", @"sure", @"confirm", @"do it"] containsObject:l] || [l isEqualToString:action];
                [current answer:@{ @"kind": yes ? @"confirm" : @"cancel" }];
            } else if ([type isEqualToString:@"choice"]) {
                NSArray *opts = current.pendingStep[@"options"];
                NSInteger idx = -1;
                for (NSUInteger i = 0; i < opts.count; i++) if ([norm(opts[i][@"title"]) isEqualToString:norm(rest)]) idx = i;
                if (idx < 0 && rest.integerValue > 0 && (NSUInteger)rest.integerValue <= opts.count) idx = rest.integerValue - 1;   /* "2": the second */
                [current answer:idx >= 0 ? @{ @"kind": @"option", @"index": @(idx) } : @{ @"kind": @"text", @"text": rest }];
            } else [current answer:@{ @"kind": @"text", @"text": rest }];
        }
        siri_ui(@{ @"mode": @"working", @"heard": rest, @"app": current.app.path ?: @"", @"appname": current.app.name ?: @"" });
        return;
    }
    if ([kind isEqualToString:@"text"] && rest.length) { [self siriHeard:rest source:@"siri"]; return; }     /* Type to Siri */
    if ([kind isEqualToString:@"cancel"] || [kind isEqualToString:@"confirm"]) siri_ui(@{ @"mode": @"hidden" });
}

/* ---- understanding a request ---- */
- (void)siriHeard:(NSString *)text source:(NSString *)source {
    last_heard = text;
    NSLog(@"SpringBoard: Siri heard “%@”", text);
    siri_ui(@{ @"mode": @"working", @"source": source, @"heard": text });
    [self refreshAppIntents:^{ [self siriUnderstand:text]; }];
}
- (void)siriUnderstand:(NSString *)text {
    NSString *t = norm(text);
    /* 1. App Shortcut phrases */
    for (NSDictionary *e in [self allAppShortcuts]) {
        HSApp *a = e[@"app"]; NSDictionary *s = e[@"shortcut"], *meta = e[@"meta"];
        for (NSString *template in s[@"phrases"]) {
            NSDictionary *params = nil;
            if ([self phrase:template app:a meta:meta intent:s[@"intent"] matches:t params:&params]) {
                NSLog(@"SpringBoard: Siri matched the App Shortcut “%@” of %@", HSPhraseText(template, a), a.name);
                NSMutableDictionary *p = [s[@"params"] ?: @{} mutableCopy]; [p addEntriesFromDictionary:params];
                [self runAppIntent:s[@"intent"] shortcut:s[@"index"] params:p app:a source:@"siri"];
                return;
            }
        }
    }
    /* 2. voice shortcuts (Add to Siri) */
    NSString *vf = [dir_named(@"Library/Siri") stringByAppendingPathComponent:@"VoiceShortcuts.plist"];
    for (NSDictionary *v in [NSDictionary dictionaryWithContentsOfFile:vf][@"shortcuts"]) {
        if (![norm(v[@"invocationPhrase"] ?: @"") isEqualToString:t]) continue;
        HSApp *a = [self appWithIdentifier:v[@"app"] ?: @""];
        if (!a) continue;
        NSLog(@"SpringBoard: Siri matched the voice shortcut “%@” of %@", v[@"invocationPhrase"], a.name);
        NSDictionary *sc = v[@"shortcut"];
        if ([sc[@"intent"] isKindOfClass:[NSDictionary class]]) { [self runSiriKit:sc[@"intent"] app:a source:@"siri"]; return; }
        NSDictionary *act = sc[@"userActivity"][@"activity"];
        if (act) { [self continueActivity:act inApp:a dialog:nil]; return; }
    }
    /* 3. SiriKit phrasings, with the app named at the end (or the start) */
    NSString *rest = text; HSApp *named = nil;
    for (HSApp *a in self.apps) {
        if (a.system) continue;
        for (NSString *prep in @[@" using ", @" with ", @" in ", @" on ", @" via "]) {
            NSString *suffix = [prep stringByAppendingString:a.name];
            if ([norm(rest) hasSuffix:norm(suffix)]) { rest = [rest substringToIndex:rest.length - suffix.length]; named = a; break; }
        }
        if (named) break;
        NSString *prefix = [a.name stringByAppendingString:@", "];
        if ([rest.lowercaseString hasPrefix:prefix.lowercaseString]) { rest = [rest substringFromIndex:prefix.length]; named = a; break; }
    }
    NSString *cls = nil;
    NSDictionary *values = siri_parse(rest, &cls);
    if (values) { [self siriIntent:cls values:values app:named]; return; }
    NSLog(@"SpringBoard: Siri did not understand “%@” (isim's Siri knows App Shortcut phrases, voice shortcuts and the SiriKit phrasings in docs/SCRIPTING.md)", text);
    siri_say(@"Sorry, I can’t help with that here.", nil, nil);
}
- (void)siriStructured:(NSString *)args {
    NSString *cls = nil;
    NSMutableDictionary *v = [structured(args, &cls) mutableCopy];
    HSApp *a = v[@"app"] ? [self appWithIdentifier:v[@"app"]] : nil;
    [v removeObjectForKey:@"app"];
    last_heard = nil;
    NSLog(@"SpringBoard: Siri intent %@ %@", cls, v);
    siri_ui(@{ @"mode": @"working", @"source": @"siri" });
    [self siriIntent:cls values:v ?: @{} app:a];
}
/* a SiriKit intent for an app that supports it (asking which app when several do) */
- (void)siriIntent:(NSString *)cls values:(NSDictionary *)values app:(HSApp *)named {
    NSDictionary *plist = intent_plist(cls, values);
    if (!plist) { siri_say(@"Sorry, I can’t help with that here.", nil, nil); return; }
    if (named && !app_handles(named, cls)) { siri_say([NSString stringWithFormat:@"%@ hasn’t added support for that with Siri.", named.name], named, nil); return; }
    NSMutableArray *apps = [NSMutableArray array];
    if (named) [apps addObject:named]; else for (HSApp *a in self.apps) if (!a.system && app_handles(a, cls)) [apps addObject:a];
    if (!apps.count) { siri_say(@"Sorry, no app on this device can do that.", nil, nil); return; }
    if (apps.count == 1) { [self runSiriKit:plist app:apps[0] source:@"siri"]; return; }
    NSMutableArray *opts = [NSMutableArray array]; for (HSApp *a in apps) [opts addObject:@{ @"title": a.name, @"subtitle": @"" }];
    NSLog(@"SpringBoard: Siri asks “Which app?” (%@)", [[opts valueForKey:@"title"] componentsJoinedByString:@", "]);
    siri_ui(@{ @"mode": @"choice", @"text": @"Which app?", @"options": opts, @"input": @"1", @"heard": last_heard ?: @"" });
    local_choice = ^(NSInteger idx, NSString *text) {
        if (idx < 0 && text) for (NSUInteger i = 0; i < apps.count; i++) if ([norm([apps[i] name]) isEqualToString:norm(text)]) idx = i;
        if (idx < 0 || idx >= (NSInteger)apps.count) { siri_say(@"OK.", nil, nil); return; }
        [self runSiriKit:plist app:apps[idx] source:@"siri"];
    };
}
/* an App Shortcut phrase template against what was said; params: the matched parameter values (ids) */
- (BOOL)phrase:(NSString *)template app:(HSApp *)a meta:(NSDictionary *)meta intent:(NSString *)intent matches:(NSString *)said params:(NSDictionary **)params {
    NSMutableString *pattern = [NSMutableString stringWithString:@"^"];
    NSMutableArray *names = [NSMutableArray array]; NSMutableArray<NSArray *> *choices = [NSMutableArray array];
    NSDictionary *updated = container_plist(a, @"AppShortcutParameters.plist")[@"parameters"];
    NSScanner *sc = [NSScanner scannerWithString:norm(template)];
    sc.charactersToBeSkipped = nil;
    while (!sc.isAtEnd) {
        NSString *lit = nil;
        if ([sc scanUpToString:@"${" intoString:&lit]) [pattern appendString:[[NSRegularExpression escapedPatternForString:lit] stringByReplacingOccurrencesOfString:@" " withString:@"\\s+"]];
        if (sc.isAtEnd) break;
        [sc scanString:@"${" intoString:NULL];
        NSString *name = nil; [sc scanUpToString:@"}" intoString:&name]; [sc scanString:@"}" intoString:NULL];
        if ([name isEqualToString:@"applicationname"] || [name isEqualToString:@"applicationName"]) {
            NSMutableArray *alts = [NSMutableArray arrayWithObject:[NSRegularExpression escapedPatternForString:norm(a.name)]];
            NSString *bn = a.info[@"CFBundleName"];
            if (bn.length && ![norm(bn) isEqualToString:norm(a.name)]) [alts addObject:[NSRegularExpression escapedPatternForString:norm(bn)]];
            [pattern appendFormat:@"(?:%@)", [alts componentsJoinedByString:@"|"]];
            continue;
        }
        /* a parameter: its choices (enum cases, the entities the app suggested or last gave the system) */
        NSString *pname = nil;
        for (NSDictionary *p in meta[@"intents"][intent][@"parameters"]) if ([[p[@"name"] lowercaseString] isEqualToString:name.lowercaseString]) pname = p[@"name"];
        NSArray *opts = nil;
        for (NSDictionary *p in meta[@"intents"][intent][@"parameters"]) if ([p[@"name"] isEqual:pname]) opts = p[@"options"];
        if (updated[[NSString stringWithFormat:@"%@.%@", intent, pname]]) opts = updated[[NSString stringWithFormat:@"%@.%@", intent, pname]];
        if (!opts.count) return NO;
        NSMutableArray *alts = [NSMutableArray array];
        for (NSDictionary *o in opts) { [alts addObject:[NSRegularExpression escapedPatternForString:norm(o[@"title"] ?: @"")]]; }
        [pattern appendFormat:@"(%@)", [alts componentsJoinedByString:@"|"]];
        [names addObject:pname ?: name]; [choices addObject:opts];
    }
    [pattern appendString:@"$"];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:said options:0 range:NSMakeRange(0, said.length)];
    if (!m) return NO;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < names.count && i + 1 < m.numberOfRanges; i++) {
        NSString *v = [said substringWithRange:[m rangeAtIndex:i + 1]];
        for (NSDictionary *o in choices[i]) if ([norm(o[@"title"] ?: @"") isEqualToString:norm(v)]) { out[names[i]] = o[@"id"] ?: o[@"title"]; break; }
    }
    *params = out;
    return YES;
}

/* ---- running ---- */
- (HSIntentRun *)newRun:(NSMutableDictionary *)req app:(HSApp *)a source:(NSString *)source {
    HSIntentRun *r = [HSIntentRun new];
    r.dir = [dir_named(@"Library/SpringBoard/Intents") stringByAppendingPathComponent:[NSString stringWithFormat:@"run-%lu-%u", (unsigned long)++run_seq, arc4random() % 100000]];
    [NSFileManager.defaultManager createDirectoryAtPath:r.dir withIntermediateDirectories:YES attributes:nil error:NULL];
    req[@"dir"] = r.dir; req[@"app"] = a.bundleID; req[@"appName"] = a.name; req[@"source"] = source; req[@"width"] = @(sb_os() >= 26 ? 354 : 358);
    [req writeToFile:[r.dir stringByAppendingPathComponent:@"request.plist"] atomically:YES];
    r.request = req; r.app = a; r.source = source; r.kind = req[@"kind"]; r.lastActivity = isim_time();
    current = r;
    local_choice = nil;
    __weak HomeViewController *weakSelf = self;
    r.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) { [weakSelf pollRun:r]; }];
    return r;
}
/* ---- Visual Intelligence (iOS 26) ----
 * "visualintelligence LABEL[,LABEL...]": what the camera or the screen shows, as labels (isim has no classifier). The
 * apps whose IntentValueQuery takes a SemanticContentDescriptor (their metadata's valueQueries) are run in the
 * background with { values = VisualIntelligence.SemanticContentDescriptor; labels } and their results logged:
 * "SpringBoard: Visual Intelligence: APP: TITLE (SUBTITLE), ...". Once every app has answered, the results sheet shows
 * over the screen (iOS 26's search results, issue #691): a tab per app that found something, its results (title,
 * subtitle). Choosing one opens it: the app's OpenIntent for the result's entity type, with the entity as its target,
 * or (without one) the app. Script ids: vi-sheet, vi-tab-N, vi-result-N (shell_siri.inc). */
static NSString *const VIInput = @"VisualIntelligence.SemanticContentDescriptor";
- (void)visualIntelligence:(NSString *)args {
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (NSString *l in [args componentsSeparatedByString:@","]) {
        NSString *t = [l stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (t.length) [labels addObject:t];
    }
    if (!labels.count) { NSLog(@"SpringBoard: visualintelligence LABEL[,LABEL...]"); return; }
    if (sb_os() < 26) { NSLog(@"SpringBoard: Visual Intelligence needs iOS 26"); return; }
    [self refreshAppIntents:^{
        NSMutableArray<HSApp *> *apps = [NSMutableArray array];
        for (HSApp *a in self.apps) if ([HSAppIntentsMetadata(a)[@"valueQueries"] containsObject:VIInput]) [apps addObject:a];
        NSString *seen = [labels componentsJoinedByString:@", "];
        if (!apps.count) { NSLog(@"SpringBoard: Visual Intelligence: no app searches “%@”", seen); return; }
        NSMutableDictionary *run = [@{ @"seen": seen, @"left": @(apps.count), @"results": [NSMutableArray array] } mutableCopy];
        for (HSApp *a in apps) {
            NSString *dir = [dir_named(@"Library/SpringBoard/Intents") stringByAppendingPathComponent:[NSString stringWithFormat:@"vi-%lu-%u", (unsigned long)++run_seq, arc4random() % 100000]];
            [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *reqPath = [dir stringByAppendingPathComponent:@"request.plist"];
            [@{ @"kind": @"appintent", @"values": VIInput, @"labels": labels, @"dir": dir, @"app": a.bundleID, @"appName": a.name, @"source": @"visualintelligence" }
                writeToFile:reqPath atomically:YES];
            NSLog(@"SpringBoard: Visual Intelligence asks %@ about “%@”", a.name, seen);
            isim_shell_request(ISIM_SHELL_SYSTEM, "launch-bg", a.path.UTF8String, [NSString stringWithFormat:@"%@\x1fisim-intent:%@", a.executable, reqPath].UTF8String);
            [self visualIntelligenceResults:dir app:a run:run tries:0];
        }
    }];
}
/* one app's answer (or its silence) is in: when the last one is, the results sheet */
- (void)visualIntelligenceAnswered:(NSMutableDictionary *)run {
    run[@"left"] = @([run[@"left"] integerValue] - 1);
    if ([run[@"left"] integerValue] > 0) return;
    NSArray<NSDictionary *> *results = run[@"results"];
    if (!results.count) return;
    NSMutableArray *tabs = [NSMutableArray array], *opts = [NSMutableArray array];
    for (NSDictionary *r in results) {
        NSString *name = [r[@"app"] name];
        if (![tabs containsObject:name]) [tabs addObject:name];
        [opts addObject:@{ @"title": r[@"title"] ?: @"", @"subtitle": r[@"subtitle"] ?: @"", @"tab": @([tabs indexOfObject:name]) }];
    }
    NSLog(@"SpringBoard: Visual Intelligence shows %lu result(s) from %@", (unsigned long)results.count, [tabs componentsJoinedByString:@", "]);
    siri_ui(@{ @"mode": @"visual", @"source": @"visualintelligence", @"text": run[@"seen"], @"tabs": tabs, @"options": opts });
    local_choice = ^(NSInteger idx, NSString *text) {
        if (idx < 0 || idx >= (NSInteger)results.count) return;
        siri_ui(@{ @"mode": @"hidden" });
        [self openVisualIntelligenceResult:results[idx]];
    };
}
/* a chosen result: the app's OpenIntent for its entity type, else the app */
- (void)openVisualIntelligenceResult:(NSDictionary *)r {
    HSApp *a = r[@"app"];
    NSDictionary *intents = HSAppIntentsMetadata(a)[@"intents"];
    for (NSString *name in [intents.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if (![r[@"entity"] length] || ![intents[name][@"openTarget"] isEqual:r[@"entity"]]) continue;
        NSLog(@"SpringBoard: Visual Intelligence opens %@ in %@ with %@", r[@"title"], a.name, name);
        [self runAppIntent:name shortcut:nil params:@{ @"target": r[@"id"] ?: @"" } app:a source:@"visualintelligence"];
        return;
    }
    NSLog(@"SpringBoard: Visual Intelligence opens %@ (%@ has no OpenIntent for it)", a.name, r[@"title"]);
    [self launch:a];
}
- (void)visualIntelligenceResults:(NSString *)dir app:(HSApp *)a run:(NSMutableDictionary *)run tries:(int)tries {
    NSDictionary *step = [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:@"step-1.plist"]];
    if (!step) {
        if (tries > 600) { NSLog(@"SpringBoard: Visual Intelligence: %@ did not answer", a.name); [self visualIntelligenceAnswered:run]; return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self visualIntelligenceResults:dir app:a run:run tries:tries + 1];
        });
        return;
    }
    NSMutableArray *found = [NSMutableArray array];
    for (NSDictionary *v in step[@"values"]) {
        NSString *sub = v[@"subtitle"];
        [found addObject:sub.length ? [NSString stringWithFormat:@"%@ (%@)", v[@"title"], sub] : (v[@"title"] ?: @"")];
        NSMutableDictionary *r = [v mutableCopy]; r[@"app"] = a;
        [run[@"results"] addObject:r];
    }
    if ([step[@"outcome"] isEqualToString:@"failure"]) NSLog(@"SpringBoard: Visual Intelligence: %@ failed: %@", a.name, step[@"error"] ?: @"");
    else NSLog(@"SpringBoard: Visual Intelligence: %@: %@", a.name, found.count ? [found componentsJoinedByString:@", "] : @"no results");
    [self visualIntelligenceAnswered:run];
}
static BOOL locked_out(NSString *auth) { return siri_locked && auth.length && ![auth isEqualToString:@"alwaysAllowed"]; }
/* the entry point for App Intents: intent = Module.TypeName; shortcut = the App Shortcut's index (its own intent
   instance) or nil; params = { name = value or entity id }; source = siri | shortcuts | spotlight | ... */
- (void)runAppIntent:(NSString *)intent shortcut:(NSNumber *)shortcut params:(NSDictionary *)params app:(HSApp *)a source:(NSString *)source {
    NSDictionary *info = HSAppIntentsMetadata(a)[@"intents"][intent];
    BOOL foreground = [info[@"openAppWhenRun"] boolValue] || [info[@"open"] boolValue];
    if (locked_out(info[@"authentication"]) || (siri_locked && foreground)) { siri_say(@"You’ll need to unlock your iPhone first.", a, @{ @"source": source }); return; }
    NSMutableDictionary *req = [@{ @"kind": @"appintent", @"intent": intent ?: @"", @"params": params ?: @{} } mutableCopy];
    if (shortcut) req[@"shortcut"] = shortcut;
    HSIntentRun *r = [self newRun:req app:a source:source];
    NSString *marker = [@"isim-intent:" stringByAppendingString:[r.dir stringByAppendingPathComponent:@"request.plist"]];
    NSLog(@"SpringBoard: running “%@” (%@) in %@%@", info[@"title"] ?: intent, intent, a.name, foreground ? @" (opens the app)" : @" (in the background)");
    siri_ui(@{ @"mode": @"working", @"source": source, @"heard": last_heard ?: @"", @"app": a.path, @"appname": a.name });
    if (foreground) [self launch:a url:marker];
    else isim_shell_request(ISIM_SHELL_SYSTEM, "launch-bg", a.path.UTF8String, [NSString stringWithFormat:@"%@\x1f%@", a.executable, marker].UTF8String);
}
/* the app's vocabulary (INVocabulary): a name said its way is spelled the app's way */
static NSString *fold(NSString *s) {
    return [[s stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:nil] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}
static id with_vocabulary(id v, NSArray *vocab, HSApp *a) {
    if ([v isKindOfClass:[NSArray class]]) { NSMutableArray *o = [NSMutableArray array]; for (id x in v) [o addObject:with_vocabulary(x, vocab, a)]; return o; }
    if (![v isKindOfClass:[NSDictionary class]]) return v;
    NSMutableDictionary *d = [v mutableCopy];
    for (NSString *k in v) {
        if (![@[@"mediaName", @"playlistName", @"displayName", @"spokenPhrase", @"artistName", @"albumName"] containsObject:k] || ![v[k] isKindOfClass:[NSString class]]) {
            d[k] = with_vocabulary(v[k], vocab, a); continue;
        }
        NSString *said = fold(v[k]);
        for (NSDictionary *e in vocab) {
            NSMutableArray *forms = [NSMutableArray arrayWithObject:e[@"spokenPhrase"] ?: @""];
            [forms addObjectsFromArray:e[@"alternatives"] ?: @[]];
            BOOL hit = NO;
            for (NSString *f in forms) if (f.length && [fold(f) isEqualToString:said]) hit = YES;
            if (!hit || [e[@"spokenPhrase"] isEqualToString:v[k]]) continue;
            NSLog(@"SpringBoard: Siri used the vocabulary of %@: “%@” is “%@”", a.name, v[k], e[@"spokenPhrase"]);
            d[k] = e[@"spokenPhrase"];
            if ([k isEqualToString:@"spokenPhrase"] && e[@"identifier"]) d[@"vocabularyIdentifier"] = d[@"identifier"] = e[@"identifier"];
            break;
        }
    }
    return d;
}
/* the last message Siri sent with the app (for "edit / unsend my last message") */
static NSString *last_sent_message(HSApp *a) {
    for (NSDictionary *e in [container_plist(a, @"Interactions.plist")[@"interactions"] reverseObjectEnumerator]) {
        if (![e[@"intent"][@"$class"] isEqual:@"INSendMessageIntent"]) continue;
        NSDictionary *r = e[@"intentResponse"];
        NSString *ident = r[@"sentMessage"][@"identifier"] ?: [r[@"sentMessages"] lastObject][@"identifier"];
        if (ident.length) return ident;
    }
    return nil;
}
- (void)runSiriKit:(NSDictionary *)intent app:(HSApp *)a source:(NSString *)source {
    NSString *cls = intent[@"$class"];
    NSMutableArray *vocab = [NSMutableArray array];
    for (NSArray *entries in [container_plist(a, @"Vocabulary.plist")[@"types"] allValues]) [vocab addObjectsFromArray:entries];
    if (vocab.count) intent = with_vocabulary(intent, vocab, a);
    if (([cls isEqualToString:@"INEditMessageIntent"] && !intent[@"messageIdentifier"]) || ([cls isEqualToString:@"INUnsendMessagesIntent"] && !intent[@"messageIdentifiers"])) {
        NSString *last = last_sent_message(a);
        NSMutableDictionary *m = [intent mutableCopy];
        if (last) { if ([cls isEqualToString:@"INEditMessageIntent"]) m[@"messageIdentifier"] = last; else m[@"messageIdentifiers"] = @[last]; }
        NSLog(@"SpringBoard: Siri's last message with %@: %@", a.name, last ?: @"none");
        intent = m;
    }
    NSString *siri = [app_default(a, @"_ISIMPrivacy.siri") description];
    if (![entitlements(a)[@"com.apple.developer.siri"] boolValue]) {
        NSLog(@"SpringBoard: %@ does not have the com.apple.developer.siri entitlement: Siri does not use it", a.name);
        siri_say([NSString stringWithFormat:@"%@ hasn’t added support for that with Siri.", a.name], a, nil); return;
    }
    if (![siri isEqualToString:@"3"]) {
        NSLog(@"SpringBoard: %@ is %@ to use Siri (INPreferences.requestSiriAuthorization)", a.name, siri.length ? @"not allowed" : @"not yet allowed");
        siri_say(siri.length ? [NSString stringWithFormat:@"%@ isn’t allowed to work with Siri. You can change this in Settings.", a.name]
                             : [NSString stringWithFormat:@"You’ll need to open %@ and allow it to use Siri first.", a.name], a, nil);
        return;
    }
    if (siri_locked && [@[@"INSendMessageIntent", @"INSearchForMessagesIntent", @"INEditMessageIntent", @"INUnsendMessagesIntent"] containsObject:cls]) {
        siri_say(@"You’ll need to unlock your iPhone first.", a, nil); return;
    }
    NSDictionary *ext = extension_for_point(a, @"com.apple.intents-service", cls);
    NSMutableDictionary *req = [@{ @"kind": @"sirikit", @"mode": @"run", @"intent": intent } mutableCopy];
    HSIntentRun *r = [self newRun:req app:a source:source];
    r.uiExtension = extension_for_point(a, @"com.apple.intents-ui-service", cls);
    siri_ui(@{ @"mode": @"working", @"source": source, @"heard": last_heard ?: @"", @"app": a.path, @"appname": a.name });
    NSString *reqPath = [r.dir stringByAppendingPathComponent:@"request.plist"];
    if (ext) {
        NSLog(@"SpringBoard: Siri sends %@ to the Intents extension of %@", cls, a.name);
        if (!helpers) helpers = [NSMutableDictionary dictionary];
        helpers[reqPath] = ^{ r.helperExited = YES; };
        isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [ext[@"exe"] UTF8String], reqPath.UTF8String);
    } else {
        NSLog(@"SpringBoard: Siri sends %@ to %@ (application(_:handlerFor:))", cls, a.name);
        isim_shell_request(ISIM_SHELL_SYSTEM, "launch-bg", a.path.UTF8String, [NSString stringWithFormat:@"%@\x1fisim-intent:%@", a.executable, reqPath].UTF8String);
    }
}
- (void)continueActivity:(NSDictionary *)activity inApp:(HSApp *)a dialog:(NSString *)dialog {
    NSString *path = [dir_named(@"Library/isim/Activities") stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"plist"]];
    [activity writeToFile:path atomically:YES];
    NSLog(@"SpringBoard: Siri continues %@ in %@", activity[@"activityType"], a.name);
    if (dialog.length) NSLog(@"SpringBoard: Siri says “%@”", dialog);
    siri_ui(@{ @"mode": @"hidden" });
    [self launch:a url:[@"isim-activity:" stringByAppendingString:path]];
}
- (void)pollRun:(HSIntentRun *)r {
    if (r.finished) { [r.timer invalidate]; return; }
    NSString *next = [r.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"step-%ld.plist", (long)r.seen + 1]];
    NSDictionary *step = [NSDictionary dictionaryWithContentsOfFile:next];
    if (!step) {
        double idle = isim_time() - r.lastActivity;
        if (!r.pending && (idle > 45 || (r.helperExited && idle > 1.5))) {
            r.finished = YES; [r.timer invalidate];
            NSLog(@"SpringBoard: %@ did not answer the intent request", r.app.name);
            if (current == r) siri_say([NSString stringWithFormat:@"Sorry, %@ isn’t responding.", r.app.name], r.app, nil);
        }
        if (r.pending) r.lastActivity = isim_time();
        return;
    }
    r.seen++; r.lastActivity = isim_time();
    if (current != r) { if ([step[@"type"] isEqual:@"result"]) { r.finished = YES; [r.timer invalidate]; } else [self answerStale:r]; return; }
    NSString *type = step[@"type"];
    NSMutableDictionary *ui = [@{ @"app": r.app.path, @"appname": r.app.name, @"source": r.source } mutableCopy];
    if (last_heard) ui[@"heard"] = last_heard;
    if ([type isEqualToString:@"result"]) { [self finishRun:r step:step ui:ui]; return; }
    r.pending = r.seen; r.pendingStep = step;
    ui[@"text"] = step[@"prompt"] ?: @"";
    if ([type isEqualToString:@"value"]) { ui[@"mode"] = @"value"; ui[@"input"] = @"1"; ui[@"placeholder"] = [step[@"kind"] isEqual:@"integer"] || [step[@"kind"] isEqual:@"decimal"] ? @"Number" : @"Text"; }
    else if ([type isEqualToString:@"choice"]) { ui[@"mode"] = @"choice"; ui[@"options"] = step[@"options"] ?: @[]; if (![step[@"text"] isEqual:@NO]) ui[@"input"] = @"1"; }
    else if ([type isEqualToString:@"confirm"]) {
        ui[@"mode"] = @"confirm"; ui[@"action"] = step[@"action"] ?: @"Confirm"; ui[@"cancel"] = step[@"cancel"] ?: @"Cancel";
        if (step[@"detail"]) ui[@"detail"] = step[@"detail"];
        if (step[@"snippet"]) ui[@"snippet"] = step[@"snippet"];
    }
    NSString *opts = [step[@"options"] count] ? [NSString stringWithFormat:@" [%@]", [[step[@"options"] valueForKey:@"title"] componentsJoinedByString:@", "]] : @"";
    NSLog(@"SpringBoard: Siri asks “%@”%@%@", ui[@"text"], opts, [type isEqualToString:@"confirm"] ? [NSString stringWithFormat:@" (%@ / %@)", ui[@"action"], ui[@"cancel"]] : @"");
    if ([type isEqualToString:@"confirm"] && r.uiExtension && step[@"interaction"]) {
        [self runUIExtension:r interaction:step[@"interaction"] confirm:YES done:^(NSString *png) { if (png) { ui[@"snippet"] = png; [ui removeObjectForKey:@"detail"]; } siri_ui(ui); }];
        return;
    }
    siri_ui(ui);
}
- (void)answerStale:(HSIntentRun *)r {            /* a run Siri moved on from: its questions are cancelled */
    r.pending = r.seen;
    [r answer:@{ @"kind": @"cancel" }];
}
- (void)runUIExtension:(HSIntentRun *)r interaction:(NSDictionary *)interaction confirm:(BOOL)confirm done:(void (^)(NSString *png))done {
    NSString *req = [r.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"ui-%ld.plist", (long)r.seen]];
    NSString *out = [r.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"ui-%ld-out.plist", (long)r.seen]];
    [@{ @"mode": @"intents-ui", @"interaction": interaction, @"confirm": @(confirm), @"width": @(sb_os() >= 26 ? 354 : 358), @"out": out } writeToFile:req atomically:YES];
    if (!helpers) helpers = [NSMutableDictionary dictionary];
    helpers[req] = ^{ NSDictionary *res = [NSDictionary dictionaryWithContentsOfFile:out]; done(res[@"image"]); };
    NSLog(@"SpringBoard: Siri asks the Intents UI extension of %@ for its view", r.app.name);
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [r.uiExtension[@"exe"] UTF8String], req.UTF8String);
}
- (void)finishRun:(HSIntentRun *)r step:(NSDictionary *)step ui:(NSMutableDictionary *)ui {
    r.finished = YES; [r.timer invalidate]; r.pending = 0;
    NSString *outcome = step[@"outcome"] ?: @"success";
    NSString *dialog = step[@"dialog"];
    if (!dialog.length && [outcome isEqualToString:@"success"]) dialog = step[@"value"] ?: @"Done.";
    if (!dialog.length && [outcome isEqualToString:@"failure"]) dialog = [NSString stringWithFormat:@"Sorry, there was a problem with %@.", r.app.name];
    if (!dialog.length && [outcome isEqualToString:@"cancelled"]) dialog = @"OK.";
    if ([r.kind isEqualToString:@"sirikit"] && [outcome isEqualToString:@"success"] && step[@"interaction"]) [self donate:step[@"interaction"] app:r.app];
    if ([outcome isEqualToString:@"continueInApp"] || [outcome isEqualToString:@"appLaunch"]) {
        [self continueActivity:step[@"activity"] ?: @{ @"activityType": r.request[@"intent"][@"$class"] ?: @"" } inApp:r.app dialog:dialog];
        if (current == r) current = nil;
        return;
    }
    if ([outcome isEqualToString:@"handleInApp"]) {          /* media: the app plays it, launched in the background */
        NSDictionary *resolved = [step[@"interaction"][@"intent"] isKindOfClass:[NSDictionary class]] ? step[@"interaction"][@"intent"] : r.request[@"intent"];
        NSMutableDictionary *req = [@{ @"kind": @"sirikit", @"mode": @"handleInApp", @"intent": resolved } mutableCopy];
        HSIntentRun *r2 = [self newRun:req app:r.app source:r.source];
        r2.carryDialog = dialog;
        NSLog(@"SpringBoard: Siri asks %@ to handle %@ in the app", r.app.name, r.request[@"intent"][@"$class"]);
        isim_shell_request(ISIM_SHELL_SYSTEM, "launch-bg", r.app.path.UTF8String,
                           [NSString stringWithFormat:@"%@\x1fisim-intent:%@", r.app.executable, [r2.dir stringByAppendingPathComponent:@"request.plist"]].UTF8String);
        ui[@"mode"] = @"working"; ui[@"text"] = dialog;
        siri_ui(ui);
        return;
    }
    if ([step[@"inApp"] boolValue] && r.carryDialog.length && [outcome isEqualToString:@"success"]) dialog = r.carryDialog;
    if (current == r) current = nil;
    if ([step[@"open"] boolValue]) {                          /* openAppWhenRun / opensIntent: the app comes forward */
        NSLog(@"SpringBoard: %@ opens", r.app.name);
        if (dialog.length && ![dialog isEqualToString:@"Done."]) NSLog(@"SpringBoard: Siri says “%@”", dialog);
        siri_ui(@{ @"mode": @"hidden" });
        /* an opened URL (OpenURLIntent, a URL-representable OpenIntent) already brought forward the app that claims it:
           launching again would cover that app, or bring this one back after the user went home */
        if (!step[@"url"]) [self launch:r.app];
        return;
    }
    ui[@"mode"] = @"result"; ui[@"text"] = dialog;
    if (step[@"detail"]) ui[@"detail"] = step[@"detail"];
    if (step[@"snippet"]) ui[@"snippet"] = step[@"snippet"];
    NSLog(@"SpringBoard: Siri says “%@”%@", dialog, step[@"snippet"] ? @" (with a snippet view)" : @"");
    if (r.uiExtension && step[@"interaction"] && ![outcome isEqualToString:@"cancelled"]) {
        [self runUIExtension:r interaction:step[@"interaction"] confirm:NO done:^(NSString *png) { if (png) { ui[@"snippet"] = png; [ui removeObjectForKey:@"detail"]; } siri_ui(ui); }];
        return;
    }
    siri_ui(ui);
}
/* like iOS, Siri donates the interactions it handled (the app's Siri Suggestions in the Shortcuts app) */
- (void)donate:(NSDictionary *)interaction app:(HSApp *)a {
    NSString *dir = [a.containerPath stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *f = [dir stringByAppendingPathComponent:@"Interactions.plist"];
    NSMutableArray *list = [[NSDictionary dictionaryWithContentsOfFile:f][@"interactions"] mutableCopy] ?: [NSMutableArray array];
    NSMutableDictionary *e = [interaction mutableCopy]; e[@"date"] = [NSDate date]; e[@"app"] = a.bundleID; e[@"siri"] = @YES;
    [list addObject:e];
    while (list.count > 100) [list removeObjectAtIndex:0];
    [@{ @"interactions": list } writeToFile:f atomically:YES];
}

/* "intent-run BUNDLE\x1fKIND\x1fID\x1fSOURCE" from the Shortcuts app (or Spotlight): KIND = shortcut (an App Shortcut's
   index) | intent (an intent type) | voice (a voice shortcut's id) | donation (a donated interaction's id) */
- (void)shortcutsRun:(NSString *)args {
    NSArray *p = [args componentsSeparatedByString:@"\x1f"];
    if (p.count < 3) return;
    HSApp *a = [self appWithIdentifier:p[0]];
    NSString *kind = p[1], *ident = p[2], *source = p.count > 3 ? p[3] : @"shortcuts";
    if (!a) { NSLog(@"SpringBoard: intent-run: no app %@", p[0]); return; }
    siri_locked = NO; last_heard = nil;
    [self refreshAppIntents:^{
        if ([kind isEqualToString:@"shortcut"]) {
            NSDictionary *s = nil;
            for (NSDictionary *x in HSAppIntentsMetadata(a)[@"shortcuts"]) if ([x[@"index"] integerValue] == ident.integerValue) s = x;
            if (!s) { NSLog(@"SpringBoard: %@ has no App Shortcut %@", a.name, ident); return; }
            [self runAppIntent:s[@"intent"] shortcut:s[@"index"] params:s[@"params"] app:a source:source];
        } else if ([kind isEqualToString:@"intent"]) [self runAppIntent:ident shortcut:nil params:nil app:a source:source];
        else if ([kind isEqualToString:@"relevant"]) {                /* INRelevantShortcutStore: "relevant-N" */
            NSArray *list = container_plist(a, @"RelevantShortcuts.plist")[@"shortcuts"];
            NSInteger n = [[ident componentsSeparatedByString:@"-"].lastObject integerValue];
            NSDictionary *sc = n >= 0 && n < (NSInteger)list.count ? list[n][@"shortcut"] : nil;
            if ([sc[@"intent"] isKindOfClass:[NSDictionary class]]) [self runSiriKit:sc[@"intent"] app:a source:source];
            else if (sc[@"userActivity"][@"activity"]) [self continueActivity:sc[@"userActivity"][@"activity"] inApp:a dialog:nil];
            else NSLog(@"SpringBoard: %@ has no relevant shortcut %@", a.name, ident);
        }
        else if ([kind isEqualToString:@"donation"]) {
            for (NSDictionary *e in container_plist(a, @"Interactions.plist")[@"interactions"]) {
                if (![e[@"identifier"] isEqual:ident]) continue;
                if ([e[@"intent"] isKindOfClass:[NSDictionary class]]) { [self runSiriKit:e[@"intent"] app:a source:source]; return; }
                if (e[@"appIntent"]) { [self runAppIntent:e[@"appIntent"] shortcut:nil params:e[@"params"] app:a source:source]; return; }   /* IntentDonationManager */
            }
        } else if ([kind isEqualToString:@"voice"]) {
            NSString *vf = [dir_named(@"Library/Siri") stringByAppendingPathComponent:@"VoiceShortcuts.plist"];
            for (NSDictionary *v in [NSDictionary dictionaryWithContentsOfFile:vf][@"shortcuts"]) {
                if (![[v[@"identifier"] isKindOfClass:[NSDictionary class]] ? v[@"identifier"][@"uuid"] : v[@"identifier"] isEqual:ident]) continue;
                NSDictionary *sc = v[@"shortcut"];
                if ([sc[@"intent"] isKindOfClass:[NSDictionary class]]) [self runSiriKit:sc[@"intent"] app:a source:source];
                else if (sc[@"userActivity"][@"activity"]) [self continueActivity:sc[@"userActivity"][@"activity"] inApp:a dialog:nil];
                return;
            }
        }
    }];
}
/* Spotlight: App Shortcuts matching a query (their title, short title, phrases or the app's name) */
- (NSArray<NSDictionary *> *)appShortcutsMatching:(NSString *)q {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *e in [self allAppShortcuts]) {
        HSApp *a = e[@"app"]; NSDictionary *s = e[@"shortcut"];
        NSDictionary *info = e[@"meta"][@"intents"][s[@"intent"]];
        if (info && ![info[@"discoverable"] boolValue]) continue;
        NSMutableArray *texts = [NSMutableArray arrayWithObjects:s[@"title"] ?: @"", s[@"shortTitle"] ?: @"", a.name, nil];
        [texts addObjectsFromArray:e[@"phrases"]];
        [texts addObjectsFromArray:info[@"keywords"] ?: @[]];
        for (NSString *t in texts) if ([t rangeOfString:q options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) { [out addObject:e]; break; }
    }
    return out;
}
- (void)runAppShortcut:(NSDictionary *)e source:(NSString *)source {
    HSApp *a = e[@"app"]; NSDictionary *s = e[@"shortcut"];
    siri_locked = NO; last_heard = nil;
    [self runAppIntent:s[@"intent"] shortcut:s[@"index"] params:s[@"params"] app:a source:source];
}
@end

/* the reusable entry point (other system features: Control Center controls, Focus filters, ...): run an App Intent
   of an installed app with the system's UI for its questions and result */
void HSRunIntentRequest(HomeViewController *home, NSString *bundleID, NSString *intentType, NSDictionary *params, NSString *source) {
    HSApp *a = [home appWithIdentifier:bundleID];
    if (!a) { NSLog(@"SpringBoard: no app %@", bundleID); return; }
    [home runAppIntent:intentType shortcut:nil params:params app:a source:source ?: @"system"];
}
NSArray<NSString *> *HSSiriKitClasses(HSApp *a) { return app_sirikit_classes(a); }
