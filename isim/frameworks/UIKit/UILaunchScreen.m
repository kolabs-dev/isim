/* isim UIKit (ARC): the launch screen. Like iOS, an app's launch screen is shown while it launches, then fades
 * out once the app's first screen is ready. From Info.plist:
 *   UILaunchStoryboardName (or UILaunchStoryboardName~iphone/~ipad): the storyboard's initial view controller
 *   UILaunchScreen dictionary: UIColorName (asset catalog color; default system background), UIImageName
 *     (centered), UIImageRespectsSafeAreaInsets, UINavigationBar / UITabBar / UIToolbar (empty bars, as on iOS)
 * It stays at least ISIM_LAUNCH_SCREEN_SECS seconds (default 0.25) after launch finished, in a window above the
 * app's that does not take touches. */
#import "UIKitPrivate.h"
#import <UIKit/UIStoryboard.h>
#include <stdlib.h>

@interface __IsimLaunchWindow : UIWindow @end
@implementation __IsimLaunchWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
@end

static __IsimLaunchWindow *launch_window;

static id info_value(NSDictionary *info, NSString *key) {
    BOOL pad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    return info[[key stringByAppendingString:pad ? @"~ipad" : @"~iphone"]] ?: info[key];
}

static UIView *bar_view(CGRect frame, BOOL top) {
    UIView *bar = [[UIView alloc] initWithFrame:frame];
    bar.backgroundColor = UIColor.systemBackgroundColor;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, top ? frame.size.height - 0.33 : 0, frame.size.width, 0.33)];
    line.backgroundColor = UIColor.separatorColor;
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth | (top ? UIViewAutoresizingFlexibleTopMargin : UIViewAutoresizingFlexibleBottomMargin);
    [bar addSubview:line];
    return bar;
}

static UIViewController *dictionary_launch_screen(NSDictionary *d) {
    UIViewController *vc = [UIViewController new];
    UIView *v = vc.view;
    UIColor *bg = [d[@"UIColorName"] length] ? [UIColor colorNamed:d[@"UIColorName"]] : nil;
    v.backgroundColor = bg ?: UIColor.systemBackgroundColor;
    CGRect b = UIScreen.mainScreen.bounds;
    const struct isim_device *dev = isim_ui_device();
    CGFloat top = 0, bottom = 0;
    if ([d[@"UINavigationBar"] isKindOfClass:[NSDictionary class]]) {
        top = dev->safe_top + 44;
        UIView *bar = bar_view(CGRectMake(0, 0, b.size.width, top), YES);
        bar.accessibilityIdentifier = @"launch-navigation-bar";
        [v addSubview:bar];
    }
    if ([d[@"UITabBar"] isKindOfClass:[NSDictionary class]] || [d[@"UIToolbar"] isKindOfClass:[NSDictionary class]]) {
        CGFloat h = ([d[@"UITabBar"] isKindOfClass:[NSDictionary class]] ? 49 : 44) + dev->safe_bottom;
        bottom = h;
        UIView *bar = bar_view(CGRectMake(0, b.size.height - h, b.size.width, h), NO);
        bar.accessibilityIdentifier = [d[@"UITabBar"] isKindOfClass:[NSDictionary class]] ? @"launch-tab-bar" : @"launch-toolbar";
        [v addSubview:bar];
    }
    if ([d[@"UIImageName"] length]) {
        UIImage *img = [UIImage imageNamed:d[@"UIImageName"]];
        if (img) {
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            CGRect area = b;
            if ([d[@"UIImageRespectsSafeAreaInsets"] boolValue]) area = CGRectMake(0, MAX(top, dev->safe_top), b.size.width, b.size.height - MAX(top, dev->safe_top) - MAX(bottom, dev->safe_bottom));
            iv.center = CGPointMake(CGRectGetMidX(area), CGRectGetMidY(area));
            iv.accessibilityIdentifier = @"launch-image";
            [v addSubview:iv];
        } else NSLog(@"isim: launch screen image %@ not found", d[@"UIImageName"]);
    }
    return vc;
}

void isim_ib_show_launch_screen(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSString *storyboard = info_value(info, @"UILaunchStoryboardName");
    NSDictionary *dict = info_value(info, @"UILaunchScreen");
    UIViewController *vc = nil;
    if ([storyboard isKindOfClass:[NSString class]] && storyboard.length) {
        if ([NSBundle.mainBundle pathForResource:storyboard ofType:@"storyboardc"]) {
            vc = [[UIStoryboard storyboardWithName:storyboard bundle:nil] instantiateInitialViewController];
            NSLog(@"isim: launch screen: storyboard %@", storyboard);
        } else NSLog(@"isim: launch screen storyboard %@ is not in the bundle", storyboard);
    } else if ([dict isKindOfClass:[NSDictionary class]]) {
        vc = dictionary_launch_screen(dict);
        NSLog(@"isim: launch screen: UILaunchScreen%@", dict.count ? [@" " stringByAppendingString:[[dict.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]] : @" (empty)");
    }
    if (!vc) return;
    const char *skip = getenv("ISIM_SKIP_LAUNCH_SCREEN");
    if (skip && *skip && strcmp(skip, "0")) { NSLog(@"isim: launch screen skipped"); return; }   /* tests */
    launch_window = [[__IsimLaunchWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    launch_window.windowLevel = UIWindowLevelStatusBar - 1;
    launch_window.accessibilityIdentifier = @"launch-screen";
    launch_window.rootViewController = vc;
    vc.view.frame = launch_window.bounds;
    launch_window.hidden = NO;
    isim_ui_set_needs_display();
}

void isim_ib_hide_launch_screen(void) {
    if (!launch_window) return;
    const char *e = getenv("ISIM_LAUNCH_SCREEN_SECS");
    double secs = e && *e ? atof(e) : 0.25;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(secs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = launch_window;
        isim_ui_animate(0.2, 0, UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ w.alpha = 0; }, ^(BOOL f) {
            w.hidden = YES; w.rootViewController = nil;
            if (launch_window == w) launch_window = nil;
            NSLog(@"isim: launch screen hidden");
        });
    });
}
