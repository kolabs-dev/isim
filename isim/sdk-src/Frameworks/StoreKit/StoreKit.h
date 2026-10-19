#pragma once
/* isim StoreKit for Objective-C: the classes are the StoreKit Swift overlay's (StoreKit.framework re-exports
   libswiftStoreKit.dylib): SKAdNetwork and SKAdImpression (ad attribution, recorded for development postbacks), the
   App Store product page and overlay (listings from Apple's public lookup API; installing is not possible on isim) and
   StoreKit 1 (products requests, payments, the payment queue and its transactions, receipt refresh, review requests),
   on the same local StoreKit testing ledger as Swift. Swift uses the overlay; these declarations are hidden from Swift.
   Not available from Objective-C yet: downloads. The classes are not
   subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKAdImpression, SKOverlay, SKOverlayConfiguration, SKOverlayTransitionContext, SKStoreProductViewController, SKPaymentQueue, SKStorefront;
@class SKProduct, SKProductsRequest, SKProductsResponse, SKRequest, SKPayment, SKPaymentTransaction;

FOUNDATION_EXPORT NSErrorDomain const SKErrorDomain;
typedef NS_ERROR_ENUM(SKErrorDomain, SKErrorCode) {
    SKErrorUnknown = 0, SKErrorClientInvalid = 1, SKErrorPaymentCancelled = 2, SKErrorPaymentInvalid = 3, SKErrorPaymentNotAllowed = 4,
    SKErrorStoreProductNotAvailable = 5, SKErrorCloudServicePermissionDenied = 6, SKErrorCloudServiceNetworkConnectionFailed = 7,
    SKErrorCloudServiceRevoked = 8, SKErrorPrivacyAcknowledgementRequired = 9, SKErrorUnauthorizedRequestData = 10,
    SKErrorInvalidOfferIdentifier = 11, SKErrorInvalidSignature = 12, SKErrorMissingOfferParams = 13, SKErrorInvalidOfferPrice = 14,
    SKErrorOverlayCancelled = 15, SKErrorOverlayInvalidConfiguration = 16, SKErrorOverlayTimeout = 17, SKErrorIneligibleForOffer = 18,
    SKErrorUnsupportedPlatform = 19, SKErrorOverlayPresentedInBackgroundScene = 20,
};

/* products */
typedef NS_ENUM(NSUInteger, SKProductPeriodUnit) { SKProductPeriodUnitDay = 0, SKProductPeriodUnitWeek, SKProductPeriodUnitMonth, SKProductPeriodUnitYear };
@interface SKProductSubscriptionPeriod : NSObject
@property (nonatomic, readonly) NSUInteger numberOfUnits;
@property (nonatomic, readonly) SKProductPeriodUnit unit;
@end
typedef NS_ENUM(NSUInteger, SKProductDiscountPaymentMode) {
    SKProductDiscountPaymentModePayAsYouGo = 0, SKProductDiscountPaymentModePayUpFront, SKProductDiscountPaymentModeFreeTrial,
};
typedef NS_ENUM(NSUInteger, SKProductDiscountType) { SKProductDiscountTypeIntroductory = 0, SKProductDiscountTypeSubscription };
@interface SKProductDiscount : NSObject
@property (nonatomic, readonly) NSDecimalNumber *price;
@property (nonatomic, readonly) NSLocale *priceLocale;
@property (nonatomic, readonly, nullable) NSString *identifier;
@property (nonatomic, readonly) SKProductSubscriptionPeriod *subscriptionPeriod;
@property (nonatomic, readonly) NSUInteger numberOfPeriods;
@property (nonatomic, readonly) SKProductDiscountPaymentMode paymentMode;
@property (nonatomic, readonly) SKProductDiscountType type;
@end
@interface SKProduct : NSObject
@property (nonatomic, readonly) NSString *localizedDescription;
@property (nonatomic, readonly) NSString *localizedTitle;
@property (nonatomic, readonly) NSDecimalNumber *price;
@property (nonatomic, readonly) NSLocale *priceLocale;
@property (nonatomic, readonly) NSString *productIdentifier;
@property (nonatomic, readonly, getter=isDownloadable) BOOL downloadable;
@property (nonatomic, readonly, getter=isFamilyShareable) BOOL isFamilyShareable;
@property (nonatomic, readonly) NSArray<NSNumber *> *downloadContentLengths;
@property (nonatomic, readonly) NSString *contentVersion;
@property (nonatomic, readonly) NSString *downloadContentVersion;
@property (nonatomic, readonly, nullable) SKProductSubscriptionPeriod *subscriptionPeriod;
@property (nonatomic, readonly, nullable) SKProductDiscount *introductoryPrice;
@property (nonatomic, readonly, nullable) NSString *subscriptionGroupIdentifier;
@property (nonatomic, readonly) NSArray<SKProductDiscount *> *discounts;
@end

