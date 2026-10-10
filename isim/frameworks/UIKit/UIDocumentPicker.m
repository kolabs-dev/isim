/* UIDocumentPickerViewController and UIDocumentBrowserViewController: the device's files, as the Files app shows them.
 *
 * Adapted: "On My iPhone" is $ISIM_DATA/Files, shared by the device's apps (the Simulator keeps it in a shared app
 * group of the File Provider), plus one folder per installed app that shares its Documents (UIFileSharingEnabled and
 * LSSupportsOpeningDocumentsInPlace in its Info.plist; its folder is the app container's Documents). There is no
 * iCloud Drive or other file provider, and no Recents / Tags. The screens follow iOS's: a Browse list with the
 * location, folder listings (folders first open, files that do not match the allowed types are dimmed), single or
 * multiple selection, folder selection for exports and folder pickers. Picking with asCopy (or the Import mode) copies
 * the files into tmp/<bundle id>-Inbox like iOS; Open mode returns the files themselves. File types come from the
 * UniformTypeIdentifiers module (isim_uti_file_conforms, looked up at run time). */
#import "UIKitPrivate.h"
#import <UIKit/UIDocumentPickerViewController.h>
#import <UIKit/UIDocumentViewController.h>
#import <objc/runtime.h>
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

NSErrorDomain const UIDocumentBrowserErrorDomain = @"UIDocumentBrowserErrorDomain";

