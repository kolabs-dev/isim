#import <UIKit/UICloudSharingController.h>
#import <UIKit/UIButton.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIStackView.h>
#import <UIKit/UIColor.h>
#import <UIKit/NSLayoutAnchor.h>

@interface UICloudSharingController ()
@property (nullable, nonatomic, readwrite) CKShare *share;
@property (nullable, nonatomic, readwrite) CKContainer *container;
@end

@implementation UICloudSharingController {
    UICloudSharingControllerPreparationHandler _preparationHandler;
}

- (instancetype)initWithShare:(CKShare *)share container:(CKContainer *)container {
    if ((self = [super init])) { _share = share; _container = container; _availablePermissions = UICloudSharingPermissionStandard; }
    return self;
}

- (instancetype)initWithPreparationHandler:(UICloudSharingControllerPreparationHandler)handler {
    if ((self = [super init])) { _preparationHandler = [handler copy]; _availablePermissions = UICloudSharingPermissionStandard; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Share with People";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *title = [UILabel new];
    title.text = [self.delegate respondsToSelector:@selector(itemTitleForCloudSharingController:)] ? [self.delegate itemTitleForCloudSharingController:self] : @"Shared item";
    title.textAlignment = NSTextAlignmentCenter;
    UILabel *note = [UILabel new]; note.text = @"Local CloudKit sharing · no invitation is sent"; note.textAlignment = NSTextAlignmentCenter; note.numberOfLines = 0;
    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem]; [done setTitle:@"Done" forState:UIControlStateNormal]; [done addTarget:self action:@selector(_isim_done) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:title]; [stack addArrangedSubview:note]; [stack addArrangedSubview:done]; [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor], [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24], [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24]]];
    if (!_share && _preparationHandler) {
        __weak typeof(self) weakSelf = self;
        _preparationHandler(self, ^(CKShare *share, CKContainer *container, NSError *error) { if (!error) { weakSelf.share = share; weakSelf.container = container; } });
    }
}

- (void)_isim_done {
    if (self.share && [self.delegate respondsToSelector:@selector(cloudSharingControllerDidSaveShare:)]) [self.delegate cloudSharingControllerDidSaveShare:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
