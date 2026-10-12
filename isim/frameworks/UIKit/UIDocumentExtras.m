/* UIDocumentInteractionController and UIManagedDocument (documentation sweep, #9).
 *
 * UIDocumentInteractionController: the preview is QuickLook's QLPreviewController (QuickLook is loaded at run time:
 * it links UIKit) presented from the delegate's documentInteractionControllerViewControllerForPreview:; the options
 * and Open In menus are isim's share sheet with the file (adapted: its Share and Action extensions, Copy, Print —
 * there are no other apps to open the file in).
 *
 * UIManagedDocument: a package holding a Core Data SQLite store (StoreContent/persistentStore) and optional
 * AdditionalContent; opening adds the store to a coordinator, saving saves the main-queue context. Core Data is looked
 * up at run time (the app links it). */
#import "UIKitPrivate.h"
#import <UIKit/UIDocumentInteractionController.h>
#import <UIKit/UIActivityViewController.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <objc/message.h>

extern NSString *isim_ui_type_for_extension(NSString *ext);   /* UIDocument.m */

/* ================= UIDocumentInteractionController ================= */
@interface __IsimDICPreviewSource : NSObject
@property (nonatomic, weak) UIDocumentInteractionController *owner;
@end
@implementation UIDocumentInteractionController {
    NSString *_uti, *_name;
    __weak UIViewController *_preview, *_menu;
    __IsimDICPreviewSource *_source;
    BOOL _menuIsOpenIn;
}
+ (UIDocumentInteractionController *)interactionControllerWithURL:(NSURL *)url { UIDocumentInteractionController *c = [self new]; c.URL = url; return c; }
- (NSString *)UTI { return _uti ?: (self.URL ? isim_ui_type_for_extension(self.URL.pathExtension) : nil); }
- (void)setUTI:(NSString *)u { _uti = [u copy]; }
- (NSString *)name { return _name ?: self.URL.lastPathComponent; }
- (void)setName:(NSString *)n { _name = [n copy]; }
- (NSArray<UIImage *> *)icons {
    NSString *t = self.UTI ?: @"";
    NSString *symbol = [t hasPrefix:@"public.image"] || [t containsString:@"png"] || [t containsString:@"jpeg"] ? @"photo"
                     : [t containsString:@"pdf"] ? @"doc.richtext" : [t containsString:@"text"] ? @"doc.text" : @"doc";
    UIImage *i = [UIImage systemImageNamed:symbol];
    return i ? @[i] : @[];
}
- (NSArray<UIGestureRecognizer *> *)gestureRecognizers { return @[]; }

/* ---- preview ---- */
- (BOOL)presentPreviewAnimated:(BOOL)animated {
    id<UIDocumentInteractionControllerDelegate> d = self.delegate;
    UIViewController *host = [d respondsToSelector:@selector(documentInteractionControllerViewControllerForPreview:)] ? [d documentInteractionControllerViewControllerForPreview:self] : nil;
    if (!host || !self.URL) return NO;
    Class ql = NSClassFromString(@"QLPreviewController");
    if (!ql) { dlopen("/System/Library/Frameworks/QuickLook.framework/QuickLook", RTLD_NOW); ql = NSClassFromString(@"QLPreviewController"); }
    if (!ql) return NO;
    if ([d respondsToSelector:@selector(documentInteractionControllerWillBeginPreview:)]) [d documentInteractionControllerWillBeginPreview:self];
    _source = [__IsimDICPreviewSource new]; _source.owner = self;
    UIViewController *pc = [ql new];
    [pc setValue:_source forKey:@"dataSource"];
    [pc setValue:_source forKey:@"delegate"];
    _preview = pc;
    NSLog(@"isim: document interaction preview of %@", self.name);
    UIViewController *top = host; while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:pc animated:animated completion:nil];
    return YES;
}
- (void)dismissPreviewAnimated:(BOOL)animated { [_preview dismissViewControllerAnimated:animated completion:nil]; }
- (void)_isim_previewEnded {
    id<UIDocumentInteractionControllerDelegate> d = self.delegate;
    _preview = nil;
    if ([d respondsToSelector:@selector(documentInteractionControllerDidEndPreview:)]) [d documentInteractionControllerDidEndPreview:self];
}

