// PassKit from Objective-C (PassKitObjCTest.app, issue #566): #import <PassKit/PassKit.h>, -framework PassKit. A payment
// request with Apple's constants (networks, contact fields, capabilities) and summary items, the errors the app reports
// and its results and updates, PKPaymentButton and PKAddPassButton, Wallet (a refused pass, the library), and payments
// through isim's sheet: PKPaymentAuthorizationController with an Objective-C delegate that changes the shipping method
// and authorizes, and PKPaymentAuthorizationViewController with one that only implements what it needs (the rest keeps
// the sheet's defaults). Results go to the log ("PassKitObjC: ...").
#import <UIKit/UIKit.h>
#import <PassKit/PassKit.h>

static void say(NSString *s) { NSLog(@"PassKitObjC: %@", s); }
static NSDecimalNumber *dec(NSString *s) { return [NSDecimalNumber decimalNumberWithString:s]; }

@interface TestViewController : UIViewController <PKPaymentAuthorizationControllerDelegate, PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) PKPaymentAuthorizationController *controller;
@end

@implementation TestViewController

- (PKPaymentRequest *)request {
    PKPaymentRequest *r = [[PKPaymentRequest alloc] init];
    r.merchantIdentifier = @"merchant.dev.isim.tests.passkit";
    r.countryCode = @"US";
    r.currencyCode = @"USD";
    r.supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard];
    r.merchantCapabilities = PKMerchantCapability3DS | PKMerchantCapabilityDebit;
    PKShippingMethod *standard = [PKShippingMethod summaryItemWithLabel:@"Standard" amount:dec(@"0")];
    standard.identifier = @"standard";
    standard.detail = @"3-5 days";
    PKShippingMethod *express = [PKShippingMethod summaryItemWithLabel:@"Express" amount:dec(@"5")];
    express.identifier = @"express";
    r.shippingMethods = @[standard, express];
    r.requiredShippingContactFields = [NSSet setWithObjects:PKContactFieldPostalAddress, PKContactFieldEmailAddress, nil];
    r.shippingType = PKShippingTypeDelivery;
    r.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:@"Book" amount:dec(@"10")],
                              [PKPaymentSummaryItem summaryItemWithLabel:@"ISIM BOOKS" amount:dec(@"10")]];
    return r;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self values];
    [self wallet];
    PKPaymentButton *pay = [PKPaymentButton buttonWithType:PKPaymentButtonTypeBuy style:PKPaymentButtonStyleBlack];
    pay.cornerRadius = 8;
    pay.frame = CGRectMake(40, 120, 300, 50);
    pay.accessibilityIdentifier = @"objc-pay";
    [pay addTarget:self action:@selector(payWithController) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pay];
    PKPaymentButton *sheet = [[PKPaymentButton alloc] initWithPaymentButtonType:PKPaymentButtonTypeCheckout paymentButtonStyle:PKPaymentButtonStyleWhiteOutline];
    sheet.frame = CGRectMake(40, 190, 300, 50);
    sheet.accessibilityIdentifier = @"objc-sheet";
    [sheet addTarget:self action:@selector(payWithViewController) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sheet];
    PKAddPassButton *add = [PKAddPassButton addPassButtonWithStyle:PKAddPassButtonStyleBlackOutline];
    add.frame = CGRectMake(40, 260, 300, 50);
    [self.view addSubview:add];
    say([NSString stringWithFormat:@"buttons %@ \"%@\" radius %.0f / %@ \"%@\" / %@ style %ld", NSStringFromClass(pay.class), [pay titleForState:UIControlStateNormal],
         pay.cornerRadius, NSStringFromClass(sheet.class), [sheet titleForState:UIControlStateNormal], NSStringFromClass(add.class), (long)add.addPassButtonStyle]);
}

- (void)values {
    PKPaymentRequest *r = [self request];
    NSArray *fields = [r.requiredShippingContactFields.allObjects sortedArrayUsingSelector:@selector(compare:)];
    PKPaymentSummaryItem *pending = [PKPaymentSummaryItem summaryItemWithLabel:@"Tip" amount:dec(@"1.5") type:PKPaymentSummaryItemTypePending];
    say([NSString stringWithFormat:@"request networks %@ capabilities %lu fields %@ shipping %lu methods %@ %@ pending %lu %@",
         [r.supportedNetworks componentsJoinedByString:@","], (unsigned long)r.merchantCapabilities, [fields componentsJoinedByString:@","],
         (unsigned long)r.shippingType, NSStringFromClass(r.shippingMethods[1].class), r.shippingMethods[0].detail, (unsigned long)pending.type, pending.amount]);
    say([NSString stringWithFormat:@"can pay %d visa %d jcb %d credit %d available %@", PKPaymentAuthorizationController.canMakePayments,
         [PKPaymentAuthorizationController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa]],
         [PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[PKPaymentNetworkJCB]],
         [PKPaymentAuthorizationController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa] capabilities:PKMerchantCapabilityCredit],
         [PKPaymentRequest.availableNetworks componentsJoinedByString:@","]]);
    NSError *e = [PKPaymentRequest paymentContactInvalidErrorWithContactField:PKContactFieldEmailAddress localizedDescription:@"Enter an email"];
    NSError *a = [PKPaymentRequest paymentShippingAddressInvalidErrorWithKey:@"postalCode" localizedDescription:nil];
    say([NSString stringWithFormat:@"error %@ %ld %@ %@ / %ld %@", e.domain, (long)e.code, e.userInfo[PKPaymentErrorContactFieldUserInfoKey], e.localizedDescription,
         (long)a.code, a.userInfo[PKPaymentErrorPostalAddressUserInfoKey]]);
    PKPaymentAuthorizationResult *res = [[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:@[e]];
    PKPaymentRequestShippingContactUpdate *u = [[PKPaymentRequestShippingContactUpdate alloc] initWithErrors:@[e] paymentSummaryItems:r.paymentSummaryItems
                                                                                                shippingMethods:r.shippingMethods];
    u.status = PKPaymentAuthorizationStatusFailure;
    say([NSString stringWithFormat:@"result %ld errors %lu update %ld errors %lu items %lu methods %lu", (long)res.status, (unsigned long)res.errors.count,
         (long)u.status, (unsigned long)u.errors.count, (unsigned long)u.paymentSummaryItems.count, (unsigned long)u.shippingMethods.count]);
}

