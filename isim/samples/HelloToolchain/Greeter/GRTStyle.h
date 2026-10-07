#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/* Objective-C part of the Greeter framework; its Swift code uses it through the framework's own module */
@interface GRTStyle : NSObject
+ (NSString *)decorate:(NSString *)text;
@end
NS_ASSUME_NONNULL_END
