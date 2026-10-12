// CarthageApp: an Objective-C app linking and embedding Carthage/Build/Foo.xcframework (`carthage build
// --use-xcframeworks` output), referenced in Link Binary With Libraries and Embed Frameworks.
#import <UIKit/UIKit.h>
@import Foo;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    printf("CarthageApp: Foo %.1f answer %ld from %s\n", FooVersionNumber, (long)[FOOThing answer], FOOThing.origin.UTF8String);
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
