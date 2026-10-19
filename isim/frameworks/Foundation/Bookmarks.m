/* isim Foundation (ARC): URL bookmarks, security-scoped access and NSFileVersion.
 * Adapted. A bookmark is "book" and a property list: the absolute path (and the path relative to the URL it was made
 * relative to), the file's device and inode, and the resource values asked for. Resolving finds the file at its path;
 * when another file is there, or none, it looks in the folder for the file with the same inode (a file renamed in its
 * folder) and reports the bookmark stale. isim has no sandbox, so security-scoped access always succeeds for file URLs
 * (the calls are counted, for apps that balance them).
 * NSFileVersion keeps the other versions of a file in a hidden ".<name>.versions" folder next to it, each with a
 * property list of its name, saving computer and modification date; there is no iCloud, so no conflict or nonlocal
 * versions. */
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <unistd.h>

static NSError *file_error(NSInteger code, NSString *path, NSString *what) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code
                           userInfo:@{ NSLocalizedDescriptionKey: what, @"NSFilePath": path ?: @"" }];
}
static BOOL file_identity(NSString *path, unsigned long long *dev, unsigned long long *ino) {
    struct stat st;
    if (stat(path.fileSystemRepresentation, &st) != 0) return NO;
    *dev = (unsigned long long)st.st_dev; *ino = (unsigned long long)st.st_ino;
    return YES;
}
static const char kMagic[4] = { 'b', 'o', 'o', 'k' };