- (void)wallet {
    NSError *error = nil;
    PKPass *pass = [[PKPass alloc] initWithData:[@"not a pass" dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    PKPassLibrary *library = [[PKPassLibrary alloc] init];
    say([NSString stringWithFormat:@"pass %@ domain %@ code %ld library %d passes %lu secure %lu add %d", pass ? @"read" : @"refused", error.domain,
         (long)error.code, PKPassLibrary.isPassLibraryAvailable, (unsigned long)[library passesOfType:PKPassTypeAny].count,
         (unsigned long)[library passesOfType:PKPassTypeSecureElement].count, PKAddPassesViewController.canAddPasses]);
}

// MARK: PKPaymentAuthorizationController

- (void)payWithController {
    PKPaymentRequest *r = [self request];
    r.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:@"Book" amount:dec(@"10")],
                              [PKPaymentSummaryItem summaryItemWithLabel:@"ISIM BOOKS" amount:dec(@"10")]];
    self.controller = [[PKPaymentAuthorizationController alloc] initWithPaymentRequest:r];
    self.controller.delegate = self;
    say([NSString stringWithFormat:@"controller delegate %d", self.controller.delegate == self]);
    [self.controller presentWithCompletion:^(BOOL presented) { say([NSString stringWithFormat:@"controller presented %d", presented]); }];
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                               handler:(void (^)(PKPaymentRequestShippingMethodUpdate *))completion {
    NSDecimalNumber *total = [dec(@"10") decimalNumberByAdding:shippingMethod.amount];
    say([NSString stringWithFormat:@"controller shipping %@ total %@", shippingMethod.identifier, total]);
    completion([[PKPaymentRequestShippingMethodUpdate alloc] initWithPaymentSummaryItems:@[
        [PKPaymentSummaryItem summaryItemWithLabel:@"Book" amount:dec(@"10")], [PKPaymentSummaryItem summaryItemWithLabel:shippingMethod.label amount:shippingMethod.amount],
        [PKPaymentSummaryItem summaryItemWithLabel:@"ISIM BOOKS" amount:total]]]);
}

- (void)paymentAuthorizationControllerWillAuthorizePayment:(PKPaymentAuthorizationController *)controller { say(@"controller will authorize"); }

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didAuthorizePayment:(PKPayment *)payment
                               handler:(void (^)(PKPaymentAuthorizationResult *))completion {
    PKPaymentMethod *m = payment.token.paymentMethod;
    NSDictionary *token = [NSJSONSerialization JSONObjectWithData:payment.token.paymentData options:0 error:nil];
    say([NSString stringWithFormat:@"controller authorized method=%@ network=%@ type=%lu token=%@ shipping=%@ email=%@ city=%@", m.displayName, m.network,
         (unsigned long)m.type, token[@"version"], payment.shippingMethod.identifier, payment.shippingContact.emailAddress, payment.shippingContact.postalAddress.city]);
    completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
}

- (void)paymentAuthorizationControllerDidFinish:(PKPaymentAuthorizationController *)controller {
    say(@"controller finished");
    [controller dismissWithCompletion:^{ say(@"controller dismissed"); }];
}

// MARK: PKPaymentAuthorizationViewController

- (void)payWithViewController {
    PKPaymentRequest *r = [self request];
    r.shippingMethods = nil;
    r.requiredShippingContactFields = [NSSet set];
    r.merchantCapabilities = PKMerchantCapability3DS;   // credit cards too: Visa 4242 first
    PKPaymentRequest *incomplete = [[PKPaymentRequest alloc] init];
    PKPaymentAuthorizationViewController *refused = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:incomplete];
    PKPaymentAuthorizationViewController *vc = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:r];
    vc.delegate = self;
    say([NSString stringWithFormat:@"view controller incomplete %@ delegate %d", refused ? @"shown" : @"nil", vc.delegate == self]);
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod
                                   handler:(void (^)(PKPaymentRequestPaymentMethodUpdate *))completion {
    say([NSString stringWithFormat:@"view controller card %@", paymentMethod.displayName]);
    completion([[PKPaymentRequestPaymentMethodUpdate alloc] initWithErrors:nil paymentSummaryItems:@[[PKPaymentSummaryItem summaryItemWithLabel:@"ISIM BOOKS" amount:dec(@"10")]]]);
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment
                                   handler:(void (^)(PKPaymentAuthorizationResult *))completion {
    say([NSString stringWithFormat:@"view controller authorized %@", payment.token.paymentMethod.displayName]);
    completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    say(@"view controller finished");
    [controller dismissViewControllerAnimated:YES completion:^{ say(@"view controller dismissed"); }];
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
