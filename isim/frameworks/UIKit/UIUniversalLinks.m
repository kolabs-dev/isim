/* Universal links (isim).
 *
 * An http(s) URL opened in the app (script `openurl URL`, or a launch URL) is a universal link of this app when
 * its host is one of the app's associated domains — `applinks:host` / `applinks:*.host` entries of
 * com.apple.developer.associated-domains in the bundle's archived-expanded-entitlements.xcent (the entitlements
 * file Xcode's simulator builds put in the .app; `isim build` writes it from CODE_SIGN_ENTITLEMENTS) — and the
 * domain's apple-app-site-association file (AASA) gives this app the URL: the details naming the app's ID (the
 * entitlements' application-identifier, or any team with the app's bundle ID), their `components` ("/", "?", "#"
 * patterns with * and ?, substitution variables, exclude, caseSensitive, percentEncoded) or legacy `paths` ("NOT "
 * excludes), first match wins. The AASA comes from $ISIM_DATA/Library/isim/AASA/<domain>.json when there is one,
 * else from the network like iOS: Apple's CDN (https://app-site-association.cdn-apple.com/a/v1/<domain>), or the
 * domain itself (https://<domain>/.well-known/apple-app-site-association) for `?mode=developer` entries; fetched
 * once per process (3 s timeout; ISIM_AASA_FETCH=0 never fetches). A domain whose AASA cannot be had (offline) keeps
 * isim's old offline behaviour: every path opens the app (logged); a domain that answers without one (404) gives the
 * app no links, as on iOS. Under the device shell, links opened from other apps or `openurl` are first routed by the
 * home screen to the app that claims them (SpringBoard/SBSystem.m, UISystemIntegration.m, both through
 * isim_ui_app_claims_link). The link reaches the app as an NSUserActivity of type NSUserActivityTypeBrowsingWeb:
 * application(_:continue:restorationHandler:), the scene delegate's scene(_:continue:), and SwiftUI's
 * onContinueUserActivity / onOpenURL. A browser (the com.apple.developer.web-browser entitlement, like isim's
 * Safari) gets other web URLs as URLs to open; in other apps they "open in Safari" (under the shell the home screen
 * routes them there before they reach the app; with `isim run` logged, or on the host browser with
 * ISIM_OPEN_URLS=1).
 *
 * CloudKit share links (https://www.icloud.com/share/<token>, the URLs of isim's local CloudKit shares, Sharing.swift)
 * are not universal links: the token names the share's container, and the link opens the app whose container it is
 * (iCloud.<bundle ID>, or one of the entitlements' com.apple.developer.icloud-container-identifiers), which gets the
 * share's metadata (UISystemIntegration.m, isim_sys_accept_share_link). */
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

static BOOL host_matches(NSString *host, NSString *pattern) {
    host = host.lowercaseString;
    if ([pattern hasPrefix:@"*."]) {
        NSString *base = [pattern substringFromIndex:2];
        return [host isEqualToString:base] || [host hasSuffix:[@"." stringByAppendingString:base]];
    }
    return [host isEqualToString:pattern];
}

/* ---- apple-app-site-association ---- */

extern NSString *isim_data_dir(void);
static NSMutableDictionary *aasa_cache;              /* domain -> AASA dictionary, or NSNull (none on the server), or @"offline" */

/* the domain's AASA: a local file, else fetched (developer mode: from the domain, else Apple's CDN) */
static id aasa_for_domain(NSString *domain, BOOL developer) {
    @synchronized ([NSProcessInfo class]) {
        if (!aasa_cache) aasa_cache = [NSMutableDictionary dictionary];
        if (aasa_cache[domain]) return aasa_cache[domain];
    }
    id result = @"offline";
    NSString *file = [[isim_data_dir() stringByAppendingPathComponent:@"Library/isim/AASA"] stringByAppendingPathComponent:[domain stringByAppendingString:@".json"]];
    NSData *local = [NSData dataWithContentsOfFile:file];
    if (local) {
        id j = [NSJSONSerialization JSONObjectWithData:local options:0 error:NULL];
        result = [j isKindOfClass:[NSDictionary class]] ? j : [NSNull null];
        NSLog(@"isim: apple-app-site-association for %@ from %@%@", domain, file, result == [NSNull null] ? @" (not valid JSON)" : @"");
    } else if (![NSProcessInfo.processInfo.environment[@"ISIM_AASA_FETCH"] isEqualToString:@"0"]) {
        NSURL *url = [NSURL URLWithString:developer ? [NSString stringWithFormat:@"https://%@/.well-known/apple-app-site-association", domain]
                                                    : [NSString stringWithFormat:@"https://app-site-association.cdn-apple.com/a/v1/%@", domain]];
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        cfg.timeoutIntervalForRequest = 3; cfg.timeoutIntervalForResource = 3;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:nil delegateQueue:[NSOperationQueue new]];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block id fetched = @"offline";
        [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger status = [resp isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)resp).statusCode : 0;
            if (!err && status == 200) {
                id j = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
                fetched = [j isKindOfClass:[NSDictionary class]] ? j : [NSNull null];
            } else if (!err && status) fetched = [NSNull null];          /* the server answered: no AASA */
            dispatch_semaphore_signal(done);
        }] resume];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC));
        [session invalidateAndCancel];
        result = fetched;
        NSLog(@"isim: apple-app-site-association for %@ from %@: %@", domain, url.absoluteString,
              result == [NSNull null] ? @"none" : [result isKindOfClass:[NSDictionary class]] ? @"loaded" : @"unreachable");
    }
    @synchronized ([NSProcessInfo class]) { aasa_cache[domain] = result; }
    return result;
}