/* ---------------- the files ---------------- */
extern NSString *isim_data_dir(void);
extern NSString *isim_ui_installed_apps_dir(void);
static NSString *files_root(void) {
    NSString *r = [isim_data_dir() stringByAppendingPathComponent:@"Files"];
    [NSFileManager.defaultManager createDirectoryAtPath:r withIntermediateDirectories:YES attributes:nil error:NULL];
    return r;
}
/* apps that share their Documents: display name -> Documents directory */
static NSDictionary<NSString *, NSString *> *shared_app_folders(void) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSMutableArray *infos = [NSMutableArray array];
    if (NSBundle.mainBundle.infoDictionary) [infos addObject:NSBundle.mainBundle.infoDictionary];
    NSString *apps = isim_ui_installed_apps_dir();
    for (NSString *a in [NSFileManager.defaultManager contentsOfDirectoryAtPath:apps error:NULL] ?: @[]) {
        if (![a hasSuffix:@".app"]) continue;
        NSDictionary *i = [NSDictionary dictionaryWithContentsOfFile:[[apps stringByAppendingPathComponent:a] stringByAppendingPathComponent:@"Info.plist"]];
        if (i) [infos addObject:i];
    }
    for (NSDictionary *i in infos) {
        if (![i[@"UIFileSharingEnabled"] boolValue] || ![i[@"LSSupportsOpeningDocumentsInPlace"] boolValue] || !i[@"CFBundleIdentifier"]) continue;
        NSString *name = i[@"CFBundleDisplayName"] ?: i[@"CFBundleName"] ?: i[@"CFBundleIdentifier"];
        NSString *docs = [[[isim_data_dir() stringByAppendingPathComponent:@"Containers"] stringByAppendingPathComponent:i[@"CFBundleIdentifier"]] stringByAppendingPathComponent:@"Documents"];
        [NSFileManager.defaultManager createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:NULL];
        out[name] = docs;
    }
    return out;
}
static BOOL is_dir(NSString *p) { BOOL d = NO; return [NSFileManager.defaultManager fileExistsAtPath:p isDirectory:&d] && d; }
/* whether a file or folder matches the allowed type identifiers (nil: everything) */
static BOOL conforms(NSString *path, NSArray<NSString *> *types) {
    if (!types) return YES;
    static int (*fn)(const char *, int, const char *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fn = (int (*)(const char *, int, const char *))dlsym(RTLD_DEFAULT, "isim_uti_file_conforms"); });
    BOOL dir = is_dir(path);
    if (!fn) {                                       /* without the type module: folders for folder types, files otherwise */
        BOOL wantsFolder = [types containsObject:@"public.folder"] || [types containsObject:@"public.directory"];
        return dir ? wantsFolder : !wantsFolder || types.count > 1;
    }
    return fn(path.pathExtension.UTF8String, dir, [types componentsJoinedByString:@","].UTF8String) != 0;
}
static BOOL wants_folders(NSArray<NSString *> *types) {
    for (NSString *t in types) if ([t isEqualToString:@"public.folder"] || [t isEqualToString:@"public.directory"]) return YES;
    return NO;
}
/* copies a file or a folder tree */
static BOOL copy_item(NSString *src, NSString *dst) {
    struct stat st;
    if (stat(src.UTF8String, &st) != 0) return NO;
    if (S_ISDIR(st.st_mode)) {
        if (mkdir(dst.UTF8String, 0755) != 0 && errno != EEXIST) return NO;
        DIR *d = opendir(src.UTF8String);
        if (!d) return NO;
        BOOL ok = YES;
        for (struct dirent *e; (e = readdir(d));) {
            if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
            NSString *n = @(e->d_name);
            ok = copy_item([src stringByAppendingPathComponent:n], [dst stringByAppendingPathComponent:n]) && ok;
        }
        closedir(d);
        return ok;
    }
    NSData *data = [NSData dataWithContentsOfFile:src];
    return data && [data writeToFile:dst atomically:YES];
}
static BOOL move_item(NSString *src, NSString *dst) {
    if (rename(src.UTF8String, dst.UTF8String) == 0) return YES;
    return copy_item(src, dst) && [NSFileManager.defaultManager removeItemAtPath:src error:NULL];
}
/* dir/name, or "name 2.ext", "name 3.ext"... when it exists (like Files) */
static NSString *unique_path(NSString *dir, NSString *name) {
    NSString *p = [dir stringByAppendingPathComponent:name];
    NSString *base = name.stringByDeletingPathExtension, *ext = name.pathExtension;
    for (int n = 2; [NSFileManager.defaultManager fileExistsAtPath:p]; n++)
        p = [dir stringByAppendingPathComponent:ext.length ? [NSString stringWithFormat:@"%@ %d.%@", base, n, ext] : [NSString stringWithFormat:@"%@ %d", base, n]];
    return p;
}
static NSString *inbox_dir(void) {
    NSString *d = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-Inbox", NSBundle.mainBundle.bundleIdentifier ?: @"app"]];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}

/* ---------------- a folder listing ---------------- */
typedef NS_ENUM(int, IsimFilesMode) { IsimFilesPick, IsimFilesPickFolder, IsimFilesExport, IsimFilesBrowse };
@interface __IsimFilesList : UITableViewController
@property (nonatomic, copy, nullable) NSString *path;           /* nil: On My iPhone (the Files root and the app folders) */
@property (nonatomic, copy, nullable) NSArray<NSString *> *types;
@property (nonatomic) IsimFilesMode mode;
@property (nonatomic) BOOL multiple, showExtensions, selecting;
@property (nonatomic, copy, nullable) NSString *exportTitle;
@property (nonatomic, copy) void (^onFiles)(NSArray<NSString *> *paths);
@property (nonatomic, copy) void (^onFolder)(NSString *path);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
@property (nonatomic, copy, nullable) void (^decorate)(__IsimFilesList *list);   /* the browser's bar buttons */
- (NSString *)folder;
- (void)reload;
@end
@implementation __IsimFilesList { NSArray<NSDictionary *> *_items; NSMutableOrderedSet<NSString *> *_chosen; }
- (NSString *)folder { return _path ?: files_root(); }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _path ? (self.title ?: _path.lastPathComponent) : @"On My iPhone";
    _chosen = [NSMutableOrderedSet orderedSet];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"f"];
    [self _bar];
    [self reload];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; }
