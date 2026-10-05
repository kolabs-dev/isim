//
//  ViewController.m
//  HelloCounter
//
//  The template's empty view controller, filled in with a small counter UI built in code.
//

#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic) NSInteger count;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Hello, iPhone on Linux";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    title.textAlignment = NSTextAlignmentCenter;

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [UIFont monospacedDigitSystemFontOfSize:72 weight:UIFontWeightBold];
    self.countLabel.textColor = [UIColor systemBlueColor];
    self.countLabel.textAlignment = NSTextAlignmentCenter;

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.hintLabel.textColor = [UIColor secondaryLabelColor];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.numberOfLines = 0;

    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = @"Tap me";
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.buttonSize = UIButtonConfigurationSizeLarge;
    config.contentInsets = NSDirectionalEdgeInsetsMake(12, 28, 12, 28);
    UIButton *tap = [UIButton buttonWithConfiguration:config primaryAction:nil];
    [tap addTarget:self action:@selector(increment:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"Reset" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(reset:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *darkLabel = [[UILabel alloc] init];
    darkLabel.text = @"Dark appearance";
    UISwitch *darkSwitch = [[UISwitch alloc] init];
    [darkSwitch addTarget:self action:@selector(toggleDark:) forControlEvents:UIControlEventValueChanged];
    UIStackView *darkRow = [[UIStackView alloc] initWithArrangedSubviews:@[darkLabel, darkSwitch]];
    darkRow.axis = UILayoutConstraintAxisHorizontal;
    darkRow.spacing = 12;
    darkRow.alignment = UIStackViewAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.countLabel, tap, reset, darkRow, self.hintLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16;
    [stack setCustomSpacing:32 afterView:reset];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [stack.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-40],
    ]];
    [self updateLabels];
}

- (void)updateLabels {
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)self.count];
    self.hintLabel.text = self.count == 0
        ? @"Objective-C · UIKit · running on Linux in isim"
        : [NSString stringWithFormat:@"You tapped %ld time%@", (long)self.count, self.count == 1 ? @"" : @"s"];
}

- (void)increment:(UIButton *)sender {
    self.count += 1;
    NSLog(@"HelloCounter: count = %ld", (long)self.count);
    [self updateLabels];
}

- (void)reset:(UIButton *)sender {
    self.count = 0;
    [self updateLabels];
}

- (void)toggleDark:(UISwitch *)sender {
    self.view.window.overrideUserInterfaceStyle = sender.isOn ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
}

@end
