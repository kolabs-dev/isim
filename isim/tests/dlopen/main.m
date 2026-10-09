// Runtime loading self-test for isim: dlopen / dlsym / dlerror / dladdr / dlopen_preflight of frameworks, dylibs and
// bundles embedded in the app but not linked by it (@rpath, @executable_path, @loader_path, absolute paths,
// RTLD_NOLOAD, RTLD_FIRST, RTLD_MAIN_ONLY, RTLD_NEXT), what a loaded image brings (initializers, +load, categories,
// thread-local variables, its own dependencies, Swift code) and NSBundle's code loading (load, isLoaded,
// principalClass, classNamed:, allFrameworks, bundleWithIdentifier:, loadAndReturnError:). A framework whose
// dependency is missing fails to load without ending the app. Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <string.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

int main_marker(void) { return 1; }                       // exported by the executable (RTLD_MAIN_ONLY)
static int added_images;
static void on_add_image(const struct mach_header *mh, intptr_t slide) { added_images++; }

static NSString *frameworks(void) { return NSBundle.mainBundle.privateFrameworksPath; }
static BOOL contains(const char *s, const char *part) { return s && strstr(s, part) != NULL; }

static int *main_tls;                                     // the main thread's copy (a thread's copy dies with it)
static void *tls_thread(void *arg) { int *(*addr)(void) = arg; return (void *)(intptr_t)(addr() != main_tls ? *addr() : -1); }

static void testDlopen(void) {
    _dyld_register_func_for_add_image(on_add_image);
    int before = added_images;

    // not loaded yet: RTLD_NOLOAD finds nothing, the symbols are not visible
    CHECK(dlopen("@rpath/ObjCPlugin.framework/ObjCPlugin", RTLD_NOLOAD) == NULL);
    CHECK(dlsym(RTLD_DEFAULT, "plugin_value") == NULL);
    CHECK(NSClassFromString(@"ObjCPluginPrincipal") == Nil);

    // @rpath (the executable's LC_RPATH @executable_path/Frameworks) loads the framework and its own dependency
    void *h = dlopen("@rpath/ObjCPlugin.framework/ObjCPlugin", RTLD_NOW);
    CHECK(h != NULL);
    if (!h) { printf("dlerror: %s\n", dlerror()); return; }
    CHECK(added_images - before == 2);                    // ObjCPlugin + libPluginHelper.dylib
    int (*value)(void) = (int (*)(void))dlsym(h, "plugin_value");
    CHECK(value && value() == 42);
    int *runs = dlsym(h, "plugin_constructor_runs");
    CHECK(runs && *runs == 1);                             // initializers ran once
    CHECK(dlsym(h, "helper_value") != NULL);               // a handle also searches its dependencies
    CHECK(dlsym(RTLD_DEFAULT, "plugin_value") == (void *)value);
    CHECK(dlsym(RTLD_MAIN_ONLY, "plugin_value") == NULL);
    CHECK(dlsym(RTLD_MAIN_ONLY, "main_marker") == (void *)main_marker);
    CHECK(dlsym(h, "no_such_symbol") == NULL && contains(dlerror(), "no_such_symbol"));
    CHECK(dlerror() == NULL);                              // dlerror clears the error

    // the same image under other spellings: one handle, no second load
    NSString *abs = [frameworks() stringByAppendingPathComponent:@"ObjCPlugin.framework/ObjCPlugin"];
    CHECK(dlopen(abs.UTF8String, RTLD_NOW) == h);
    CHECK(dlopen("@executable_path/Frameworks/ObjCPlugin.framework/ObjCPlugin", RTLD_LAZY) == h);
    CHECK(dlopen("@loader_path/Frameworks/ObjCPlugin.framework/ObjCPlugin", RTLD_LAZY) == h);   // loader = this executable
    CHECK(dlopen("@rpath/ObjCPlugin.framework/ObjCPlugin", RTLD_NOLOAD) == h);
    CHECK(*runs == 1 && added_images - before == 2);
    CHECK(dlclose(h) == 0);
    CHECK(dlopen("@rpath/ObjCPlugin.framework/ObjCPlugin", RTLD_NOLOAD) == h);   // images stay loaded

    // Objective-C: classes, +load, categories from the loaded image
    Class principal = NSClassFromString(@"ObjCPluginPrincipal");
    CHECK(principal != Nil);
    CHECK(((int (*)(id, SEL))objc_msgSend)(principal, @selector(loads)) == 1);
    CHECK([@"abc" respondsToSelector:NSSelectorFromString(@"plugin_shout")]);
    NSString *(*shout)(id, SEL) = (NSString *(*)(id, SEL))objc_msgSend;
    CHECK([shout(@"abc", NSSelectorFromString(@"plugin_shout")) isEqualToString:@"ABC"]);

    // thread-local variables of the loaded image: one copy per thread
    int *(*tls)(void) = (int *(*)(void))dlsym(h, "plugin_tls_address");
    CHECK(tls && *tls() == 5);
    *tls() = 9;
    main_tls = tls();
    pthread_t t; void *other = NULL;
    pthread_create(&t, NULL, tls_thread, (void *)tls); pthread_join(t, &other);
    CHECK((intptr_t)other == 5 && *tls() == 9);

    // dladdr names the framework's file and symbol
    Dl_info di;
    CHECK(dladdr((void *)value, &di) && contains(di.dli_fname, "ObjCPlugin.framework/ObjCPlugin") && di.dli_sname && !strcmp(di.dli_sname, "plugin_value"));

    // RTLD_FIRST: only the image itself
    void *hf = dlopen("@rpath/libPluginHelper.dylib", RTLD_NOW | RTLD_FIRST);
    CHECK(hf != NULL && dlsym(hf, "helper_value") != NULL && dlsym(hf, "malloc") == NULL);
    CHECK(dlsym(h, "malloc") != NULL);                     // without RTLD_FIRST, dependencies (libSystem) count

    // RTLD_NEXT from the executable: images loaded after it (libSystem's malloc), never the executable's own
    CHECK(dlsym(RTLD_NEXT, "malloc") != NULL && dlsym(RTLD_NEXT, "main_marker") == NULL);

    // failures: a missing file, a framework whose dependency is missing (the app keeps running), preflight
    CHECK(dlopen("@rpath/Nope.framework/Nope", RTLD_NOW) == NULL);
    const char *e = dlerror();
    CHECK(contains(e, "Nope.framework") && contains(e, "no such file"));
    CHECK(!dlopen_preflight([frameworks() stringByAppendingPathComponent:@"Broken.framework/Broken"].UTF8String));
    CHECK(dlopen("@rpath/Broken.framework/Broken", RTLD_NOW) == NULL);
    e = dlerror();
    CHECK(contains(e, "Library not loaded: @rpath/libMissing.dylib"));
    CHECK(dlsym(RTLD_DEFAULT, "broken_value") == NULL);
    CHECK(dlopen_preflight("@rpath/SwiftPlugin.framework/SwiftPlugin"));
    CHECK(dlsym(RTLD_DEFAULT, "swift_plugin_value") == NULL);   // preflight does not load
}

