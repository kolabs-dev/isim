// StoreKitTest from Objective-C (StoreKitTestObjCTest.app, issue #564): #import <StoreKitTest/StoreKitTest.h>,
// -framework StoreKitTest, over isim's local store with the Products.storekit of HelloStoreTesting (copied into the app).
// A session from the configuration: settings, a purchase outside the app (buyProductWithProductIdentifier:), the
// transaction list, a refund, Ask to Buy and time-rate settings, SKTestErrorDomain errors for unknown transactions,
// and clearing. Results go to the log ("SKTestObjC: ...").
#import <UIKit/UIKit.h>
#import <StoreKitTest/StoreKitTest.h>

static void say(NSString *s) { NSLog(@"SKTestObjC: %@", s); }

@interface TestViewController : UIViewController
@property (nonatomic, strong) SKTestSession *session;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    NSError *err = nil;
    SKTestSession *missing = [[SKTestSession alloc] initWithConfigurationFileNamed:@"Nope" error:&err];
    say([NSString stringWithFormat:@"missing configuration %@ domain %@", missing ? @"loaded" : @"refused", err.domain]);
    err = nil;
    self.session = [[SKTestSession alloc] initWithConfigurationFileNamed:@"Products" error:&err];
    [self.session resetToDefaultState];
    self.session.disableDialogs = YES;
    self.session.timeRate = SKTestTimeRateMonthlyRenewalEveryThirtySeconds;
    self.session.askToBuyEnabled = NO;
    self.session.failureError = SKErrorPaymentNotAllowed;
    say([NSString stringWithFormat:@"session %@ error %@ storefront %@ locale %@ dialogs %d rate %ld failure %ld transactions %lu",
         self.session ? @"yes" : @"no", err ? err.domain : @"none", self.session.storefront, self.session.locale.localeIdentifier,
         self.session.disableDialogs, (long)self.session.timeRate, (long)self.session.failureError, (unsigned long)self.session.allTransactions.count]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL bought = [self.session buyProductWithProductIdentifier:@"dev.isim.store.full_game" error:&err];
#pragma clang diagnostic pop
    say([NSString stringWithFormat:@"buy requested %d", bought]);
    [self waitForPurchase:50];
}

- (void)waitForPurchase:(int)tries {
    SKTestTransaction *t = self.session.allTransactions.firstObject;
    if (!t && tries > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self waitForPurchase:tries - 1]; });
        return;
    }
    say([NSString stringWithFormat:@"transaction %@ state %ld refunded %d ask %d issue %d", t.productIdentifier, (long)t.state, t.refunded,
         t.pendingAskToBuyConfirmation, t.hasPurchaseIssue]);
    NSError *err = nil;
    BOOL refunded = [self.session refundTransactionWithIdentifier:t.identifier error:&err];
    SKTestTransaction *after = self.session.allTransactions.firstObject;
    say([NSString stringWithFormat:@"refund %d refunded %d revoked %d", refunded, after.refunded, after.revocationDate != nil]);
    BOOL deleted = [self.session deleteTransactionWithIdentifier:999999 error:&err];
    say([NSString stringWithFormat:@"delete unknown %d domain %@ code %ld", deleted, err.domain, (long)err.code]);
    err = nil;
    BOOL renewed = [self.session forceRenewalOfSubscriptionWithProductIdentifier:@"dev.isim.store.plus.monthly" error:&err];
    say([NSString stringWithFormat:@"renew without subscription %d domain %@", renewed, err.domain]);
    [self.session clearTransactions];
    say([NSString stringWithFormat:@"cleared %lu", (unsigned long)self.session.allTransactions.count]);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TestViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
