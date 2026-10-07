#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDictionary<KeyType, ObjectType>;
typedef NSString *NSErrorDomain;
typedef NSString *NSErrorUserInfoKey;
FOUNDATION_EXPORT NSErrorDomain const NSCocoaErrorDomain;
FOUNDATION_EXPORT NSErrorDomain const NSPOSIXErrorDomain;
FOUNDATION_EXPORT NSErrorDomain const NSOSStatusErrorDomain;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSLocalizedDescriptionKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSUnderlyingErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSLocalizedFailureReasonErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSLocalizedRecoverySuggestionErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSLocalizedRecoveryOptionsErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSRecoveryAttempterErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSHelpAnchorErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSDebugDescriptionErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSLocalizedFailureErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSStringEncodingErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSURLErrorKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const NSMultipleUnderlyingErrorsKey;
@class NSArray<ObjectType>;
@interface NSError : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict NS_DESIGNATED_INITIALIZER;
+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict;
@property (readonly, copy) NSErrorDomain domain;
@property (readonly) NSInteger code;
@property (readonly, copy) NSDictionary<NSErrorUserInfoKey, id> *userInfo;
@property (readonly, copy) NSString *localizedDescription;
@property (nullable, readonly, copy) NSString *localizedFailureReason;
@property (nullable, readonly, copy) NSString *localizedRecoverySuggestion;
@property (nullable, readonly, copy) NSArray<NSString *> *localizedRecoveryOptions;
@property (nullable, readonly, strong) id recoveryAttempter;
@property (nullable, readonly, copy) NSString *helpAnchor;
@property (readonly, copy) NSArray<NSError *> *underlyingErrors;
+ (void)setUserInfoValueProviderForDomain:(NSErrorDomain)errorDomain provider:(id _Nullable (^ _Nullable)(NSError *err, NSErrorUserInfoKey userInfoKey))provider NS_SWIFT_NAME(setUserInfoValueProvider(forDomain:provider:));
+ (id _Nullable (^ _Nullable)(NSError *err, NSErrorUserInfoKey userInfoKey))userInfoValueProviderForDomain:(NSErrorDomain)errorDomain;
@end
NS_ASSUME_NONNULL_END
