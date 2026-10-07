#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/* Objective-C in the app target: seen by Swift through the bridging header, and it calls Swift code
 * through the generated HelloToolchain-Swift.h */
@interface LegacyFormatter : NSObject
+ (NSString *)describeScore;
@end
NS_ASSUME_NONNULL_END
