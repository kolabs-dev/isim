// HelloStoreObjC: StoreKit 1 from Objective-C (issue #226), as Unity IAP and the Capacitor / Cordova purchase plugins
// use it: an SKProductsRequest, buying through the SKPaymentQueue with a transaction observer, finishing transactions,
// restoring purchases, signed promotional offers (#454), refreshing the receipt and asking for a review. It uses HelloStore's local StoreKit
// configuration. Logs "so ..." lines; the buttons have accessibility identifiers.
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>
#include <stdio.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("so %s\n", s.UTF8String);
    fflush(stdout);
}

static NSString *stateName(SKPaymentTransactionState s) {
    switch (s) {
    case SKPaymentTransactionStatePurchasing: return @"purchasing";
    case SKPaymentTransactionStatePurchased: return @"purchased";
    case SKPaymentTransactionStateFailed: return @"failed";
    case SKPaymentTransactionStateRestored: return @"restored";
    case SKPaymentTransactionStateDeferred: return @"deferred";
    }
    return @"?";
}

@interface StoreController : UIViewController <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property (nonatomic, strong) SKProductsRequest *request;
@property (nonatomic, strong) SKReceiptRefreshRequest *refresh;
@property (nonatomic, strong) NSDictionary<NSString *, SKProduct *> *products;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UILabel *status;
@end

@implementation StoreController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Store (Objective-C)";
    self.stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 12;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
    self.status = [UILabel new];
    self.status.text = @"Loading products…";
    self.status.accessibilityIdentifier = @"status";
    self.status.numberOfLines = 0;
    [self.stack addArrangedSubview:self.status];

    say(@"canMakePayments %d storefront %@", [SKPaymentQueue canMakePayments], [SKPaymentQueue defaultQueue].storefront.countryCode);
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    NSSet *ids = [NSSet setWithObjects:@"dev.isim.store.coins", @"dev.isim.store.full_game", @"dev.isim.store.plus.monthly",
                                       @"dev.isim.store.nonexistent", nil];
    self.request = [[SKProductsRequest alloc] initWithProductIdentifiers:ids];
    self.request.delegate = self;
    [self.request start];
}

- (UIButton *)button:(NSString *)title id:(NSString *)ident action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.accessibilityIdentifier = ident;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:b];
    return b;
}

// MARK: SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSMutableDictionary *byID = [NSMutableDictionary dictionary];
    NSArray *sorted = [response.products sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"productIdentifier" ascending:YES]]];
    for (SKProduct *p in sorted) {
        byID[p.productIdentifier] = p;
        NSNumberFormatter *f = [NSNumberFormatter new];
        f.numberStyle = NSNumberFormatterCurrencyStyle;
        f.locale = p.priceLocale;
        NSString *period = p.subscriptionPeriod ? [NSString stringWithFormat:@" period=%lu/%lu", (unsigned long)p.subscriptionPeriod.numberOfUnits,
                                                   (unsigned long)p.subscriptionPeriod.unit] : @"";
        NSString *intro = p.introductoryPrice ? [NSString stringWithFormat:@" intro=%@x%lu mode=%lu", p.introductoryPrice.price,
                                                 (unsigned long)p.introductoryPrice.numberOfPeriods, (unsigned long)p.introductoryPrice.paymentMode] : @"";
        say(@"product %@ title=%@ price=%@ formatted=%@ decimal=%d%@%@ group=%@", p.productIdentifier, p.localizedTitle, p.price,
            [f stringFromNumber:p.price], [p.price isKindOfClass:[NSDecimalNumber class]], period, intro, p.subscriptionGroupIdentifier ?: @"-");
        [self button:[NSString stringWithFormat:@"Buy %@", p.localizedTitle] id:[@"buy-" stringByAppendingString:p.productIdentifier]
              action:@selector(buy:)];
    }
    self.products = byID;
    say(@"invalid %@", [response.invalidProductIdentifiers componentsJoinedByString:@","]);
    [self button:@"Promotional Offer" id:@"promo" action:@selector(promo:)];
    [self button:@"Forged Offer" id:@"promo-bad" action:@selector(promo:)];
    [self button:@"Buy Unknown" id:@"buy-unknown" action:@selector(buyUnknown)];
    [self button:@"Restore Purchases" id:@"restore" action:@selector(restore)];
    [self button:@"Refresh Receipt" id:@"refresh-receipt" action:@selector(refreshReceipt)];
    [self button:@"Rate the App" id:@"review" action:@selector(review)];
    self.status.text = [NSString stringWithFormat:@"%lu products", (unsigned long)response.products.count];
}
- (void)requestDidFinish:(SKRequest *)request {
    if (request == self.refresh) {
        NSURL *url = [NSBundle mainBundle].appStoreReceiptURL;
        NSData *d = url ? [NSData dataWithContentsOfURL:url] : nil;
        say(@"receipt refreshed bytes>0=%d pkcs7=%d", d.length > 0, d.length > 2 && ((const unsigned char *)d.bytes)[0] == 0x30);
    } else {
        say(@"request finished");
    }
}
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error { say(@"request failed %@ %ld", error.domain, (long)error.code); }

