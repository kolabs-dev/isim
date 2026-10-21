#pragma once
/* isim PassKit: the Apple Pay sheet over the app (isim's simulated sheet, with the device's test cards). */
#import <PassKit/PKPayment.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PKPaymentAuthorizationController;
@protocol PKPaymentAuthorizationControllerDelegate <NSObject>
@required
- (void)paymentAuthorizationControllerDidFinish:(PKPaymentAuthorizationController *)controller;
@optional
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didAuthorizePayment:(PKPayment *)payment
                               handler:(void (^)(PKPaymentAuthorizationResult *result))completion;
- (void)paymentAuthorizationControllerWillAuthorizePayment:(PKPaymentAuthorizationController *)controller;
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                               handler:(void (^)(PKPaymentRequestShippingMethodUpdate *requestUpdate))completion;
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectShippingContact:(PKContact *)contact
                               handler:(void (^)(PKPaymentRequestShippingContactUpdate *requestUpdate))completion;
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod
                               handler:(void (^)(PKPaymentRequestPaymentMethodUpdate *requestUpdate))completion;
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didChangeCouponCode:(NSString *)couponCode
                               handler:(void (^)(PKPaymentRequestCouponCodeUpdate *requestUpdate))completion;
- (nullable UIWindow *)presentationWindowForPaymentAuthorizationController:(PKPaymentAuthorizationController *)controller;
@end
@interface PKPaymentAuthorizationController : NSObject
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray<PKPaymentNetwork> *)supportedNetworks;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray<PKPaymentNetwork> *)supportedNetworks capabilities:(PKMerchantCapability)capabilties;
- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)request;
@property (nonatomic, weak, nullable) id<PKPaymentAuthorizationControllerDelegate> delegate;
- (void)presentWithCompletion:(nullable void (^)(BOOL success))completion;
- (void)dismissWithCompletion:(nullable void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
#endif
