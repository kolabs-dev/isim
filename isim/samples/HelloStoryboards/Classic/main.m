// HelloStoryboardsClassic: an Objective-C app without scenes; UIKit loads UIMainStoryboardFile (Classic.storyboard)
// into a window it gives to the app delegate, and shows the UILaunchScreen dictionary while launching.
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app willFinishLaunchingWithOptions:(NSDictionary *)options {
    printf("classic: willFinishLaunching window=%s\n", self.window ? "set" : "nil");
    return YES;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    printf("classic: didFinishLaunching root=%s storyboard=%s\n", NSStringFromClass([self.window.rootViewController class]).UTF8String,
           self.window.rootViewController.storyboard ? "yes" : "no");
    return YES;
}
@end

@interface ClassicViewController : UIViewController
@property (nonatomic, weak) IBOutlet UILabel *countLabel;
@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *buttons;
@property (nonatomic) NSInteger count;
@end

@implementation ClassicViewController
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) printf("classic: initWithCoder title=%s\n", self.title.UTF8String ?: "nil");
    return self;
}
- (void)awakeFromNib { [super awakeFromNib]; printf("classic: awakeFromNib\n"); }
- (void)viewDidLoad {
    [super viewDidLoad];
    printf("classic: viewDidLoad label=%s buttons=%lu\n", self.countLabel.text.UTF8String ?: "nil", (unsigned long)self.buttons.count);
}
- (IBAction)increment:(UIButton *)sender {
    self.count += 1;
    self.countLabel.text = [NSString stringWithFormat:@"Count %ld", (long)self.count];
    printf("classic: count %ld\n", (long)self.count);
}
- (IBAction)reset:(id)sender { self.count = 0; self.countLabel.text = @"Count 0"; printf("classic: reset\n"); }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
