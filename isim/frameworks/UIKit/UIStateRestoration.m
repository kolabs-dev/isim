/* View controller-based state restoration (adapted; see UIStateRestoration.h for the behaviour).
 *
 * The archive (Library/isim/RestorationState.archive) is one keyed archive: the system keys
 * (UIApplicationStateRestoration*Key), what the app delegate encodes in application:willEncodeRestorableStateWithCoder:,
 * and "_isimRecords": one property list per saved object, parents first —
 *   kind ("vc", "view", "object"), path (restoration identifiers from the root), class, restorationClass,
 *   storyboard (name), state (a keyed archive of the object's own encodeRestorableStateWithCoder:),
 *   children (navigation stack: child paths), selected (tab index), presented (path).
 * Each object decodes from its own coder; a view controller's coder also answers
 * UIStateRestorationViewControllerStoryboardKey with the storyboard it came from. */
#import "UIKitPrivate.h"
#import <UIKit/UIStateRestoration.h>
#import <objc/runtime.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"   /* the pre-13.2 app delegate methods are the fallback */

NSString *const UIStateRestorationViewControllerStoryboardKey = @"UIStateRestorationViewControllerStoryboardKey";
NSString *const UIApplicationStateRestorationBundleVersionKey = @"UIApplicationStateRestorationBundleVersionKey";
NSString *const UIApplicationStateRestorationUserInterfaceIdiomKey = @"UIApplicationStateRestorationUserInterfaceIdiomKey";
NSString *const UIApplicationStateRestorationTimestampKey = @"UIApplicationStateRestorationTimestampKey";
NSString *const UIApplicationStateRestorationSystemVersionKey = @"UIApplicationStateRestorationSystemVersionKey";

@interface NSKeyedUnarchiver (IsimRestoration)
- (void)setRequiresSecureCoding:(BOOL)v;
@end

/* ---- the coder a restored object reads: its archive, plus the storyboard key ---- */
@interface __IsimRestorationCoder : NSCoder
- (instancetype)initWithData:(NSData *)data secure:(BOOL)secure storyboard:(UIStoryboard *)storyboard;
@end
@implementation __IsimRestorationCoder { NSKeyedUnarchiver *_u; UIStoryboard *_storyboard; }
- (instancetype)initWithData:(NSData *)data secure:(BOOL)secure storyboard:(UIStoryboard *)storyboard {
    if ((self = [super init])) {
        _u = data ? [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL] : nil;
        [_u setRequiresSecureCoding:secure];
        _storyboard = storyboard;
    }
    return self;
}
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)requiresSecureCoding { return _u.requiresSecureCoding; }
- (NSDecodingFailurePolicy)decodingFailurePolicy { return NSDecodingFailurePolicySetErrorAndReturn; }
- (NSError *)error { return _u.error; }
- (void)failWithError:(NSError *)e { [_u failWithError:e]; }
- (NSSet *)allowedClasses { return _u.allowedClasses; }
- (BOOL)isStoryboardKey:(NSString *)k { return _storyboard && [k isEqualToString:UIStateRestorationViewControllerStoryboardKey]; }
- (BOOL)containsValueForKey:(NSString *)k { return [self isStoryboardKey:k] || [_u containsValueForKey:k]; }
- (id)decodeObjectForKey:(NSString *)k { return [self isStoryboardKey:k] ? _storyboard : [_u decodeObjectForKey:k]; }
- (id)decodeObjectOfClass:(Class)c forKey:(NSString *)k { return [self isStoryboardKey:k] ? _storyboard : [_u decodeObjectOfClass:c forKey:k]; }
- (id)decodeObjectOfClasses:(NSSet *)c forKey:(NSString *)k { return [self isStoryboardKey:k] ? _storyboard : [_u decodeObjectOfClasses:c forKey:k]; }
- (id)decodeTopLevelObjectForKey:(NSString *)k error:(NSError **)e { return [self decodeObjectForKey:k]; }
- (NSArray *)decodeArrayOfObjectsOfClass:(Class)c forKey:(NSString *)k { return [_u decodeArrayOfObjectsOfClass:c forKey:k]; }
- (NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)kc objectsOfClass:(Class)oc forKey:(NSString *)k { return [_u decodeDictionaryWithKeysOfClass:kc objectsOfClass:oc forKey:k]; }
- (BOOL)decodeBoolForKey:(NSString *)k { return [_u decodeBoolForKey:k]; }
- (int)decodeIntForKey:(NSString *)k { return [_u decodeIntForKey:k]; }
- (int32_t)decodeInt32ForKey:(NSString *)k { return [_u decodeInt32ForKey:k]; }
- (int64_t)decodeInt64ForKey:(NSString *)k { return [_u decodeInt64ForKey:k]; }
- (NSInteger)decodeIntegerForKey:(NSString *)k { return [_u decodeIntegerForKey:k]; }
- (float)decodeFloatForKey:(NSString *)k { return [_u decodeFloatForKey:k]; }
- (double)decodeDoubleForKey:(NSString *)k { return [_u decodeDoubleForKey:k]; }
- (const uint8_t *)decodeBytesForKey:(NSString *)k returnedLength:(NSUInteger *)n { return [_u decodeBytesForKey:k returnedLength:n]; }
@end

