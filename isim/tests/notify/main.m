// Darwin notifications across processes (NotifyTest.app, issue #263): test_notify.py runs it twice on one device.
//   listen   registers notify(3) clients and a Darwin CFNotificationCenter observer, says "listening", waits for the
//            other process's posts, then answers with its own post
//   post     posts until the listener answers
//   local    the in-process API: CFNotificationCenter's local and Darwin centers, notify(3) keys and statuses
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <notify.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int checks, failures;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

/* runs the main run loop (main-queue callbacks) until done() or the timeout */
static BOOL wait_for(BOOL (^done)(void), double seconds) {
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent() + seconds;
    while (!done() && CFAbsoluteTimeGetCurrent() < end) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
    return done();
}

static int cf_calls;
static const void *cf_last_object;
static void on_cf(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo) {
    cf_calls++;
    cf_last_object = object;
    printf("cf notification %s (observer %s)\n", CFStringGetCStringPtr(name, kCFStringEncodingUTF8) ?: [(__bridge NSString *)name UTF8String],
           observer ? (const char *)observer : "-");
}

static void listen(void) {
    __block int pings = 0;
    int ping, check;
    CHECK(notify_register_dispatch("dev.isim.notify.ping", &ping, dispatch_get_main_queue(), ^(int t) { pings++; }) == NOTIFY_STATUS_OK);
    CHECK(notify_register_check("dev.isim.notify.ping", &check) == NOTIFY_STATUS_OK);
    int flag = 0;
    notify_check(check, &flag);                                    // the first check reports a change
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), "listener", on_cf, CFSTR("dev.isim.notify.cf"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    printf("listening\n");
    fflush(stdout);
    CHECK(wait_for(^{ return (BOOL)(pings > 0 && cf_calls > 0); }, 30));     // from the other process
    CHECK(notify_check(check, &flag) == NOTIFY_STATUS_OK && flag == 1);
    printf("received %d ping(s), %d cf notification(s)\n", pings, cf_calls);
    notify_post("dev.isim.notify.pong");
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), "listener");
}

static void post(void) {
    __block BOOL pong = NO;
    int token;
    CHECK(notify_register_dispatch("dev.isim.notify.pong", &token, dispatch_get_main_queue(), ^(int t) { pong = YES; }) == NOTIFY_STATUS_OK);
    CHECK(wait_for(^BOOL{
        notify_post("dev.isim.notify.ping");
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("dev.isim.notify.cf"), NULL, NULL, true);
        return pong;
    }, 30));
    printf("pong received\n");
}

static void local(void) {
    // the local center: name and object filters, every observer of a name, removal
    CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
    CHECK(center == CFNotificationCenterGetLocalCenter() && CFGetTypeID(center) == CFNotificationCenterGetTypeID());
    static int tag;
    CFNotificationCenterAddObserver(center, "a", on_cf, CFSTR("dev.isim.local"), &tag, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, "b", on_cf, NULL, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);   // every name
    cf_calls = 0;
    CFNotificationCenterPostNotification(center, CFSTR("dev.isim.local"), &tag, NULL, true);
    CHECK(cf_calls == 2 && cf_last_object == &tag);
    cf_calls = 0;
    CFNotificationCenterPostNotification(center, CFSTR("dev.isim.local"), NULL, NULL, true);   // another object: only "b"
    CHECK(cf_calls == 1);
    CFNotificationCenterRemoveObserver(center, "b", NULL, NULL);
    cf_calls = 0;
    CFNotificationCenterPostNotificationWithOptions(center, CFSTR("dev.isim.other"), NULL, NULL, kCFNotificationDeliverImmediately);
    CHECK(cf_calls == 0);
    CFNotificationCenterRemoveEveryObserver(center, "a");
    // the Darwin center within the process: a main-queue callback, no object
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, "d", on_cf, CFSTR("dev.isim.darwin"), &tag, CFNotificationSuspensionBehaviorCoalesce);
    cf_calls = 0; cf_last_object = &tag;
    CFNotificationCenterPostNotification(darwin, CFSTR("dev.isim.darwin"), &tag, NULL, true);
    CHECK(wait_for(^{ return (BOOL)(cf_calls == 1); }, 5) && cf_last_object == NULL);
    CFNotificationCenterRemoveObserver(darwin, "d", CFSTR("dev.isim.darwin"), NULL);
    CFNotificationCenterPostNotification(darwin, CFSTR("dev.isim.darwin"), NULL, NULL, true);
    wait_for(^{ return NO; }, 0.2);
    CHECK(cf_calls == 1);                                           // removed: no more callbacks
    // notify(3) extras
    int token;
    CHECK(notify_register_mach_port("dev.isim.port", NULL, 0, &token) == NOTIFY_STATUS_FAILED);
    CHECK(!strcmp(kNotifyTimeZoneChange, "com.apple.system.timezone") && NOTIFY_TOKEN_INVALID == -1 && !notify_is_valid_token(12345));
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        const char *role = argc > 1 ? argv[1] : "local";
        if (!strcmp(role, "listen")) listen();
        else if (!strcmp(role, "post")) post();
        else local();
        printf("notify test (%s): %d/%d passed\n", role, checks - failures, checks);
        return failures ? 1 : 0;
    }
}
