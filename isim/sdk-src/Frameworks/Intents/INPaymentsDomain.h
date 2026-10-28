/* isim Intents: the payments domain (sending and requesting money) and the payment types the rides domain shares
 * (issue #411). Imported by <Intents/Intents.h>. isim: "send NAME $20 for dinner", "request $15 from NAME" (or
 * `siri intent SendPayment payee=NAME amount=20 note=TEXT`); Siri confirms a payment before handling it, as iOS does. */
#pragma once
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INPaymentMethodType) {
    INPaymentMethodTypeUnknown = 0,
    INPaymentMethodTypeChecking,
    INPaymentMethodTypeSavings,
    INPaymentMethodTypeBrokerage,
    INPaymentMethodTypeDebit,
    INPaymentMethodTypeCredit,
    INPaymentMethodTypePrepaid,
    INPaymentMethodTypeStore,
    INPaymentMethodTypeApplePay,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INPaymentMethod : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithType:(INPaymentMethodType)type name:(nullable NSString *)name identificationHint:(nullable NSString *)identificationHint icon:(nullable INImage *)icon NS_DESIGNATED_INITIALIZER;
+ (instancetype)applePayPaymentMethod;
@property (readonly) INPaymentMethodType type;
@property (readonly, copy, nullable) NSString *name;
@property (readonly, copy, nullable) INImage *icon;
@property (readonly, copy, nullable) NSString *identificationHint;
@end
API_AVAILABLE(ios(11.0))
@interface INPaymentMethodResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedPaymentMethod:(INPaymentMethod *)resolvedPaymentMethod NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithPaymentMethodsToDisambiguate:(NSArray<INPaymentMethod *> *)paymentMethodsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithPaymentMethodToConfirm:(nullable INPaymentMethod *)paymentMethodToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end

typedef NS_ENUM(NSInteger, INPaymentStatus) {
    INPaymentStatusUnknown = 0,
    INPaymentStatusPending,
    INPaymentStatusCompleted,
    INPaymentStatusCanceled,
    INPaymentStatusFailed,
    INPaymentStatusUnpaid API_AVAILABLE(ios(10.3)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.3))
@interface INPaymentStatusResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedPaymentStatus:(INPaymentStatus)resolvedPaymentStatus NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithPaymentStatusToConfirm:(INPaymentStatus)paymentStatusToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
API_AVAILABLE(ios(10.0))
@interface INPaymentRecord : NSObject <NSCopying, NSSecureCoding>
- (nullable instancetype)initWithPayee:(nullable INPerson *)payee payer:(nullable INPerson *)payer currencyAmount:(nullable INCurrencyAmount *)currencyAmount paymentMethod:(nullable INPaymentMethod *)paymentMethod note:(nullable NSString *)note status:(INPaymentStatus)status feeAmount:(nullable INCurrencyAmount *)feeAmount NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(11.0));
- (nullable instancetype)initWithPayee:(nullable INPerson *)payee payer:(nullable INPerson *)payer currencyAmount:(nullable INCurrencyAmount *)currencyAmount paymentMethod:(nullable INPaymentMethod *)paymentMethod note:(nullable NSString *)note status:(INPaymentStatus)status;
@property (readonly, copy, nullable) INPerson *payee;
@property (readonly, copy, nullable) INPerson *payer;
@property (readonly, copy, nullable) INCurrencyAmount *currencyAmount;
@property (readonly, copy, nullable) NSString *note;
@property (readonly) INPaymentStatus status;
@property (readonly, copy, nullable) INPaymentMethod *paymentMethod;
@property (readonly, copy, nullable) INCurrencyAmount *feeAmount API_AVAILABLE(ios(11.0));
@end

