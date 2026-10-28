// isim FileProvider for Objective-C: the C constants (the classes and protocols are the FileProvider Swift overlay's).
#import <FileProvider/FileProvider.h>

NSFileProviderItemIdentifier const NSFileProviderRootContainerItemIdentifier = @"NSFileProviderRootContainerItemIdentifier";
NSFileProviderItemIdentifier const NSFileProviderWorkingSetContainerItemIdentifier = @"NSFileProviderWorkingSetContainerItemIdentifier";
NSFileProviderItemIdentifier const NSFileProviderTrashContainerItemIdentifier = @"NSFileProviderTrashContainerItemIdentifier";
NSFileProviderUserInfoKey const NSFileProviderUserInfoExperimentIDKey = @"NSFileProviderUserInfoExperimentID";
unsigned long long const NSFileProviderFavoriteRankUnranked = ~0ULL;

NSErrorDomain const NSFileProviderErrorDomain = @"NSFileProviderErrorDomain";
NSString * const NSFileProviderErrorCollidingItemKey = @"NSFileProviderErrorCollidingItem";
NSString * const NSFileProviderErrorItemKey = @"NSFileProviderErrorItem";
NSString * const NSFileProviderErrorNonExistentItemIdentifierKey = @"NSFileProviderErrorNonExistentItemIdentifier";

/* ---- for the document picker's item menus (UIKit: UIDocumentPicker.m) ---- */
#include <dlfcn.h>
extern NSDictionary *isim_fp_item_info(NSString *path);                              /* Host.swift */
extern NSDictionary *isim_fp_domain_info(NSString *path);
extern void isim_fp_perform(NSString *action, NSArray *paths, void (^done)(NSError *));

/* whether an action's NSExtensionFileProviderActionActivationRule (an NSPredicate format; its object has the items as
   `fileproviderItems`) holds for the item */
static BOOL rule_holds(id rule, NSDictionary *info) {
    if (!rule) return YES;
    if (![rule isKindOfClass:[NSString class]]) return NO;
    NSDictionary *item = @{ @"itemIdentifier": info[@"identifier"], @"filename": info[@"filename"], @"typeIdentifier": info[@"contentType"],
                            @"contentType": @{ @"identifier": info[@"contentType"] }, @"isFolder": info[@"folder"],
                            @"isDownloaded": @(![info[@"dataless"] boolValue]), @"documentSize": info[@"size"] ?: @0 };
    @try {
        return [[NSPredicate predicateWithFormat:rule] evaluateWithObject:@{ @"fileproviderItems": @[item] }];
    } @catch (NSException *e) {
        NSLog(@"isim FileProvider: the activation rule \"%@\" is not a predicate: %@", rule, e.reason);
        return NO;
    }
}

/* the actions of the item's provider (NSExtensionFileProviderActions of its file provider extension, then of its
   FileProviderUI extension): [{ identifier, title, kind (custom | ui), extensionPath, domain, item }] */
NSArray *isim_fp_actions(NSString *path) {
    NSDictionary *info = isim_fp_item_info(path);
    if (!info) return @[];
    NSMutableArray *out = [NSMutableArray array];
    NSString *plugins = [info[@"appPath"] stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *kind in @[@"custom", @"ui"]) {
        NSString *point = [kind isEqual:@"ui"] ? @"com.apple.fileprovider-actionsui" : @"com.apple.fileprovider-nonui";
        for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
            if (![n hasSuffix:@".appex"]) continue;
            NSString *x = [plugins stringByAppendingPathComponent:n];
            NSDictionary *ext = [NSDictionary dictionaryWithContentsOfFile:[x stringByAppendingPathComponent:@"Info.plist"]][@"NSExtension"];
            if (![ext[@"NSExtensionPointIdentifier"] isEqual:point]) continue;
            for (NSDictionary *a in ext[@"NSExtensionFileProviderActions"]) {
                NSString *ident = a[@"NSExtensionFileProviderActionIdentifier"], *title = a[@"NSExtensionFileProviderActionName"] ?: ident;
                if (!ident.length || !rule_holds(a[@"NSExtensionFileProviderActionActivationRule"], info)) continue;
                [out addObject:@{ @"identifier": ident, @"title": title, @"kind": kind, @"extensionPath": x, @"domain": info[@"domain"],
                                  @"item": info[@"identifier"] }];
            }
        }
    }
    return out;
}

typedef void (*fpui_present_fn)(NSString *, NSString *, NSArray *, NSString *, NSError *, id, void (^)(NSError *));
static fpui_present_fn fpui_present(void) {
    if (!dlopen("/System/Library/Frameworks/FileProviderUI.framework/FileProviderUI", RTLD_NOW)) return NULL;
    return (fpui_present_fn)dlsym(RTLD_DEFAULT, "isim_fpui_present");
}
/* the app's FileProviderUI extension */
static NSString *ui_extension(NSString *appPath) {
    NSString *plugins = [appPath stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *x = [plugins stringByAppendingPathComponent:n];
        NSDictionary *ext = [NSDictionary dictionaryWithContentsOfFile:[x stringByAppendingPathComponent:@"Info.plist"]][@"NSExtension"];
        if ([n hasSuffix:@".appex"] && [ext[@"NSExtensionPointIdentifier"] isEqual:@"com.apple.fileprovider-actionsui"]) return x;
    }
    return nil;
}

/* a domain failed to sync with NSFileProviderErrorNotAuthenticated: the provider's FileProviderUI extension shows
   (prepareForError:), like iOS's sign-in sheet; done gets the error when there is none */
void isim_fp_show_error(NSString *path, NSError *error, id presenter, void (^done)(NSError *)) {
    NSDictionary *d = isim_fp_domain_info(path);
    NSString *x = d ? ui_extension(d[@"appPath"]) : nil;
    fpui_present_fn present = x ? fpui_present() : NULL;
    if (!present) { done(error); return; }
    present(x, nil, @[], d[@"domain"], error, presenter, done);
}

/* runs one of those actions: a custom action in the file provider extension, or the FileProviderUI extension's view
   controller presented over `presenter` */
void isim_fp_run_action(NSDictionary *action, NSArray *paths, id presenter, void (^done)(NSError *)) {
    if ([action[@"kind"] isEqual:@"custom"]) { isim_fp_perform(action[@"identifier"], paths, done); return; }
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *p in paths) { NSString *i = isim_fp_item_info(p)[@"identifier"]; if (i) [items addObject:i]; }
    fpui_present_fn present = fpui_present();
    if (!present) { done([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]); return; }
    present(action[@"extensionPath"], action[@"identifier"], items, action[@"domain"], nil, presenter, done);
}
