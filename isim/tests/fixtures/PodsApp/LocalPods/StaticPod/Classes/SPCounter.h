#import <Foundation/Foundation.h>

@interface SPCounter : NSObject
@property (nonatomic, readonly) NSInteger value;
- (void)increment;
/// Text from StaticPodResources.bundle (copied into the app by the Pods resources phase).
+ (NSString *)resourceText;
@end
