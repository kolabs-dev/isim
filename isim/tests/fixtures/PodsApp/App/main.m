// PodsApp: an Objective-C app using two pods through CocoaPods' workspace: StaticPod (a static library with a
// resource bundle copied by "[CP] Copy Pods Resources") and FramePod (a dynamic framework, use_frameworks! style,
// with its resource bundle inside the framework, embedded by "[CP] Embed Pods Frameworks").
#import <UIKit/UIKit.h>
#import <StaticPod/SPCounter.h>
@import FramePod;                      // FramePod.framework's module map (CocoaPods' FramePod.modulemap)

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    SPCounter *c = [SPCounter new];
    [c increment]; [c increment];
    printf("PodsApp: StaticPod %ld %s | FramePod %s | COCOAPODS=%d\n", (long)c.value, [SPCounter resourceText].UTF8String,
           [FPGreeter greeting].UTF8String, COCOAPODS);
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