// MARK: actions
- (void)buy:(UIButton *)sender {
    NSString *pid = [sender.accessibilityIdentifier substringFromIndex:4];
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:self.products[pid]];
    payment.quantity = [pid isEqualToString:@"dev.isim.store.coins"] ? 2 : 1;
    payment.applicationUsername = @"player-1";
    say(@"add payment %@ quantity=%ld mutable=%d", payment.productIdentifier, (long)payment.quantity, [payment isKindOfClass:[SKMutablePayment class]]);
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}
// The test supplies an offer signed by the device's local subscription offers key (a stand-in offer server).
- (void)promo:(UIButton *)sender {
    NSDictionary *env = NSProcessInfo.processInfo.environment;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:self.products[@"dev.isim.store.plus.monthly"]];
    NSUUID *nonce = [[NSUUID alloc] initWithUUIDString:env[@"STOREOBJC_NONCE"]];
    NSNumber *timestamp = @([env[@"STOREOBJC_TIMESTAMP"] longLongValue]);
    NSString *signature = [sender.accessibilityIdentifier isEqualToString:@"promo-bad"] ? @"Zm9yZ2Vk" : env[@"STOREOBJC_SIGNATURE"];
    if (!nonce || !signature) { say(@"offer needs a signed payload from the test offer server"); return; }
    SKPaymentDiscount *discount = [[SKPaymentDiscount alloc] initWithIdentifier:@"comeback" keyIdentifier:env[@"STOREOBJC_KEY_ID"]
                                                                       nonce:nonce signature:signature timestamp:timestamp];
    payment.paymentDiscount = discount;
    SKPayment *base = payment;
    say(@"discount class=%d identity=%d fields=%d", [discount isKindOfClass:[NSObject class]], base.paymentDiscount == discount,
        [discount.identifier isEqualToString:@"comeback"] && [discount.keyIdentifier isEqualToString:env[@"STOREOBJC_KEY_ID"]] &&
        [discount.nonce isEqual:nonce] && [discount.signature isEqualToString:signature] && [discount.timestamp isEqual:timestamp]);
    payment.paymentDiscount = nil;
    say(@"discount cleared=%d", base.paymentDiscount == nil);
    payment.paymentDiscount = discount;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}
- (void)buyUnknown {
    SKMutablePayment *payment = [[SKMutablePayment alloc] init];
    payment.productIdentifier = @"dev.isim.store.nonexistent";
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}
- (void)restore { [[SKPaymentQueue defaultQueue] restoreCompletedTransactions]; }
- (void)refreshReceipt {
    self.refresh = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:@{SKReceiptPropertyIsVolumePurchase: @YES}];
    self.refresh.delegate = self;
    [self.refresh start];
}
- (void)review { [SKStoreReviewController requestReviewInScene:self.view.window.windowScene]; }

// MARK: SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *t in transactions) {
        NSString *extra = @"";
        if (t.transactionState == SKPaymentTransactionStateFailed)
            extra = [NSString stringWithFormat:@" error=%@/%ld", t.error.domain, (long)t.error.code];
        else if (t.transactionState == SKPaymentTransactionStateRestored)
            extra = [NSString stringWithFormat:@" original=%d", t.originalTransaction.transactionIdentifier.length > 0];
        else if (t.transactionState == SKPaymentTransactionStatePurchased)
            extra = [NSString stringWithFormat:@" id=%d date=%d", t.transactionIdentifier.length > 0, t.transactionDate != nil];
        say(@"transaction %@ %@ quantity=%ld%@", t.payment.productIdentifier, stateName(t.transactionState), (long)t.payment.quantity, extra);
        if (t.transactionState != SKPaymentTransactionStatePurchasing && t.transactionState != SKPaymentTransactionStateDeferred)
            [queue finishTransaction:t];
        self.status.text = [NSString stringWithFormat:@"%@: %@", t.payment.productIdentifier, stateName(t.transactionState)];
    }
}
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    say(@"removed %lu pending=%lu", (unsigned long)transactions.count, (unsigned long)queue.transactions.count);
}
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue { say(@"restore finished"); }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[StoreController new]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
