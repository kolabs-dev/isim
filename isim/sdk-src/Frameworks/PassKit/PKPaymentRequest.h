#pragma once
/* isim PassKit: payment requests, summary items, shipping methods and contacts (the PassKit Swift overlay's classes). */
#import <PassKit/PKConstants.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface PKPaymentSummaryItem : NSObject
+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount;
+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount type:(PKPaymentSummaryItemType)type;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSDecimalNumber *amount;
@property (nonatomic, assign) PKPaymentSummaryItemType type;
@end
@interface PKRecurringPaymentSummaryItem : PKPaymentSummaryItem
@property (nonatomic, copy, nullable) NSDate *startDate;
@property (nonatomic, assign) NSCalendarUnit intervalUnit;
@property (nonatomic, assign) NSInteger intervalCount;
@property (nonatomic, copy, nullable) NSDate *endDate;
@end
@interface PKDeferredPaymentSummaryItem : PKPaymentSummaryItem
@property (nonatomic, copy) NSDate *deferredDate;
@end
@interface PKAutomaticReloadPaymentSummaryItem : PKPaymentSummaryItem
@property (nonatomic, copy) NSDecimalNumber *thresholdAmount;
@end
@interface PKDateComponentsRange : NSObject <NSCopying, NSSecureCoding>
- (nullable instancetype)initWithStartDateComponents:(NSDateComponents *)startDateComponents endDateComponents:(NSDateComponents *)endDateComponents;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy, readonly) NSDateComponents *startDateComponents;
@property (nonatomic, copy, readonly) NSDateComponents *endDateComponents;
@end
@interface PKShippingMethod : PKPaymentSummaryItem
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, copy, nullable) PKDateComponentsRange *dateComponentsRange;
@end
@interface PKContact : NSObject
@property (nonatomic, strong, nullable) NSPersonNameComponents *name;
@property (nonatomic, strong, nullable) CNPostalAddress *postalAddress;
@property (nonatomic, strong, nullable) NSString *emailAddress;
@property (nonatomic, strong, nullable) CNPhoneNumber *phoneNumber;
@property (nonatomic, copy, nullable) NSString *supplementarySubLocality API_DEPRECATED("use postalAddress.subLocality", ios(9.2, 10.3));
@end
@interface PKRecurringPaymentRequest : NSObject
- (instancetype)initWithPaymentDescription:(NSString *)paymentDescription regularBilling:(PKRecurringPaymentSummaryItem *)regularBilling
                             managementURL:(NSURL *)managementURL;
@property (nonatomic, copy) NSString *paymentDescription;
@property (nonatomic, copy) PKRecurringPaymentSummaryItem *regularBilling;
@property (nonatomic, copy, nullable) PKRecurringPaymentSummaryItem *trialBilling;
@property (nonatomic, copy, nullable) NSString *billingAgreement;
@property (nonatomic, copy) NSURL *managementURL;
@property (nonatomic, copy, nullable) NSURL *tokenNotificationURL;
@end
@interface PKDeferredPaymentRequest : NSObject
- (instancetype)initWithPaymentDescription:(NSString *)paymentDescription deferredBilling:(PKDeferredPaymentSummaryItem *)deferredBilling
                             managementURL:(NSURL *)managementURL;
@property (nonatomic, copy) NSString *paymentDescription;
@property (nonatomic, copy) PKDeferredPaymentSummaryItem *deferredBilling;
@property (nonatomic, copy, nullable) NSString *billingAgreement;
@property (nonatomic, copy) NSURL *managementURL;
@property (nonatomic, copy, nullable) NSURL *tokenNotificationURL;
@property (nonatomic, copy, nullable) NSDate *freeCancellationDate;
@property (nonatomic, copy, nullable) NSTimeZone *freeCancellationDateTimeZone;
@end
@interface PKAutomaticReloadPaymentRequest : NSObject
- (instancetype)initWithPaymentDescription:(NSString *)paymentDescription automaticReloadBilling:(PKAutomaticReloadPaymentSummaryItem *)automaticReloadBilling
                             managementURL:(NSURL *)managementURL;
