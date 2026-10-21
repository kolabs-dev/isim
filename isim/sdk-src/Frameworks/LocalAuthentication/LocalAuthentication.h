#pragma once
/* isim LocalAuthentication for Objective-C: the classes are the LocalAuthentication Swift overlay's
   (LocalAuthentication.framework re-exports libswiftLocalAuthentication.dylib): the same simulated Face ID / Touch ID
   (an alert stands in for the scan; `biometry match|nomatch|enrolled on|off` script commands), lockout after five
   failures, rights with P-256 keys kept in the app's container. Swift uses the overlay; these declarations are hidden
   from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <Security/Security.h>

/* LAPublicDefines.h */
#define kLAPolicyDeviceOwnerAuthenticationWithBiometrics 1
#define kLAPolicyDeviceOwnerAuthentication 2
#define kLAPolicyDeviceOwnerAuthenticationWithWatch 3
#define kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch 4
#define kLAPolicyDeviceOwnerAuthenticationWithWristDetection 5
#define kLAPolicyDeviceOwnerAuthenticationWithCompanion 6
#define kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrCompanion 7
#define kLAOptionUserFallback 1
#define kLAOptionAuthenticationReason 2
#define kLACredentialTypeApplicationPassword 0
#define kLACredentialSmartCardPIN -3
#define kLAErrorDomain "com.apple.LocalAuthentication"
#define kLAErrorAuthenticationFailed -1
#define kLAErrorUserCancel -2
#define kLAErrorUserFallback -3
#define kLAErrorSystemCancel -4
#define kLAErrorPasscodeNotSet -5
#define kLAErrorTouchIDNotAvailable -6
#define kLAErrorTouchIDNotEnrolled -7
#define kLAErrorTouchIDLockout -8
#define kLAErrorBiometryNotAvailable -6
#define kLAErrorBiometryNotEnrolled -7
#define kLAErrorBiometryLockout -8
#define kLAErrorAppCancel -9
#define kLAErrorInvalidContext -10
#define kLAErrorWatchNotAvailable -11
#define kLAErrorCompanionNotAvailable -11
#define kLAErrorBiometryNotPaired -12
#define kLAErrorBiometryDisconnected -13
#define kLAErrorInvalidDimensions -14
#define kLAErrorNotInteractive -1004
#define kLAAccessControlOperationCreateItem 0
#define kLAAccessControlOperationUseItem 1
#define kLAAccessControlOperationCreateKey 2
#define kLAAccessControlOperationUseKeySign 3
#define kLAAccessControlOperationUseKeyDecrypt 4
#define kLAAccessControlOperationUseKeyKeyExchange 5
#define kLABiometryTypeNone 0
#define kLABiometryTypeTouchID 1
#define kLABiometryTypeFaceID 2
#define kLABiometryTypeOpticID 4
#define kLACompanionTypeNone 0
#define kLACompanionTypeWatch 1
#define kLACompanionTypeMac 2
#define kLACompanionTypeVision 4

#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

/* LAError.h */
FOUNDATION_EXPORT NSErrorDomain const LAErrorDomain;
typedef NS_ERROR_ENUM(LAErrorDomain, LAError) {
    LAErrorAuthenticationFailed = kLAErrorAuthenticationFailed,
    LAErrorUserCancel = kLAErrorUserCancel,
    LAErrorUserFallback = kLAErrorUserFallback,
    LAErrorSystemCancel = kLAErrorSystemCancel,
    LAErrorPasscodeNotSet = kLAErrorPasscodeNotSet,
    LAErrorTouchIDNotAvailable = kLAErrorTouchIDNotAvailable,
    LAErrorTouchIDNotEnrolled = kLAErrorTouchIDNotEnrolled,
    LAErrorTouchIDLockout = kLAErrorTouchIDLockout,
    LAErrorAppCancel = kLAErrorAppCancel,
    LAErrorInvalidContext = kLAErrorInvalidContext,
    LAErrorBiometryNotAvailable = kLAErrorBiometryNotAvailable,
    LAErrorBiometryNotEnrolled = kLAErrorBiometryNotEnrolled,
    LAErrorBiometryLockout = kLAErrorBiometryLockout,
    LAErrorNotInteractive = kLAErrorNotInteractive,
    LAErrorCompanionNotAvailable API_AVAILABLE(ios(18.0)) = kLAErrorCompanionNotAvailable,
};

