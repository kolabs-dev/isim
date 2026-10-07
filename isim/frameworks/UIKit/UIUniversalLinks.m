/* Universal links (isim, local simulation).
 *
 * An http(s) URL opened in the app (script `openurl URL`, or a launch URL) is a universal link of this app when
 * its host is one of the app's associated domains: `applinks:host` / `applinks:*.host` entries of
 * com.apple.developer.associated-domains in the bundle's archived-expanded-entitlements.xcent (the entitlements
 * file Xcode's simulator builds put in the .app). isim does not fetch apple-app-site-association files, so every
 * path of a declared domain opens the app. The link reaches the app as an NSUserActivity of type
 * NSUserActivityTypeBrowsingWeb: application(_:continue:restorationHandler:), the scene delegate's
 * scene(_:continue:), and SwiftUI's onContinueUserActivity / onOpenURL. Other web URLs "open in Safari"
 * (logged; on the host browser with ISIM_OPEN_URLS=1). */
#import "UIKitPrivate.h"

static NSArray<NSString *> *app_link_domains(void) {
    static NSArray *domains;
    if (domains) return domains;
    NSMutableArray *out = [NSMutableArray array];
    NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"];
    NSData *d = [NSData dataWithContentsOfFile:path];
    NSDictionary *ent = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    id list = [ent isKindOfClass:[NSDictionary class]] ? ent[@"com.apple.developer.associated-domains"] : nil;
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
    if (!mine) {
        BOOL host = isim_open_url(url.absoluteString.UTF8String);
        NSLog(@"isim: %@ is not a universal link of this app: opened in Safari%@", url.absoluteString,
              host ? @" (on the host)" : @" (not shown; ISIM_OPEN_URLS=1 opens it on the host)");
        return YES;
    }
    NSLog(@"isim: universal link %@ -> this app (NSUserActivityTypeBrowsingWeb)", url.absoluteString);
    NSUserActivity *act = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    act.webpageURL = url;
    UIApplication *app = UIApplication.sharedApplication;
    id<UIApplicationDelegate> d = app.delegate;
    BOOL taken = NO;
    for (UIScene *s in app.connectedScenes) {
        id<UISceneDelegate> sd = s.delegate;
        if ([sd respondsToSelector:@selector(scene:willContinueUserActivityWithType:)]) [sd scene:s willContinueUserActivityWithType:act.activityType];
        if ([sd respondsToSelector:@selector(scene:continueUserActivity:)]) { [sd scene:s continueUserActivity:act]; taken = YES; }
    }
    if (!taken) {
        if ([d respondsToSelector:@selector(application:willContinueUserActivityWithType:)]) [d application:app willContinueUserActivityWithType:act.activityType];
        if ([d respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)])
            [d application:app continueUserActivity:act restorationHandler:^(NSArray *objects) {}];
    }
    /* SwiftUI: onContinueUserActivity(NSUserActivityTypeBrowsingWeb), else onOpenURL */
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimContinueUserActivity" object:act];
    return YES;
}