@property (nonatomic, copy) NSString *paymentDescription;
@property (nonatomic, copy) PKAutomaticReloadPaymentSummaryItem *automaticReloadBilling;
@property (nonatomic, copy, nullable) NSString *billingAgreement;
@property (nonatomic, copy) NSURL *managementURL;
@property (nonatomic, copy, nullable) NSURL *tokenNotificationURL;
@end
@interface PKPaymentTokenContext : NSObject
- (instancetype)initWithMerchantIdentifier:(NSString *)merchantIdentifier externalIdentifier:(NSString *)externalIdentifier
                              merchantName:(NSString *)merchantName merchantDomain:(nullable NSString *)merchantDomain amount:(NSDecimalNumber *)amount;
@property (nonatomic, copy) NSString *merchantIdentifier;
@property (nonatomic, copy) NSString *externalIdentifier;
@property (nonatomic, copy) NSString *merchantName;
@property (nonatomic, copy, nullable) NSString *merchantDomain;
@property (nonatomic, copy) NSDecimalNumber *amount;
@end
@interface PKPaymentRequest : NSObject
+ (NSArray<PKPaymentNetwork> *)availableNetworks;
+ (NSError *)paymentContactInvalidErrorWithContactField:(PKContactField)field localizedDescription:(nullable NSString *)localizedDescription;
+ (NSError *)paymentShippingAddressInvalidErrorWithKey:(NSString *)postalAddressKey localizedDescription:(nullable NSString *)localizedDescription;
+ (NSError *)paymentBillingAddressInvalidErrorWithKey:(NSString *)postalAddressKey localizedDescription:(nullable NSString *)localizedDescription;
+ (NSError *)paymentShippingAddressUnserviceableErrorWithLocalizedDescription:(nullable NSString *)localizedDescription;
+ (NSError *)paymentCouponCodeInvalidErrorWithLocalizedDescription:(nullable NSString *)localizedDescription;
+ (NSError *)paymentCouponCodeExpiredErrorWithLocalizedDescription:(nullable NSString *)localizedDescription;
@property (nonatomic, copy) NSString *merchantIdentifier;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSArray<PKPaymentNetwork> *supportedNetworks;
@property (nonatomic, assign) PKMerchantCapability merchantCapabilities;
@property (nonatomic, copy, nullable) NSSet<NSString *> *supportedCountries;
@property (nonatomic, copy) NSString *currencyCode;
@property (nonatomic, copy) NSArray<PKPaymentSummaryItem *> *paymentSummaryItems;
@property (nonatomic, strong) NSSet<PKContactField> *requiredBillingContactFields;
@property (nonatomic, strong, nullable) PKContact *billingContact;
@property (nonatomic, strong) NSSet<PKContactField> *requiredShippingContactFields;
@property (nonatomic, strong, nullable) PKContact *shippingContact;
@property (nonatomic, copy, nullable) NSArray<PKShippingMethod *> *shippingMethods;
@property (nonatomic, assign) PKShippingType shippingType;
@property (nonatomic, assign) PKShippingContactEditingMode shippingContactEditingMode;
@property (nonatomic, copy, nullable) NSData *applicationData;
@property (nonatomic, copy, nullable) NSString *couponCode;
@property (nonatomic, assign) BOOL supportsCouponCode;
@property (nonatomic, strong, nullable) PKRecurringPaymentRequest *recurringPaymentRequest;
@property (nonatomic, strong, nullable) PKDeferredPaymentRequest *deferredPaymentRequest;
@property (nonatomic, strong, nullable) PKAutomaticReloadPaymentRequest *automaticReloadPaymentRequest;
@property (nonatomic, copy) NSArray<PKPaymentTokenContext *> *multiTokenContexts;
@property (nonatomic, copy, nullable) NSString *attributionIdentifier;
@end
NS_ASSUME_NONNULL_END
#endif
