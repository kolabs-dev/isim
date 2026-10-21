// isim PassKit for Objective-C: the C constants (the values the PassKit Swift overlay uses), Apple's factories and
// initializers where the overlay's take Swift enums (the overlay's _isim_ entry points make the objects).
#import <PassKit/PassKit.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

PKPaymentNetwork const PKPaymentNetworkAmex = @"AmEx";
PKPaymentNetwork const PKPaymentNetworkBancontact = @"Bancontact";
PKPaymentNetwork const PKPaymentNetworkBancomat = @"Bancomat";
PKPaymentNetwork const PKPaymentNetworkBankAxept = @"BankAxept";
PKPaymentNetwork const PKPaymentNetworkBarcode = @"Barcode";
PKPaymentNetwork const PKPaymentNetworkCarteBancaire = @"CarteBancaire";
PKPaymentNetwork const PKPaymentNetworkCarteBancaires = @"CarteBancaires";
PKPaymentNetwork const PKPaymentNetworkCartesBancaires = @"CartesBancaires";
PKPaymentNetwork const PKPaymentNetworkChinaUnionPay = @"ChinaUnionPay";
PKPaymentNetwork const PKPaymentNetworkConecs = @"Conecs";
PKPaymentNetwork const PKPaymentNetworkDankort = @"Dankort";
PKPaymentNetwork const PKPaymentNetworkDiscover = @"Discover";
PKPaymentNetwork const PKPaymentNetworkEftpos = @"Eftpos";
PKPaymentNetwork const PKPaymentNetworkElCorteIngles = @"ElCorteIngles";
PKPaymentNetwork const PKPaymentNetworkElcard = @"Elcard";
PKPaymentNetwork const PKPaymentNetworkElectron = @"Electron";
PKPaymentNetwork const PKPaymentNetworkElo = @"Elo";
PKPaymentNetwork const PKPaymentNetworkGirocard = @"Girocard";
PKPaymentNetwork const PKPaymentNetworkHimyan = @"Himyan";
PKPaymentNetwork const PKPaymentNetworkHumo = @"Humo";
PKPaymentNetwork const PKPaymentNetworkIDCredit = @"iD";
PKPaymentNetwork const PKPaymentNetworkInterac = @"Interac";
PKPaymentNetwork const PKPaymentNetworkJaywan = @"Jaywan";
PKPaymentNetwork const PKPaymentNetworkJCB = @"JCB";
PKPaymentNetwork const PKPaymentNetworkMaal = @"Maal";
PKPaymentNetwork const PKPaymentNetworkMada = @"mada";
PKPaymentNetwork const PKPaymentNetworkMaestro = @"Maestro";
PKPaymentNetwork const PKPaymentNetworkMasterCard = @"MasterCard";
PKPaymentNetwork const PKPaymentNetworkMeeza = @"Meeza";
PKPaymentNetwork const PKPaymentNetworkMir = @"Mir";
PKPaymentNetwork const PKPaymentNetworkMyDebit = @"MyDebit";
PKPaymentNetwork const PKPaymentNetworkNAPAS = @"Napas";
PKPaymentNetwork const PKPaymentNetworkNanaco = @"Nanaco";
PKPaymentNetwork const PKPaymentNetworkPagoBancomat = @"PagoBancomat";
PKPaymentNetwork const PKPaymentNetworkPayPak = @"PayPak";
PKPaymentNetwork const PKPaymentNetworkPostFinance = @"PostFinance";
PKPaymentNetwork const PKPaymentNetworkPrivateLabel = @"PrivateLabel";
PKPaymentNetwork const PKPaymentNetworkQuicPay = @"QUICPay";
PKPaymentNetwork const PKPaymentNetworkRuPay = @"RuPay";
PKPaymentNetwork const PKPaymentNetworkSuica = @"Suica";
PKPaymentNetwork const PKPaymentNetworkTmoney = @"TMoney";
PKPaymentNetwork const PKPaymentNetworkUzCard = @"UzCard";
PKPaymentNetwork const PKPaymentNetworkVerve = @"Verve";
PKPaymentNetwork const PKPaymentNetworkVisa = @"Visa";
PKPaymentNetwork const PKPaymentNetworkVPay = @"VPay";
PKPaymentNetwork const PKPaymentNetworkWaon = @"WAON";
PKContactField const PKContactFieldPostalAddress = @"post";
PKContactField const PKContactFieldEmailAddress = @"email";
PKContactField const PKContactFieldPhoneNumber = @"phone";
PKContactField const PKContactFieldName = @"name";
PKContactField const PKContactFieldPhoneticName = @"phoneticName";