/* LAContext.h */
typedef NS_ENUM(NSInteger, LAPolicy) {
    LAPolicyDeviceOwnerAuthenticationWithBiometrics = kLAPolicyDeviceOwnerAuthenticationWithBiometrics,
    LAPolicyDeviceOwnerAuthentication = kLAPolicyDeviceOwnerAuthentication,
    LAPolicyDeviceOwnerAuthenticationWithCompanion API_AVAILABLE(ios(18.0)) = kLAPolicyDeviceOwnerAuthenticationWithCompanion,
    LAPolicyDeviceOwnerAuthenticationWithBiometricsOrCompanion API_AVAILABLE(ios(18.0)) = kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrCompanion,
};

FOUNDATION_EXPORT const NSTimeInterval LATouchIDAuthenticationMaximumAllowableReuseDuration;

typedef NS_ENUM(NSInteger, LACredentialType) {
    LACredentialTypeApplicationPassword = kLACredentialTypeApplicationPassword,
};

typedef NS_ENUM(NSInteger, LAAccessControlOperation) {
    LAAccessControlOperationCreateItem = kLAAccessControlOperationCreateItem,
    LAAccessControlOperationUseItem = kLAAccessControlOperationUseItem,
    LAAccessControlOperationCreateKey = kLAAccessControlOperationCreateKey,
    LAAccessControlOperationUseKeySign = kLAAccessControlOperationUseKeySign,
    LAAccessControlOperationUseKeyDecrypt = kLAAccessControlOperationUseKeyDecrypt,
    LAAccessControlOperationUseKeyKeyExchange = kLAAccessControlOperationUseKeyKeyExchange,
};

typedef NS_ENUM(NSInteger, LABiometryType) {
    LABiometryTypeNone = kLABiometryTypeNone,
    LABiometryNone API_DEPRECATED_WITH_REPLACEMENT("LABiometryTypeNone", ios(11.0, 11.2)) = kLABiometryTypeNone,
    LABiometryTypeTouchID = kLABiometryTypeTouchID,
    LABiometryTypeFaceID = kLABiometryTypeFaceID,
    LABiometryTypeOpticID API_AVAILABLE(ios(17.0)) = kLABiometryTypeOpticID,
};

typedef NS_ENUM(NSInteger, LACompanionType) {
    LACompanionTypeWatch = kLACompanionTypeWatch,
    LACompanionTypeMac = kLACompanionTypeMac,
    LACompanionTypeVision = kLACompanionTypeVision,
} API_AVAILABLE(ios(18.0));

/* LADomainState.h (iOS 18) */
API_AVAILABLE(ios(18.0)) @interface LADomainStateBiometry : NSObject
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, nullable, readonly) NSData *stateHash;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0)) @interface LADomainStateCompanion : NSObject
@property (nonatomic, readonly) NSSet<NSNumber *> *availableCompanionTypes;
@property (nonatomic, nullable, readonly) NSData *stateHash;
- (nullable NSData *)stateHashForCompanionType:(LACompanionType)companionType;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0)) @interface LADomainState : NSObject
@property (nonatomic, readonly) LADomainStateBiometry *biometry;
@property (nonatomic, readonly) LADomainStateCompanion *companion;
@property (nonatomic, nullable, readonly) NSData *stateHash;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface LAContext : NSObject
- (BOOL)canEvaluatePolicy:(LAPolicy)policy error:(NSError **)error;
- (void)evaluatePolicy:(LAPolicy)policy localizedReason:(NSString *)localizedReason reply:(void (^)(BOOL success, NSError * _Nullable error))reply;
- (void)invalidate;
- (BOOL)setCredential:(nullable NSData *)credential type:(LACredentialType)type;
- (BOOL)isCredentialSet:(LACredentialType)type;
- (void)evaluateAccessControl:(SecAccessControlRef)accessControl operation:(LAAccessControlOperation)operation
              localizedReason:(NSString *)localizedReason reply:(void (^)(BOOL success, NSError * _Nullable error))reply;