/* an AASA pattern as a regular expression: * any characters, ? one, $(name) one of the substitution variable's values */
static NSString *aasa_regex(NSString *pattern, NSDictionary *vars) {
    NSMutableString *re = [NSMutableString stringWithString:@"^"];
    NSUInteger i = 0, n = pattern.length;
    while (i < n) {
        unichar c = [pattern characterAtIndex:i];
        if (c == '*') { [re appendString:@".*"]; i++; continue; }
        if (c == '?') { [re appendString:@"."]; i++; continue; }
        if (c == '$' && i + 1 < n && [pattern characterAtIndex:i + 1] == '(') {
            NSRange close = [pattern rangeOfString:@")" options:0 range:NSMakeRange(i, n - i)];
            if (close.location != NSNotFound) {
                NSString *name = [pattern substringWithRange:NSMakeRange(i + 2, close.location - i - 2)];
                NSArray *values = vars[name];
                NSDictionary *builtin = @{ @"alpha": @"[A-Za-z]", @"upper": @"[A-Z]", @"lower": @"[a-z]", @"alnum": @"[A-Za-z0-9]",
                                           @"digit": @"[0-9]", @"xdigit": @"[0-9A-Fa-f]" };
                if ([values isKindOfClass:[NSArray class]]) {
                    NSMutableArray *alts = [NSMutableArray array];
                    for (id v in values) if ([v isKindOfClass:[NSString class]]) [alts addObject:[aasa_regex(v, @{}) substringFromIndex:1]];
                    [re appendFormat:@"(?:%@)", [[alts valueForKey:@"description"] componentsJoinedByString:@"|"]];
                } else if (builtin[name]) [re appendString:builtin[name]];
                else [re appendString:[NSRegularExpression escapedPatternForString:[pattern substringWithRange:NSMakeRange(i, close.location - i + 1)]]];
                i = close.location + 1;
                continue;
            }
        }
        [re appendString:[NSRegularExpression escapedPatternForString:[NSString stringWithCharacters:&c length:1]]];
        i++;
    }
    return re;
}
static BOOL aasa_match(NSString *pattern, NSString *value, NSDictionary *vars, BOOL caseSensitive) {
    if (![pattern isKindOfClass:[NSString class]]) return YES;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:[aasa_regex(pattern, vars) stringByAppendingString:@"$"]
                                                                        options:caseSensitive ? 0 : NSRegularExpressionCaseInsensitive error:NULL];
    return re && [re firstMatchInString:value ?: @"" options:0 range:NSMakeRange(0, (value ?: @"").length)] != nil;
}