- (void)_bar {
    if (_mode == IsimFilesBrowse) { if (self.decorate) self.decorate(self); return; }
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(isimCancel)];
    cancel.accessibilityIdentifier = @"docs-cancel";
    self.navigationItem.leftBarButtonItem = cancel;
    self.navigationItem.leftItemsSupplementBackButton = YES;        /* back to the parent folder / Browse, and Cancel */
    NSString *right = _mode == IsimFilesExport ? _exportTitle : (_mode == IsimFilesPickFolder || _multiple) ? @"Open" : nil;
    if (right) {
        UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithTitle:right style:UIBarButtonItemStyleDone target:self action:@selector(isimDone)];
        b.accessibilityIdentifier = _mode == IsimFilesExport ? @"docs-export" : @"docs-open";
        b.enabled = _mode != IsimFilesPick || _chosen.count > 0;
        self.navigationItem.rightBarButtonItem = b;
    }
}
- (void)reload {
    NSMutableArray *items = [NSMutableArray array];
    NSString *dir = self.folder;
    for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL] ?: @[]) {
        if ([n hasPrefix:@"."]) continue;
        NSString *p = [dir stringByAppendingPathComponent:n];
        [items addObject:@{ @"name": n, @"path": p, @"dir": @(is_dir(p)) }];
    }
    if (!_path) [shared_app_folders() enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *p, BOOL *stop) {
        [items addObject:@{ @"name": name, @"path": p, @"dir": @YES, @"app": @YES }];
    }];
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]]; }];
    _items = items;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_items.count; }
