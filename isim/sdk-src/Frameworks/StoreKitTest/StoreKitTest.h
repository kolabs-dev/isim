#pragma once
/* isim StoreKitTest for Objective-C: SKTestSession and SKTestTransaction are the StoreKitTest Swift overlay's classes
 * (StoreKitTest.framework re-exports libswiftStoreKitTest.dylib), over isim's local store (the ledger `isim storekit`
 * edits). Simulated errors (setSimulatedError:forAPI:) are Swift-only, as in Apple's SDK. Swift uses the overlay;
 * these declarations are hidden from Swift. */
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define SKTEST_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define SKTEST_EXTERN extern __attribute__((visibility("default")))
#endif
SKTEST_EXTERN NSString * const SKTestErrorDomain;
typedef NS_ENUM(NSInteger, SKTestTimeRate) {
    SKTestTimeRateRealTime = 0, SKTestTimeRateOneSecondIsOneDay = 1, SKTestTimeRateOneRenewalEveryTwoSeconds = 2,
    SKTestTimeRateOneRenewalEveryTenSeconds = 3, SKTestTimeRateOneRenewalEveryFifteenSeconds = 4, SKTestTimeRateOneRenewalEveryThirtySeconds = 5,
    SKTestTimeRateOneRenewalEveryMinute = 6, SKTestTimeRateMonthlyRenewalEveryThirtySeconds = 7, SKTestTimeRateMonthlyRenewalEveryMinute = 8,
    SKTestTimeRateMonthlyRenewalEveryFiveMinutes = 9, SKTestTimeRateMonthlyRenewalEveryFifteenMinutes = 10,
    SKTestTimeRateMonthlyRenewalEveryThirtyMinutes = 11, SKTestTimeRateMonthlyRenewalEveryHour = 12
};
@interface SKTestTransaction : NSObject
@property (nonatomic, readonly) NSUInteger identifier;
@property (nonatomic, readonly) NSUInteger originalTransactionIdentifier;
@property (nonatomic, readonly) NSString *productIdentifier;
@property (nonatomic, readonly) NSDate *purchaseDate;
@property (nonatomic, readonly, nullable) NSDate *expirationDate;
@property (nonatomic, readonly, nullable) NSDate *revocationDate;
@property (nonatomic, readonly, nullable) NSString *webOrderLineItemID;
@property (nonatomic, readonly) SKPaymentTransactionState state;
@property (nonatomic, readonly) BOOL autoRenewingEnabled;
@property (nonatomic, readonly) BOOL hasPurchaseIssue;
@property (nonatomic, readonly) BOOL pendingAskToBuyConfirmation;
@property (nonatomic, readonly) BOOL isUpgraded;
@property (nonatomic, readonly) BOOL refunded;
@end
@interface SKTestSession : NSObject
- (nullable instancetype)initWithConfigurationFileNamed:(NSString *)configurationFileName error:(NSError **)error;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
- (void)resetToDefaultState;
@property (nonatomic, copy) NSString *storefront;
@property (nonatomic, copy) NSLocale *locale;
@property (nonatomic) BOOL disableDialogs;
- (NSArray<SKTestTransaction *> *)allTransactions;
- (BOOL)deleteTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (void)clearTransactions;
@property (nonatomic) BOOL failTransactionsEnabled;
@property (nonatomic) SKErrorCode failureError;
@property (nonatomic) BOOL interruptedPurchasesEnabled;
- (BOOL)resolveIssueForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
@property (nonatomic) BOOL askToBuyEnabled;
- (BOOL)approveAskToBuyTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)declineAskToBuyTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
@property (nonatomic) SKTestTimeRate timeRate;
- (BOOL)enableAutoRenewForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)disableAutoRenewForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)forceRenewalOfSubscriptionWithProductIdentifier:(NSString *)productIdentifier error:(NSError **)error;
- (BOOL)expireSubscriptionWithProductIdentifier:(NSString *)productIdentifier error:(NSError **)error;
@property (nonatomic) BOOL billingGracePeriodIsEnabled;
@property (nonatomic) BOOL shouldEnterBillingRetryOnRenewal;
- (BOOL)requestPriceIncreaseConsentForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)consentToPriceIncreaseForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)declinePriceIncreaseForTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)refundTransactionWithIdentifier:(NSUInteger)identifier error:(NSError **)error;
- (BOOL)buyProductWithProductIdentifier:(NSString *)productIdentifier error:(NSError **)error
    API_DEPRECATED("use buyProduct(identifier:options:) in Swift", ios(14.0, 17.0));
@end
NS_ASSUME_NONNULL_END
#endif
