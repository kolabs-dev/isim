// isim CoreFoundation: CFNotificationCenter. The Darwin center is notify(3) (Notify.m: every process of the device;
// callbacks run on the main queue, without object or userInfo, as on iOS); the local center (and the distributed
// one, macOS's: in the process too) calls its observers on the posting thread, matching name and object (NULL: any).
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <notify.h>

enum { CENTER_LOCAL, CENTER_DISTRIBUTED, CENTER_DARWIN };

@interface __IsimCFNotificationObservation : NSObject {
@public
    const void *observer, *object;
    CFNotificationCallback callback;
    NSString *name;
    int token;                                  /* the Darwin center's notify(3) registration (-1: none) */
}
@end
@implementation __IsimCFNotificationObservation
@end

@interface __IsimCFNotificationCenter : NSObject {
@public
    int kind;
    NSMutableArray<__IsimCFNotificationObservation *> *observations;
}
@end
@implementation __IsimCFNotificationCenter
- (CFTypeID)_isimCFTypeID { return CFNotificationCenterGetTypeID(); }
@end

static CFNotificationCenterRef center_of(int kind) {
    static __IsimCFNotificationCenter *centers[3];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (int i = 0; i < 3; i++) { centers[i] = [__IsimCFNotificationCenter new]; centers[i]->kind = i; centers[i]->observations = [NSMutableArray array]; }
    });
    return (__bridge CFNotificationCenterRef)centers[kind];
}
#define CENTER(c) ((__bridge __IsimCFNotificationCenter *)(c))

CFTypeID CFNotificationCenterGetTypeID(void) { return 0x5e30; }
CFNotificationCenterRef CFNotificationCenterGetLocalCenter(void) { return center_of(CENTER_LOCAL); }
CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void) { return center_of(CENTER_DISTRIBUTED); }
CFNotificationCenterRef CFNotificationCenterGetDarwinNotifyCenter(void) { return center_of(CENTER_DARWIN); }

void CFNotificationCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack,
                                     CFStringRef name, const void *object, CFNotificationSuspensionBehavior behavior) {
    __IsimCFNotificationCenter *c = CENTER(center);
    if (!c || !callBack) return;
    if (c->kind == CENTER_DARWIN && !name) return;                    /* Darwin observers need a name */
    __IsimCFNotificationObservation *o = [__IsimCFNotificationObservation new];
    o->observer = observer; o->callback = callBack; o->name = [(__bridge NSString *)name copy]; o->token = -1;
    o->object = c->kind == CENTER_DARWIN ? NULL : object;             /* the Darwin center ignores the object */
    if (c->kind == CENTER_DARWIN) {
        NSString *n = o->name;
        CFNotificationCallback cb = callBack;
        const void *who = observer;
        if (notify_register_dispatch(n.UTF8String, &o->token, dispatch_get_main_queue(), ^(int token) {
                cb(center, (void *)who, (__bridge CFStringRef)n, NULL, NULL);
            }) != NOTIFY_STATUS_OK) return;
    }
    @synchronized (c) { [c->observations addObject:o]; }
}
static void remove_matching(__IsimCFNotificationCenter *c, BOOL (^match)(__IsimCFNotificationObservation *)) {
    NSMutableArray *gone = [NSMutableArray array];
    @synchronized (c) {
        for (__IsimCFNotificationObservation *o in c->observations) if (match(o)) [gone addObject:o];
        [c->observations removeObjectsInArray:gone];
    }
    for (__IsimCFNotificationObservation *o in gone) if (o->token >= 0) notify_cancel(o->token);
}
/* NULL name or object: every name or object of the observer */
void CFNotificationCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFNotificationName name, const void *object) {
    if (!center) return;
    NSString *n = (__bridge NSString *)name;
    remove_matching(CENTER(center), ^BOOL(__IsimCFNotificationObservation *o) {
        return o->observer == observer && (!n || [o->name isEqualToString:n]) && (!object || o->object == object);
    });
}
void CFNotificationCenterRemoveEveryObserver(CFNotificationCenterRef center, const void *observer) {
    if (!center) return;
    remove_matching(CENTER(center), ^BOOL(__IsimCFNotificationObservation *o) { return o->observer == observer; });
}
void CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterRef center, CFNotificationName name, const void *object,
                                                     CFDictionaryRef userInfo, CFOptionFlags options) {
    __IsimCFNotificationCenter *c = CENTER(center);
    if (!c || !name) return;
    if (c->kind == CENTER_DARWIN) { notify_post([(__bridge NSString *)name UTF8String]); return; }
    NSString *n = (__bridge NSString *)name;
    NSArray *list;
    @synchronized (c) { list = [c->observations copy]; }
    for (__IsimCFNotificationObservation *o in list) {
        if (o->name && ![o->name isEqualToString:n]) continue;
        if (o->object && o->object != object) continue;
        o->callback(center, (void *)o->observer, name, object, userInfo);
    }
}
void CFNotificationCenterPostNotification(CFNotificationCenterRef center, CFNotificationName name, const void *object,
                                          CFDictionaryRef userInfo, Boolean deliverImmediately) {
    CFNotificationCenterPostNotificationWithOptions(center, name, object, userInfo, deliverImmediately ? kCFNotificationDeliverImmediately : 0);
}
