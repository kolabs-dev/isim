/* isim Foundation (ARC): Objective-C classes that Foundation's Swift overlay defines (the URL loading system:
 * NSURLSession, NSURLRequest, NSURLComponents, NSHTTPCookie, ...). Their headers mark them objc_runtime_visible, so
 * Objective-C code finds them with objc_lookUpClass instead of a linker symbol; an app without Swift has not loaded
 * the overlay, so the first lookup of one of these names loads it (libswiftFoundation and the Swift runtime). */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <string.h>

static objc_hook_getClass previous_hook;
static const char *const swift_classes[] = {
    "NSURLSession", "NSURLSessionConfiguration", "NSURLSessionTask", "NSURLSessionDataTask", "NSURLSessionUploadTask",
    "NSURLSessionDownloadTask",
    "NSURLRequest", "NSMutableURLRequest", "NSURLResponse", "NSHTTPURLResponse", "NSURLComponents", "NSURLQueryItem",
    "NSHTTPCookie", "NSHTTPCookieStorage", "NSURLCache", "NSCachedURLResponse", "NSURLCredential", "NSURLCredentialStorage",
    "NSURLProtectionSpace", "NSURLAuthenticationChallenge",
};

static BOOL load_overlay(void) {
    static dispatch_once_t once;
    static BOOL loaded;
    dispatch_once(&once, ^{
        loaded = dlopen("/usr/lib/swift/libswiftFoundation.dylib", RTLD_NOW | RTLD_GLOBAL) != NULL;
        if (!loaded) NSLog(@"isim: Foundation could not load its Swift overlay for the URL loading classes: %s", dlerror());
    });
    return loaded;
}

static BOOL lazy_swift_class(const char *name, Class _Nullable *outClass) {
    if (previous_hook(name, outClass)) return YES;
    for (size_t i = 0; i < sizeof swift_classes / sizeof *swift_classes; i++)
        if (!strcmp(name, swift_classes[i])) {
            if (!load_overlay()) return NO;
            return previous_hook(name, outClass);      /* registered by the overlay's image now */
        }
    return NO;
}

__attribute__((constructor)) static void install_swift_class_hook(void) {
    objc_setHook_getClass(lazy_swift_class, &previous_hook);
}
