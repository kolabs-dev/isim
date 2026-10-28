// isim home screen: BackgroundAssets downloader extensions (<App>.app/PlugIns/*.appex with NSExtensionPointIdentifier
// com.apple.background-asset-downloader-extension). Like iOS's system, the home screen runs an app's downloader
// extension (a helper process the shell starts: "ext-run EXE REQUEST") once when the app is installed (.install), and
// when `isim bgassets run APP install|update|periodic [--manifest URL]` drops a request into
// <isim data>/Library/isim/BackgroundAssets/Queue. The request carries the app's BAManifestURL (or --manifest), its
// app group (BAAppGroupID) and allowances (BAEssentialMaxInstallSize, BAMaxInstallSize); the extension
// (BackgroundAssets/Extension.swift) writes what it downloaded, which is logged and kept per app
// (…/BackgroundAssets/<bundle id>.plist: the install event ran, the last results).
#import "SpringBoard.h"

static NSString *const kDownloaderPoint = @"com.apple.background-asset-downloader-extension";
static NSString *ba_dir(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/BackgroundAssets"]; }
static NSString *ba_queue(void) { return [ba_dir() stringByAppendingPathComponent:@"Queue"]; }
static NSMutableDictionary<NSString *, NSString *> *ba_pending;     /* request path -> app bundle id */
static NSUInteger ba_seq;

/* the app's downloader extension: { path, exe } */
static NSDictionary *downloader_extension(HSApp *a) {
    NSString *plugins = [a.path stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        if (![info[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:kDownloaderPoint]) continue;
        return @{ @"path": p, @"exe": [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension] };
    }
    return nil;
}
static NSString *state_path(NSString *bundle) { return [ba_dir() stringByAppendingPathComponent:[bundle stringByAppendingPathExtension:@"plist"]]; }

@implementation HomeViewController (BackgroundAssets)
- (void)installBackgroundAssetsObservers {
    [NSFileManager.defaultManager createDirectoryAtPath:ba_queue() withIntermediateDirectories:YES attributes:nil error:NULL];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSystemEvent" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSString *t = n.object;
        if (![t hasPrefix:@"ext-done "]) return;
        NSString *args = [t substringFromIndex:9];
        NSRange sp = [args rangeOfString:@" "];
        NSString *req = sp.location == NSNotFound ? args : [args substringFromIndex:sp.location + 1];
        NSString *bundle = ba_pending[req];
        if (!bundle) return;                                       /* another kind of extension's */
        [ba_pending removeObjectForKey:req];
        [self backgroundAssetsDone:req bundle:bundle];
    }];
    [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *timer) { [self scanBackgroundAssetsQueue]; }];
}
/* from reload: the install event of apps that have not had it */
- (void)discoverBackgroundAssets {
    for (HSApp *a in self.apps) {
        if (a.system || !downloader_extension(a)) continue;
        NSDictionary *st = [NSDictionary dictionaryWithContentsOfFile:state_path(a.bundleID)];
        if ([st[@"installed"] boolValue]) continue;
        NSMutableDictionary *m = [st mutableCopy] ?: [NSMutableDictionary dictionary];
        m[@"installed"] = @YES;
        [NSFileManager.defaultManager createDirectoryAtPath:ba_dir() withIntermediateDirectories:YES attributes:nil error:NULL];
        [m writeToFile:state_path(a.bundleID) atomically:YES];
        [self runDownloader:a request:@"install" manifest:nil];
    }
}
- (void)scanBackgroundAssetsQueue {
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:ba_queue() error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *f in files) {
        if (![f hasSuffix:@".plist"]) continue;
        NSString *p = [ba_queue() stringByAppendingPathComponent:f];
        NSDictionary *q = [NSDictionary dictionaryWithContentsOfFile:p];
        [NSFileManager.defaultManager removeItemAtPath:p error:NULL];
        HSApp *a = [self appWithIdentifier:q[@"bundle"] ?: @""];
        if (!a) { NSLog(@"SpringBoard: background assets: no app %@", q[@"bundle"]); continue; }
        [self runDownloader:a request:q[@"request"] ?: @"periodic" manifest:q[@"manifest"]];
    }
}
- (void)runDownloader:(HSApp *)a request:(NSString *)request manifest:(NSString *)manifest {
    NSDictionary *ext = downloader_extension(a);
    if (!ext) { NSLog(@"SpringBoard: background assets: %@ has no downloader extension", a.bundleID); return; }
    NSString *dir = [ba_dir() stringByAppendingPathComponent:@"Requests"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *base = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu-%u", a.bundleID, (unsigned long)++ba_seq, arc4random() % 100000]];
    NSString *req = [base stringByAppendingPathExtension:@"plist"];
    NSMutableDictionary *r = [@{ @"request": request, @"bundle": a.bundleID, @"out": [base stringByAppendingString:@"-result.plist"] } mutableCopy];
    NSString *url = manifest.length ? manifest : a.info[@"BAManifestURL"];
    if (url) r[@"manifestURL"] = url;
    if (a.info[@"BAAppGroupID"]) r[@"appGroup"] = a.info[@"BAAppGroupID"];
    if (a.info[@"BAEssentialMaxInstallSize"]) r[@"essentialBudget"] = a.info[@"BAEssentialMaxInstallSize"];
    if (a.info[@"BAMaxInstallSize"]) r[@"budget"] = a.info[@"BAMaxInstallSize"];
    [r writeToFile:req atomically:YES];
    if (!ba_pending) ba_pending = [NSMutableDictionary dictionary];
    ba_pending[req] = a.bundleID;
    NSLog(@"SpringBoard: background assets: %@ for %@", request, a.bundleID);
    isim_shell_request(ISIM_SHELL_SYSTEM, "ext-run", [ext[@"exe"] UTF8String], req.UTF8String);
}
- (void)backgroundAssetsDone:(NSString *)req bundle:(NSString *)bundle {
    NSDictionary *res = [NSDictionary dictionaryWithContentsOfFile:[[req stringByDeletingPathExtension] stringByAppendingString:@"-result.plist"]];
    NSUInteger ok = 0, failed = 0;
    for (NSDictionary *d in res[@"downloads"]) { if ([d[@"state"] isEqual:@"finished"]) ok++; else failed++; }
    if (!res) NSLog(@"SpringBoard: background assets for %@: the extension ended without a result", bundle);
    else if (res[@"manifestError"]) NSLog(@"SpringBoard: background assets for %@: the manifest could not be downloaded", bundle);
    else NSLog(@"SpringBoard: background assets for %@: %lu finished, %lu failed", bundle, (unsigned long)ok, (unsigned long)failed);
    NSMutableDictionary *st = [[NSDictionary dictionaryWithContentsOfFile:state_path(bundle)] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (res) st[@"last"] = res;
    [st writeToFile:state_path(bundle) atomically:YES];
}
@end