- (BOOL)_enabled:(NSDictionary *)it {
    if ([it[@"dir"] boolValue]) return YES;                        /* folders open */
    return (_mode == IsimFilesPick || _mode == IsimFilesBrowse) && conforms(it[@"path"], _types);
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSDictionary *it = _items[ip.row];
    BOOL dir = [it[@"dir"] boolValue], on = [self _enabled:it];
    NSString *name = it[@"name"];
    c.textLabel.text = dir || _showExtensions ? name : name.stringByDeletingPathExtension;
    c.textLabel.textColor = on ? UIColor.labelColor : UIColor.tertiaryLabelColor;
    if (dir) {
        NSUInteger n = 0;
        for (NSString *e in [NSFileManager.defaultManager contentsOfDirectoryAtPath:it[@"path"] error:NULL] ?: @[]) if (![e hasPrefix:@"."]) n++;
        c.detailTextLabel.text = n == 1 ? @"1 item" : [NSString stringWithFormat:@"%lu items", (unsigned long)n];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        struct stat st; long long size = stat([it[@"path"] UTF8String], &st) == 0 ? st.st_size : 0;
        NSDateFormatter *f = [NSDateFormatter new]; f.dateStyle = NSDateFormatterMediumStyle; f.timeStyle = NSDateFormatterShortStyle;
        NSString *when = [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:stat([it[@"path"] UTF8String], &st) == 0 ? st.st_mtime : 0]];
        NSString *sz = size < 1000 ? [NSString stringWithFormat:@"%lld bytes", size] : size < 1000000 ? [NSString stringWithFormat:@"%lld KB", (size + 500) / 1000]
                     : [NSString stringWithFormat:@"%.1f MB", size / 1e6];
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@ – %@", when, sz];
        c.accessoryType = [_chosen containsObject:it[@"path"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    c.selectionStyle = on ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    c.accessibilityIdentifier = [@"docs-item-" stringByAppendingString:[name stringByReplacingOccurrencesOfString:@" " withString:@"-"]];   /* tapid stops at spaces */
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *it = _items[ip.row];
    if ([it[@"dir"] boolValue]) {
        __IsimFilesList *next = [__IsimFilesList new];
        next.path = it[@"path"]; next.title = it[@"name"]; next.types = _types; next.mode = _mode; next.multiple = _multiple;
        next.showExtensions = _showExtensions; next.exportTitle = _exportTitle; next.selecting = _selecting;
        next.onFiles = _onFiles; next.onFolder = _onFolder; next.onCancel = _onCancel; next.decorate = _decorate;
        [self.navigationController pushViewController:next animated:YES];
        return;
    }
    if (![self _enabled:it]) return;
    if (_multiple || _selecting) {
        if ([_chosen containsObject:it[@"path"]]) [_chosen removeObject:it[@"path"]]; else [_chosen addObject:it[@"path"]];
        self.navigationItem.rightBarButtonItem.enabled = _chosen.count > 0;
        [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    if (self.onFiles) self.onFiles(@[it[@"path"]]);
}
- (void)isimCancel { if (self.onCancel) self.onCancel(); }
- (void)isimDone {
    if (_mode == IsimFilesExport || _mode == IsimFilesPickFolder) { if (self.onFolder) self.onFolder(self.folder); }
    else if (_chosen.count && self.onFiles) self.onFiles(_chosen.array);
}
- (void)isimClearSelection { [_chosen removeAllObjects]; [self.tableView reloadData]; }
- (NSArray<NSString *> *)isimChosen { return _chosen.array; }
@end

@interface __IsimFilesList (Copy)
- (__IsimFilesList *)copyForRoot;     /* a list with the same settings, for another folder */
@end

/* the Browse list: the locations (only On My iPhone on isim) */
@interface __IsimFilesBrowse : UITableViewController
@property (nonatomic, copy) void (^open)(void);
@property (nonatomic, copy, nullable) void (^decorate)(UIViewController *vc);
@end
@implementation __IsimFilesBrowse
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"Browse"; if (self.decorate) self.decorate(self); }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @"Locations"; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 1; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    c.textLabel.text = @"On My iPhone";
    c.imageView.image = [UIImage systemImageNamed:@"iphone"];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    c.accessibilityIdentifier = @"docs-location-on-my-iphone";
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip { [tv deselectRowAtIndexPath:ip animated:YES]; if (self.open) self.open(); }
@end

/* the lists from On My iPhone down to a folder inside it (for directoryURL / reveal) */
static NSArray<NSString *> *folder_chain(NSString *target) {
    NSString *root = files_root();
    target = target.stringByStandardizingPath;
    __block NSString *base = nil, *baseName = nil;
    if ([target isEqualToString:root] || [target hasPrefix:[root stringByAppendingString:@"/"]]) base = root;
    else [shared_app_folders() enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *p, BOOL *stop) {
        if ([target isEqualToString:p] || [target hasPrefix:[p stringByAppendingString:@"/"]]) { base = p; baseName = name; *stop = YES; }
    }];
    if (!base) return nil;
    NSMutableArray *chain = [NSMutableArray array];
    if (baseName) [chain addObject:base];
    NSString *rest = [target substringFromIndex:base.length];
    NSString *cur = base;
    for (NSString *c in [rest componentsSeparatedByString:@"/"]) {
        if (!c.length) continue;
        cur = [cur stringByAppendingPathComponent:c];
        [chain addObject:cur];
    }
    return chain;
}

/* ---------------- UIDocumentPickerViewController ---------------- */
@implementation UIDocumentPickerViewController {
    NSArray<NSString *> *_types;
    NSArray<NSURL *> *_exportURLs;
    BOOL _asCopy;
    UINavigationController *_nav;
}
- (instancetype)initIsimMode:(UIDocumentPickerMode)mode {
    if ((self = [super initWithNibName:nil bundle:nil])) { _documentPickerMode = mode; self.modalPresentationStyle = UIModalPresentationFormSheet; }
    return self;
}
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)utis inMode:(UIDocumentPickerMode)mode {
    if ((self = [self initIsimMode:mode])) { _types = [utis copy]; _asCopy = mode == UIDocumentPickerModeImport; }
    return self;
}
- (instancetype)initForIsimOpeningTypeIdentifiers:(NSArray<NSString *> *)ids asCopy:(BOOL)asCopy {
    if ((self = [self initIsimMode:asCopy ? UIDocumentPickerModeImport : UIDocumentPickerModeOpen])) { _types = [ids copy]; _asCopy = asCopy; }
    return self;
}
- (instancetype)initWithURL:(NSURL *)url inMode:(UIDocumentPickerMode)mode { return [self initIsimExportingURLs:@[url] mode:mode]; }
- (instancetype)initIsimExportingURLs:(NSArray<NSURL *> *)urls mode:(UIDocumentPickerMode)mode {
    if ((self = [self initIsimMode:mode])) { _exportURLs = [urls copy]; _asCopy = mode != UIDocumentPickerModeMoveToService; }
    return self;
}
- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls inMode:(UIDocumentPickerMode)mode { return [self initIsimExportingURLs:urls mode:mode]; }
- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls asCopy:(BOOL)asCopy {
    return [self initIsimExportingURLs:urls mode:asCopy ? UIDocumentPickerModeExportToService : UIDocumentPickerModeMoveToService];
}
- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls { return [self initForExportingURLs:urls asCopy:NO]; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initForIsimOpeningTypeIdentifiers:@[@"public.item"] asCopy:NO]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    BOOL exporting = _exportURLs != nil;
    __weak UIDocumentPickerViewController *w = self;
    __IsimFilesList *list = [__IsimFilesList new];
    list.types = exporting ? nil : _types;
    list.mode = exporting ? IsimFilesExport : wants_folders(_types) ? IsimFilesPickFolder : IsimFilesPick;
    list.multiple = self.allowsMultipleSelection && !exporting;
    list.showExtensions = self.shouldShowFileExtensions;
    list.exportTitle = _asCopy ? @"Save" : @"Move";
    list.onCancel = ^{ [w _isimCancel]; };
    list.onFiles = ^(NSArray<NSString *> *paths) { [w _isimPicked:paths]; };
    list.onFolder = ^(NSString *folder) { UIDocumentPickerViewController *s = w; if (!s) return; if (s->_exportURLs) [s _isimExportTo:folder]; else [s _isimPicked:@[folder]]; };
    __IsimFilesBrowse *browse = [__IsimFilesBrowse new];
    _nav = [[UINavigationController alloc] initWithRootViewController:browse];
    browse.open = ^{ UIDocumentPickerViewController *s = w; __IsimFilesList *l = [list copyForRoot]; [s->_nav pushViewController:l animated:YES]; };
    browse.decorate = ^(UIViewController *vc) {
        UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:w action:@selector(_isimCancel)];
        cancel.accessibilityIdentifier = @"docs-cancel";
        vc.navigationItem.leftBarButtonItem = cancel;
    };
    /* start in On My iPhone, or in directoryURL's folder */
    NSMutableArray *stack = [NSMutableArray arrayWithObjects:browse, list, nil];
    NSArray *chain = self.directoryURL.isFileURL ? folder_chain(self.directoryURL.path) : nil;
    for (NSString *p in chain) {
        __IsimFilesList *l = [list copyForRoot];
        l.path = p; l.title = p.lastPathComponent;
        [shared_app_folders() enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *ap, BOOL *stop) { if ([ap isEqualToString:p]) l.title = name; }];
        [stack addObject:l];
    }
    _nav.viewControllers = stack;
    [self addChildViewController:_nav];
    _nav.view.frame = self.view.bounds;
    _nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_nav.view];
    [_nav didMoveToParentViewController:self];
    NSLog(@"isim UIKit: document picker (%@) shows %@", exporting ? (_asCopy ? @"export, copy" : @"export, move") : _asCopy ? @"import" : @"open",
          chain.count ? [chain.lastObject lastPathComponent] : @"On My iPhone");
}
- (void)_isimFinish:(NSArray<NSURL *> *)urls {
    id<UIDocumentPickerDelegate> d = self.delegate;
    NSLog(@"isim UIKit: document picker picked %@", [[urls valueForKey:@"lastPathComponent"] componentsJoinedByString:@", "]);
    UIViewController *presenter = self.presentingViewController;
    void (^tell)(void) = ^{
        if ([d respondsToSelector:@selector(documentPicker:didPickDocumentsAtURLs:)]) [d documentPicker:self didPickDocumentsAtURLs:urls];
        else if (urls.count && [d respondsToSelector:@selector(documentPicker:didPickDocumentAtURL:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [d documentPicker:self didPickDocumentAtURL:urls.firstObject];
#pragma clang diagnostic pop
        }
    };
    if (presenter) [presenter dismissViewControllerAnimated:YES completion:tell]; else tell();     /* the picker dismisses itself, like iOS */
}
- (void)_isimPicked:(NSArray<NSString *> *)paths {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSString *p in paths) {
        if (_asCopy) {
            NSString *dst = unique_path(inbox_dir(), p.lastPathComponent);
            if (copy_item(p, dst)) [urls addObject:[NSURL fileURLWithPath:dst]];
        } else [urls addObject:[NSURL fileURLWithPath:p]];
    }
    [self _isimFinish:urls];
}
- (void)_isimExportTo:(NSString *)folder {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSURL *u in _exportURLs) {
        NSString *dst = unique_path(folder, u.lastPathComponent);
        if (_asCopy ? copy_item(u.path, dst) : move_item(u.path, dst)) [urls addObject:[NSURL fileURLWithPath:dst]];
        else NSLog(@"isim UIKit: document picker could not %@ %@", _asCopy ? @"copy" : @"move", u.path);
    }
    [self _isimFinish:urls];
}
- (void)_isimCancel {
    id<UIDocumentPickerDelegate> d = self.delegate;
    NSLog(@"isim UIKit: document picker cancelled");
    UIViewController *presenter = self.presentingViewController;
    void (^tell)(void) = ^{ if ([d respondsToSelector:@selector(documentPickerWasCancelled:)]) [d documentPickerWasCancelled:self]; };
    if (presenter) [presenter dismissViewControllerAnimated:YES completion:tell]; else tell();
}
@end

