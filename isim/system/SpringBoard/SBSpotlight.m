// isim home screen: Spotlight (pull down on the home screen, the Search button, or the script command `spotlight`).
// Searches installed apps and what apps indexed in <isim data>/Library/Spotlight/<bundle id>.plist (CoreSpotlight
// CSSearchableItems and NSUserActivity with isEligibleForSearch). Choosing an indexed item continues it in its app
// as an NSUserActivity (CSSearchableItemActionType for CoreSpotlight items), like iOS.
#import "SpringBoard.h"
#include <ctype.h>

static UIView *spot_view; static UITextField *spot_field; static UIScrollView *spot_results;

@implementation HomeViewController (Spotlight)
- (void)showSpotlight {
    if (spot_view) return;
    CGRect b = self.view.bounds; CGFloat top = self.view.safeAreaInsets.top;
    UIView *ov = [[UIView alloc] initWithFrame:b];
    ov.accessibilityIdentifier = @"spotlight";
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
    blur.frame = b; [ov addSubview:blur];
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, top + 8, b.size.width - 100, 38)];
    f.placeholder = NSLocalizedString(@"Search", nil); f.textColor = UIColor.whiteColor;
    f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18]; f.layer.cornerRadius = 10; f.font = [UIFont systemFontOfSize:17];
    f.leftView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]]; f.leftView.tintColor = [UIColor colorWithWhite:1 alpha:0.6];
    f.leftView.frame = CGRectMake(0, 0, 30, 20); f.leftView.contentMode = UIViewContentModeCenter; f.leftViewMode = UITextFieldViewModeAlways;
    f.accessibilityIdentifier = @"spotlight-field";
    [f addTarget:self action:@selector(spotlightChanged) forControlEvents:UIControlEventEditingChanged];
    [ov addSubview:f];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    [cancel setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    cancel.frame = CGRectMake(b.size.width - 80, top + 8, 70, 38); cancel.accessibilityIdentifier = @"spotlight-cancel";
    [cancel addTarget:self action:@selector(hideSpotlight) forControlEvents:UIControlEventTouchUpInside];
    [ov addSubview:cancel];
    UIScrollView *res = [[UIScrollView alloc] initWithFrame:CGRectMake(0, top + 58, b.size.width, b.size.height - top - 58)];
    [ov addSubview:res];
    spot_view = ov; spot_field = f; spot_results = res;
    [self.view addSubview:ov];
    [f becomeFirstResponder];
    [self spotlightChanged];
    NSLog(@"SpringBoard: Spotlight");
}
- (void)hideSpotlight {
    if (!spot_view) return;
    [spot_field resignFirstResponder];
    [spot_view removeFromSuperview]; spot_view = nil; spot_field = nil; spot_results = nil;
}
static BOOL matches(NSString *q, NSArray *texts) {
    for (id t in texts) if ([t isKindOfClass:[NSString class]] && [t rangeOfString:q options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}
- (UIControl *)spotRow:(NSString *)title subtitle:(NSString *)sub app:(HSApp *)a ident:(NSString *)ident y:(CGFloat)y {
    CGFloat W = spot_results.bounds.size.width;
    UIControl *row = [[UIControl alloc] initWithFrame:CGRectMake(16, y, W - 32, 56)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12]; row.layer.cornerRadius = 12;
    HSIcon *icon = [[HSIcon alloc] initWithApp:a size:38 label:NO]; icon.frame = CGRectMake(10, 9, 38, 38); icon.userInteractionEnabled = NO;
    [row addSubview:icon];
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(60, sub.length ? 8 : 0, W - 110, sub.length ? 22 : 56)];
    t.text = title; t.textColor = UIColor.whiteColor; t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium]; t.userInteractionEnabled = NO;
    [row addSubview:t];
    if (sub.length) {
        UILabel *s = [[UILabel alloc] initWithFrame:CGRectMake(60, 30, W - 110, 18)];
        s.text = sub; s.textColor = [UIColor colorWithWhite:1 alpha:0.6]; s.font = [UIFont systemFontOfSize:13]; s.userInteractionEnabled = NO;
        [row addSubview:s];
    }
    row.accessibilityIdentifier = ident;
    [spot_results addSubview:row];
    return row;
}
- (UILabel *)spotHeader:(NSString *)text y:(CGFloat)y {
    UILabel *h = [[UILabel alloc] initWithFrame:CGRectMake(20, y, spot_results.bounds.size.width - 40, 28)];
    h.text = text; h.textColor = [UIColor colorWithWhite:1 alpha:0.75]; h.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [spot_results addSubview:h];
    return h;
}
- (void)spotlightChanged {
    for (UIView *v in spot_results.subviews) [v removeFromSuperview];
    NSString *q = [spot_field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    CGFloat y = 4; NSUInteger nApps = 0, nItems = 0;
    if (!q.length) {               /* Siri Suggestions: the first apps */
        [self spotHeader:NSLocalizedString(@"Siri Suggestions", nil) y:y]; y += 32;
        NSArray *apps = self.apps; CGFloat W = spot_results.bounds.size.width, cell = (W - 32) / 4, s = self.iconSize;
        for (NSUInteger i = 0; i < MIN((NSUInteger)8, apps.count); i++) {
            HSIcon *icon = [[HSIcon alloc] initWithApp:apps[i] size:s label:YES];
            icon.frame = CGRectMake(16 + (i % 4) * cell + (cell - s) / 2, y + (i / 4) * (s + 34), s, s + 22);
            [icon addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
            [spot_results addSubview:icon];
        }
        return;
    }
    /* apps */
    NSMutableArray *apps = [NSMutableArray array];
    for (HSApp *a in self.apps) if (matches(q, @[a.name, a.bundleID])) [apps addObject:a];
    if (apps.count) {
        [self spotHeader:NSLocalizedString(@"Applications", nil) y:y]; y += 32;
        for (HSApp *a in apps) {
            UIControl *r = [self spotRow:a.name subtitle:@"" app:a ident:[@"spotlight-app-" stringByAppendingString:a.bundleID] y:y];
            r.accessibilityValue = [@"app:" stringByAppendingString:a.bundleID];
            [r addTarget:self action:@selector(spotlightChose:) forControlEvents:UIControlEventTouchUpInside];
            y += 62; nApps++;
        }
    }
    /* what apps indexed */
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Library/Spotlight"];
    for (NSString *f in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![f hasSuffix:@".plist"]) continue;
        NSString *bundle = f.stringByDeletingPathExtension;
        HSApp *app = nil; for (HSApp *a in self.apps) if ([a.bundleID isEqualToString:bundle]) app = a;
        if (!app) continue;                                    /* deleted apps' items are not shown */
        BOOL header = NO;
        for (NSDictionary *it in [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:f]][@"items"]) {
            NSMutableArray *texts = [NSMutableArray arrayWithObjects:it[@"title"] ?: @"", it[@"description"] ?: @"", nil];
            [texts addObjectsFromArray:it[@"keywords"] ?: @[]];
            if (!matches(q, texts)) continue;
            if (!header) { [self spotHeader:app.name y:y]; y += 32; header = YES; }
            /* script-friendly identifier: the item id without spaces/separators, shortened */
            NSMutableString *safe = [NSMutableString string];
            for (NSUInteger k = 0; k < [it[@"id"] length] && safe.length < 40; k++) {
                unichar ch = [it[@"id"] characterAtIndex:k];
                [safe appendFormat:@"%C", (unichar)((isalnum(ch) || ch == '-' || ch == '.') ? ch : '_')];
            }
            NSString *ident = [@"spotlight-item-" stringByAppendingString:safe];
            UIControl *r = [self spotRow:it[@"title"] ?: @"" subtitle:it[@"description"] ?: @"" app:app ident:ident y:y];
            r.accessibilityValue = [NSString stringWithFormat:@"item:%@\x1f%@", bundle, it[@"id"]];
            [r addTarget:self action:@selector(spotlightChose:) forControlEvents:UIControlEventTouchUpInside];
            y += 62; nItems++;
        }
    }
    if (!nApps && !nItems) { UILabel *l = [self spotHeader:NSLocalizedString(@"No Results", nil) y:y + 40]; l.textAlignment = NSTextAlignmentCenter; }
    spot_results.contentSize = CGSizeMake(spot_results.bounds.size.width, y + 20);
    NSLog(@"SpringBoard: Spotlight “%@”: %lu app(s), %lu item(s)", q, (unsigned long)nApps, (unsigned long)nItems);
}
- (void)spotlightChose:(UIControl *)row {
    NSString *v = row.accessibilityValue;
    if ([v hasPrefix:@"app:"]) {
        HSApp *a = [self appWithIdentifier:[v substringFromIndex:4]];
        [self hideSpotlight];
        if (a) [self launch:a];
        return;
    }
    NSArray *parts = [[v substringFromIndex:5] componentsSeparatedByString:@"\x1f"];
    HSApp *a = [self appWithIdentifier:parts[0]];
    NSDictionary *item = nil;
    NSString *file = [[isim_data_dir() stringByAppendingPathComponent:@"Library/Spotlight"] stringByAppendingPathComponent:[parts[0] stringByAppendingPathExtension:@"plist"]];
    for (NSDictionary *it in [NSDictionary dictionaryWithContentsOfFile:file][@"items"]) if ([it[@"id"] isEqual:parts[1]]) item = it;
    [self hideSpotlight];
    if (!a || !item) return;
    /* the activity to continue: the indexed NSUserActivity, or CSSearchableItemActionType for a CoreSpotlight item */
    NSDictionary *activity = [item[@"kind"] isEqual:@"activity"] ? item[@"activity"]
        : @{ @"activityType": @"com.apple.corespotlightitem", @"title": item[@"title"] ?: @"",
             @"userInfo": @{ @"kCSSearchableItemActivityIdentifier": item[@"id"] ?: @"" } };
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Library/isim/Activities"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *path = [dir stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"plist"]];
    [activity writeToFile:path atomically:YES];
    NSLog(@"SpringBoard: Spotlight continues %@ in %@", activity[@"activityType"], a.name);
    [self launch:a url:[@"isim-activity:" stringByAppendingString:path]];
}
@end