/* ---- the options and Open In menus: the share sheet with the file ---- */
static UIViewController *controller_for_view(UIView *v) {
    for (UIResponder *r = v; r; r = r.nextResponder) if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    return v.window.rootViewController;
}
- (BOOL)_isim_presentMenu:(BOOL)openIn rect:(CGRect)rect view:(UIView *)view item:(UIBarButtonItem *)item animated:(BOOL)animated {
    if (!self.URL) return NO;
    id<UIDocumentInteractionControllerDelegate> d = self.delegate;
    SEL will = openIn ? @selector(documentInteractionControllerWillPresentOpenInMenu:) : @selector(documentInteractionControllerWillPresentOptionsMenu:);
    if ([d respondsToSelector:will]) ((void (*)(id, SEL, id))objc_msgSend)(d, will, self);
    UIActivityViewController *s = [[UIActivityViewController alloc] initWithActivityItems:@[self.URL] applicationActivities:nil];
    __weak UIDocumentInteractionController *ws = self;
    s.completionWithItemsHandler = ^(UIActivityType t, BOOL completed, NSArray *items, NSError *e) { [ws _isim_menuDismissed]; };
    if (view) { s.popoverPresentationController.sourceView = view; s.popoverPresentationController.sourceRect = rect; }
    if (item) s.popoverPresentationController.barButtonItem = item;
    UIViewController *host = view ? controller_for_view(view) : UIApplication.sharedApplication.keyWindow.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    if (!host) return NO;
    _menu = s; _menuIsOpenIn = openIn;
    NSLog(@"isim: document interaction %@ menu for %@", openIn ? @"Open In" : @"options", self.name);
    [host presentViewController:s animated:animated completion:nil];
    return YES;
}
- (void)_isim_menuDismissed {
    id<UIDocumentInteractionControllerDelegate> d = self.delegate;
    SEL did = _menuIsOpenIn ? @selector(documentInteractionControllerDidDismissOpenInMenu:) : @selector(documentInteractionControllerDidDismissOptionsMenu:);
    _menu = nil;
    if ([d respondsToSelector:did]) ((void (*)(id, SEL, id))objc_msgSend)(d, did, self);
}
- (BOOL)presentOptionsMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated { return [self _isim_presentMenu:NO rect:rect view:view item:nil animated:animated]; }
- (BOOL)presentOptionsMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { return [self _isim_presentMenu:NO rect:CGRectZero view:nil item:item animated:animated]; }
- (BOOL)presentOpenInMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated { return [self _isim_presentMenu:YES rect:rect view:view item:nil animated:animated]; }
- (BOOL)presentOpenInMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { return [self _isim_presentMenu:YES rect:CGRectZero view:nil item:item animated:animated]; }
- (void)dismissMenuAnimated:(BOOL)animated {
    UIViewController *m = _menu;
    if (m) [m dismissViewControllerAnimated:animated completion:^{ [self _isim_menuDismissed]; }];
}
@end

/* QuickLook's data source and delegate (informal: QuickLook is not linked) */
@implementation __IsimDICPreviewSource
- (NSInteger)numberOfPreviewItemsInPreviewController:(id)c { return self.owner.URL ? 1 : 0; }
- (id)previewController:(id)c previewItemAtIndex:(NSInteger)i { return self.owner.URL; }
- (void)previewControllerDidDismiss:(id)c { [self.owner _isim_previewEnded]; }
@end

