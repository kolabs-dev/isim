// Sample: UIKit's iOS 14+ configuration APIs from Objective-C (issue #235): cell and supplementary registrations, a
// diffable data source with an outline (section snapshot handlers) and reordering handlers, configuration states with
// custom keys, a cell subclass overriding -updateConfigurationUsingState: and a configurationUpdateHandler, window
// scene placements, keypad HID usages, and symbol effects on an image view (Symbols.framework). Each step prints a
// "co ..." line the test checks.
#import <UIKit/UIKit.h>
#import <Symbols/Symbols.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("co %s\n", s.UTF8String); fflush(stdout);
}
static UIConfigurationStateCustomKey const BadgeKey = @"dev.isim.badge";

/// a list cell that styles itself for its state, as Objective-C apps override it
@interface FruitCell : UICollectionViewListCell
@property (nonatomic, copy) NSString *fruit;
@end
@implementation FruitCell
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    [super updateConfigurationUsingState:state];              /* runs the configurationUpdateHandler */
    UIListContentConfiguration *c = [self defaultContentConfiguration];
    c.text = state.selected ? [self.fruit stringByAppendingString:@" ✓"] : self.fruit;
    c.secondaryText = state[BadgeKey];
    self.contentConfiguration = c;
    self.accessibilityIdentifier = [@"fruit-" stringByAppendingString:self.fruit];
    if (state.selected) say(@"update %@ selected=%d editing=%d", self.fruit, state.selected, state.editing);
}
@end

@interface ViewController : UIViewController
@property (nonatomic, strong) UICollectionView *list;
@property (nonatomic, strong) UICollectionViewDiffableDataSourceReference *source;
@property (nonatomic, strong) UIImageView *heart;
@end

@implementation ViewController
- (UIButton *)button:(NSString *)title id:(NSString *)ident x:(CGFloat)x action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.accessibilityIdentifier = ident;
    b.frame = CGRectMake(x, self.view.bounds.size.height - 110, 100, 44);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self states];
    [self placements];
    say(@"hid a=%ld keypad1=%ld keypadEnter=%ld", (long)UIKeyboardHIDUsageKeyboardA, (long)UIKeyboardHIDUsageKeypad1,
        (long)UIKeyboardHIDUsageKeypadEnter);
    [self makeList];
    self.heart = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
    self.heart.frame = CGRectMake(self.view.bounds.size.width / 2 - 22, self.view.bounds.size.height - 170, 44, 40);
    self.heart.tintColor = UIColor.systemPinkColor;
    self.heart.accessibilityIdentifier = @"heart";
    [self.view addSubview:self.heart];
    CGFloat w = self.view.bounds.size.width;
    [self button:@"Edit" id:@"edit" x:8 action:@selector(toggleEditing)];
    [self button:@"Bounce" id:@"bounce" x:w / 2 - 50 action:@selector(bounce)];
    [self button:@"Pulse" id:@"pulse" x:w - 108 action:@selector(pulse)];
}

#pragma mark configuration states
- (void)states {
    UICellConfigurationState *s = [[UICellConfigurationState alloc] initWithTraitCollection:self.traitCollection];
    s.selected = YES; s.editing = YES; s.cellDragState = UICellConfigurationDragStateLifting;
    s[BadgeKey] = @"new";
    UICellConfigurationState *copy = [s copy];
    [copy setCustomState:@"sale" forKey:BadgeKey];
    say(@"state selected=%d editing=%d drag=%ld badge=%@ copy=%@ equal=%d reequal=%d", s.selected, s.editing, (long)s.cellDragState,
        s[BadgeKey], [copy customStateForKey:BadgeKey], [s isEqual:copy], [s isEqual:[s copy]]);
    UIViewConfigurationState *v = [[UIViewConfigurationState alloc] initWithTraitCollection:self.traitCollection];
    say(@"view state disabled=%d is-cell=%d", v.disabled, [v isKindOfClass:[UICellConfigurationState class]]);
}

#pragma mark placements
- (void)placements {
    UIWindowSceneActivationRequestOptions *o = [[UIWindowSceneActivationRequestOptions alloc] init];
    o.placement = [UIWindowSceneProminentPlacement prominentPlacement];
    long prominent = (long)o.preferredPresentationStyle;
    o.placement = [UIWindowSceneStandardPlacement standardPlacement];
    say(@"placement prominent=%ld standard=%ld back=%@ equal=%d", prominent, (long)o.preferredPresentationStyle,
        NSStringFromClass([o.placement class]), [[UIWindowSceneProminentPlacement prominentPlacement] isEqual:[UIWindowSceneProminentPlacement prominentPlacement]]);
}