@implementation NSURL (NSURLBookmarks)
@dynamic standardizedURL, URLByStandardizingPath;      /* Additions.m */
- (NSData *)bookmarkDataWithOptions:(NSURLBookmarkCreationOptions)options includingResourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys
                      relativeToURL:(NSURL *)relativeURL error:(NSError **)error {
    if (!self.isFileURL) { if (error) *error = file_error(NSFileReadUnsupportedSchemeError, self.absoluteString, @"Only file URLs can be bookmarked."); return nil; }
    NSString *path = self.path.stringByStandardizingPath;
    unsigned long long dev = 0, ino = 0;
    if (!file_identity(path, &dev, &ino)) {
        if (error) *error = file_error(NSFileReadNoSuchFileError, path, @"The file doesn’t exist.");
        return nil;
    }
    NSMutableDictionary *b = [@{ @"path": path, @"device": @(dev), @"inode": @(ino), @"options": @(options) } mutableCopy];
    if (relativeURL.isFileURL) {
        NSString *base = relativeURL.path.stringByStandardizingPath;
        if ([path hasPrefix:[base stringByAppendingString:@"/"]]) b[@"relative"] = [path substringFromIndex:base.length + 1];
    }
    if (keys.count) {
        NSMutableDictionary *vals = [NSMutableDictionary dictionary];
        [[self resourceValuesForKeys:keys error:NULL] enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *stop) {
            if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSDate class]] || [v isKindOfClass:[NSData class]])
                vals[k] = v;
        }];
        b[@"resources"] = vals;
    }
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:b format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!plist) return nil;
    NSMutableData *out = [NSMutableData dataWithBytes:kMagic length:4];
    [out appendData:plist];
    return out;
}
static NSDictionary *bookmark_plist(NSData *data) {
    if (data.length < 5 || memcmp(data.bytes, kMagic, 4) != 0) return nil;
    id b = [NSPropertyListSerialization propertyListWithData:[data subdataWithRange:NSMakeRange(4, data.length - 4)] options:0 format:NULL error:NULL];
    return [b isKindOfClass:[NSDictionary class]] ? b : nil;
}
- (instancetype)initByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL
                        bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error {
    NSURL *u = [NSURL URLByResolvingBookmarkData:bookmarkData options:options relativeToURL:relativeURL bookmarkDataIsStale:isStale error:error];
    return u ? [self initFileURLWithPath:u.path] : nil;
}
+ (instancetype)URLByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL
                       bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error {
    if (isStale) *isStale = NO;
    NSDictionary *b = bookmark_plist(bookmarkData);
    if (!b) { if (error) *error = file_error(NSFileReadCorruptFileError, @"", @"The bookmark data isn’t in the correct format."); return nil; }
    NSString *path = b[@"path"];
    if (relativeURL.isFileURL && b[@"relative"]) path = [relativeURL.path.stringByStandardizingPath stringByAppendingPathComponent:b[@"relative"]];
    unsigned long long dev = [b[@"device"] unsignedLongLongValue], ino = [b[@"inode"] unsignedLongLongValue], d = 0, i = 0;
    if (file_identity(path, &d, &i) && d == dev && i == ino) return [self fileURLWithPath:path];
    // moved or replaced: the file with the same identity in the same folder (a rename), else the file at the path
    NSString *dir = path.stringByDeletingLastPathComponent;
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL]) {
        NSString *p = [dir stringByAppendingPathComponent:name];
        if (file_identity(p, &d, &i) && d == dev && i == ino) { if (isStale) *isStale = YES; return [self fileURLWithPath:p]; }
    }
    if (file_identity(path, &d, &i)) { if (isStale) *isStale = YES; return [self fileURLWithPath:path]; }
    if (error) *error = file_error(NSFileNoSuchFileError, path, @"The file couldn’t be opened because it doesn’t exist.");
    return nil;
}
+ (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys fromBookmarkData:(NSData *)bookmarkData {
    NSDictionary *b = bookmark_plist(bookmarkData);
    if (!b) return nil;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSDictionary *vals = b[@"resources"];
    for (NSString *k in keys) {
        if (vals[k]) out[k] = vals[k];
        else if ([k isEqual:NSURLPathKey]) out[k] = b[@"path"];
        else if ([k isEqual:NSURLNameKey]) out[k] = [b[@"path"] lastPathComponent];
    }
    return out;
}
+ (BOOL)writeBookmarkData:(NSData *)bookmarkData toURL:(NSURL *)bookmarkFileURL options:(NSURLBookmarkFileCreationOptions)options error:(NSError **)error {
    return [bookmarkData writeToURL:bookmarkFileURL options:NSDataWritingAtomic error:error];
}
+ (NSData *)bookmarkDataWithContentsOfURL:(NSURL *)bookmarkFileURL error:(NSError **)error {
    NSData *d = [NSData dataWithContentsOfURL:bookmarkFileURL options:0 error:error];
    if (d && !bookmark_plist(d)) { if (error) *error = file_error(NSFileReadCorruptFileError, bookmarkFileURL.path, @"The file isn’t a bookmark."); return nil; }
    return d;
}

static NSCountedSet *scoped;
- (BOOL)startAccessingSecurityScopedResource {
    if (!self.isFileURL) return NO;
    @synchronized ([NSURL class]) { if (!scoped) scoped = [NSCountedSet set]; [scoped addObject:self.path.stringByStandardizingPath]; }
    return YES;
}
- (void)stopAccessingSecurityScopedResource {
    if (!self.isFileURL) return;
    @synchronized ([NSURL class]) { [scoped removeObject:self.path.stringByStandardizingPath]; }
}
@end

#pragma mark - NSFileVersion

@interface NSFileVersion ()
@property (readwrite, copy) NSURL *URL;
@property (nullable, readwrite, copy) NSString *localizedName, *localizedNameOfSavingComputer;
@property (nullable, readwrite, copy) NSDate *modificationDate;
@property (readwrite, retain) id<NSCoding> persistentIdentifier;
@property (nonatomic, copy) NSURL *item;          // the file it is a version of
@property (nonatomic) BOOL current;
@end

static NSDictionary *read_plist(NSURL *url) {
    NSData *d = [NSData dataWithContentsOfURL:url];
    id p = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    return [p isKindOfClass:[NSDictionary class]] ? p : nil;
}
static void write_plist(NSDictionary *dict, NSURL *url) {
    [[NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] writeToURL:url atomically:YES];
}
static NSURL *versions_dir(NSURL *item) {
    NSString *p = item.path.stringByStandardizingPath;
    return [NSURL fileURLWithPath:[p.stringByDeletingLastPathComponent stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@".%@.versions", p.lastPathComponent]] isDirectory:YES];
}
/* the saving computer: the device's name (UIDevice.name: "iPhone", or "iPad") */
static NSString *device_name(void) {
    NSString *d = NSProcessInfo.processInfo.environment[@"ISIM_DEVICE"];
    return [d.lowercaseString hasPrefix:@"ipad"] ? @"iPad" : @"iPhone";
}