/* requests */
@protocol SKRequestDelegate <NSObject>
@optional
- (void)requestDidFinish:(SKRequest *)request;
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error;
@end
@interface SKRequest : NSObject
@property (nonatomic, weak, nullable) id<SKRequestDelegate> delegate;
- (void)start;
- (void)cancel;
@end
@protocol SKProductsRequestDelegate <SKRequestDelegate>
@required
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
@end
@interface SKProductsResponse : NSObject
@property (nonatomic, readonly) NSArray<SKProduct *> *products;
@property (nonatomic, readonly) NSArray<NSString *> *invalidProductIdentifiers;
@end
@interface SKProductsRequest : SKRequest
- (instancetype)initWithProductIdentifiers:(NSSet<NSString *> *)productIdentifiers;
@property (nonatomic, weak, nullable) id<SKProductsRequestDelegate> delegate;
@end
FOUNDATION_EXPORT NSString * const SKReceiptPropertyIsExpired;
FOUNDATION_EXPORT NSString * const SKReceiptPropertyIsRevoked;
FOUNDATION_EXPORT NSString * const SKReceiptPropertyIsVolumePurchase;
@interface SKReceiptRefreshRequest : SKRequest
- (instancetype)init;
- (instancetype)initWithReceiptProperties:(nullable NSDictionary<NSString *, id> *)properties;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *receiptProperties;
@end

/* payments */
@interface SKPaymentDiscount : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier keyIdentifier:(NSString *)keyIdentifier nonce:(NSUUID *)nonce signature:(NSString *)signature timestamp:(NSNumber *)timestamp;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *keyIdentifier;
@property (nonatomic, copy, readonly) NSUUID *nonce;
@property (nonatomic, copy, readonly) NSString *signature;
@property (nonatomic, copy, readonly) NSNumber *timestamp;
@end
@interface SKPayment : NSObject
+ (instancetype)paymentWithProduct:(SKProduct *)product;
@property (nonatomic, copy, readonly) NSString *productIdentifier;
@property (nonatomic, copy, readonly, nullable) NSData *requestData;
@property (nonatomic, readonly) NSInteger quantity;
@property (nonatomic, copy, readonly, nullable) NSString *applicationUsername;
@property (nonatomic, readonly) BOOL simulatesAskToBuyInSandbox;
@property (nonatomic, copy, readonly, nullable) SKPaymentDiscount *paymentDiscount;
@end
@interface SKMutablePayment : SKPayment
- (instancetype)init;
@property (nonatomic, copy, readwrite) NSString *productIdentifier;
@property (nonatomic, copy, readwrite, nullable) NSData *requestData;
@property (nonatomic, readwrite) NSInteger quantity;
@property (nonatomic, copy, readwrite, nullable) NSString *applicationUsername;
@property (nonatomic, readwrite) BOOL simulatesAskToBuyInSandbox;
@property (nonatomic, copy, readwrite, nullable) SKPaymentDiscount *paymentDiscount;
@end
typedef NS_ENUM(NSInteger, SKPaymentTransactionState) {
    SKPaymentTransactionStatePurchasing = 0, SKPaymentTransactionStatePurchased, SKPaymentTransactionStateFailed,
    SKPaymentTransactionStateRestored, SKPaymentTransactionStateDeferred,
};
@interface SKPaymentTransaction : NSObject
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) SKPaymentTransaction *originalTransaction;
@property (nonatomic, readonly) SKPayment *payment;
@property (nonatomic, readonly) NSArray *downloads;
@property (nonatomic, readonly, nullable) NSDate *transactionDate;
@property (nonatomic, readonly, nullable) NSString *transactionIdentifier;
@property (nonatomic, readonly) SKPaymentTransactionState transactionState;
@end

