// isim home screen: Spotlight asking apps (CoreSpotlight, issue #412).
// - Requests from `isim spotlight reindex|items|throttle APP ...` (<isim data>/Library/isim/Spotlight/Queue) go to
//   <isim data>/Library/Spotlight/Requests/<bundle id>/ with a Darwin notification (dev.isim.spotlight.<bundle id>),
//   which the running app's index delegate answers (CoreSpotlight/Delegate.swift). When none takes it within a second,
//   the app's Spotlight index extension (<App>.app/PlugIns/*.appex, NSExtensionPointIdentifier com.apple.spotlight.index)
//   runs as a helper process ("ext-run EXE REQUEST"); without one the request waits for the app's delegate.
// - Import extensions (com.apple.spotlight.import): files of the types they declare (CSSupportedContentTypes) in the
//   app's Documents are imported when they appear or change (and by `isim spotlight import APP FILE`); what the
//   extension fills in is indexed as the app's item, the file's URL its identifier. Removed files leave the index.
#import "SpringBoard.h"
#include <notify.h>
#include <sys/stat.h>

static NSString *const kIndexPoint = @"com.apple.spotlight.index";
static NSString *const kImportPoint = @"com.apple.spotlight.import";
static NSString *cs_dir(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/Spotlight"]; }
static NSString *cs_queue(void) { return [cs_dir() stringByAppendingPathComponent:@"Queue"]; }
static NSMutableDictionary<NSString *, NSDictionary *> *cs_pending;     /* request path -> { bundle, request, file } */
static NSUInteger cs_seq;
static NSArray<HSApp *> *cs_importers;                                     /* apps with an import extension */

/* the app's extension for a Spotlight extension point: { path, exe, info } */
static NSDictionary *cs_extension(HSApp *a, NSString *point) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        if (![info[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:point]) continue;
        return @{ @"path": p, @"exe": [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension], @"info": info };
    }
    return nil;
}
/* the filename extensions of the content types an import extension takes (the app's declared types, then common ones) */
static NSDictionary<NSString *, NSString *> *cs_import_extensions(HSApp *a, NSDictionary *ext) {
    NSArray *types = ext[@"info"][@"NSExtension"][@"NSExtensionAttributes"][@"CSSupportedContentTypes"] ?: @[];
    NSMutableDictionary *byExt = [NSMutableDictionary dictionary];
    NSDictionary *common = @{ @"public.plain-text": @[@"txt"], @"public.text": @[@"txt"], @"net.daringfireball.markdown": @[@"md", @"markdown"],
                              @"public.json": @[@"json"], @"public.png": @[@"png"], @"public.jpeg": @[@"jpg", @"jpeg"], @"com.adobe.pdf": @[@"pdf"],
                              @"public.html": @[@"html", @"htm"], @"public.comma-separated-values-text": @[@"csv"] };
    NSMutableArray *decls = [NSMutableArray arrayWithArray:a.info[@"UTExportedTypeDeclarations"] ?: @[]];
    [decls addObjectsFromArray:a.info[@"UTImportedTypeDeclarations"] ?: @[]];
    for (NSString *t in types) {
        for (NSDictionary *d in decls) {
            if (![d[@"UTTypeIdentifier"] isEqual:t]) continue;
            id exts = d[@"UTTypeTagSpecification"][@"public.filename-extension"];
            for (NSString *e in [exts isKindOfClass:[NSArray class]] ? exts : exts ? @[exts] : @[]) byExt[e.lowercaseString] = t;
        }
        for (NSString *e in common[t]) if (!byExt[e]) byExt[e] = t;
    }
    return byExt;
}
static NSString *index_file(NSString *bundle) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/Spotlight"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:[bundle stringByAppendingPathExtension:@"plist"]];
}
static void edit_index(NSString *bundle, void (^edit)(NSMutableArray *items)) {
    NSString *f = index_file(bundle);
    NSMutableDictionary *all = [[NSDictionary dictionaryWithContentsOfFile:f] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableArray *items = [all[@"items"] mutableCopy] ?: [NSMutableArray array];
    edit(items);
    all[@"items"] = items;
    [all writeToFile:f atomically:YES];
}

@implementation HomeViewController (SpotlightIndex)
- (void)installSpotlightIndexObservers {
    [NSFileManager.defaultManager createDirectoryAtPath:cs_queue() withIntermediateDirectories:YES attributes:nil error:NULL];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if (![t hasPrefix:@"ext-done "]) return;
        NSString *args = [t substringFromIndex:9];
        NSRange sp = [args rangeOfString:@" "];
        NSString *req = sp.location == NSNotFound ? args : [args substringFromIndex:sp.location + 1];
        NSDictionary *p = cs_pending[req];
        if (!p) return;                                            /* another kind of extension's */
        [cs_pending removeObjectForKey:req];
        [self spotlightExtensionDone:req pending:p];
    }];
    [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *timer) { [self scanSpotlightQueue]; }];
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) { [self scanSpotlightImports]; }];
}
/* from reload: the apps with an import extension */
- (void)discoverSpotlightExtensions {
    NSMutableArray *a = [NSMutableArray array];
    for (HSApp *app in self.apps) if (!app.system && cs_extension(app, kImportPoint)) [a addObject:app];
    cs_importers = a;
    [self scanSpotlightImports];
}
- (void)scanSpotlightQueue {
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:cs_queue() error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *f in files) {
        if (![f hasSuffix:@".plist"]) continue;
        NSString *p = [cs_queue() stringByAppendingPathComponent:f];
        NSDictionary *q = [NSDictionary dictionaryWithContentsOfFile:p];
        [NSFileManager.defaultManager removeItemAtPath:p error:NULL];
        HSApp *a = [self appWithIdentifier:q[@"bundle"] ?: @""];
        if (!a) { NSLog(@"SpringBoard: Spotlight: no app %@", q[@"bundle"]); continue; }
        if ([q[@"request"] isEqual:@"import"]) {
            NSString *file = q[@"file"] ?: @"";
            if (!file.isAbsolutePath) file = [a.containerPath stringByAppendingPathComponent:file];
            [self spotlightImport:a file:file];
        } else [self spotlightAsk:a request:q[@"request"] ?: @"reindex" identifiers:q[@"identifiers"] ?: @[]];
    }
}
- (NSString *)spotlightRequestPath:(HSApp *)a {
    NSString *dir = [cs_dir() stringByAppendingPathComponent:@"Requests"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu-%u.plist", a.bundleID, (unsigned long)++cs_seq, arc4random() % 100000]];
}
/* reindex all or some items, items by identifier, throttling: the running app's index delegate, else (after a second)
   the index extension */
- (void)spotlightAsk:(HSApp *)a request:(NSString *)request identifiers:(NSArray *)ids {
    NSString *what = ids.count ? [ids componentsJoinedByString:@", "] : @"all items";
    NSString *dir = [[isim_data_dir() stringByAppendingPathComponent:@"Library/Spotlight/Requests"] stringByAppendingPathComponent:a.bundleID];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *pending = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%.6f-%lu.plist", isim_time(), (unsigned long)++cs_seq]];
    [@{ @"request": request, @"identifiers": ids } writeToFile:pending atomically:YES];
    NSLog(@"SpringBoard: Spotlight asks %@: %@ (%@)", a.name, request, what);
    notify_post([@"dev.isim.spotlight." stringByAppendingString:a.bundleID].UTF8String);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![NSFileManager.defaultManager fileExistsAtPath:pending]) return;          /* the app's index delegate took it */
        NSDictionary *ext = cs_extension(a, kIndexPoint);
        if (!ext) {
            NSLog(@"SpringBoard: Spotlight: no index delegate of %@ answered (the app is not running, or has no CSSearchableIndexDelegate); the request waits for it", a.name);
            return;
        }
        [NSFileManager.defaultManager removeItemAtPath:pending error:NULL];
        NSString *req = [self spotlightRequestPath:a];
        [@{ @"request": request, @"identifiers": ids, @"bundle": a.bundleID, @"out": [[req stringByDeletingPathExtension] stringByAppendingString:@"-result.plist"] }
            writeToFile:req atomically:YES];
        if (!cs_pending) cs_pending = [NSMutableDictionary dictionary];
        cs_pending[req] = @{ @"bundle": a.bundleID, @"request": request };
        NSLog(@"SpringBoard: Spotlight asks the index extension of %@: %@ (%@)", a.name, request, what);
        isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [ext[@"exe"] UTF8String], req.UTF8String);
    });
}
/* a file for the app's import extension */
- (void)spotlightImport:(HSApp *)a file:(NSString *)file {
    NSDictionary *ext = cs_extension(a, kImportPoint);
    if (!ext) { NSLog(@"SpringBoard: Spotlight: %@ has no import extension", a.name); return; }
    NSString *type = cs_import_extensions(a, ext)[file.pathExtension.lowercaseString];
    NSString *req = [self spotlightRequestPath:a];
    NSMutableDictionary *r = [@{ @"request": @"import", @"file": file, @"bundle": a.bundleID,
                                  @"out": [[req stringByDeletingPathExtension] stringByAppendingString:@"-result.plist"] } mutableCopy];
    if (type) r[@"contentType"] = type;
    [r writeToFile:req atomically:YES];
    if (!cs_pending) cs_pending = [NSMutableDictionary dictionary];
    cs_pending[req] = @{ @"bundle": a.bundleID, @"request": @"import", @"file": file };
    NSLog(@"SpringBoard: Spotlight imports %@ with %@'s import extension", file.lastPathComponent, a.name);
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [ext[@"exe"] UTF8String], req.UTF8String);
}
- (void)spotlightExtensionDone:(NSString *)req pending:(NSDictionary *)p {
    NSDictionary *res = [NSDictionary dictionaryWithContentsOfFile:[[req stringByDeletingPathExtension] stringByAppendingString:@"-result.plist"]];
    [NSFileManager.defaultManager removeItemAtPath:req error:NULL];
    if (![p[@"request"] isEqual:@"import"]) {
        NSLog(@"SpringBoard: Spotlight: the index extension of %@ %@", p[@"bundle"], res[@"acknowledged"] ? @"acknowledged" : @"ended without acknowledging");
        return;
    }
    NSString *file = p[@"file"];
    NSDictionary *attrs = res[@"attributes"];
    if (!attrs) { NSLog(@"SpringBoard: Spotlight: %@ was not imported (%@)", file.lastPathComponent, res[@"error"] ?: @"no result"); return; }
    NSMutableDictionary *a = [attrs mutableCopy];
    NSString *url = [NSURL fileURLWithPath:file].absoluteString;
    if (!a[@"contentURL"]) a[@"contentURL"] = @{ @"$url": url };
    NSString *title = a[@"title"] ?: a[@"displayName"] ?: file.lastPathComponent;
    edit_index(p[@"bundle"], ^(NSMutableArray *items) {
        [items filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *b) { return ![e[@"id"] isEqual:url]; }]];
        NSMutableDictionary *e = [@{ @"id": url, @"kind": @"item", @"index": @"default", @"domain": @"", @"title": title,
                                     @"contentType": a[@"contentType"] ?: @"", @"attributes": a, @"imported": @YES } mutableCopy];
        if (a[@"contentDescription"]) e[@"description"] = a[@"contentDescription"];
        if (a[@"keywords"]) e[@"keywords"] = a[@"keywords"];
        [items addObject:e];
    });
    NSLog(@"SpringBoard: Spotlight indexed %@ for %@ (“%@”)", file.lastPathComponent, p[@"bundle"], title);
}
/* new, changed and removed files in the Documents of apps with an import extension */
- (void)scanSpotlightImports {
    for (HSApp *a in cs_importers) {
        NSDictionary *ext = cs_extension(a, kImportPoint);
        NSDictionary *types = cs_import_extensions(a, ext);
        if (!types.count) continue;
        NSString *docs = [a.containerPath stringByAppendingPathComponent:@"Documents"];
        NSString *statePath = [[cs_dir() stringByAppendingPathComponent:@"Imported"] stringByAppendingPathComponent:[a.bundleID stringByAppendingPathExtension:@"plist"]];
        NSMutableDictionary *state = [[NSDictionary dictionaryWithContentsOfFile:statePath] mutableCopy] ?: [NSMutableDictionary dictionary];
        NSMutableSet *seen = [NSMutableSet set];
        BOOL changed = NO;
        NSDirectoryEnumerator *en = [NSFileManager.defaultManager enumeratorAtPath:docs];
        for (NSString *rel in en) {
            if (en.level > 4) { [en skipDescendants]; continue; }
            if (!types[rel.pathExtension.lowercaseString]) continue;
            NSString *full = [docs stringByAppendingPathComponent:rel];
            struct stat st;
            if (stat(full.fileSystemRepresentation, &st) != 0 || !S_ISREG(st.st_mode)) continue;
            [seen addObject:full];
            NSNumber *m = @((double)st.st_mtime);
            if ([state[full] isEqual:m]) continue;
            state[full] = m; changed = YES;
            [self spotlightImport:a file:full];
        }
        for (NSString *f in state.allKeys) {
            if ([seen containsObject:f]) continue;
            [state removeObjectForKey:f]; changed = YES;
            NSString *url = [NSURL fileURLWithPath:f].absoluteString;
            edit_index(a.bundleID, ^(NSMutableArray *items) {
                [items filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *b) { return ![e[@"id"] isEqual:url]; }]];
            });
            NSLog(@"SpringBoard: Spotlight removed %@ of %@ (the file is gone)", f.lastPathComponent, a.name);
        }
        if (changed) {
            [NSFileManager.defaultManager createDirectoryAtPath:statePath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
            [state writeToFile:statePath atomically:YES];
        }
    }
}
@end
