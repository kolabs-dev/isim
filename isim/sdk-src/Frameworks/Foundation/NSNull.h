#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSNull : NSObject <NSCopying, NSSecureCoding>
+ (NSNull *)null;
@end
NS_ASSUME_NONNULL_END
