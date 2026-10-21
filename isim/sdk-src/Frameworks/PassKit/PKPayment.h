#pragma once
/* isim PassKit: authorized payments, their tokens and payment methods, the app's results and the request updates (the
 * PassKit Swift overlay's classes). A payment's token is isim's test token: its paymentData is JSON with "version":
 * "isim-test" and no cryptogram, so nothing can be charged. */
#import <PassKit/PKPaymentRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface PKPaymentMethod : NSObject
@property (nonatomic, copy, readonly, nullable) NSString *displayName;
@property (nonatomic, copy, readonly, nullable) PKPaymentNetwork network;
@property (nonatomic, readonly) PKPaymentMethodType type;
@property (nonatomic, copy, readonly, nullable) CNContact *billingAddress;
@end
@interface PKPaymentToken : NSObject
@property (nonatomic, strong, readonly) PKPaymentMethod *paymentMethod;
@property (nonatomic, copy, readonly) NSString *paymentInstrumentName API_DEPRECATED("use paymentMethod", ios(8.0, 9.0));
@property (nonatomic, copy, readonly) NSString *paymentNetwork API_DEPRECATED("use paymentMethod", ios(8.0, 9.0));
@property (nonatomic, copy, readonly) NSString *transactionIdentifier;
@property (nonatomic, copy, readonly) NSData *paymentData;
@end
@interface PKPayment : NSObject
@property (nonatomic, strong, readonly) PKPaymentToken *token;
@property (nonatomic, strong, readonly, nullable) PKContact *billingContact;
@property (nonatomic, strong, readonly, nullable) PKContact *shippingContact;
@property (nonatomic, strong, readonly, nullable) PKShippingMethod *shippingMethod;
@end
@interface PKPaymentOrderDetails : NSObject
- (instancetype)initWithOrderTypeIdentifier:(NSString *)orderTypeIdentifier orderIdentifier:(NSString *)orderIdentifier
                              webServiceURL:(NSURL *)webServiceURL authenticationToken:(NSString *)authenticationToken;
@property (nonatomic, copy) NSString *orderTypeIdentifier;
@property (nonatomic, copy) NSString *orderIdentifier;
@property (nonatomic, copy) NSURL *webServiceURL;
@property (nonatomic, copy) NSString *authenticationToken;
@end
@interface PKPaymentAuthorizationResult : NSObject
- (instancetype)initWithStatus:(PKPaymentAuthorizationStatus)status errors:(nullable NSArray<NSError *> *)errors;
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@property (nonatomic, strong, nullable) PKPaymentOrderDetails *orderDetails;
@end
@interface PKPaymentRequestUpdate : NSObject
- (instancetype)initWithPaymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems;
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (nonatomic, copy) NSArray<PKPaymentSummaryItem *> *paymentSummaryItems;
@property (nonatomic, copy) NSArray<PKShippingMethod *> *shippingMethods;
@property (nonatomic, copy, nullable) NSArray<PKPaymentTokenContext *> *multiTokenContexts;
@property (nonatomic, strong, nullable) PKRecurringPaymentRequest *recurringPaymentRequest;
@property (nonatomic, strong, nullable) PKDeferredPaymentRequest *deferredPaymentRequest;
@property (nonatomic, strong, nullable) PKAutomaticReloadPaymentRequest *automaticReloadPaymentRequest;
@end
@interface PKPaymentRequestShippingMethodUpdate : PKPaymentRequestUpdate
@end
@interface PKPaymentRequestShippingContactUpdate : PKPaymentRequestUpdate
- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
               shippingMethods:(NSArray<PKShippingMethod *> *)shippingMethods;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@end
@interface PKPaymentRequestPaymentMethodUpdate : PKPaymentRequestUpdate
- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@end
@interface PKPaymentRequestCouponCodeUpdate : PKPaymentRequestUpdate
- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
               shippingMethods:(NSArray<PKShippingMethod *> *)shippingMethods;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@end
NS_ASSUME_NONNULL_END
#endif
