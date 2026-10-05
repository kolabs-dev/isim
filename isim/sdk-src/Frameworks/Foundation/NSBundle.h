#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>;
@interface NSBundle : NSObject
@property (class, readonly, strong) NSBundle *mainBundle;
@property (readonly, copy) NSString *bundlePath;
@property (nullable, readonly, copy) NSString *resourcePath;
@property (nullable, readonly, copy) NSString *executablePath;
@property (nullable, readonly, copy) NSString *bundleIdentifier;
@property (nullable, readonly, copy) NSDictionary<NSString *, id> *infoDictionary;
- (nullable id)objectForInfoDictionaryKey:(NSString *)key;
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext;
@property (readonly, copy) NSArray<NSString *> *localizations;
@property (readonly, copy) NSArray<NSString *> *preferredLocalizations;
@property (nullable, readonly, copy) NSString *developmentLocalization;
+ (NSArray<NSString *> *)preferredLocalizationsFromArray:(NSArray<NSString *> *)localizationsArray;
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath forLocalization:(nullable NSString *)localizationName;
- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value table:(nullable NSString *)tableName;
@end
#define NSLocalizedString(key, comment) [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:nil]
#define NSLocalizedStringFromTable(key, tbl, comment) [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) [bundle localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringWithDefaultValue(key, tbl, bundle, val, comment) [bundle localizedStringForKey:(key) value:(val) table:(tbl)]
NS_ASSUME_NONNULL_END
