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
@interface NSError : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict NS_DESIGNATED_INITIALIZER;
+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)dict;
@property (readonly, copy) NSErrorDomain domain;
@property (readonly) NSInteger code;
@property (readonly, copy) NSDictionary<NSErrorUserInfoKey, id> *userInfo;
@property (readonly, copy) NSString *localizedDescription;
@property (nullable, readonly, copy) NSString *localizedFailureReason;
@end
NS_ASSUME_NONNULL_END
