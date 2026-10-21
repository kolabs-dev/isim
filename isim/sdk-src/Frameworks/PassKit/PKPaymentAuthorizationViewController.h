#pragma once
/* isim PassKit: the Apple Pay sheet as a view controller the app presents (isim's simulated sheet). */
#import <PassKit/PKPayment.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PKPaymentAuthorizationViewController;
@protocol PKPaymentAuthorizationViewControllerDelegate <NSObject>
@required
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller;
@optional
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment
                                   handler:(void (^)(PKPaymentAuthorizationResult *result))completion;
- (void)paymentAuthorizationViewControllerWillAuthorizePayment:(PKPaymentAuthorizationViewController *)controller;
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                   handler:(void (^)(PKPaymentRequestShippingMethodUpdate *update))completion;
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingContact:(PKContact *)contact
                                   handler:(void (^)(PKPaymentRequestShippingContactUpdate *update))completion;
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod
                                   handler:(void (^)(PKPaymentRequestPaymentMethodUpdate *update))completion;
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didChangeCouponCode:(NSString *)couponCode
                                   handler:(void (^)(PKPaymentRequestCouponCodeUpdate *update))completion;
@end
@interface PKPaymentAuthorizationViewController : UIViewController
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray<PKPaymentNetwork> *)supportedNetworks;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray<PKPaymentNetwork> *)supportedNetworks capabilities:(PKMerchantCapability)capabilties;
/* nil when the device cannot pay with the request's networks, or the request is incomplete */
- (nullable instancetype)initWithPaymentRequest:(PKPaymentRequest *)request;
@property (nonatomic, weak, nullable) id<PKPaymentAuthorizationViewControllerDelegate> delegate;
@end
NS_ASSUME_NONNULL_END
#endif