/* ---- properties ---- */
static char kRestorationID, kRestorationClass;
@implementation UIView (UIStateRestoration)
- (NSString *)restorationIdentifier { return objc_getAssociatedObject(self, &kRestorationID); }
- (void)setRestorationIdentifier:(NSString *)s { objc_setAssociatedObject(self, &kRestorationID, s, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {}
@end
@implementation UIViewController (UIStateRestoration)
- (NSString *)restorationIdentifier { return objc_getAssociatedObject(self, &kRestorationID); }
- (void)setRestorationIdentifier:(NSString *)s { objc_setAssociatedObject(self, &kRestorationID, s, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (Class)restorationClass { return objc_getAssociatedObject(self, &kRestorationClass); }
- (void)setRestorationClass:(Class)c { objc_setAssociatedObject(self, &kRestorationClass, c, OBJC_ASSOCIATION_ASSIGN); }
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {}
- (void)applicationFinishedRestoringState {}
@end

/* scroll views keep their offset; table and collection views their selection (by model identifier) */
static NSString *const kOffsetX = @"_isimContentOffsetX", *const kOffsetY = @"_isimContentOffsetY", *const kSelection = @"_isimSelectedModelIdentifiers";
@implementation UIScrollView (UIStateRestoration)
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [coder encodeDouble:self.contentOffset.x forKey:kOffsetX];
    [coder encodeDouble:self.contentOffset.y forKey:kOffsetY];
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    if (![coder containsValueForKey:kOffsetY]) return;
    [self layoutIfNeeded];
    CGPoint o = CGPointMake([coder decodeDoubleForKey:kOffsetX], [coder decodeDoubleForKey:kOffsetY]);
    CGSize cs = self.contentSize, b = self.bounds.size;
    UIEdgeInsets in = self.adjustedContentInset;
    o.x = MAX(-in.left, MIN(o.x, MAX(-in.left, cs.width - b.width + in.right)));
    o.y = MAX(-in.top, MIN(o.y, MAX(-in.top, cs.height - b.height + in.bottom)));
    self.contentOffset = o;
}
@end
static NSArray *model_ids(UIView *v, id ds, NSArray<NSIndexPath *> *paths) {
    NSMutableArray *ids = [NSMutableArray array];
    if (![ds conformsToProtocol:@protocol(UIDataSourceModelAssociation)]) return ids;
    for (NSIndexPath *p in paths) { NSString *m = [ds modelIdentifierForElementAtIndexPath:p inView:v]; if (m) [ids addObject:m]; }
    return ids;
}
static NSArray<NSIndexPath *> *index_paths(UIView *v, id ds, NSArray *ids) {
    NSMutableArray *a = [NSMutableArray array];
    if (![ds conformsToProtocol:@protocol(UIDataSourceModelAssociation)]) return a;
    for (NSString *m in ids) if ([m isKindOfClass:[NSString class]]) { NSIndexPath *p = [ds indexPathForElementWithModelIdentifier:m inView:v]; if (p) [a addObject:p]; }
    return a;
}
@implementation UITableView (UIStateRestoration)
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    NSArray *ids = model_ids(self, self.dataSource, self.indexPathsForSelectedRows ?: @[]);
    if (ids.count) [coder encodeObject:ids forKey:kSelection];
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    NSArray *ids = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:kSelection];
    for (NSIndexPath *p in index_paths(self, self.dataSource, ids)) [self selectRowAtIndexPath:p animated:NO scrollPosition:UITableViewScrollPositionNone];
}
@end
@implementation UICollectionView (UIStateRestoration)
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    NSArray *ids = model_ids(self, self.dataSource, self.indexPathsForSelectedItems ?: @[]);
    if (ids.count) [coder encodeObject:ids forKey:kSelection];
}
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    NSArray *ids = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:kSelection];
    for (NSIndexPath *p in index_paths(self, self.dataSource, ids)) [self selectItemAtIndexPath:p animated:NO scrollPosition:UICollectionViewScrollPositionNone];
}
@end

