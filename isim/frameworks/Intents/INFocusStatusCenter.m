/* isim Intents: INFocusStatusCenter (ARC). Adapted: the Focus the shell keeps in <ISIM_DATA>/Library/isim/Focus/Current
   (shell_controls.inc); the app's permission in its defaults, asked with an alert like iOS. */
#import <Intents/Intents.h>
#import <UIKit/UIKit.h>
#include <objc/message.h>

static NSString *const kAuthKey = @"_ISIMFocusStatusAuthorization";

@implementation INFocusStatus
- (instancetype)initWithIsFocused:(NSNumber *)isFocused { if ((self = [super init])) _isFocused = [isFocused copy]; return self; }
- (id)copyWithZone:(NSZone *)zone { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_isFocused forKey:@"isFocused"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithIsFocused:[c decodeObjectOfClass:[NSNumber class] forKey:@"isFocused"]]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[INFocusStatus class]] && (_isFocused == ((INFocusStatus *)o).isFocused || [_isFocused isEqual:((INFocusStatus *)o).isFocused]); }
- (NSUInteger)hash { return _isFocused.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<INFocusStatus isFocused=%@>", _isFocused ?: @"nil"]; }
@end

@implementation INFocusStatusCenter
+ (INFocusStatusCenter *)defaultCenter { static INFocusStatusCenter *c; static dispatch_once_t once; dispatch_once(&once, ^{ c = [INFocusStatusCenter new]; }); return c; }
- (INFocusStatusAuthorizationStatus)authorizationStatus { return [NSUserDefaults.standardUserDefaults integerForKey:kAuthKey]; }
- (INFocusStatus *)focusStatus {
    if (self.authorizationStatus != INFocusStatusAuthorizationStatusAuthorized) return [[INFocusStatus alloc] initWithIsFocused:nil];
    const char *d = getenv("ISIM_DATA");
    NSString *cur = d && *d ? [NSString stringWithContentsOfFile:[@(d) stringByAppendingPathComponent:@"Library/isim/Focus/Current"] encoding:NSUTF8StringEncoding error:NULL] : nil;
    cur = [cur stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [[INFocusStatus alloc] initWithIsFocused:@(cur.length > 0 && ![cur isEqualToString:@"off"])];
}
- (void)requestAuthorizationWithCompletionHandler:(void (^)(INFocusStatusAuthorizationStatus))completion {
    void (^done)(INFocusStatusAuthorizationStatus) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        INFocusStatusAuthorizationStatus s = self.authorizationStatus;
        void (^answer)(BOOL) = ^(BOOL ok) {
            INFocusStatusAuthorizationStatus r = ok ? INFocusStatusAuthorizationStatusAuthorized : INFocusStatusAuthorizationStatusDenied;
            [NSUserDefaults.standardUserDefaults setInteger:r forKey:kAuthKey];
            NSLog(@"isim Intents: Focus status %@", ok ? @"shared" : @"not shared");
            if (done) dispatch_async(dispatch_get_global_queue(0, 0), ^{ done(r); });
        };
        if (s != INFocusStatusAuthorizationStatusNotDetermined) { if (done) dispatch_async(dispatch_get_global_queue(0, 0), ^{ done(s); }); return; }
        const char *env = getenv("ISIM_FOCUS_STATUS_PERMISSION");
        if (env && *env) { answer(!strcmp(env, "allow") || !strcmp(env, "1")); return; }
        UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController ?: UIApplication.sharedApplication.windows.firstObject.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (!top) { answer(NO); return; }
        NSDictionary *info = NSBundle.mainBundle.infoDictionary;
        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"App";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Allow “%@” to Access Your Focus Status?", name]
            message:info[@"NSFocusStatusUsageDescription"] ?: @"" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { answer(NO); }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { answer(YES); }]];
        SEL mark = NSSelectorFromString(@"_isim_markSystemAlert");
        if ([alert respondsToSelector:mark]) ((void (*)(id, SEL))objc_msgSend)(alert, mark);
        [top presentViewController:alert animated:YES completion:nil];
    });
}
@end