/* the review prompt */
@interface SKStoreReviewController : NSObject
+ (void)requestReview;
+ (void)requestReviewInScene:(UIWindowScene *)windowScene;
@end

/* the app receipt (StoreKit's: signed by the device, as Xcode's local receipts) */
@interface NSBundle (SKAppStoreReceipt)
@property (nonatomic, readonly, copy, nullable) NSURL *appStoreReceiptURL;
@end

FOUNDATION_EXPORT NSErrorDomain const SKANErrorDomain;
typedef NS_ENUM(NSInteger, SKANError) {
    SKANErrorImpressionMissingRequiredValue = 0, SKANErrorUnsupported, SKANErrorAmbiguousInput, SKANErrorImpressionNotFound,
    SKANErrorInvalidCampaignIdentifier, SKANErrorInvalidConversionValue, SKANErrorInvalidSourceAppStoreIdentifier,
    SKANErrorInvalidAdvertisedAppStoreIdentifier, SKANErrorInvalidVersion, SKANErrorMismatchedSourceAppStoreIdentifier,
    SKANErrorImpressionTooShort, SKANErrorInvalidCoarseConversionValue, SKANErrorInvalidLockWindowValue,
};
typedef NSString *SKAdNetworkCoarseConversionValue NS_TYPED_ENUM;
FOUNDATION_EXPORT SKAdNetworkCoarseConversionValue const SKAdNetworkCoarseConversionValueHigh;
FOUNDATION_EXPORT SKAdNetworkCoarseConversionValue const SKAdNetworkCoarseConversionValueMedium;
FOUNDATION_EXPORT SKAdNetworkCoarseConversionValue const SKAdNetworkCoarseConversionValueLow;

@interface SKAdImpression : NSObject
- (instancetype)initWithSourceAppStoreItemIdentifier:(NSNumber *)sourceAppStoreItemIdentifier
                    advertisedAppStoreItemIdentifier:(NSNumber *)advertisedAppStoreItemIdentifier
                                 adNetworkIdentifier:(NSString *)adNetworkIdentifier adCampaignIdentifier:(NSNumber *)adCampaignIdentifier
                              adImpressionIdentifier:(NSString *)adImpressionIdentifier timestamp:(NSNumber *)timestamp
                                           signature:(NSString *)signature version:(NSString *)version;
@property (nonatomic, strong) NSNumber *sourceAppStoreItemIdentifier;
@property (nonatomic, strong) NSNumber *advertisedAppStoreItemIdentifier;
@property (nonatomic, copy) NSString *adNetworkIdentifier;
@property (nonatomic, strong) NSNumber *adCampaignIdentifier;
@property (nonatomic, strong) NSNumber *sourceIdentifier;
@property (nonatomic, copy) NSString *adImpressionIdentifier;
@property (nonatomic, copy, nullable) NSString *adType;
@property (nonatomic, copy, nullable) NSString *adDescription;
@property (nonatomic, copy, nullable) NSString *adPurchaserName;
@property (nonatomic, strong) NSNumber *timestamp;
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, copy) NSString *version;
@end
@interface SKAdNetwork : NSObject
+ (void)startImpression:(SKAdImpression *)impression completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
+ (void)endImpression:(SKAdImpression *)impression completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
+ (void)registerAppForAdNetworkAttribution __attribute__((deprecated));
+ (void)updateConversionValue:(NSInteger)conversionValue __attribute__((deprecated));
+ (void)updatePostbackConversionValue:(NSInteger)conversionValue completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
+ (void)updatePostbackConversionValue:(NSInteger)fineValue coarseValue:(SKAdNetworkCoarseConversionValue)coarseValue
                    completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
+ (void)updatePostbackConversionValue:(NSInteger)fineValue coarseValue:(SKAdNetworkCoarseConversionValue)coarseValue lockWindow:(BOOL)lockWindow
                    completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
@end