/* ================= UIManagedDocument ================= */
/* the Core Data messages (sent to objects of classes looked up at run time) */
@protocol __IsimCoreData
+ (id)mergedModelFromBundles:(NSArray *)bundles;
- (id)initWithManagedObjectModel:(id)model;
- (id)initWithConcurrencyType:(NSUInteger)type;
- (void)setPersistentStoreCoordinator:(id)c;
- (id)persistentStoreCoordinator;
- (id)addPersistentStoreWithType:(NSString *)t configuration:(NSString *)c URL:(NSURL *)u options:(NSDictionary *)o error:(NSError **)e;
- (NSArray *)persistentStores;
- (BOOL)hasChanges;
- (BOOL)save:(NSError **)e;
@end
static Class core_data_class(NSString *name) {
    Class c = NSClassFromString(name);
    if (!c) { dlopen("/System/Library/Frameworks/CoreData.framework/CoreData", RTLD_NOW); c = NSClassFromString(name); }
    return c;
}
@implementation UIManagedDocument {
    id _context, _model;
}
+ (NSString *)persistentStoreName { return @"persistentStore"; }
- (NSManagedObjectModel *)managedObjectModel {
    if (!_model) _model = [(id)core_data_class(@"NSManagedObjectModel") mergedModelFromBundles:nil];
    return _model;
}
- (NSManagedObjectContext *)managedObjectContext {
    if (!_context) {
        _context = [(id)[core_data_class(@"NSManagedObjectContext") alloc] initWithConcurrencyType:2 /* main queue */];
        id psc = [(id)[core_data_class(@"NSPersistentStoreCoordinator") alloc] initWithManagedObjectModel:self.managedObjectModel];
        [_context setPersistentStoreCoordinator:psc];
    }
    return _context;
}
- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType { return @"SQLite"; }   /* NSSQLiteStoreType */
- (NSURL *)_isim_storeURL:(NSURL *)doc { return [[doc URLByAppendingPathComponent:@"StoreContent"] URLByAppendingPathComponent:self.class.persistentStoreName]; }
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration
                                     storeOptions:(NSDictionary *)storeOptions error:(NSError **)error {
    id psc = [(id)self.managedObjectContext persistentStoreCoordinator];
    if ([psc persistentStores].count) return YES;
    [NSFileManager.defaultManager createDirectoryAtPath:storeURL.path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    return [psc addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType] configuration:configuration URL:storeURL options:storeOptions error:error] != nil;
}
- (BOOL)readAdditionalContentFromURL:(NSURL *)absoluteURL error:(NSError **)error { return YES; }
- (id)additionalContentForURL:(NSURL *)absoluteURL error:(NSError **)error { return nil; }
- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)original error:(NSError **)error { return YES; }
/* opening: the store in the package (on the main queue, where the context lives) */
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError {
    __block BOOL ok = NO; __block NSError *err = nil;
    void (^open)(void) = ^{
        NSError *e = nil;
        ok = [self configurePersistentStoreCoordinatorForURL:[self _isim_storeURL:url] ofType:self.fileType ?: @"" modelConfiguration:self.modelConfiguration
                                               storeOptions:self.persistentStoreOptions error:&e];
        NSURL *extra = [url URLByAppendingPathComponent:@"AdditionalContent"];
        if (ok && [NSFileManager.defaultManager fileExistsAtPath:extra.path]) ok = [self readAdditionalContentFromURL:extra error:&e];
        err = e;
    };
    if (NSThread.isMainThread) open(); else dispatch_sync(dispatch_get_main_queue(), open);
    if (!ok && outError) *outError = err;
    return ok;
}
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError { return YES; }
- (id)contentsForType:(NSString *)typeName error:(NSError **)outError { return self.managedObjectContext; }
/* saving: the store is created on first save, then the context saves into it */
- (BOOL)writeContents:(id)contents andAttributes:(NSDictionary *)attrs safelyToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)op error:(NSError **)outError {
    __block BOOL ok = NO; __block NSError *err = nil;
    void (^save)(void) = ^{
        NSError *e = nil;
        ok = [self configurePersistentStoreCoordinatorForURL:[self _isim_storeURL:url] ofType:self.fileType ?: @"" modelConfiguration:self.modelConfiguration
                                               storeOptions:self.persistentStoreOptions error:&e];
        if (ok && [(id)self.managedObjectContext hasChanges]) ok = [(id)self.managedObjectContext save:&e];
        if (ok) {
            NSURL *extra = [url URLByAppendingPathComponent:@"AdditionalContent"];
            id more = [self additionalContentForURL:extra error:&e];
            if (more) ok = [self writeAdditionalContent:more toURL:extra originalContentsURL:nil error:&e];
        }
        err = e;
    };
    if (NSThread.isMainThread) save(); else dispatch_sync(dispatch_get_main_queue(), save);
    if (!ok && outError) *outError = err;
    return ok;
}
@end