/* ---- registered objects ---- */
static NSMapTable<id, NSString *> *registered;            /* object (weak) -> restoration identifier */
@implementation UIApplication (UIStateRestoration)
- (void)extendStateRestoration { NSLog(@"isim: state restoration extended"); }
- (void)completeStateRestoration { NSLog(@"isim: state restoration completed"); }
- (void)ignoreSnapshotOnNextApplicationLaunch {}           /* isim keeps no launch snapshots */
+ (void)registerObjectForStateRestoration:(id<UIStateRestoring>)object restorationIdentifier:(NSString *)rid {
    if (!object || !rid.length) return;
    if (!registered) registered = [NSMapTable weakToStrongObjectsMapTable];
    [registered setObject:[rid copy] forKey:object];
}
@end

/* ---- the archive ---- */
static NSString *archive_path(void) {
    NSString *d = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:@"RestorationState.archive"];
}
static BOOL scene_app(void) {
    UIApplication *app = UIApplication.sharedApplication;
    return NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"] != nil
        || [app.delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)];
}
static NSString *key_of(NSArray *path) { return [path componentsJoinedByString:@"/"]; }
static NSData *object_state(id o, BOOL secure) {
    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initRequiringSecureCoding:secure];
    if ([o respondsToSelector:@selector(encodeRestorableStateWithCoder:)]) [o encodeRestorableStateWithCoder:a];
    [a finishEncoding];
    return a.encodedData;
}

/* views with a restoration identifier in a controller's view (not in its children's views) */
static void collect_views(UIView *v, UIViewController *owner, NSMutableArray *out) {
    for (UIView *s in v.subviews) {
        UIResponder *n = s.nextResponder;
        if ([n isKindOfClass:[UIViewController class]] && n != owner) continue;
        if (s.restorationIdentifier.length) [out addObject:s];
        collect_views(s, owner, out);
    }
}
static NSArray<UIViewController *> *children_of(UIViewController *vc) {
    if ([vc isKindOfClass:[UINavigationController class]]) return ((UINavigationController *)vc).viewControllers;
    if ([vc isKindOfClass:[UITabBarController class]]) return ((UITabBarController *)vc).viewControllers ?: @[];
    if ([vc isKindOfClass:[UISplitViewController class]]) return ((UISplitViewController *)vc).viewControllers;
    return vc.childViewControllers;
}
static void save_vc(UIViewController *vc, NSArray *parent, BOOL secure, NSMutableArray *records, NSMutableDictionary *paths) {
    NSString *rid = vc.restorationIdentifier;
    if (!rid.length) return;
    NSArray *path = [parent arrayByAddingObject:rid];
    if (paths[key_of(path)]) { NSLog(@"isim: state restoration: two view controllers with the path %@; saving the first", key_of(path)); return; }
    NSMutableDictionary *r = [@{ @"kind": @"vc", @"path": path, @"class": NSStringFromClass(vc.class), @"state": object_state(vc, secure) } mutableCopy];
    paths[key_of(path)] = path;
    if (vc.restorationClass) r[@"restorationClass"] = NSStringFromClass(vc.restorationClass);
    NSString *sb = [vc.storyboard valueForKey:@"name"];
    if (sb) r[@"storyboard"] = sb;
    [records addObject:r];
    if (vc.isViewLoaded) {
        NSMutableArray *views = [NSMutableArray array];
        collect_views(vc.view, vc, views);
        if (vc.view.restorationIdentifier.length) [views insertObject:vc.view atIndex:0];
        for (UIView *v in views)
            [records addObject:@{ @"kind": @"view", @"path": [path arrayByAddingObject:v.restorationIdentifier], @"owner": path, @"state": object_state(v, secure) }];
    }
    NSMutableArray *kids = [NSMutableArray array];
    for (UIViewController *c in children_of(vc)) {
        if (!c.restorationIdentifier.length) continue;
        save_vc(c, path, secure, records, paths);
        [kids addObject:[path arrayByAddingObject:c.restorationIdentifier]];
    }
    if (kids.count) r[@"children"] = kids;
    if ([vc isKindOfClass:[UITabBarController class]]) r[@"selected"] = @(((UITabBarController *)vc).selectedIndex);
    UIViewController *p = vc.presentedViewController;
    if (p && p.presentingViewController == vc && p.restorationIdentifier.length && !p.isBeingDismissed) {
        save_vc(p, path, secure, records, paths);
        r[@"presented"] = [path arrayByAddingObject:p.restorationIdentifier];
    }
}
static NSArray *object_path(id o, NSMutableDictionary *paths, NSMutableSet *visiting) {
    NSString *rid = [registered objectForKey:o];
    if (!rid) {
        if ([o isKindOfClass:[UIViewController class]] && [o restorationIdentifier]) {   /* a saved controller */
            for (NSArray *p in paths.allValues) if ([p.lastObject isEqualToString:[o restorationIdentifier]]) return p;
        }
        return nil;
    }
    if ([visiting containsObject:o]) return nil;
    [visiting addObject:o];
    id parent = [o respondsToSelector:@selector(restorationParent)] ? [o restorationParent] : nil;
    NSArray *base = parent ? object_path(parent, paths, visiting) : @[];
    return base ? [base arrayByAddingObject:rid] : nil;
}

