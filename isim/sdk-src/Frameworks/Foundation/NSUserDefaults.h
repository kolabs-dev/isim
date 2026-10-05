#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray, NSDictionary<KeyType, ObjectType>;
/* isim: persisted as an XML plist in the app container (Library/Preferences/<bundle id>.plist). */
FOUNDATION_EXPORT NSString *const NSGlobalDomain;
@interface NSUserDefaults : NSObject
@property (class, readonly, strong) NSUserDefaults *standardUserDefaults;
- (nullable instancetype)initWithSuiteName:(nullable NSString *)suitename;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
- (nullable id)objectForKey:(NSString *)defaultName;
- (void)setObject:(nullable id)value forKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (nullable NSString *)stringForKey:(NSString *)defaultName;
- (double)doubleForKey:(NSString *)defaultName;
- (void)setDouble:(double)value forKey:(NSString *)defaultName;
- (nullable NSArray *)arrayForKey:(NSString *)defaultName;
- (nullable NSDictionary<NSString *, id> *)dictionaryForKey:(NSString *)defaultName;
- (void)registerDefaults:(NSDictionary<NSString *, id> *)registrationDictionary;
- (BOOL)synchronize;
@end
NS_ASSUME_NONNULL_END