/* accounts and amounts (an account a payment is made from, an amount due) */
typedef NS_ENUM(NSInteger, INAccountType) {
    INAccountTypeUnknown = 0,
    INAccountTypeChecking,
    INAccountTypeCredit,
    INAccountTypeDebit,
    INAccountTypeInvestment,
    INAccountTypeMortgage,
    INAccountTypePrepaid,
    INAccountTypeSaving,
} API_AVAILABLE(ios(10.3));
typedef NS_ENUM(NSInteger, INBalanceType) {
    INBalanceTypeUnknown = 0,
    INBalanceTypeMoney,
    INBalanceTypePoints,
    INBalanceTypeMiles,
} API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSInteger, INAmountType) {
    INAmountTypeUnknown = 0,
    INAmountTypeMinimumDue,
    INAmountTypeAmountDue,
    INAmountTypeCurrentBalance,
    INAmountTypeMaximumTransferAmount API_AVAILABLE(ios(12.0)),
    INAmountTypeMinimumTransferAmount API_AVAILABLE(ios(12.0)),
    INAmountTypeStatementBalance API_AVAILABLE(ios(12.0)),
} API_AVAILABLE(ios(10.3));
API_AVAILABLE(ios(11.0))
@interface INBalanceAmount : NSObject <NSCopying, NSSecureCoding>
- (nullable instancetype)initWithAmount:(NSDecimalNumber *)amount balanceType:(INBalanceType)balanceType NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithAmount:(NSDecimalNumber *)amount currencyCode:(NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSDecimalNumber *amount;
@property (readonly) INBalanceType balanceType;
@property (readonly, copy, nullable) NSString *currencyCode;
@end
API_AVAILABLE(ios(10.3))
@interface INPaymentAmount : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithAmountType:(INAmountType)amountType amount:(INCurrencyAmount *)amount NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) INCurrencyAmount *amount;
@property (readonly) INAmountType amountType;
@end
API_AVAILABLE(ios(11.0))
@interface INPaymentAmountResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedPaymentAmount:(INPaymentAmount *)resolvedPaymentAmount NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithPaymentAmountsToDisambiguate:(NSArray<INPaymentAmount *> *)paymentAmountsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithPaymentAmountToConfirm:(nullable INPaymentAmount *)paymentAmountToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
API_AVAILABLE(ios(10.3))
@interface INPaymentAccount : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithNickname:(INSpeakableString *)nickname number:(nullable NSString *)number accountType:(INAccountType)accountType organizationName:(nullable INSpeakableString *)organizationName balance:(nullable INBalanceAmount *)balance secondaryBalance:(nullable INBalanceAmount *)secondaryBalance NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(11.0));
- (nullable instancetype)initWithNickname:(INSpeakableString *)nickname number:(nullable NSString *)number accountType:(INAccountType)accountType organizationName:(nullable INSpeakableString *)organizationName;
@property (readonly, copy, nullable) INSpeakableString *nickname;
@property (readonly, copy, nullable) NSString *accountNumber;
@property (readonly) INAccountType accountType;
@property (readonly, copy, nullable) INSpeakableString *organizationName;
@property (readonly, copy, nullable) INBalanceAmount *balance API_AVAILABLE(ios(11.0));
@property (readonly, copy, nullable) INBalanceAmount *secondaryBalance API_AVAILABLE(ios(11.0));
@end
API_AVAILABLE(ios(11.0))
@interface INPaymentAccountResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedPaymentAccount:(INPaymentAccount *)resolvedPaymentAccount NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithPaymentAccountsToDisambiguate:(NSArray<INPaymentAccount *> *)paymentAccountsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithPaymentAccountToConfirm:(nullable INPaymentAccount *)paymentAccountToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end