/* the app went to the background */
void isim_ui_save_restoration_state(void) {
    if (scene_app()) return;
    UIApplication *app = UIApplication.sharedApplication;
    id<UIApplicationDelegate> d = app.delegate;
    NSKeyedArchiver *top = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    BOOL secure = YES, save = NO;
    if ([d respondsToSelector:@selector(application:shouldSaveSecureApplicationState:)]) save = [d application:app shouldSaveSecureApplicationState:top];
    else if ([d respondsToSelector:@selector(application:shouldSaveApplicationState:)]) {
        top = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO]; secure = NO;
        save = [d application:app shouldSaveApplicationState:top];
    }
    if (!save) { [NSFileManager.defaultManager removeItemAtPath:archive_path() error:NULL]; return; }
    NSMutableArray *records = [NSMutableArray array];
    NSMutableDictionary *paths = [NSMutableDictionary dictionary];
    for (UIWindow *w in app.windows) if (w.rootViewController && !w.hidden) save_vc(w.rootViewController, @[], secure, records, paths);
    NSUInteger vcs = records.count;
    for (id o in registered.keyEnumerator.allObjects) {
        NSArray *path = object_path(o, paths, [NSMutableSet set]);
        if (!path) continue;
        NSMutableDictionary *r = [@{ @"kind": @"object", @"path": path, @"class": NSStringFromClass([o class]), @"state": object_state(o, secure) } mutableCopy];
        Class rc = [o respondsToSelector:@selector(objectRestorationClass)] ? [o objectRestorationClass] : nil;
        if (rc) r[@"restorationClass"] = NSStringFromClass(rc);
        [records addObject:r];
    }
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    if (info[@"CFBundleVersion"]) [top encodeObject:info[@"CFBundleVersion"] forKey:UIApplicationStateRestorationBundleVersionKey];
    [top encodeObject:@(UIDevice.currentDevice.userInterfaceIdiom) forKey:UIApplicationStateRestorationUserInterfaceIdiomKey];
    [top encodeObject:[NSDate date] forKey:UIApplicationStateRestorationTimestampKey];
    [top encodeObject:UIDevice.currentDevice.systemVersion forKey:UIApplicationStateRestorationSystemVersionKey];
    if ([d respondsToSelector:@selector(application:willEncodeRestorableStateWithCoder:)]) [d application:app willEncodeRestorableStateWithCoder:top];
    [top encodeObject:records forKey:@"_isimRecords"];
    [top encodeBool:secure forKey:@"_isimSecure"];
    [top finishEncoding];
    if ([top.encodedData writeToFile:archive_path() atomically:YES])
        NSLog(@"isim: state restoration: saved %lu objects (%lu view controllers and views)", (unsigned long)records.count, (unsigned long)vcs);
}
/* closed in the app switcher: nothing to restore next time */
void isim_ui_discard_restoration_state(void) { [NSFileManager.defaultManager removeItemAtPath:archive_path() error:NULL]; }

