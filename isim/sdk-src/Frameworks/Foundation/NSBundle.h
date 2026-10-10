#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSError;
@interface NSBundle : NSObject
@property (class, readonly, strong) NSBundle *mainBundle;
+ (nullable instancetype)bundleWithPath:(NSString *)path;
- (nullable instancetype)initWithPath:(NSString *)path;
+ (NSBundle *)bundleForClass:(Class)aClass;
+ (nullable NSBundle *)bundleWithIdentifier:(NSString *)identifier;
@property (class, readonly, copy) NSArray<NSBundle *> *allBundles;
@property (class, readonly, copy) NSArray<NSBundle *> *allFrameworks;
- (BOOL)load;
@property (readonly, getter=isLoaded) BOOL loaded;
- (BOOL)unload;
- (BOOL)preflightAndReturnError:(NSError **)error;
- (BOOL)loadAndReturnError:(NSError **)error;
@property (nullable, readonly) Class principalClass;
- (nullable Class)classNamed:(NSString *)className;
@property (nullable, readonly, copy) NSString *privateFrameworksPath;
@property (nullable, readonly, copy) NSString *sharedFrameworksPath;
@property (readonly, copy) NSString *builtInPlugInsPath;
@property (readonly, copy) NSString *bundlePath;
@property (nullable, readonly, copy) NSString *resourcePath;
@property (nullable, readonly, copy) NSString *executablePath;
@property (nullable, readonly, copy) NSString *bundleIdentifier;
@property (nullable, readonly, copy) NSDictionary<NSString *, id> *infoDictionary;
- (nullable id)objectForInfoDictionaryKey:(NSString *)key;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *localizedInfoDictionary;
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext;
@property (readonly, copy) NSArray<NSString *> *localizations;
@property (readonly, copy) NSArray<NSString *> *preferredLocalizations;
@property (nullable, readonly, copy) NSString *developmentLocalization;
+ (NSArray<NSString *> *)preferredLocalizationsFromArray:(NSArray<NSString *> *)localizationsArray;
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath forLocalization:(nullable NSString *)localizationName;
- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value table:(nullable NSString *)tableName;
@end
@interface NSString (NSBundleExtensionMethods)
/* a width variation of a localized string (String Catalog / .stringsdict NSStringVariableWidthRuleType) */
- (NSString *)variantFittingPresentationWidth:(NSInteger)width;
@end
#define NSLocalizedString(key, comment) [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:nil]
#define NSLocalizedStringFromTable(key, tbl, comment) [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) [bundle localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringWithDefaultValue(key, tbl, bundle, val, comment) [bundle localizedStringForKey:(key) value:(val) table:(tbl)]
NS_ASSUME_NONNULL_END
