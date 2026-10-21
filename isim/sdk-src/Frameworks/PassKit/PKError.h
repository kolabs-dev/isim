#pragma once
/* isim PassKit: Apple Pay's and Wallet's errors (PKPaymentErrorDomain, PKPassKitErrorDomain). */
#import <PassKit/PKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
PK_EXTERN NSErrorDomain const PKPaymentErrorDomain;
typedef NSString * PKPaymentErrorKey NS_TYPED_ENUM;
PK_EXTERN PKPaymentErrorKey const PKPaymentErrorContactFieldUserInfoKey;
PK_EXTERN PKPaymentErrorKey const PKPaymentErrorPostalAddressUserInfoKey;
typedef NS_ERROR_ENUM(PKPaymentErrorDomain, PKPaymentErrorCode) {
    PKPaymentUnknownError = -1, PKPaymentShippingContactInvalidError = 1, PKPaymentBillingContactInvalidError,
    PKPaymentShippingAddressUnserviceableError, PKPaymentCouponCodeInvalidError, PKPaymentCouponCodeExpiredError
};
PK_EXTERN NSErrorDomain const PKPassKitErrorDomain;
typedef NS_ERROR_ENUM(PKPassKitErrorDomain, PKPassKitErrorCode) {
    PKUnknownError = -1, PKInvalidDataError = 1, PKUnsupportedVersionError, PKInvalidSignature, PKNotEntitledError
};
NS_ASSUME_NONNULL_END
#endif
