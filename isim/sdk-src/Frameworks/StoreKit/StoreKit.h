#pragma once
/* isim StoreKit for Objective-C: the classes are the StoreKit Swift overlay's (StoreKit.framework re-exports
   libswiftStoreKit.dylib): SKAdNetwork and SKAdImpression (ad attribution, recorded for development postbacks), the
   App Store product page and overlay (listings from Apple's public lookup API; installing is not possible on isim) and
   the payment queue's entry points. Swift uses the overlay; these declarations are hidden from Swift. Not available from
   Objective-C yet: products, payments and transactions' members (StoreKit 1 purchases), receipts and review requests.
   The classes are not subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKAdImpression, SKOverlay, SKOverlayConfiguration, SKOverlayTransitionContext, SKStoreProductViewController, SKPaymentQueue, SKStorefront;

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
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
@optional
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions;
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
@property (nonatomic, readonly) NSArray *transactions;
@property (nonatomic, readonly, nullable) SKStorefront *storefront;
@end
NS_ASSUME_NONNULL_END
#else
@class SKAdImpression, SKAdNetwork, SKOverlay, SKStoreProductViewController, SKPaymentQueue;
#endif