@property (nonatomic, nullable, copy) NSString *localizedFallbackTitle;
@property (nonatomic, nullable, copy) NSString *localizedCancelTitle;
@property (nonatomic) NSTimeInterval touchIDAuthenticationAllowableReuseDuration;
@property (nonatomic, copy) NSString *localizedReason;
@property (nonatomic) BOOL interactionNotAllowed;
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, nullable, readonly) NSData *evaluatedPolicyDomainState;
@property (nonatomic, readonly) LADomainState *domainState API_AVAILABLE(ios(18.0));
@end

/* LAEnvironment.h (iOS 18) */
@class LAEnvironment, LAEnvironmentState;

API_AVAILABLE(ios(18.0)) @protocol LAEnvironmentObserver <NSObject>
@optional
- (void)environment:(LAEnvironment *)environment stateDidChangeFromOldState:(LAEnvironmentState *)oldState;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironmentMechanism : NSObject
@property (nonatomic, readonly) BOOL isUsable;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *iconSystemName;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironmentMechanismBiometry : LAEnvironmentMechanism
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, readonly) BOOL isEnrolled;
@property (nonatomic, readonly) BOOL isLockedOut;
@property (nonatomic, readonly) NSData *stateHash;
@property (nonatomic, readonly) BOOL builtInSensorInaccessible;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironmentMechanismUserPassword : LAEnvironmentMechanism
@property (nonatomic, readonly) BOOL isSet;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironmentMechanismCompanion : LAEnvironmentMechanism
@property (nonatomic, readonly) LACompanionType type;
@property (nonatomic, nullable, readonly) NSData *stateHash;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironmentState : NSObject
@property (nonatomic, nullable, readonly) LAEnvironmentMechanismBiometry *biometry;
@property (nonatomic, nullable, readonly) LAEnvironmentMechanismUserPassword *userPassword;
@property (nonatomic, readonly) NSArray<LAEnvironmentMechanismCompanion *> *companions;
@property (nonatomic, readonly) NSArray<LAEnvironmentMechanism *> *allMechanisms;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.0)) @interface LAEnvironment : NSObject
@property (class, nonatomic, readonly) LAEnvironment *currentUser;
@property (nonatomic, readonly) LAEnvironmentState *state;
- (void)addObserver:(id<LAEnvironmentObserver>)observer;
- (void)removeObserver:(id<LAEnvironmentObserver>)observer;
- (instancetype)init NS_UNAVAILABLE;
@end

/* LAAuthenticationRequirement.h, LARight.h, LAPersistedRight.h, LAPrivateKey.h, LAPublicKey.h, LASecret.h, LARightStore.h */
API_AVAILABLE(ios(16.0)) @interface LABiometryFallbackRequirement : NSObject
@property (class, readonly) LABiometryFallbackRequirement *defaultRequirement;
@property (class, readonly) LABiometryFallbackRequirement *devicePasscodeRequirement;
@end

API_AVAILABLE(ios(16.0)) @interface LAAuthenticationRequirement : NSObject
@property (class, readonly) LAAuthenticationRequirement *defaultRequirement;
@property (class, readonly) LAAuthenticationRequirement *biometryRequirement;
@property (class, readonly) LAAuthenticationRequirement *biometryCurrentSetRequirement;
+ (LAAuthenticationRequirement *)biometryRequirementWithFallback:(LABiometryFallbackRequirement *)fallback;
@end

