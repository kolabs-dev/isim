#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDictionary<KeyType, ObjectType>;
@interface NSBundle : NSObject
@property (class, readonly, strong) NSBundle *mainBundle;
@property (readonly, copy) NSString *bundlePath;
@property (nullable, readonly, copy) NSString *resourcePath;
@property (nullable, readonly, copy) NSString *executablePath;
@property (nullable, readonly, copy) NSString *bundleIdentifier;
@property (nullable, readonly, copy) NSDictionary<NSString *, id> *infoDictionary;
- (nullable id)objectForInfoDictionaryKey:(NSString *)key;
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext;
- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value table:(nullable NSString *)tableName;
@end
#define NSLocalizedString(key, comment) [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:nil]
NS_ASSUME_NONNULL_END