@implementation NSFileVersion
@synthesize resolved = _resolved, discardable = _discardable;
- (BOOL)isConflict { return NO; }
- (BOOL)hasLocalContents { return YES; }
- (BOOL)hasThumbnail { return NO; }
- (NSPersonNameComponents *)originatorNameComponents { return nil; }
+ (NSFileVersion *)_versionAt:(NSURL *)url item:(NSURL *)item ident:(NSString *)ident current:(BOOL)current {
    NSFileVersion *v = [NSFileVersion new];
    v.URL = url; v.item = item; v.persistentIdentifier = ident; v.current = current;
    NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:NULL];
    v.modificationDate = a.fileModificationDate;
    v.localizedName = item.lastPathComponent.stringByDeletingPathExtension;
    v.localizedNameOfSavingComputer = device_name();
    v->_resolved = YES;
    if (!current) {
        NSDictionary *info = read_plist([[versions_dir(item) URLByAppendingPathComponent:ident] URLByAppendingPathExtension:@"plist"]);
        if (info[@"date"]) v.modificationDate = info[@"date"];
        if (info[@"computer"]) v.localizedNameOfSavingComputer = info[@"computer"];
        v->_discardable = [info[@"discardable"] boolValue];
    }
    return v;
}
+ (NSFileVersion *)currentVersionOfItemAtURL:(NSURL *)url {
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return nil;
    return [self _versionAt:url item:url ident:@"current" current:YES];
}
+ (NSArray<NSFileVersion *> *)otherVersionsOfItemAtURL:(NSURL *)url {
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return nil;
    NSURL *dir = versions_dir(url);
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir.path error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if ([name.pathExtension isEqual:@"plist"]) continue;
        [out addObject:[self _versionAt:[dir URLByAppendingPathComponent:name] item:url ident:name current:NO]];
    }
    [out sortUsingComparator:^NSComparisonResult(NSFileVersion *a, NSFileVersion *b) { return [a.modificationDate compare:b.modificationDate]; }];
    return out;
}
+ (NSArray<NSFileVersion *> *)unresolvedConflictVersionsOfItemAtURL:(NSURL *)url {
    return [NSFileManager.defaultManager fileExistsAtPath:url.path] ? @[] : nil;
}
+ (void)getNonlocalVersionsOfItemAtURL:(NSURL *)url completionHandler:(void (^)(NSArray<NSFileVersion *> *, NSError *))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(@[], nil); });
}
+ (NSFileVersion *)versionOfItemAtURL:(NSURL *)url forPersistentIdentifier:(id)persistentIdentifier {
    if ([persistentIdentifier isEqual:@"current"]) return [self currentVersionOfItemAtURL:url];
    for (NSFileVersion *v in [self otherVersionsOfItemAtURL:url] ?: @[]) if ([(id)v.persistentIdentifier isEqual:persistentIdentifier]) return v;
    return nil;
}
+ (NSFileVersion *)addVersionOfItemAtURL:(NSURL *)url withContentsOfURL:(NSURL *)contentsURL options:(NSFileVersionAddingOptions)options error:(NSError **)outError {
    NSURL *dir = versions_dir(url);
    if (![NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:outError]) return nil;
    NSString *ident = [NSUUID UUID].UUIDString;
    NSString *ext = url.pathExtension;
    NSString *name = ext.length ? [ident stringByAppendingPathExtension:ext] : ident;
    NSURL *dest = [dir URLByAppendingPathComponent:name];
    BOOL ok = options & NSFileVersionAddingByMoving ? [NSFileManager.defaultManager moveItemAtURL:contentsURL toURL:dest error:outError]
                                                    : [NSFileManager.defaultManager copyItemAtURL:contentsURL toURL:dest error:outError];
    if (!ok) return nil;
    write_plist(@{ @"date": [NSDate date], @"computer": device_name() }, [[dir URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"plist"]);
    return [self _versionAt:dest item:url ident:name current:NO];
}
+ (NSURL *)temporaryDirectoryURLForNewVersionOfItemAtURL:(NSURL *)url {
    NSURL *t = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:t withIntermediateDirectories:YES attributes:nil error:NULL];
    return t;
}
+ (BOOL)removeOtherVersionsOfItemAtURL:(NSURL *)url error:(NSError **)outError {
    NSURL *dir = versions_dir(url);
    if (![NSFileManager.defaultManager fileExistsAtPath:dir.path]) return YES;
    return [NSFileManager.defaultManager removeItemAtURL:dir error:outError];
}
- (NSURL *)replaceItemAtURL:(NSURL *)url options:(NSFileVersionReplacingOptions)options error:(NSError **)error {
    if (self.current && [url.path.stringByStandardizingPath isEqual:self.URL.path.stringByStandardizingPath]) return url;
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:url.path] && ![fm removeItemAtURL:url error:error]) return nil;
    BOOL ok = options & NSFileVersionReplacingByMoving ? [fm moveItemAtURL:self.URL toURL:url error:error] : [fm copyItemAtURL:self.URL toURL:url error:error];
    return ok ? url : nil;
}
- (BOOL)removeAndReturnError:(NSError **)outError {
    if (self.current) {
        if (outError) *outError = file_error(NSFileWriteNoPermissionError, self.URL.path, @"The current version can’t be removed.");
        return NO;
    }
    [NSFileManager.defaultManager removeItemAtURL:[self.URL URLByAppendingPathExtension:@"plist"] error:NULL];
    return [NSFileManager.defaultManager removeItemAtURL:self.URL error:outError];
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSFileVersion %@%@>", self.URL.path, self.current ? @" (current)" : @""]; }
@end