/* YES / NO when a component or path of the details decides, -1 when none matches */
static int aasa_detail_decides(NSDictionary *detail, NSURL *url, NSDictionary *vars, NSDictionary *defaults) {
    NSURLComponents *uc = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSDictionary *dd = [detail[@"defaults"] isKindOfClass:[NSDictionary class]] ? detail[@"defaults"] : defaults;
    NSArray *components = detail[@"components"];
    if ([components isKindOfClass:[NSArray class]]) {
        for (NSDictionary *c in components) {
            if (![c isKindOfClass:[NSDictionary class]]) continue;
            BOOL cs = c[@"caseSensitive"] ? [c[@"caseSensitive"] boolValue] : dd[@"caseSensitive"] ? [dd[@"caseSensitive"] boolValue] : YES;
            BOOL pe = c[@"percentEncoded"] ? [c[@"percentEncoded"] boolValue] : dd[@"percentEncoded"] ? [dd[@"percentEncoded"] boolValue] : YES;
            NSString *path = (pe ? uc.percentEncodedPath : uc.path) ?: @"";
            if (!path.length) path = @"/";
            if (!aasa_match(c[@"/"], path, vars, cs)) continue;
            id q = c[@"?"];
            if ([q isKindOfClass:[NSString class]] && !aasa_match(q, (pe ? uc.percentEncodedQuery : uc.query) ?: @"", vars, cs)) continue;
            if ([q isKindOfClass:[NSDictionary class]]) {
                BOOL all = YES;
                for (NSString *k in q) {
                    NSString *v = nil; BOOL has = NO;
                    for (NSURLQueryItem *it in uc.queryItems) if ([it.name isEqualToString:k]) { has = YES; v = it.value ?: @""; break; }
                    if (!has || !aasa_match(q[k], v, vars, cs)) { all = NO; break; }
                }
                if (!all) continue;
            }
            if ([c[@"#"] isKindOfClass:[NSString class]] && !aasa_match(c[@"#"], (pe ? uc.percentEncodedFragment : uc.fragment) ?: @"", vars, cs)) continue;
            return [c[@"exclude"] boolValue] ? NO : YES;
        }
        return -1;
    }
    NSArray *paths = detail[@"paths"];                          /* the older format */
    if ([paths isKindOfClass:[NSArray class]])
        for (NSString *p in paths) {
            if (![p isKindOfClass:[NSString class]]) continue;
            BOOL not = [p hasPrefix:@"NOT "];
            if (aasa_match(not ? [p substringFromIndex:4] : p, uc.percentEncodedPath.length ? uc.percentEncodedPath : @"/", vars, YES)) return not ? NO : YES;
        }
    return -1;
}

