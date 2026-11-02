/* isim Accessibility: feature override sessions (ARC). An app with the com.apple.developer.accessibility.feature-override
   entitlement turns features on or off while a session runs: VoiceOver (isim's simulated VoiceOver), grayscale and invert
   colors (what UIAccessibilityIsGrayscaleEnabled / IsInvertColorsEnabled report, with their notifications); Zoom and
   Voice Control are recorded and logged. Ending the session (or the app quitting) restores them. Adapted: isim does not
   draw the screen in grayscale or inverted. One session at a time, as on iOS. */
#import <Accessibility/Accessibility.h>
#include <dlfcn.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework builds for iOS 15 */

NSErrorDomain const AXFeatureOverrideSessionErrorDomain = @"AXFeatureOverrideSessionErrorDomain";

@interface AXFeatureOverrideSession ()
@property (nonatomic) AXFeatureOverrideSessionOptions enabling, disabling;
@property (nonatomic, copy) NSUUID *uuid;
@property (nonatomic) BOOL ended;
@end
@implementation AXFeatureOverrideSession
- (instancetype)_isim_init { return [super init]; }
- (NSString *)description { return [NSString stringWithFormat:@"<AXFeatureOverrideSession %@>", _uuid.UUIDString]; }
@end

typedef void (*override_fn)(NSString *, int);
static void apply(NSString *feature, int state) {
    static override_fn fn;
    if (!fn) fn = (override_fn)dlsym(RTLD_DEFAULT, "isim_ui_feature_override");   /* UIKit */
    if (fn) fn(feature, state);
}
static NSString *names(AXFeatureOverrideSessionOptions o) {
    NSMutableArray *a = [NSMutableArray array];
    if (o & AXFeatureOverrideSessionOptionVoiceOver) [a addObject:@"VoiceOver"];
    if (o & AXFeatureOverrideSessionOptionZoom) [a addObject:@"Zoom"];
    if (o & AXFeatureOverrideSessionOptionGrayscale) [a addObject:@"Grayscale"];
    if (o & AXFeatureOverrideSessionOptionInvertColors) [a addObject:@"Invert Colors"];
    if (o & AXFeatureOverrideSessionOptionVoiceControl) [a addObject:@"Voice Control"];
    return a.count ? [a componentsJoinedByString:@", "] : @"nothing";
}
static void apply_options(AXFeatureOverrideSessionOptions on, AXFeatureOverrideSessionOptions off, BOOL restore) {
    struct { AXFeatureOverrideSessionOptions opt; NSString *feature; } map[] = {
        { AXFeatureOverrideSessionOptionVoiceOver, @"voiceover" }, { AXFeatureOverrideSessionOptionGrayscale, @"grayscale" },
        { AXFeatureOverrideSessionOptionInvertColors, @"invert" } };
    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++) {
        if (!((on | off) & map[i].opt)) continue;
        apply(map[i].feature, restore ? -1 : (on & map[i].opt) ? 1 : 0);
    }
}

@implementation AXFeatureOverrideSessionManager {
    AXFeatureOverrideSession *_active;
}
+ (AXFeatureOverrideSessionManager *)sharedInstance {
    static AXFeatureOverrideSessionManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[AXFeatureOverrideSessionManager alloc] _isim_init]; });
    return m;
}
- (instancetype)_isim_init { return [super init]; }
static BOOL entitled(void) {
    NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"];
    return [[NSDictionary dictionaryWithContentsOfFile:path][@"com.apple.developer.accessibility.feature-override"] boolValue];
}
static NSError *err(AXFeatureOverrideSessionError code) { return [NSError errorWithDomain:AXFeatureOverrideSessionErrorDomain code:code userInfo:nil]; }
- (AXFeatureOverrideSession *)beginOverrideSessionEnablingOptions:(AXFeatureOverrideSessionOptions)on disablingOptions:(AXFeatureOverrideSessionOptions)off error:(NSError **)error {
    if (!entitled()) {
        NSLog(@"isim: feature override session refused: the app does not have the com.apple.developer.accessibility.feature-override entitlement");
        if (error) *error = err(AXFeatureOverrideSessionErrorAppNotEntitled);
        return nil;
    }
    if (_active) { if (error) *error = err(AXFeatureOverrideSessionErrorOverrideIsAlreadyActive); return nil; }
    AXFeatureOverrideSession *s = [[AXFeatureOverrideSession alloc] _isim_init];
    s.enabling = on; s.disabling = off & ~on; s.uuid = [NSUUID UUID];
    _active = s;
    NSLog(@"isim: feature override session began: on %@; off %@", names(on), names(s.disabling));
    apply_options(s.enabling, s.disabling, NO);
    return s;
}
- (BOOL)endOverrideSession:(AXFeatureOverrideSession *)session error:(NSError **)error {
    if (!session || session != _active || session.ended) { if (error) *error = err(AXFeatureOverrideSessionErrorOverrideNotFoundForUUID); return NO; }
    session.ended = YES;
    _active = nil;
    apply_options(session.enabling, session.disabling, YES);
    NSLog(@"isim: feature override session ended: %@ restored", names(session.enabling | session.disabling));
    return YES;
}
@end
