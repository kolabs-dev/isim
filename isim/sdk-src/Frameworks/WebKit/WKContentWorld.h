#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKContentWorld : NSObject
@property (class, nonatomic, readonly) WKContentWorld *pageWorld;
@property (class, nonatomic, readonly) WKContentWorld *defaultClientWorld;
+ (WKContentWorld *)worldWithName:(NSString *)name;
@property (nullable, nonatomic, readonly, copy) NSString *name;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
