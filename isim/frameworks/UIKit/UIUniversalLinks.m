/* Universal links (isim, local simulation).
 *
 * An http(s) URL opened in the app (script `openurl URL`, or a launch URL) is a universal link of this app when
 * its host is one of the app's associated domains: `applinks:host` / `applinks:*.host` entries of
 * com.apple.developer.associated-domains in the bundle's archived-expanded-entitlements.xcent (the entitlements
 * file Xcode's simulator builds put in the .app; `isim build` writes it from CODE_SIGN_ENTITLEMENTS). Under the
 * device shell, links opened from other apps or `openurl` are first routed by the home screen to the app that
 * claims the domain (SpringBoard/SBSystem.m, UISystemIntegration.m). isim does not fetch apple-app-site-association files, so every
 * path of a declared domain opens the app. The link reaches the app as an NSUserActivity of type
 * NSUserActivityTypeBrowsingWeb: application(_:continue:restorationHandler:), the scene delegate's
 * scene(_:continue:), and SwiftUI's onContinueUserActivity / onOpenURL. A browser (the com.apple.developer.web-browser
 * entitlement, like isim's Safari) gets other web URLs as URLs to open; in other apps they "open in Safari" (under the
 * shell the home screen routes them there before they reach the app; with `isim run` logged, or on the host browser
 * with ISIM_OPEN_URLS=1). */
#import "UIKitPrivate.h"

static NSDictionary *app_entitlements(void) {
    static NSDictionary *ent;
    if (ent) return ent;
    NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"];
    NSData *d = [NSData dataWithContentsOfFile:path];
    id e = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    ent = [e isKindOfClass:[NSDictionary class]] ? e : @{};
    return ent;
}

static NSArray<NSString *> *app_link_domains(void) {
    static NSArray *domains;
    if (domains) return domains;
    NSMutableArray *out = [NSMutableArray array];
    id list = app_entitlements()[@"com.apple.developer.associated-domains"];
    if ([list isKindOfClass:[NSArray class]])
        for (id e in list) {
            if (![e isKindOfClass:[NSString class]] || ![e hasPrefix:@"applinks:"]) continue;
            NSString *dom = [e substringFromIndex:9];
            NSRange q = [dom rangeOfString:@"?"];          /* applinks:host?mode=developer */
            if (q.location != NSNotFound) dom = [dom substringToIndex:q.location];
            [out addObject:dom.lowercaseString];
        }
    domains = [out copy];
    return domains;
}

static BOOL host_matches(NSString *host, NSString *pattern) {
    host = host.lowercaseString;
    if ([pattern hasPrefix:@"*."]) {
        NSString *base = [pattern substringFromIndex:2];
        return [host isEqualToString:base] || [host hasSuffix:[@"." stringByAppendingString:base]];
    }
    return [host isEqualToString:pattern];
}

/* YES if the URL was handled as a web URL (an app link of this app, or opened "in Safari") */
BOOL isim_ui_open_web_url(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    BOOL mine = NO;
    if ([scheme isEqualToString:@"https"] && url.host)
        for (NSString *d in app_link_domains()) if (host_matches(url.host, d)) { mine = YES; break; }
    if (!mine && [app_entitlements()[@"com.apple.developer.web-browser"] boolValue]) return NO;   /* a browser (isim's Safari): application(_:open:options:) */
    if (!mine) {
        BOOL host = isim_open_url(url.absoluteString.UTF8String);
        NSLog(@"isim: %@ is not a universal link of this app: opened in Safari%@", url.absoluteString,
              host ? @" (on the host)" : @" (not shown; ISIM_OPEN_URLS=1 opens it on the host)");
        return YES;
    }
    NSLog(@"isim: universal link %@ -> this app (NSUserActivityTypeBrowsingWeb)", url.absoluteString);
    NSUserActivity *act = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    act.webpageURL = url;
    /* scene / app delegates, SwiftUI onContinueUserActivity (else onOpenURL): UISystemIntegration.m */
    extern void isim_sys_continue_activity(NSUserActivity *a);
    isim_sys_continue_activity(act);
    return YES;
}