/* YES if the app at appPath claims the https URL as a universal link (associated domain + AASA) */
BOOL isim_ui_app_claims_link(NSString *appPath, NSURL *url) {
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || !url.host) return NO;
    NSData *d = [NSData dataWithContentsOfFile:[appPath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
    id ent = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    if (![ent isKindOfClass:[NSDictionary class]]) return NO;
    NSString *matched = nil; BOOL developer = NO;
    id list = ent[@"com.apple.developer.associated-domains"];
    if ([list isKindOfClass:[NSArray class]])
        for (id e in list) {
            if (![e isKindOfClass:[NSString class]] || ![e hasPrefix:@"applinks:"]) continue;
            NSString *dom = [e substringFromIndex:9];
            NSRange q = [dom rangeOfString:@"?"];          /* applinks:host?mode=developer */
            BOOL dev = q.location != NSNotFound && [[dom substringFromIndex:q.location] containsString:@"mode=developer"];
            if (q.location != NSNotFound) dom = [dom substringToIndex:q.location];
            if (host_matches(url.host, dom.lowercaseString)) { matched = dom.lowercaseString; developer = dev; break; }
        }
    if (!matched) return NO;
    NSString *domain = [matched hasPrefix:@"*."] ? [matched substringFromIndex:2] : matched;
    id aasa = aasa_for_domain(domain, developer);
    if ([aasa isKindOfClass:[NSString class]]) {          /* offline: every path (isim's fallback) */
        static NSMutableSet *told;
        @synchronized ([NSProcessInfo class]) {
            if (!told) told = [NSMutableSet set];
            if (![told containsObject:domain]) {
                [told addObject:domain];
                NSLog(@"isim: no apple-app-site-association for %@ (offline): every path of it opens the app", domain);
            }
        }
        return YES;
    }
    if (![aasa isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *applinks = [aasa[@"applinks"] isKindOfClass:[NSDictionary class]] ? aasa[@"applinks"] : @{};
    NSDictionary *vars = [applinks[@"substitutionVariables"] isKindOfClass:[NSDictionary class]] ? applinks[@"substitutionVariables"] : @{};
    NSDictionary *defaults = [applinks[@"defaults"] isKindOfClass:[NSDictionary class]] ? applinks[@"defaults"] : @{};
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *bundle = info[@"CFBundleIdentifier"] ?: @"", *appID = [ent[@"application-identifier"] isKindOfClass:[NSString class]] ? ent[@"application-identifier"] : nil;
    for (NSDictionary *detail in [applinks[@"details"] isKindOfClass:[NSArray class]] ? applinks[@"details"] : @[]) {
        if (![detail isKindOfClass:[NSDictionary class]]) continue;
        NSMutableArray *ids = [NSMutableArray array];
        if ([detail[@"appIDs"] isKindOfClass:[NSArray class]]) [ids addObjectsFromArray:detail[@"appIDs"]];
        if ([detail[@"appID"] isKindOfClass:[NSString class]]) [ids addObject:detail[@"appID"]];
        BOOL mine = NO;
        for (NSString *i in ids)
            if ([i isKindOfClass:[NSString class]] && (appID ? [i isEqualToString:appID] : [i hasSuffix:[@"." stringByAppendingString:bundle]])) mine = YES;
        if (!mine) continue;
        int r = aasa_detail_decides(detail, url, vars, defaults);
        if (r >= 0) return r == YES;
    }
    return NO;
}

/* Shared web credentials (Security's SecAddSharedWebCredential / SecRequestSharedWebCredential): the app's
   `webcredentials:` domains (wildcards like applinks), each confirmed by its AASA's webcredentials.apps naming the app's
   ID; a domain whose AASA cannot be had (offline) is allowed, logged, like links. Returns the domains the app may use
   (all of them for fqdn nil, else the one matching fqdn, or none). */
NSArray<NSString *> *isim_ui_webcredentials_domains(NSString *fqdn) {
    NSDictionary *ent = app_entitlements();
    NSMutableArray *out = [NSMutableArray array];
    id list = ent[@"com.apple.developer.associated-domains"];
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *appID = [ent[@"application-identifier"] isKindOfClass:[NSString class]] ? ent[@"application-identifier"] : nil;
    for (id e in [list isKindOfClass:[NSArray class]] ? list : @[]) {
        if (![e isKindOfClass:[NSString class]] || ![e hasPrefix:@"webcredentials:"]) continue;
        NSString *dom = [e substringFromIndex:15];
        NSRange q = [dom rangeOfString:@"?"];
        BOOL developer = q.location != NSNotFound && [[dom substringFromIndex:q.location] containsString:@"mode=developer"];
        if (q.location != NSNotFound) dom = [dom substringToIndex:q.location];
        dom = dom.lowercaseString;
        NSString *name = fqdn ? fqdn.lowercaseString : ([dom hasPrefix:@"*."] ? [dom substringFromIndex:2] : dom);
        if (!host_matches(name, dom)) continue;
        id aasa = aasa_for_domain([dom hasPrefix:@"*."] ? [dom substringFromIndex:2] : dom, developer);
        BOOL ok = NO;
        if ([aasa isKindOfClass:[NSString class]]) {
            NSLog(@"isim: no apple-app-site-association for %@ (offline): its shared web credentials are allowed", name);
            ok = YES;
        } else if ([aasa isKindOfClass:[NSDictionary class]]) {
            NSDictionary *wc = [aasa[@"webcredentials"] isKindOfClass:[NSDictionary class]] ? aasa[@"webcredentials"] : @{};
            for (NSString *i in [wc[@"apps"] isKindOfClass:[NSArray class]] ? wc[@"apps"] : @[])
                if ([i isKindOfClass:[NSString class]] && (appID ? [i isEqualToString:appID] : [i hasSuffix:[@"." stringByAppendingString:bundle]])) ok = YES;
            if (!ok) NSLog(@"isim: the apple-app-site-association of %@ does not list this app under webcredentials", name);
        }
        if (ok && ![out containsObject:name]) [out addObject:name];
    }
    return out;
}

/* ---- CloudKit share links ---- */
/* the container a share link names (nil: not a share link) */
NSString *isim_ui_share_link_container(NSURL *url) {
    NSArray *parts = url.path.pathComponents;
    if (![url.host.lowercaseString isEqualToString:@"www.icloud.com"] || parts.count < 3 || ![parts[1] isEqualToString:@"share"]) return nil;
    NSString *b = [[parts[2] stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (b.length % 4) b = [b stringByAppendingString:@"="];
    NSData *d = [[NSData alloc] initWithBase64EncodedString:b options:0];
    NSString *token = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
    NSArray *p = [token componentsSeparatedByString:@"\x1f"];
    return p.count == 4 && [p[0] length] ? p[0] : nil;
}
/* YES if the share link names a container of the app at appPath */
BOOL isim_ui_app_owns_share_link(NSString *appPath, NSURL *url) {
    NSString *container = isim_ui_share_link_container(url);
    if (!container) return NO;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
    if ([info[@"CFBundleIdentifier"] isKindOfClass:[NSString class]] && [container isEqualToString:[@"iCloud." stringByAppendingString:info[@"CFBundleIdentifier"]]]) return YES;
    NSData *d = [NSData dataWithContentsOfFile:[appPath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
    id ent = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    id list = [ent isKindOfClass:[NSDictionary class]] ? ent[@"com.apple.developer.icloud-container-identifiers"] : nil;
    return [list isKindOfClass:[NSArray class]] && [list containsObject:container];
}

/* YES if the URL was handled as a web URL (an app link of this app, or opened "in Safari") */
BOOL isim_ui_open_web_url(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    if (isim_ui_app_owns_share_link(NSBundle.mainBundle.bundlePath, url)) {
        extern void isim_sys_accept_share_link(NSURL *url);
        isim_sys_accept_share_link(url);
        return YES;
    }
    BOOL mine = isim_ui_app_claims_link(NSBundle.mainBundle.bundlePath, url);
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