static void testBundles(void) {
    NSBundle *main = NSBundle.mainBundle;
    CHECK([main.privateFrameworksPath hasSuffix:@"DlopenTest.app/Frameworks"]);
    CHECK([main.builtInPlugInsPath hasSuffix:@"DlopenTest.app/PlugIns"]);
    CHECK(main.isLoaded);

    // a framework loaded by dlopen above: its bundle, resources, principal class
    NSBundle *plugin = [NSBundle bundleWithPath:[frameworks() stringByAppendingPathComponent:@"ObjCPlugin.framework"]];
    CHECK(plugin.isLoaded);
    CHECK([plugin.bundleIdentifier isEqualToString:@"dev.kolabs.isim.dlopen-test.objc-plugin"]);
    CHECK(plugin.principalClass == NSClassFromString(@"ObjCPluginPrincipal"));
    CHECK([plugin classNamed:@"ObjCPluginOther"] != Nil && [plugin classNamed:@"NSObject"] == Nil);
    NSString *(*message)(id, SEL) = (NSString *(*)(id, SEL))objc_msgSend;
    CHECK([message([plugin.principalClass new], NSSelectorFromString(@"greeting")) isEqualToString:@"hello from the plug-in"]);
    CHECK([[NSBundle bundleForClass:plugin.principalClass].bundlePath isEqualToString:plugin.bundlePath]);
    CHECK([[NSBundle bundleWithIdentifier:@"dev.kolabs.isim.dlopen-test.objc-plugin"].bundlePath isEqualToString:plugin.bundlePath]);
    BOOL listed = NO;
    for (NSBundle *b in NSBundle.allFrameworks) if ([b.bundlePath isEqualToString:plugin.bundlePath]) listed = YES;
    CHECK(listed);

    // a .bundle in PlugIns: not loaded until -load; principal class = its first class
    NSBundle *extra = [NSBundle bundleWithPath:[main.builtInPlugInsPath stringByAppendingPathComponent:@"Extra.bundle"]];
    CHECK(extra && !extra.isLoaded && NSClassFromString(@"ExtraFirst") == Nil);
    NSError *err = nil;
    CHECK([extra preflightAndReturnError:&err] && !extra.isLoaded);
    CHECK([extra loadAndReturnError:&err] && extra.isLoaded);
    Class first = extra.principalClass;
    CHECK(first == NSClassFromString(@"ExtraFirst") && ((int (*)(id, SEL))objc_msgSend)([first new], @selector(answer)) == 7);
    CHECK([extra unload] == NO && extra.isLoaded);
    listed = NO;
    for (NSBundle *b in NSBundle.allBundles) if ([b.bundlePath isEqualToString:extra.bundlePath]) listed = YES;
    CHECK(listed);

    // a Swift framework through NSBundle: Swift classes, metadata and conformances of a loaded image
    NSBundle *swiftPlugin = [NSBundle bundleWithPath:[frameworks() stringByAppendingPathComponent:@"SwiftPlugin.framework"]];
    CHECK([swiftPlugin load]);
    Class entry = swiftPlugin.principalClass;
    CHECK(entry == NSClassFromString(@"SwiftPluginEntry"));
    NSString *described = message([entry new], NSSelectorFromString(@"describe"));
    CHECK([described isEqualToString:@"Square 9.0 true dev.kolabs.isim.dlopen-test.swift-plugin"]);
    long (*swiftValue)(void) = (long (*)(void))dlsym(RTLD_DEFAULT, "swift_plugin_value");
    CHECK(swiftValue && swiftValue() == 42);

    // a framework that cannot load: NO and an NSError, the app continues
    NSBundle *broken = [NSBundle bundleWithPath:[frameworks() stringByAppendingPathComponent:@"Broken.framework"]];
    err = nil;
    CHECK(![broken loadAndReturnError:&err] && !broken.isLoaded);
    CHECK([err.domain isEqualToString:NSCocoaErrorDomain] && err.code == 3587);
    CHECK([err.userInfo[NSDebugDescriptionErrorKey] containsString:@"libMissing.dylib"]);
    CHECK(broken.principalClass == Nil);
    NSBundle *gone = [NSBundle bundleWithPath:[frameworks() stringByAppendingPathComponent:@"NoExecutable.framework"]];
    err = nil;
    CHECK(gone && ![gone loadAndReturnError:&err] && err.code == 4);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        testDlopen();
        testBundles();
        NSLog(@"dlopen test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