typedef NS_ENUM(NSInteger, LARightState) {
    LARightStateUnknown = 0,
    LARightStateAuthorizing = 1,
    LARightStateAuthorized = 2,
    LARightStateNotAuthorized = 3,
} API_AVAILABLE(ios(16.0));

API_AVAILABLE(ios(16.0)) @interface LARight : NSObject
@property (nonatomic, readonly) LARightState state;
@property (nonatomic) NSInteger tag;
- (instancetype)init;
- (instancetype)initWithRequirement:(LAAuthenticationRequirement *)requirement;
- (void)authorizeWithLocalizedReason:(NSString *)localizedReason completion:(void (^)(NSError * _Nullable error))handler;
- (void)checkCanAuthorizeWithCompletion:(void (^)(NSError * _Nullable error))handler;
- (void)deauthorizeWithCompletion:(void (^)(void))handler;
@end

API_AVAILABLE(ios(16.0)) @interface LAPublicKey : NSObject
- (void)exportBytesWithCompletion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))handler;
- (void)encryptData:(NSData *)data secKeyAlgorithm:(SecKeyAlgorithm)algorithm completion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))handler;
- (BOOL)canEncryptUsingSecKeyAlgorithm:(SecKeyAlgorithm)algorithm;
- (void)verifyData:(NSData *)signedData signature:(NSData *)signature secKeyAlgorithm:(SecKeyAlgorithm)algorithm
        completion:(void (^)(NSError * _Nullable error))handler;
- (BOOL)canVerifyUsingSecKeyAlgorithm:(SecKeyAlgorithm)algorithm;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(16.0)) @interface LAPrivateKey : NSObject
@property (nonatomic, readonly) LAPublicKey *publicKey;
- (void)signData:(NSData *)data secKeyAlgorithm:(SecKeyAlgorithm)algorithm completion:(void (^)(NSData * _Nullable signature, NSError * _Nullable error))handler;
- (BOOL)canSignUsingSecKeyAlgorithm:(SecKeyAlgorithm)algorithm;
- (void)decryptData:(NSData *)data secKeyAlgorithm:(SecKeyAlgorithm)algorithm completion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))handler;
- (BOOL)canDecryptUsingSecKeyAlgorithm:(SecKeyAlgorithm)algorithm;
- (void)exchangeKeysWithPublicKey:(NSData *)publicKey secKeyAlgorithm:(SecKeyAlgorithm)algorithm secKeyParameters:(NSDictionary *)parameters
                       completion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))handler;
- (BOOL)canExchangeKeysUsingSecKeyAlgorithm:(SecKeyAlgorithm)algorithm;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(16.0)) @interface LASecret : NSObject
- (void)loadDataWithCompletion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))handler;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(16.0)) @interface LAPersistedRight : LARight
@property (nonatomic, readonly) LAPrivateKey *key;
@property (nonatomic, readonly) LASecret *secret;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(16.0)) @interface LARightStore : NSObject
@property (class, readonly) LARightStore *sharedStore;
- (void)rightForIdentifier:(NSString *)identifier completion:(void (^)(LAPersistedRight * _Nullable right, NSError * _Nullable error))handler;
- (void)saveRight:(LARight *)right identifier:(NSString *)identifier completion:(void (^)(LAPersistedRight * _Nullable right, NSError * _Nullable error))handler;
- (void)saveRight:(LARight *)right identifier:(NSString *)identifier secret:(NSData *)secret
       completion:(void (^)(LAPersistedRight * _Nullable right, NSError * _Nullable error))handler;
- (void)removeRight:(LAPersistedRight *)right completion:(void (^)(NSError * _Nullable error))handler;
- (void)removeRightForIdentifier:(NSString *)identifier completion:(void (^)(NSError * _Nullable error))handler;
- (void)removeAllRightsWithCompletion:(void (^)(NSError * _Nullable error))handler;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
