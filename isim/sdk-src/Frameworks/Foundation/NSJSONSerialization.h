#pragma once
/* isim Foundation: NSJSONSerialization for Objective-C (self-authored; Swift code uses the Foundation overlay's
 * JSONSerialization). UTF-8 JSON (a UTF-8 BOM is skipped); numbers become NSNumber (integers stay integers), true/false
 * boolean NSNumbers, null NSNull. Streams are not supported. */
#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>
#import <Foundation/NSError.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSJSONReadingOptions) {
    NSJSONReadingMutableContainers = (1UL << 0),
    NSJSONReadingMutableLeaves = (1UL << 1),
    NSJSONReadingFragmentsAllowed = (1UL << 2),
    NSJSONReadingJSON5Allowed API_AVAILABLE(ios(15.0)) = (1UL << 3),
    NSJSONReadingTopLevelDictionaryAssumed API_AVAILABLE(ios(15.0)) = (1UL << 4),
    NSJSONReadingAllowFragments = NSJSONReadingFragmentsAllowed,
};
typedef NS_OPTIONS(NSUInteger, NSJSONWritingOptions) {
    NSJSONWritingPrettyPrinted = (1UL << 0),
    NSJSONWritingSortedKeys API_AVAILABLE(ios(11.0)) = (1UL << 1),
    NSJSONWritingFragmentsAllowed = (1UL << 2),
    NSJSONWritingWithoutEscapingSlashes API_AVAILABLE(ios(13.0)) = (1UL << 3),
};

@interface NSJSONSerialization : NSObject
+ (BOOL)isValidJSONObject:(id)obj;
+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
+ (nullable id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
