// HelloKeychainObjC: the keychain from Objective-C and C (issue #228): SecItemAdd / SecItemCopyMatching /
// SecItemUpdate / SecItemDelete with kSecClassGenericPassword items, results as data, attributes and arrays,
// duplicates and missing items, SecCopyErrorMessageString, and an item protected by SecAccessControl
// (biometryCurrentSet) whose data asks for Face ID when it is read. Logs "kc ..." lines.
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#include <stdio.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("kc %s\n", s.UTF8String);
    fflush(stdout);
}

static NSDictionary *base(NSString *account) {
    return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: @"dev.isim.keychain-objc",
             (__bridge id)kSecAttrAccount: account};
}
static NSDictionary *with(NSDictionary *d, NSDictionary *more) { NSMutableDictionary *m = [d mutableCopy]; [m addEntriesFromDictionary:more]; return m; }
static NSString *string(CFTypeRef data) {
    return data && CFGetTypeID(data) == CFDataGetTypeID() ? [[NSString alloc] initWithData:(__bridge NSData *)data encoding:NSUTF8StringEncoding] : @"-";
}

static void basics(void) {
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword});   // a clean start
    NSData *secret = [@"hunter2" dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus s = SecItemAdd((__bridge CFDictionaryRef)with(base(@"alice"), @{(__bridge id)kSecValueData: secret,
                                                                              (__bridge id)kSecAttrLabel: @"Alice's password"}), NULL);
    OSStatus dup = SecItemAdd((__bridge CFDictionaryRef)with(base(@"alice"), @{(__bridge id)kSecValueData: secret}), NULL);
    SecItemAdd((__bridge CFDictionaryRef)with(base(@"bob"), @{(__bridge id)kSecValueData: [@"swordfish" dataUsingEncoding:NSUTF8StringEncoding]}), NULL);
    say(@"add %d duplicate %d", (int)s, (int)dup);

    CFTypeRef data = NULL;
    s = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"alice"), @{(__bridge id)kSecReturnData: @YES,
                                                                              (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne}), &data);
    say(@"read %d %@", (int)s, string(data));
    if (data) CFRelease(data);

    CFTypeRef all = NULL;
    s = SecItemCopyMatching((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                                        (__bridge id)kSecAttrService: @"dev.isim.keychain-objc",
                                                        (__bridge id)kSecReturnAttributes: @YES,
                                                        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll}, &all);
    NSArray *items = (__bridge_transfer NSArray *)all;
    NSArray *accounts = [[items valueForKey:(__bridge NSString *)kSecAttrAccount] sortedArrayUsingSelector:@selector(compare:)];
    NSDictionary *alice = nil;
    for (NSDictionary *d in items) if ([d[(__bridge id)kSecAttrAccount] isEqual:@"alice"]) alice = d;
    say(@"all %d %@ label=%@ created=%d", (int)s, [accounts componentsJoinedByString:@","], alice[(__bridge id)kSecAttrLabel],
        [alice[(__bridge id)kSecAttrCreationDate] isKindOfClass:[NSDate class]]);

    s = SecItemUpdate((__bridge CFDictionaryRef)base(@"alice"),
                      (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: [@"correct horse" dataUsingEncoding:NSUTF8StringEncoding]});
    data = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"alice"), @{(__bridge id)kSecReturnData: @YES}), &data);
    say(@"update %d %@", (int)s, string(data));
    if (data) CFRelease(data);

    s = SecItemDelete((__bridge CFDictionaryRef)base(@"bob"));
    OSStatus missing = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"bob"), @{(__bridge id)kSecReturnData: @YES}), NULL);
    CFStringRef msg = SecCopyErrorMessageString(missing, NULL);
    say(@"delete %d then %d \"%@\"", (int)s, (int)missing, (__bridge NSString *)msg);
    if (msg) CFRelease(msg);
    say(@"constants %d %d", CFEqual(kSecClassGenericPassword, CFSTR("genp")), CFEqual(kSecMatchLimitAll, CFSTR("m_LimitAll")));
}

static void addProtected(void) {
    CFErrorRef err = NULL;
    SecAccessControlRef ac = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                             kSecAccessControlBiometryCurrentSet, &err);
    OSStatus s = SecItemAdd((__bridge CFDictionaryRef)with(base(@"vault"), @{(__bridge id)kSecValueData: [@"open sesame" dataUsingEncoding:NSUTF8StringEncoding],
                                                                              (__bridge id)kSecAttrAccessControl: (__bridge id)ac}), NULL);
    say(@"protected add %d typeid=%d", (int)s, CFGetTypeID(ac) == SecAccessControlGetTypeID());
    CFRelease(ac);
    // without user interaction: refused, or the item is skipped; its attributes need no authentication
    OSStatus fail = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"vault"), @{(__bridge id)kSecReturnData: @YES,
                                        (__bridge id)kSecUseAuthenticationUI: (__bridge id)kSecUseAuthenticationUIFail}), NULL);
    OSStatus skip = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"vault"), @{(__bridge id)kSecReturnData: @YES,
                                        (__bridge id)kSecUseAuthenticationUI: (__bridge id)kSecUseAuthenticationUISkip}), NULL);
    OSStatus attrs = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"vault"), @{(__bridge id)kSecReturnAttributes: @YES}), NULL);
    say(@"protected noui fail=%d skip=%d attributes=%d", (int)fail, (int)skip, (int)attrs);
}

@interface VaultController : UIViewController
@end
@implementation VaultController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:@"Open the Vault" forState:UIControlStateNormal];
    b.accessibilityIdentifier = @"open-vault";
    b.frame = CGRectMake(40, 200, 300, 44);
    [b addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
}
- (void)open {
    CFTypeRef data = NULL;
    OSStatus s = SecItemCopyMatching((__bridge CFDictionaryRef)with(base(@"vault"), @{(__bridge id)kSecReturnData: @YES,
                                     (__bridge id)kSecUseOperationPrompt: @"Open the vault"}), &data);
    say(@"vault %d %@", (int)s, string(data));
    if (data) CFRelease(data);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    basics();
    addProtected();
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [VaultController new];
    [self.window makeKeyAndVisible];
    say(@"ready");
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
