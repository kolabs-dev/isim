/* isim Accessibility: the accessibility settings (ARC). They are the device's Settings > Accessibility values in the
   global domain (keys ISIMAnimatedImages, ISIMPrefersHorizontalText, ...; the `accessibility` script command writes them,
   UISystemIntegration.m), read like UIKit's UIAccessibility settings; a change posts the matching notification. */
#import <Accessibility/Accessibility.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework builds for iOS 15 */

extern NSDictionary *isim_global_preferences(void);       /* Foundation: the device's global domain */

NSNotificationName const AXAnimatedImagesEnabledDidChangeNotification = @"AXAnimatedImagesEnabledDidChangeNotification";
NSNotificationName const AXPrefersHorizontalTextLayoutDidChangeNotification = @"AXPrefersHorizontalTextLayoutDidChangeNotification";

static BOOL pref(NSString *key, BOOL dflt) {
    id v = isim_global_preferences()[key];
    return v ? [v boolValue] : dflt;
}
BOOL AXAnimatedImagesEnabled(void) { return pref(@"ISIMAnimatedImages", YES); }
BOOL AXPrefersHorizontalTextLayout(void) { return pref(@"ISIMPrefersHorizontalText", NO); }

/* for the Swift overlay's AccessibilitySettings: the setting behind a key (unknown keys: NO) */
BOOL isim_ax_setting(NSString *key) {
    if ([key isEqualToString:@"ISIMAnimatedImages"]) return AXAnimatedImagesEnabled();
    return pref(key, NO);
}

/* the settings with their notifications (names shared with the Swift overlay) */
static NSDictionary<NSString *, NSString *> *watched(void) {
    return @{ @"ISIMAnimatedImages": AXAnimatedImagesEnabledDidChangeNotification,
              @"ISIMPrefersHorizontalText": AXPrefersHorizontalTextLayoutDidChangeNotification,
              @"ISIMNonBlinkingCursor": @"AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification",
              @"ISIMShowBorders": @"AXShowBordersEnabledStatusDidChangeNotification",
              @"ISIMReduceHighlightingEffects": @"AXReduceHighlightingEffectsEnabledDidChangeNotification",
              @"ISIMPrefersActionSlider": @"AXPrefersActionSliderAlternativeDidChangeNotification",
              @"ISIMAssistiveAccess": @"AXAssistiveAccessEnabledDidChangeNotification" };
}
static NSDictionary *snapshot(void) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *key in watched()) d[key] = @(isim_ax_setting(key));
    return d;
}
__attribute__((constructor)) static void watch_settings(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block NSDictionary *last = snapshot();
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimGlobalPreferencesChanged" object:nil queue:nil usingBlock:^(NSNotification *n) {
            NSDictionary *now = snapshot();
            for (NSString *key in watched())
                if (![now[key] isEqual:last[key]]) [NSNotificationCenter.defaultCenter postNotificationName:watched()[key] object:nil];
            last = now;
        }];
    });
}