NSErrorDomain const PKPaymentErrorDomain = @"PKPaymentErrorDomain";
PKPaymentErrorKey const PKPaymentErrorContactFieldUserInfoKey = @"PKPaymentErrorContactField";
PKPaymentErrorKey const PKPaymentErrorPostalAddressUserInfoKey = @"PKPaymentErrorPostalAddress";
NSErrorDomain const PKPassKitErrorDomain = @"PKPassKitErrorDomain";
PKPassLibraryNotificationName const PKPassLibraryDidChangeNotification = @"PKPassLibraryDidChangeNotification";
PKPassLibraryNotificationName const PKPassLibraryRemotePaymentPassesDidChangeNotification = @"PKPassLibraryRemotePaymentPassesDidChangeNotification";
PKPassLibraryNotificationKey const PKPassLibraryAddedPassesUserInfoKey = @"PKPassLibraryAddedPassesUserInfoKey";
PKPassLibraryNotificationKey const PKPassLibraryReplacementPassesUserInfoKey = @"PKPassLibraryReplacementPassesUserInfoKey";
PKPassLibraryNotificationKey const PKPassLibraryRemovedPassInfosUserInfoKey = @"PKPassLibraryRemovedPassInfosUserInfoKey";
PKPassLibraryNotificationKey const PKPassLibraryPassTypeIdentifierUserInfoKey = @"PKPassLibraryPassTypeIdentifierUserInfoKey";
PKPassLibraryNotificationKey const PKPassLibrarySerialNumberUserInfoKey = @"PKPassLibrarySerialNumberUserInfoKey";
PKPassLibraryNotificationKey const PKPassLibraryRecoveredPassesUserInfoKey = @"PKPassLibraryRecoveredPassesUserInfoKey";

@interface PKPaymentButton (ISIMPassKit)
+ (PKPaymentButton *)_isim_buttonWithType:(NSInteger)type style:(NSInteger)style;
@end
@interface PKAddPassButton (ISIMPassKit)
+ (PKAddPassButton *)_isim_addPassButtonWithStyle:(NSInteger)style;
@end

@implementation PKPaymentSummaryItem (ISIMFactories)
+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount {
    PKPaymentSummaryItem *i = [[self alloc] init];
    i.label = label;
    i.amount = amount;
    return i;
}
+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount type:(PKPaymentSummaryItemType)type {
    PKPaymentSummaryItem *i = [self summaryItemWithLabel:label amount:amount];
    i.type = type;
    return i;
}
@end

@implementation PKPaymentAuthorizationResult (ISIMInit)
- (instancetype)initWithStatus:(PKPaymentAuthorizationStatus)status errors:(NSArray<NSError *> *)errors {
    self = [self init];
    self.status = status;
    self.errors = errors ?: @[];
    return self;
}
@end

@implementation PKPaymentButton (ISIMFactories)
+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle {
    return (id)[PKPaymentButton _isim_buttonWithType:buttonType style:buttonStyle];
}
- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style {
    return (id)[PKPaymentButton _isim_buttonWithType:type style:style];
}
@end

@implementation PKAddPassButton (ISIMFactories)
+ (instancetype)addPassButtonWithStyle:(PKAddPassButtonStyle)addPassButtonStyle {
    return (id)[PKAddPassButton _isim_addPassButtonWithStyle:addPassButtonStyle];
}
- (instancetype)initWithAddPassButtonStyle:(PKAddPassButtonStyle)style {
    return (id)[PKAddPassButton _isim_addPassButtonWithStyle:style];
}
@end