FOUNDATION_EXPORT NSString * const SKStoreProductParameterITunesItemIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterProductIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterCustomProductPageIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAffiliateToken;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterCampaignToken;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterProviderToken;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdvertisingPartnerToken;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkCampaignIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkSourceIdentifier;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkTimestamp;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkNonce;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkAttributionSignature;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkVersion;
FOUNDATION_EXPORT NSString * const SKStoreProductParameterAdNetworkSourceAppStoreIdentifier;
@protocol SKStoreProductViewControllerDelegate <NSObject>
@optional
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController;
@end
@interface SKStoreProductViewController : UIViewController
@property (nonatomic, weak, nullable) id<SKStoreProductViewControllerDelegate> delegate;
- (void)loadProductWithParameters:(NSDictionary<NSString *, id> *)parameters completionBlock:(nullable void (^)(BOOL result, NSError * _Nullable error))block;
@end

typedef NS_ENUM(NSInteger, SKOverlayPosition) { SKOverlayPositionBottom = 0, SKOverlayPositionBottomRaised = 1 };
@interface SKOverlayConfiguration : NSObject
@end
@interface SKOverlayAppConfiguration : SKOverlayConfiguration
- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier position:(SKOverlayPosition)position;
@property (nonatomic, retain) NSString *appIdentifier;
@property (nonatomic, retain, nullable) NSString *campaignToken;
@property (nonatomic, retain, nullable) NSString *providerToken;
@property (nonatomic, retain, nullable) NSString *customProductPageIdentifier;
@property (nonatomic, retain, nullable) NSString *latestReleaseID;
@property (nonatomic) SKOverlayPosition position;
@property (nonatomic) BOOL userDismissible;
- (nullable id)additionalValueForKey:(NSString *)key;
- (void)setAdditionalValue:(nullable id)value forKey:(NSString *)key;
@end
@interface SKOverlayTransitionContext : NSObject
- (void)addAnimationBlock:(void (^)(void))block;
@property (nonatomic, readonly) CGRect startFrame;
@property (nonatomic, readonly) CGRect endFrame;
@end
@protocol SKOverlayDelegate <NSObject>
@optional
- (void)storeOverlay:(SKOverlay *)overlay didFailToLoadWithError:(NSError *)error;
- (void)storeOverlay:(SKOverlay *)overlay willStartPresentation:(SKOverlayTransitionContext *)transitionContext;
- (void)storeOverlay:(SKOverlay *)overlay didFinishPresentation:(SKOverlayTransitionContext *)transitionContext;
- (void)storeOverlay:(SKOverlay *)overlay willStartDismissal:(SKOverlayTransitionContext *)transitionContext;
- (void)storeOverlay:(SKOverlay *)overlay didFinishDismissal:(SKOverlayTransitionContext *)transitionContext;
@end
@interface SKOverlay : NSObject
- (instancetype)initWithConfiguration:(SKOverlayConfiguration *)configuration;
- (void)presentInScene:(UIWindowScene *)scene;
+ (void)dismissOverlayInScene:(UIWindowScene *)scene;
@property (nonatomic, weak, nullable) id<SKOverlayDelegate> delegate;
@property (nonatomic, readonly, copy) SKOverlayConfiguration *configuration;
@end

@protocol SKPaymentTransactionObserver <NSObject>
@required
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
@optional
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
@end
@interface SKStorefront : NSObject
@property (nonatomic, readonly) NSString *countryCode;
@property (nonatomic, readonly) NSString *identifier;
@end
@interface SKPaymentQueue : NSObject
+ (instancetype)defaultQueue;
+ (BOOL)canMakePayments;
- (void)addTransactionObserver:(id<SKPaymentTransactionObserver>)observer;
- (void)removeTransactionObserver:(id<SKPaymentTransactionObserver>)observer;
- (void)addPayment:(SKPayment *)payment;
- (void)finishTransaction:(SKPaymentTransaction *)transaction;
- (void)restoreCompletedTransactions;
- (void)restoreCompletedTransactionsWithApplicationUsername:(nullable NSString *)username;
- (void)presentCodeRedemptionSheet;
@property (nonatomic, readonly) NSArray<SKPaymentTransaction *> *transactions;
@property (nonatomic, readonly, nullable) SKStorefront *storefront;
@end
NS_ASSUME_NONNULL_END
#else
@class SKAdImpression, SKAdNetwork, SKOverlay, SKStoreProductViewController, SKPaymentQueue;
#endif