#pragma mark the list
- (void)makeList {
    UICollectionLayoutListConfiguration *config = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearanceInsetGrouped];
    config.headerMode = UICollectionLayoutListHeaderModeSupplementary;
    CGRect f = self.view.bounds;
    f.size.height -= 190;
    self.list = [[UICollectionView alloc] initWithFrame:f collectionViewLayout:[UICollectionViewCompositionalLayout layoutWithListConfiguration:config]];
    [self.view addSubview:self.list];

    UICollectionViewCellRegistration *groups = [UICollectionViewCellRegistration registrationWithCellClass:[UICollectionViewListCell class]
        configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *indexPath, NSString *group) {
        UIListContentConfiguration *c = [cell defaultContentConfiguration];
        c.text = group;
        cell.contentConfiguration = c;
        cell.accessories = @[[UICellAccessoryOutlineDisclosure new]];
        cell.accessibilityIdentifier = [@"group-" stringByAppendingString:group];
    }];
    UICollectionViewCellRegistration *fruits = [UICollectionViewCellRegistration registrationWithCellClass:[FruitCell class]
        configurationHandler:^(FruitCell *cell, NSIndexPath *indexPath, NSString *fruit) {
        cell.fruit = fruit;
        UICellAccessoryReorder *reorder = [UICellAccessoryReorder new];
        reorder.displayedState = UICellAccessoryDisplayedWhenEditing;
        cell.accessories = @[reorder];
        cell.configurationUpdateHandler = ^(FruitCell *c, UICellConfigurationState *state) {
            if (state.selected) say(@"handler %@ selected=%d", c.fruit, state.selected);
        };
        [cell setNeedsUpdateConfiguration];
    }];
    UICollectionViewSupplementaryRegistration *headers = [UICollectionViewSupplementaryRegistration
        registrationWithSupplementaryClass:[UICollectionViewListCell class] elementKind:UICollectionElementKindSectionHeader
        configurationHandler:^(UICollectionViewListCell *header, NSString *kind, NSIndexPath *indexPath) {
        UIListContentConfiguration *c = [UIListContentConfiguration groupedHeaderConfiguration];
        c.text = @"Fruit";
        header.contentConfiguration = c;
        header.accessibilityIdentifier = @"header";
        say(@"header %@ section=%ld", kind, (long)indexPath.section);
    }];
    NSSet *groupNames = [NSSet setWithObjects:@"Citrus", @"Berries", nil];
    self.source = [[UICollectionViewDiffableDataSourceReference alloc] initWithCollectionView:self.list
        cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *indexPath, NSString *item) {
        return [cv dequeueConfiguredReusableCellWithRegistration:[groupNames containsObject:item] ? groups : fruits forIndexPath:indexPath item:item];
    }];
    self.source.supplementaryViewProvider = ^UICollectionReusableView *(UICollectionView *cv, NSString *kind, NSIndexPath *indexPath) {
        return [cv dequeueConfiguredReusableSupplementaryViewWithRegistration:headers forIndexPath:indexPath];
    };

    UICollectionViewDiffableDataSourceSectionSnapshotHandlers *outline = [UICollectionViewDiffableDataSourceSectionSnapshotHandlers new];
    outline.shouldCollapseItemHandler = ^BOOL(NSString *item) { return ![item isEqualToString:@"Berries"]; };
    outline.willExpandItemHandler = ^(NSString *item) { say(@"will expand %@", item); };
    outline.willCollapseItemHandler = ^(NSString *item) { say(@"will collapse %@", item); };
    self.source.sectionSnapshotHandlers = outline;
    UICollectionViewDiffableDataSourceReorderingHandlers *reorder = [UICollectionViewDiffableDataSourceReorderingHandlers new];
    reorder.canReorderItemHandler = ^BOOL(NSString *item) { return ![groupNames containsObject:item]; };
    reorder.willReorderHandler = ^(NSDiffableDataSourceTransaction *t) {
        say(@"will reorder sections=%lu", (unsigned long)t.sectionTransactions.count);
    };
    reorder.didReorderHandler = ^(NSDiffableDataSourceTransaction *t) {
        NSDiffableDataSourceSectionSnapshotReference *s = [self.source snapshotForSection:@"fruit"];
        say(@"reordered: %@", [[s snapshotOfParentItem:@"Citrus"].items componentsJoinedByString:@","]);
    };
    self.source.reorderingHandlers = reorder;

    NSDiffableDataSourceSnapshotReference *snap = [NSDiffableDataSourceSnapshotReference new];
    [snap appendSectionsWithIdentifiers:@[@"fruit"]];
    [self.source applySnapshot:snap animatingDifferences:NO];
    NSDiffableDataSourceSectionSnapshotReference *tree = [NSDiffableDataSourceSectionSnapshotReference new];
    [tree appendItems:@[@"Citrus", @"Berries"]];
    [tree appendItems:@[@"Lemon", @"Lime", @"Orange"] intoParentItem:@"Citrus"];
    [tree appendItems:@[@"Blueberry", @"Raspberry"] intoParentItem:@"Berries"];
    [tree expandItems:@[@"Berries"]];
    [self.source applySnapshot:tree toSection:@"fruit" animatingDifferences:NO];
    say(@"list items=%@", [[self.source snapshotForSection:@"fruit"].visibleItems componentsJoinedByString:@","]);
}
- (void)toggleEditing {
    self.list.editing = !self.list.editing;
    say(@"editing %d", self.list.editing);
}

#pragma mark symbol effects
- (void)bounce {
    [self.heart addSymbolEffect:[NSSymbolBounceEffect bounceUpEffect] options:[NSSymbolEffectOptions optionsWithRepeatCount:2] animated:YES
                     completion:^(UISymbolEffectCompletionContext *context) {
        say(@"bounce finished=%d effect=%@ sender=%d", context.finished, NSStringFromClass([context.effect class]), context.sender == self.heart);
    }];
}
- (void)pulse {
    [self.heart addSymbolEffect:[[NSSymbolPulseEffect effect] effectWithByLayer] options:[NSSymbolEffectOptions optionsWithSpeed:2]];
    say(@"pulse added");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.heart removeSymbolEffectOfType:[NSSymbolPulseEffect effect] options:[NSSymbolEffectOptions options] animated:YES
                                  completion:^(UISymbolEffectCompletionContext *context) { say(@"pulse removed finished=%d", context.finished); }];
        [self.heart setSymbolImage:[UIImage systemImageNamed:@"star.fill"] withContentTransition:[NSSymbolReplaceContentTransition replaceDownUpTransition]
                           options:[NSSymbolEffectOptions options] completion:^(UISymbolEffectCompletionContext *context) {
            say(@"replaced finished=%d transition=%@", context.finished, NSStringFromClass([context.contentTransition class]));
        }];
    });
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
