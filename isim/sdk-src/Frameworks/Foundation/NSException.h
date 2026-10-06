#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSNumber, NSDictionary<KeyType, ObjectType>;
typedef NSString *NSExceptionName;
FOUNDATION_EXPORT NSExceptionName const NSGenericException;
FOUNDATION_EXPORT NSExceptionName const NSRangeException;
FOUNDATION_EXPORT NSExceptionName const NSInvalidArgumentException;
FOUNDATION_EXPORT NSExceptionName const NSInternalInconsistencyException;
@interface NSException : NSObject <NSCopying>
+ (NSException *)exceptionWithName:(NSExceptionName)name reason:(nullable NSString *)reason userInfo:(nullable NSDictionary *)userInfo;
- (instancetype)initWithName:(NSExceptionName)aName reason:(nullable NSString *)aReason userInfo:(nullable NSDictionary *)aUserInfo;
@property (readonly, copy) NSExceptionName name;
@property (nullable, readonly, copy) NSString *reason;
@property (nullable, readonly, copy) NSDictionary *userInfo;
- (void)raise __attribute__((noreturn));
+ (void)raise:(NSExceptionName)name format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3) __attribute__((noreturn));
+ (void)raise:(NSExceptionName)name format:(NSString *)format arguments:(va_list)argList NS_FORMAT_FUNCTION(2, 0) __attribute__((noreturn));
/* return addresses / symbolicated frames recorded when the exception was thrown */
@property (readonly, copy) NSArray<NSNumber *> *callStackReturnAddresses;
@property (readonly, copy) NSArray<NSString *> *callStackSymbols;
@end
typedef void NSUncaughtExceptionHandler(NSException *exception);
FOUNDATION_EXPORT NSUncaughtExceptionHandler * _Nullable NSGetUncaughtExceptionHandler(void);
FOUNDATION_EXPORT void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * _Nullable handler);
#define NSAssert(condition, desc, ...) do { if (!(condition)) [NSException raise:NSInternalInconsistencyException format:(desc), ##__VA_ARGS__]; } while (0)
#define NSParameterAssert(condition) NSAssert((condition), @"Invalid parameter not satisfying: %s", #condition)
#define NSCAssert NSAssert
NS_ASSUME_NONNULL_END
