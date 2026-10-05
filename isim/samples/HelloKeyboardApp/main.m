// Containing app for the HelloKeyboard extension: a scrolling form (Auto Layout via
// contentLayoutGuide) with a text field; the system keyboard can switch to the embedded keyboard.
#import <UIKit/UIKit.h>

@interface FormViewController : UIViewController <UITextFieldDelegate, UIScrollViewDelegate>
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIScrollView *scroll;
@end
@implementation FormViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.delegate = self;
    scroll.accessibilityIdentifier = @"form-scroll";
    [self.view addSubview:scroll];
    self.scroll = scroll;
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20],
        [scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];
    UILabel *title = [UILabel new];
    title.text = @"Keyboard test";
    title.font = [UIFont boldSystemFontOfSize:34];
    [stack addArrangedSubview:title];
    UITextField *field = [UITextField new];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = @"Type here";
    field.returnKeyType = UIReturnKeyDone;
    field.accessibilityIdentifier = @"field";
    field.delegate = self;
    [field addTarget:self action:@selector(changed:) forControlEvents:UIControlEventEditingChanged];
    [stack addArrangedSubview:field];
    self.field = field;
    for (int i = 1; i <= 14; i++) {
        UILabel *row = [UILabel new];
        row.text = [NSString stringWithFormat:@"Row %d", i];
        row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        [row.heightAnchor constraintEqualToConstant:60].active = YES;
        row.accessibilityIdentifier = [NSString stringWithFormat:@"row-%d", i];
        [stack addArrangedSubview:row];
    }
    [NSNotificationCenter.defaultCenter addObserverForName:UIKeyboardDidShowNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        CGRect f = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        NSLog(@"HelloKeyboardApp: keyboard did show, height %g", f.size.height);
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:UIKeyboardDidChangeFrameNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        CGRect f = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        NSLog(@"HelloKeyboardApp: keyboard frame height %g", f.size.height);
    }];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    NSLog(@"HelloKeyboardApp: contentSize %g x %g", self.scroll.contentSize.width, self.scroll.contentSize.height);
}
- (void)changed:(UITextField *)f { NSLog(@"HelloKeyboardApp: text = \"%@\"", f.text); }
- (BOOL)textFieldShouldReturn:(UITextField *)f { NSLog(@"HelloKeyboardApp: return pressed"); [f resignFirstResponder]; return NO; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)s { NSLog(@"HelloKeyboardApp: scrolled to %g", s.contentOffset.y); }
- (void)scrollViewDidEndDragging:(UIScrollView *)s willDecelerate:(BOOL)d { if (!d) NSLog(@"HelloKeyboardApp: scrolled to %g", s.contentOffset.y); }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [FormViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