/* ---------------- sending money ---------------- */
API_AVAILABLE(ios(10.0))
@interface INSendPaymentIntent : INIntent
- (instancetype)initWithPayee:(nullable INPerson *)payee currencyAmount:(nullable INCurrencyAmount *)currencyAmount note:(nullable NSString *)note;
@property (readonly, copy, nullable) INPerson *payee;
@property (readonly, copy, nullable) INCurrencyAmount *currencyAmount;
@property (readonly, copy, nullable) NSString *note;
@end
typedef NS_ENUM(NSInteger, INSendPaymentIntentResponseCode) {
    INSendPaymentIntentResponseCodeUnspecified = 0,
    INSendPaymentIntentResponseCodeReady,
    INSendPaymentIntentResponseCodeInProgress,
    INSendPaymentIntentResponseCodeSuccess,
    INSendPaymentIntentResponseCodeFailure,
    INSendPaymentIntentResponseCodeFailureRequiringAppLaunch,
    INSendPaymentIntentResponseCodeFailureCredentialsUnverified,
    INSendPaymentIntentResponseCodeFailurePaymentsAmountBelowMinimum,
    INSendPaymentIntentResponseCodeFailurePaymentsAmountAboveMaximum,
    INSendPaymentIntentResponseCodeFailurePaymentsCurrencyUnsupported,
    INSendPaymentIntentResponseCodeFailureInsufficientFunds,
    INSendPaymentIntentResponseCodeFailureNoBankAccount API_AVAILABLE(ios(11.0)),
    INSendPaymentIntentResponseCodeFailureNotEligible API_AVAILABLE(ios(11.1)),
    INSendPaymentIntentResponseCodeFailureTermsAndConditionsAcceptanceRequired API_AVAILABLE(ios(11.1)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INSendPaymentIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSendPaymentIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSendPaymentIntentResponseCode code;
@property (copy, nullable) INPaymentRecord *paymentRecord;
@end
typedef NS_ENUM(NSInteger, INSendPaymentPayeeUnsupportedReason) {
    INSendPaymentPayeeUnsupportedReasonCredentialsUnverified = 1,
    INSendPaymentPayeeUnsupportedReasonInsufficientFunds,
    INSendPaymentPayeeUnsupportedReasonNoAccount,
    INSendPaymentPayeeUnsupportedReasonNoValidHandle API_AVAILABLE(ios(11.1)),
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INSendPaymentPayeeResolutionResult : INPersonResolutionResult
+ (instancetype)unsupportedForReason:(INSendPaymentPayeeUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult;
@end
typedef NS_ENUM(NSInteger, INSendPaymentCurrencyAmountUnsupportedReason) {
    INSendPaymentCurrencyAmountUnsupportedReasonPaymentsAmountBelowMinimum = 1,
    INSendPaymentCurrencyAmountUnsupportedReasonPaymentsAmountAboveMaximum,
    INSendPaymentCurrencyAmountUnsupportedReasonPaymentsCurrencyUnsupported,
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INSendPaymentCurrencyAmountResolutionResult : INCurrencyAmountResolutionResult
+ (instancetype)unsupportedForReason:(INSendPaymentCurrencyAmountUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithCurrencyAmountResolutionResult:(INCurrencyAmountResolutionResult *)currencyAmountResolutionResult;
@end
API_AVAILABLE(ios(10.0))
@protocol INSendPaymentIntentHandling <NSObject>
@required
- (void)handleSendPayment:(INSendPaymentIntent *)intent completion:(void (^)(INSendPaymentIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmSendPayment:(INSendPaymentIntent *)intent completion:(void (^)(INSendPaymentIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolvePayeeForSendPayment:(INSendPaymentIntent *)intent withCompletion:(void (^)(INPersonResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePayee(for:with:)) API_DEPRECATED("resolvePayeeForSendPayment:withCompletion: is deprecated. Use resolvePayeeForSendPayment:completion: instead", ios(10.0, 11.0));
- (void)resolvePayeeForSendPayment:(INSendPaymentIntent *)intent completion:(void (^)(INSendPaymentPayeeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePayee(for:with:)) API_AVAILABLE(ios(11.0));
- (void)resolveCurrencyAmountForSendPayment:(INSendPaymentIntent *)intent withCompletion:(void (^)(INCurrencyAmountResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveCurrencyAmount(for:with:)) API_DEPRECATED("resolveCurrencyAmountForSendPayment:withCompletion: is deprecated. Use resolveCurrencyAmountForSendPayment:completion: instead", ios(10.0, 11.0));
- (void)resolveCurrencyAmountForSendPayment:(INSendPaymentIntent *)intent completion:(void (^)(INSendPaymentCurrencyAmountResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveCurrencyAmount(for:with:)) API_AVAILABLE(ios(11.0));
- (void)resolveNoteForSendPayment:(INSendPaymentIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveNote(for:with:));
@end

/* ---------------- requesting money ---------------- */
API_AVAILABLE(ios(10.0))
@interface INRequestPaymentIntent : INIntent
- (instancetype)initWithPayer:(nullable INPerson *)payer currencyAmount:(nullable INCurrencyAmount *)currencyAmount note:(nullable NSString *)note;
@property (readonly, copy, nullable) INPerson *payer;
@property (readonly, copy, nullable) INCurrencyAmount *currencyAmount;
@property (readonly, copy, nullable) NSString *note;
@end
typedef NS_ENUM(NSInteger, INRequestPaymentIntentResponseCode) {
    INRequestPaymentIntentResponseCodeUnspecified = 0,
    INRequestPaymentIntentResponseCodeReady,
    INRequestPaymentIntentResponseCodeInProgress,
    INRequestPaymentIntentResponseCodeSuccess,
    INRequestPaymentIntentResponseCodeFailure,
    INRequestPaymentIntentResponseCodeFailureRequiringAppLaunch,
    INRequestPaymentIntentResponseCodeFailureCredentialsUnverified,
    INRequestPaymentIntentResponseCodeFailurePaymentsAmountBelowMinimum,
    INRequestPaymentIntentResponseCodeFailurePaymentsAmountAboveMaximum,
    INRequestPaymentIntentResponseCodeFailurePaymentsCurrencyUnsupported,
    INRequestPaymentIntentResponseCodeFailureNoBankAccount API_AVAILABLE(ios(11.0)),
    INRequestPaymentIntentResponseCodeFailureNotEligible API_AVAILABLE(ios(11.1)),
    INRequestPaymentIntentResponseCodeFailureTermsAndConditionsAcceptanceRequired API_AVAILABLE(ios(11.1)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INRequestPaymentIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INRequestPaymentIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INRequestPaymentIntentResponseCode code;
@property (copy, nullable) INPaymentRecord *paymentRecord;
@end
typedef NS_ENUM(NSInteger, INRequestPaymentPayerUnsupportedReason) {
    INRequestPaymentPayerUnsupportedReasonCredentialsUnverified = 1,
    INRequestPaymentPayerUnsupportedReasonNoAccount,
    INRequestPaymentPayerUnsupportedReasonNoValidHandle API_AVAILABLE(ios(11.1)),
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INRequestPaymentPayerResolutionResult : INPersonResolutionResult
+ (instancetype)unsupportedForReason:(INRequestPaymentPayerUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult;
@end
typedef NS_ENUM(NSInteger, INRequestPaymentCurrencyAmountUnsupportedReason) {
    INRequestPaymentCurrencyAmountUnsupportedReasonPaymentsAmountBelowMinimum = 1,
    INRequestPaymentCurrencyAmountUnsupportedReasonPaymentsAmountAboveMaximum,
    INRequestPaymentCurrencyAmountUnsupportedReasonPaymentsCurrencyUnsupported,
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INRequestPaymentCurrencyAmountResolutionResult : INCurrencyAmountResolutionResult
+ (instancetype)unsupportedForReason:(INRequestPaymentCurrencyAmountUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithCurrencyAmountResolutionResult:(INCurrencyAmountResolutionResult *)currencyAmountResolutionResult;
@end
API_AVAILABLE(ios(10.0))
@protocol INRequestPaymentIntentHandling <NSObject>
@required
- (void)handleRequestPayment:(INRequestPaymentIntent *)intent completion:(void (^)(INRequestPaymentIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmRequestPayment:(INRequestPaymentIntent *)intent completion:(void (^)(INRequestPaymentIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolvePayerForRequestPayment:(INRequestPaymentIntent *)intent withCompletion:(void (^)(INPersonResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePayer(for:with:)) API_DEPRECATED("resolvePayerForRequestPayment:withCompletion: is deprecated. Use resolvePayerForRequestPayment:completion: instead", ios(10.0, 11.0));
- (void)resolvePayerForRequestPayment:(INRequestPaymentIntent *)intent completion:(void (^)(INRequestPaymentPayerResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePayer(for:with:)) API_AVAILABLE(ios(11.0));
- (void)resolveCurrencyAmountForRequestPayment:(INRequestPaymentIntent *)intent withCompletion:(void (^)(INCurrencyAmountResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveCurrencyAmount(for:with:)) API_DEPRECATED("resolveCurrencyAmountForRequestPayment:withCompletion: is deprecated. Use resolveCurrencyAmountForRequestPayment:completion: instead", ios(10.0, 11.0));
- (void)resolveCurrencyAmountForRequestPayment:(INRequestPaymentIntent *)intent completion:(void (^)(INRequestPaymentCurrencyAmountResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveCurrencyAmount(for:with:)) API_AVAILABLE(ios(11.0));
- (void)resolveNoteForRequestPayment:(INRequestPaymentIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveNote(for:with:));
@end

/* the payments domain: an app that handles every payments intent isim implements */
API_AVAILABLE(ios(10.0))
@protocol INPaymentsDomainHandling <INSendPaymentIntentHandling, INRequestPaymentIntentHandling>
@end

INTENTS_EXTERN NSString *const INSendPaymentIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INRequestPaymentIntentIdentifier API_AVAILABLE(ios(10.0));

NS_ASSUME_NONNULL_END
