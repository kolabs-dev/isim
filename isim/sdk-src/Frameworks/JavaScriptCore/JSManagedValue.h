#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class JSValue;
/* isim: a managed value keeps its JavaScript value alive while the JSManagedValue exists (Apple's is a conditional
   reference kept alive by its owners' reachability; the difference only shows in when JavaScript garbage-collects) */
@interface JSManagedValue : NSObject
+ (JSManagedValue *)managedValueWithValue:(JSValue *)value;
+ (JSManagedValue *)managedValueWithValue:(JSValue *)value andOwner:(id)owner;
- (instancetype)initWithValue:(nullable JSValue *)value;
@property (nullable, readonly, strong) JSValue *value;
@end
NS_ASSUME_NONNULL_END
