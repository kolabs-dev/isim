#pragma once
/* isim PassKit: the payment networks, contact fields and enums of Apple Pay (the PassKit Swift overlay's values). */
#import <PassKit/PKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NSString * PKPaymentNetwork NS_TYPED_EXTENSIBLE_ENUM;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkAmex;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkBancontact;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkBancomat API_DEPRECATED("use PKPaymentNetworkPagoBancomat or PKPaymentNetworkCartesBancaires", ios(12.0, 17.0));
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkBankAxept;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkBarcode;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkCarteBancaire API_DEPRECATED("use PKPaymentNetworkPagoBancomat or PKPaymentNetworkCartesBancaires", ios(12.0, 17.0));
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkCarteBancaires API_DEPRECATED("use PKPaymentNetworkPagoBancomat or PKPaymentNetworkCartesBancaires", ios(12.0, 17.0));
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkCartesBancaires;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkChinaUnionPay;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkConecs;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkDankort;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkDiscover;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkEftpos;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkElCorteIngles;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkElcard;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkElectron;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkElo;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkGirocard;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkHimyan;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkHumo;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkIDCredit;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkInterac;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkJaywan;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkJCB;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMaal;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMada;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMaestro;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMasterCard;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMeeza;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMir;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkMyDebit;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkNAPAS;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkNanaco;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkPagoBancomat;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkPayPak;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkPostFinance;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkPrivateLabel;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkQuicPay;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkRuPay;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkSuica;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkTmoney;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkUzCard;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkVerve;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkVisa;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkVPay;
PK_EXTERN PKPaymentNetwork const PKPaymentNetworkWaon;
typedef NSString * PKContactField NS_TYPED_ENUM;
PK_EXTERN PKContactField const PKContactFieldPostalAddress;
PK_EXTERN PKContactField const PKContactFieldEmailAddress;
PK_EXTERN PKContactField const PKContactFieldPhoneNumber;
PK_EXTERN PKContactField const PKContactFieldName;
PK_EXTERN PKContactField const PKContactFieldPhoneticName;
typedef NS_OPTIONS(NSUInteger, PKMerchantCapability) {
    PKMerchantCapability3DS = 1UL << 0, PKMerchantCapabilityEMV = 1UL << 1, PKMerchantCapabilityCredit = 1UL << 2,
    PKMerchantCapabilityDebit = 1UL << 3, PKMerchantCapabilityInstantFundsOut = 1UL << 7
};
typedef NS_ENUM(NSUInteger, PKShippingType) {
    PKShippingTypeShipping = 0, PKShippingTypeDelivery, PKShippingTypeStorePickup, PKShippingTypeServicePickup
};
typedef NS_ENUM(NSUInteger, PKShippingContactEditingMode) {
    PKShippingContactEditingModeAvailable = 1, PKShippingContactEditingModeEnabled = 1, PKShippingContactEditingModeStorePickup = 2
};
typedef NS_ENUM(NSUInteger, PKPaymentSummaryItemType) { PKPaymentSummaryItemTypeFinal = 0, PKPaymentSummaryItemTypePending };
typedef NS_ENUM(NSUInteger, PKPaymentMethodType) {
    PKPaymentMethodTypeUnknown = 0, PKPaymentMethodTypeDebit, PKPaymentMethodTypeCredit, PKPaymentMethodTypePrepaid,
    PKPaymentMethodTypeStore, PKPaymentMethodTypeEMoney
};
typedef NS_ENUM(NSInteger, PKPaymentAuthorizationStatus) {
    PKPaymentAuthorizationStatusSuccess = 0, PKPaymentAuthorizationStatusFailure,
    PKPaymentAuthorizationStatusInvalidBillingPostalAddress, PKPaymentAuthorizationStatusInvalidShippingPostalAddress,
    PKPaymentAuthorizationStatusInvalidShippingContact, PKPaymentAuthorizationStatusPINRequired,
    PKPaymentAuthorizationStatusPINIncorrect, PKPaymentAuthorizationStatusPINLockout
};
typedef NS_ENUM(NSInteger, PKPaymentButtonType) {
    PKPaymentButtonTypePlain = 0, PKPaymentButtonTypeBuy, PKPaymentButtonTypeSetUp, PKPaymentButtonTypeInStore,
    PKPaymentButtonTypeDonate, PKPaymentButtonTypeCheckout, PKPaymentButtonTypeBook, PKPaymentButtonTypeSubscribe,
    PKPaymentButtonTypeReload, PKPaymentButtonTypeAddMoney, PKPaymentButtonTypeTopUp, PKPaymentButtonTypeOrder,
    PKPaymentButtonTypeRent, PKPaymentButtonTypeSupport, PKPaymentButtonTypeContribute, PKPaymentButtonTypeTip,
    PKPaymentButtonTypeContinue
};
typedef NS_ENUM(NSInteger, PKPaymentButtonStyle) {
    PKPaymentButtonStyleWhite = 0, PKPaymentButtonStyleWhiteOutline, PKPaymentButtonStyleBlack, PKPaymentButtonStyleAutomatic
};
typedef NS_ENUM(NSInteger, PKAddPassButtonStyle) { PKAddPassButtonStyleBlack = 0, PKAddPassButtonStyleBlackOutline };
typedef NS_ENUM(NSUInteger, PKPassType) { PKPassTypeBarcode = 0, PKPassTypeSecureElement = 1, PKPassTypeAny = ~(NSUInteger)0 };
NS_ASSUME_NONNULL_END
#endif