@implementation __IsimFilesList (Copy)
- (__IsimFilesList *)copyForRoot {
    __IsimFilesList *l = [__IsimFilesList new];
    l.types = self.types; l.mode = self.mode; l.multiple = self.multiple; l.showExtensions = self.showExtensions; l.exportTitle = self.exportTitle;
    l.onFiles = self.onFiles; l.onFolder = self.onFolder; l.onCancel = self.onCancel; l.decorate = self.decorate; l.selecting = self.selecting;
    return l;
}
@end

/* ---------------- UIDocumentBrowserViewController ---------------- */
@implementation UIDocumentBrowserViewController { UINavigationController *_nav; __IsimFilesList *_template; }
- (instancetype)initForIsimOpeningTypeIdentifiers:(NSArray<NSString *> *)ids {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _allowedContentTypes = [ids copy]; _allowsDocumentCreation = YES; _defaultDocumentAspectRatio = 2.0 / 3;
        _localizedCreateDocumentActionTitle = @"Create Document";
        _additionalLeadingNavigationBarButtonItems = @[]; _additionalTrailingNavigationBarButtonItems = @[];
    }
    return self;
}
- (instancetype)initForOpeningFilesWithContentTypes:(NSArray<NSString *> *)types { return [self initForIsimOpeningTypeIdentifiers:types]; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initForIsimOpeningTypeIdentifiers:nil]; }
- (__IsimFilesList *)_top { return [_nav.topViewController isKindOfClass:[__IsimFilesList class]] ? (__IsimFilesList *)_nav.topViewController : nil; }
- (void)viewDidLoad {
    [super viewDidLoad];
    __weak UIDocumentBrowserViewController *w = self;
    _template = [__IsimFilesList new];
    _template.types = _allowedContentTypes; _template.mode = IsimFilesBrowse; _template.showExtensions = _shouldShowFileExtensions;
    _template.onFiles = ^(NSArray<NSString *> *paths) { [w _isimPicked:paths]; };
    _template.decorate = ^(__IsimFilesList *l) { [w _isimDecorate:l]; };
    __IsimFilesBrowse *browse = [__IsimFilesBrowse new];
    browse.open = ^{ UIDocumentBrowserViewController *s = w; [s->_nav pushViewController:[s->_template copyForRoot] animated:YES]; };
    browse.decorate = ^(UIViewController *vc) { [w _isimDecorate:vc]; };
    _nav = [[UINavigationController alloc] initWithRootViewController:browse];
    _nav.viewControllers = @[browse, [_template copyForRoot]];
    if (_browserUserInterfaceStyle == UIDocumentBrowserUserInterfaceStyleDark) _nav.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self addChildViewController:_nav];
    _nav.view.frame = self.view.bounds;
    _nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_nav.view];
    [_nav didMoveToParentViewController:self];
}
/* the bar buttons follow these properties, also when they change after the browser appeared */
- (void)_isimRedecorate { for (UIViewController *vc in _nav.viewControllers) [self _isimDecorate:vc]; }
- (void)setAllowsDocumentCreation:(BOOL)v { _allowsDocumentCreation = v; [self _isimRedecorate]; }
- (void)setAllowsPickingMultipleItems:(BOOL)v { _allowsPickingMultipleItems = v; [self _isimRedecorate]; }
- (void)setAdditionalLeadingNavigationBarButtonItems:(NSArray<UIBarButtonItem *> *)items { _additionalLeadingNavigationBarButtonItems = [items copy] ?: @[]; [self _isimRedecorate]; }
- (void)setAdditionalTrailingNavigationBarButtonItems:(NSArray<UIBarButtonItem *> *)items { _additionalTrailingNavigationBarButtonItems = [items copy] ?: @[]; [self _isimRedecorate]; }
- (void)_isimDecorate:(UIViewController *)vc {
    NSMutableArray *right = [NSMutableArray array], *left = [NSMutableArray arrayWithArray:_additionalLeadingNavigationBarButtonItems];
    if (_allowsDocumentCreation && [vc isKindOfClass:[__IsimFilesList class]]) {
        UIBarButtonItem *create = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_isimCreateDefault)];
        create.accessibilityIdentifier = @"docs-create"; create.accessibilityLabel = _localizedCreateDocumentActionTitle;
        [right addObject:create];
    }
    if (_allowsPickingMultipleItems && [vc isKindOfClass:[__IsimFilesList class]]) {
        __IsimFilesList *l = (__IsimFilesList *)vc;
        UIBarButtonItem *sel = [[UIBarButtonItem alloc] initWithTitle:l.selecting ? @"Open" : @"Select" style:l.selecting ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain
                                                               target:self action:@selector(_isimSelect)];
        sel.accessibilityIdentifier = l.selecting ? @"docs-open" : @"docs-select";
        [right addObject:sel];
    }
    [right addObjectsFromArray:_additionalTrailingNavigationBarButtonItems];
    vc.navigationItem.rightBarButtonItems = right;
    vc.navigationItem.leftBarButtonItems = left;
    vc.navigationItem.leftItemsSupplementBackButton = YES;
}
- (void)_isimSelect {
    __IsimFilesList *l = [self _top]; if (!l) return;
    if (l.selecting) {
        NSArray *chosen = [l performSelector:@selector(isimChosen)];
        l.selecting = NO; [l performSelector:@selector(isimClearSelection)];
        if (chosen.count) [self _isimPicked:chosen];
    } else l.selecting = YES;
    [self _isimDecorate:l];
}
- (void)_isimPicked:(NSArray<NSString *> *)paths {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSString *p in paths) [urls addObject:[NSURL fileURLWithPath:p]];
    NSLog(@"isim UIKit: document browser picked %@", [[urls valueForKey:@"lastPathComponent"] componentsJoinedByString:@", "]);
    id<UIDocumentBrowserViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(documentBrowser:didPickDocumentsAtURLs:)]) [d documentBrowser:self didPickDocumentsAtURLs:urls];
}
/* imports src into folder (copy / move); tells the delegate */
- (NSURL *)_isimImport:(NSURL *)src into:(NSString *)folder mode:(UIDocumentBrowserImportMode)mode error:(NSError **)err {
    NSString *dst = unique_path(folder, src.lastPathComponent);
    BOOL ok = mode == UIDocumentBrowserImportModeMove ? move_item(src.path, dst) : copy_item(src.path, dst);
    if (!ok) { if (err) *err = [NSError errorWithDomain:UIDocumentBrowserErrorDomain code:UIDocumentBrowserErrorGeneric userInfo:@{ NSLocalizedDescriptionKey: @"The document could not be imported." }]; return nil; }
    return [NSURL fileURLWithPath:dst];
}
- (void)_isimCreate {
    id<UIDocumentBrowserViewControllerDelegate> d = self.delegate;
    if (![d respondsToSelector:@selector(documentBrowser:didRequestDocumentCreationWithHandler:)]) return;
    NSString *folder = [self _top].folder ?: files_root();
    __weak UIDocumentBrowserViewController *w = self;
    [d documentBrowser:self didRequestDocumentCreationWithHandler:^(NSURL *url, UIDocumentBrowserImportMode mode) {
        UIDocumentBrowserViewController *s = w; if (!s) return;
        if (!url || mode == UIDocumentBrowserImportModeNone) { NSLog(@"isim UIKit: document browser: creation cancelled"); return; }
        NSError *err = nil;
        NSURL *dst = [s _isimImport:url into:folder mode:mode error:&err];
        id<UIDocumentBrowserViewControllerDelegate> d2 = s.delegate;
        if (dst) {
            NSLog(@"isim UIKit: document browser created %@", dst.lastPathComponent);
            [[s _top] reload];
            if ([d2 respondsToSelector:@selector(documentBrowser:didImportDocumentAtURL:toDestinationURL:)]) [d2 documentBrowser:s didImportDocumentAtURL:url toDestinationURL:dst];
        } else if ([d2 respondsToSelector:@selector(documentBrowser:failedToImportDocumentAtURL:error:)]) [d2 documentBrowser:s failedToImportDocumentAtURL:url error:err];
    }];
}
- (void)revealDocumentAtURL:(NSURL *)url importIfNeeded:(BOOL)importIfNeeded completion:(void (^)(NSURL *, NSError *))completion {
    NSString *path = url.path;
    NSArray *chain = folder_chain(path.stringByDeletingLastPathComponent);
    if (!chain && importIfNeeded) {
        NSError *err = nil;
        NSURL *dst = [self _isimImport:url into:files_root() mode:UIDocumentBrowserImportModeCopy error:&err];
        if (!dst) { if (completion) completion(nil, err); return; }
        path = dst.path; chain = @[];
    }
    if (!chain) { if (completion) completion(nil, [NSError errorWithDomain:UIDocumentBrowserErrorDomain code:UIDocumentBrowserErrorNoLocationAvailable userInfo:nil]); return; }
    if (!self.isViewLoaded) [self loadViewIfNeeded];
    NSMutableArray *stack = [NSMutableArray arrayWithObjects:_nav.viewControllers.firstObject, [_template copyForRoot], nil];
    for (NSString *p in chain) { __IsimFilesList *l = [_template copyForRoot]; l.path = p; l.title = p.lastPathComponent; [stack addObject:l]; }
    _nav.viewControllers = stack;
    NSLog(@"isim UIKit: document browser revealed %@", path.lastPathComponent);
    if (completion) completion([NSURL fileURLWithPath:path], nil);
}
- (void)importDocumentAtURL:(NSURL *)url nextToDocumentAtURL:(NSURL *)neighbour mode:(UIDocumentBrowserImportMode)mode completionHandler:(void (^)(NSURL *, NSError *))completion {
    NSError *err = nil;
    NSURL *dst = mode == UIDocumentBrowserImportModeNone ? nil : [self _isimImport:url into:neighbour.path.stringByDeletingLastPathComponent mode:mode error:&err];
    [[self _top] reload];
    if (completion) completion(dst, dst ? nil : err ?: [NSError errorWithDomain:UIDocumentBrowserErrorDomain code:UIDocumentBrowserErrorGeneric userInfo:nil]);
}
@end

/* iOS 18: the intent of the create document action that asked the delegate for a document */
static char kActiveIntent;
@implementation UIDocumentBrowserViewController (UIDocumentCreationIntent)
- (UIDocumentCreationIntent)activeDocumentCreationIntent { return objc_getAssociatedObject(self, &kActiveIntent); }
- (void)_isimCreateWithIntent:(UIDocumentCreationIntent)intent {
    objc_setAssociatedObject(self, &kActiveIntent, intent, OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSLog(@"isim UIKit: document browser: create document (%@)", intent);
    [self _isimCreate];                                            /* the delegate is asked synchronously */
    objc_setAssociatedObject(self, &kActiveIntent, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (void)_isimCreateDefault { [self _isimCreateWithIntent:UIDocumentCreationIntentDefault]; }
@end
