#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
typedef unsigned char uuid_t[16];
@interface NSUUID : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)UUID;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithUUIDString:(NSString *)string;
- (instancetype)initWithUUIDBytes:(const uuid_t _Nullable)bytes;
- (void)getUUIDBytes:(uuid_t _Nonnull)uuid;
- (NSComparisonResult)compare:(NSUUID *)otherUUID;
@property (readonly, copy) NSString *UUIDString;
@end
NS_ASSUME_NONNULL_END