/* ---- restoring ---- */
static UIViewController *find_existing(NSArray *path) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIViewController *vc = w.rootViewController;
        if (!vc || ![vc.restorationIdentifier isEqualToString:path.firstObject]) continue;
        for (NSUInteger i = 1; i < path.count && vc; i++) {
            UIViewController *next = nil;
            NSMutableArray *candidates = [children_of(vc) mutableCopy];
            if (vc.presentedViewController) [candidates addObject:vc.presentedViewController];
            for (UIViewController *c in candidates) if ([c.restorationIdentifier isEqualToString:path[i]]) { next = c; break; }
            vc = next;
        }
        if (vc) return vc;
    }
    return nil;
}
static UIView *find_view(UIView *root, UIViewController *owner, NSString *rid) {
    if ([root.restorationIdentifier isEqualToString:rid]) return root;
    NSMutableArray *views = [NSMutableArray array];
    collect_views(root, owner, views);
    for (UIView *v in views) if ([v.restorationIdentifier isEqualToString:rid]) return v;
    return nil;
}
/* (checked first: isim's runtime cannot catch the exceptions UIStoryboard raises) */
static UIStoryboard *storyboard_named(NSString *name) {
    if (!name || (![NSBundle.mainBundle pathForResource:name ofType:@"storyboardc"])) return nil;
    return [UIStoryboard storyboardWithName:name bundle:nil];
}
static BOOL storyboard_has(UIStoryboard *sb, NSString *identifier) { return [[sb valueForKey:@"data"][@"identifiers"] objectForKey:identifier] != nil; }

/* between application:willFinishLaunchingWithOptions: and application:didFinishLaunchingWithOptions: */
void isim_ui_restore_state(void) {
    if (scene_app()) return;
    NSData *data = [NSData dataWithContentsOfFile:archive_path()];
    if (!data) return;
    UIApplication *app = UIApplication.sharedApplication;
    id<UIApplicationDelegate> d = app.delegate;
    NSKeyedUnarchiver *peek = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
    if (!peek) { NSLog(@"isim: state restoration: unreadable archive, discarded"); isim_ui_discard_restoration_state(); return; }
    BOOL secure = [peek decodeBoolForKey:@"_isimSecure"];
    __IsimRestorationCoder *top = [[__IsimRestorationCoder alloc] initWithData:data secure:secure storyboard:nil];
    BOOL restore = NO;
    if ([d respondsToSelector:@selector(application:shouldRestoreSecureApplicationState:)]) restore = [d application:app shouldRestoreSecureApplicationState:top];
    else if ([d respondsToSelector:@selector(application:shouldRestoreApplicationState:)]) restore = [d application:app shouldRestoreApplicationState:top];
    if (!restore) { NSLog(@"isim: state restoration: declined by the app delegate"); return; }
    [peek setRequiresSecureCoding:NO];
    NSArray *records = [peek decodeObjectForKey:@"_isimRecords"];
    NSMutableDictionary<NSString *, id> *objects = [NSMutableDictionary dictionary];
    NSMutableArray *restored = [NSMutableArray array];            /* [object, coder] in order */
    NSUInteger wanted = 0;
    for (NSDictionary *r in records) {
        if (![r[@"kind"] isEqualToString:@"vc"]) continue;
        wanted++;
        NSArray *path = r[@"path"];
        UIStoryboard *sb = storyboard_named(r[@"storyboard"]);
        __IsimRestorationCoder *coder = [[__IsimRestorationCoder alloc] initWithData:r[@"state"] secure:secure storyboard:sb];
        UIViewController *vc = nil;
        Class rc = r[@"restorationClass"] ? NSClassFromString(r[@"restorationClass"]) : nil;
        if (rc) {                                                   /* the restoration class decides (nil: not restored) */
            if ([rc respondsToSelector:@selector(viewControllerWithRestorationIdentifierPath:coder:)]) vc = [rc viewControllerWithRestorationIdentifierPath:path coder:coder];
        } else {
            if ([d respondsToSelector:@selector(application:viewControllerWithRestorationIdentifierPath:coder:)]) vc = [d application:app viewControllerWithRestorationIdentifierPath:path coder:coder];
            if (!vc) vc = find_existing(path);
            if (!vc && sb && storyboard_has(sb, path.lastObject)) vc = [sb instantiateViewControllerWithIdentifier:path.lastObject];
        }
        if (!vc) { NSLog(@"isim: state restoration: no view controller for %@", key_of(path)); continue; }
        if (!vc.restorationIdentifier) vc.restorationIdentifier = path.lastObject;
        objects[key_of(path)] = vc;
        [restored addObject:@[vc, coder]];
    }
    /* containers: navigation stacks and the selected tab */
    for (NSDictionary *r in records) {
        UIViewController *vc = objects[key_of(r[@"path"])];
        if (!vc) continue;
        if ([vc isKindOfClass:[UINavigationController class]] && r[@"children"]) {
            NSMutableArray *stack = [NSMutableArray array];
            for (NSArray *p in r[@"children"]) if (objects[key_of(p)]) [stack addObject:objects[key_of(p)]];
            UINavigationController *nav = (UINavigationController *)vc;
            if (stack.count && ![stack isEqualToArray:nav.viewControllers]) [nav setViewControllers:stack animated:NO];
        }
        if ([vc isKindOfClass:[UITabBarController class]] && r[@"selected"]) {
            UITabBarController *tab = (UITabBarController *)vc;
            NSUInteger i = [r[@"selected"] unsignedIntegerValue];
            if (i < tab.viewControllers.count) tab.selectedIndex = i;
        }
    }
    /* objects registered for restoration */
    for (NSDictionary *r in records) {
        if (![r[@"kind"] isEqualToString:@"object"]) continue;
        NSArray *path = r[@"path"];
        __IsimRestorationCoder *coder = [[__IsimRestorationCoder alloc] initWithData:r[@"state"] secure:secure storyboard:nil];
        id o = nil;
        Class rc = r[@"restorationClass"] ? NSClassFromString(r[@"restorationClass"]) : nil;
        if (rc && [rc respondsToSelector:@selector(objectWithRestorationIdentifierPath:coder:)]) o = [rc objectWithRestorationIdentifierPath:path coder:coder];
        if (!o) for (id x in registered.keyEnumerator.allObjects) if ([[registered objectForKey:x] isEqualToString:path.lastObject]) { o = x; break; }
        if (!o) { NSLog(@"isim: state restoration: no object for %@", key_of(path)); continue; }
        objects[key_of(path)] = o;
        [restored addObject:@[o, coder]];
    }
    for (NSArray *pair in restored) if ([pair[0] respondsToSelector:@selector(decodeRestorableStateWithCoder:)]) [pair[0] decodeRestorableStateWithCoder:pair[1]];
    if ([d respondsToSelector:@selector(application:didDecodeRestorableStateWithCoder:)]) [d application:app didDecodeRestorableStateWithCoder:top];
    NSUInteger vcs = 0;
    for (NSArray *pair in restored) if ([pair[0] isKindOfClass:[UIViewController class]]) vcs++;
    NSLog(@"isim: state restoration: restored %lu of %lu view controllers", (unsigned long)vcs, (unsigned long)wanted);
    /* once the window is up: presented controllers, views (they need their data and layout), then finished */
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSDictionary *r in records) {
            UIViewController *vc = objects[key_of(r[@"path"])], *p = r[@"presented"] ? objects[key_of(r[@"presented"])] : nil;
            if (vc && p && !vc.presentedViewController && vc.view.window) [vc presentViewController:p animated:NO completion:nil];
        }
        for (UIWindow *w in app.windows) [w layoutIfNeeded];
        NSUInteger views = 0;
        for (NSDictionary *r in records) {
            if (![r[@"kind"] isEqualToString:@"view"]) continue;
            UIViewController *owner = objects[key_of(r[@"owner"])];
            UIView *v = owner ? find_view(owner.view, owner, [r[@"path"] lastObject]) : nil;
            if (!v) continue;
            [v layoutIfNeeded];
            [v decodeRestorableStateWithCoder:[[__IsimRestorationCoder alloc] initWithData:r[@"state"] secure:secure storyboard:nil]];
            views++;
        }
        for (NSArray *pair in restored) if ([pair[0] respondsToSelector:@selector(applicationFinishedRestoringState)]) [pair[0] applicationFinishedRestoringState];
        NSLog(@"isim: state restoration: finished (%lu views)", (unsigned long)views);
    });
}
