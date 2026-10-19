// Sample: drag and drop from Objective-C (issue #245): a UIDragInteraction source, a UIDropInteraction target that
// loads the dropped string, a table view with drag and drop delegates (UITableViewDropCoordinator), a text field
// with a text drop delegate, a spring-loaded button (UISpringLoadedInteraction) and a UIPasteConfiguration. Each step
// prints a "dd ..." line the test checks.
#import <UIKit/UIKit.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("dd %s\n", s.UTF8String); fflush(stdout);
}

@interface ViewController : UIViewController <UIDragInteractionDelegate, UIDropInteractionDelegate, UITableViewDataSource,
                                              UITableViewDragDelegate, UITableViewDropDelegate, UITextDropDelegate,
                                              UICollectionViewDataSource, UICollectionViewDragDelegate, UICollectionViewDropDelegate>
@property (nonatomic, strong) UILabel *source, *target;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableArray<NSString *> *rows;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) NSMutableArray<NSString *> *tiles;
@end

@implementation ViewController
- (UILabel *)box:(NSString *)text id:(NSString *)ident frame:(CGRect)frame color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text; l.textAlignment = NSTextAlignmentCenter; l.backgroundColor = color;
    l.userInteractionEnabled = YES; l.accessibilityIdentifier = ident;
    [self.view addSubview:l];
    return l;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.source = [self box:@"Apple" id:@"source" frame:CGRectMake(20, 100, 150, 60) color:UIColor.systemYellowColor];
    self.target = [self box:@"Drop here" id:@"target" frame:CGRectMake(220, 100, 150, 60) color:UIColor.systemTealColor];
    UIDragInteraction *drag = [[UIDragInteraction alloc] initWithDelegate:self];
    drag.enabled = YES;
    [self.source addInteraction:drag];
    UIDropInteraction *drop = [[UIDropInteraction alloc] initWithDelegate:self];
    [self.target addInteraction:drop];
    say(@"interactions drag=%d delegate=%d enabled=%d default=%d drop=%d", drag.view == self.source, drag.delegate == self, drag.isEnabled,
        UIDragInteraction.isEnabledByDefault, drop.delegate == self);

    // a spring-loaded button: activated under a resting drag
    UIButton *spring = [UIButton buttonWithType:UIButtonTypeSystem];
    [spring setTitle:@"Spring" forState:UIControlStateNormal];
    spring.frame = CGRectMake(20, 180, 150, 44);
    spring.accessibilityIdentifier = @"spring";
    [spring addInteraction:[[UISpringLoadedInteraction alloc] initWithActivationHandler:^(UISpringLoadedInteraction *i, id<UISpringLoadedInteractionContext> c) {
        say(@"spring activated state=%ld view=%d", (long)c.state, c.targetView == spring);
    }]];
    [self.view addSubview:spring];

    // a table view: rows drag out, strings drop in at the destination row
    self.rows = [@[@"One", @"Two", @"Three"] mutableCopy];
    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 260, self.view.bounds.size.width, 180) style:UITableViewStylePlain];
    self.table.accessibilityIdentifier = @"table";
    self.table.dataSource = self;
    [self.table registerClass:UITableViewCell.class forCellReuseIdentifier:@"row"];
    self.table.dragDelegate = self; self.table.dropDelegate = self; self.table.dragInteractionEnabled = YES;
    [self.view addSubview:self.table];
    say(@"table delegates drag=%d drop=%d enabled=%d active=%d", self.table.dragDelegate == self, self.table.dropDelegate == self,
        self.table.dragInteractionEnabled, self.table.hasActiveDrag);

    // a text field with a text drop delegate
    self.field = [[UITextField alloc] initWithFrame:CGRectMake(20, 470, self.view.bounds.size.width - 40, 44)];
    self.field.borderStyle = UITextBorderStyleRoundedRect;
    self.field.placeholder = @"Drop text";
    self.field.accessibilityIdentifier = @"field";
    self.field.textDropDelegate = self;
    [self.view addSubview:self.field];
    say(@"field drop delegate=%d interaction=%d", self.field.textDropDelegate == self, self.field.textDropInteraction != nil);

    // a collection view: items drag out, strings drop in
    self.tiles = [@[@"A", @"B", @"C"] mutableCopy];
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.itemSize = CGSizeMake(80, 80);
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 540, self.view.bounds.size.width, 100) collectionViewLayout:flow];
    self.grid.accessibilityIdentifier = @"grid";
    self.grid.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.grid.dataSource = self;
    [self.grid registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"tile"];
    self.grid.dragDelegate = self; self.grid.dropDelegate = self;
    [self.view addSubview:self.grid];
    say(@"grid delegates drag=%d drop=%d", self.grid.dragDelegate == self, self.grid.dropDelegate == self);

    // a paste configuration from the strings' readable types
    UIPasteConfiguration *paste = [[UIPasteConfiguration alloc] initWithTypeIdentifiersForAcceptingClass:NSString.class];
    [paste addAcceptableTypeIdentifiers:@[@"public.png"]];
    self.pasteConfiguration = paste;
    say(@"paste text=%d png=%d same=%d", [paste.acceptableTypeIdentifiers containsObject:@"public.utf8-plain-text"],
        [paste.acceptableTypeIdentifiers containsObject:@"public.png"], self.pasteConfiguration == paste);

    UIDropProposal *p = [[UIDropProposal alloc] initWithDropOperation:UIDropOperationCopy];
    p.precise = YES;
    UITableViewDropProposal *tp = [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
    say(@"proposals op=%ld precise=%d table=%ld intent=%ld", (long)p.operation, p.isPrecise, (long)tp.operation, (long)tp.intent);
}

#pragma mark drag source
- (NSArray<UIDragItem *> *)dragInteraction:(UIDragInteraction *)interaction itemsForBeginningSession:(id<UIDragSession>)session {
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:self.source.text]];
    item.localObject = self.source.text;
    say(@"drag begins at %.0f,%.0f", [session locationInView:self.source].x, [session locationInView:self.source].y);
    return @[item];
}
- (void)dragInteraction:(UIDragInteraction *)interaction sessionWillBegin:(id<UIDragSession>)session {
    say(@"drag session items=%lu local=%@", (unsigned long)session.items.count, session.items.firstObject.localObject);
}
- (void)dragInteraction:(UIDragInteraction *)interaction session:(id<UIDragSession>)session didEndWithOperation:(UIDropOperation)operation {
    say(@"drag ended operation=%ld", (long)operation);
}

#pragma mark drop target
- (BOOL)dropInteraction:(UIDropInteraction *)interaction canHandleSession:(id<UIDropSession>)session {
    return [session canLoadObjectsOfClass:NSString.class] && [session hasItemsConformingToTypeIdentifiers:@[@"public.plain-text"]];
}
- (UIDropProposal *)dropInteraction:(UIDropInteraction *)interaction sessionDidUpdate:(id<UIDropSession>)session {
    return [[UIDropProposal alloc] initWithDropOperation:session.localDragSession ? UIDropOperationCopy : UIDropOperationForbidden];
}
- (void)dropInteraction:(UIDropInteraction *)interaction performDrop:(id<UIDropSession>)session {
    [session loadObjectsOfClass:NSString.class completion:^(NSArray<NSString *> *objects) {
        self.target.text = objects.firstObject;
        say(@"target got %@", objects.firstObject);
    }];
}

#pragma mark table
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"row" forIndexPath:indexPath];
    c.textLabel.text = self.rows[(NSUInteger)indexPath.row];
    c.accessibilityIdentifier = [@"row-" stringByAppendingString:self.rows[(NSUInteger)indexPath.row]];
    return c;
}
- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    say(@"table drag row %ld", (long)indexPath.row);
    return @[[[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:self.rows[(NSUInteger)indexPath.row]]]];
}
- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCopy intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}
- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *dest = coordinator.destinationIndexPath ?: [NSIndexPath indexPathForRow:(NSInteger)self.rows.count inSection:0];
    say(@"table drop items=%lu at %ld intent=%ld", (unsigned long)coordinator.items.count, (long)dest.row, (long)coordinator.proposal.intent);
    [coordinator.session loadObjectsOfClass:NSString.class completion:^(NSArray<NSString *> *objects) {
        NSUInteger at = MIN((NSUInteger)dest.row, self.rows.count);
        for (NSString *s in objects) [self.rows insertObject:s atIndex:at];
        [self.table reloadData];
        say(@"table rows %@", [self.rows componentsJoinedByString:@","]);
    }];
}

#pragma mark collection
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return (NSInteger)self.tiles.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *c = [collectionView dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:indexPath];
    c.backgroundColor = UIColor.systemOrangeColor;
    c.accessibilityIdentifier = [@"tile-" stringByAppendingString:self.tiles[(NSUInteger)indexPath.item]];
    return c;
}
- (NSArray<UIDragItem *> *)collectionView:(UICollectionView *)collectionView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    say(@"grid drag item %ld", (long)indexPath.item);
    return @[[[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:self.tiles[(NSUInteger)indexPath.item]]]];
}
- (UICollectionViewDropProposal *)collectionView:(UICollectionView *)collectionView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    return [[UICollectionViewDropProposal alloc] initWithDropOperation:UIDropOperationCopy intent:UICollectionViewDropIntentInsertAtDestinationIndexPath];
}
- (void)collectionView:(UICollectionView *)collectionView performDropWithCoordinator:(id<UICollectionViewDropCoordinator>)coordinator {
    NSIndexPath *dest = coordinator.destinationIndexPath ?: [NSIndexPath indexPathForItem:(NSInteger)self.tiles.count inSection:0];
    say(@"grid drop items=%lu at %ld source=%d", (unsigned long)coordinator.items.count, (long)dest.item, coordinator.items.firstObject.sourceIndexPath != nil);
    [coordinator.session loadObjectsOfClass:NSString.class completion:^(NSArray<NSString *> *objects) {
        NSUInteger at = MIN((NSUInteger)dest.item, self.tiles.count);
        for (NSString *s in objects) [self.tiles insertObject:s atIndex:at];
        [self.grid reloadData];
        say(@"grid tiles %@", [self.tiles componentsJoinedByString:@","]);
    }];
}

#pragma mark text drop
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidEnter:(id<UIDropSession>)session {
    say(@"field drop entered");
}
- (UITextDropProposal *)textDroppableView:(UIView<UITextDroppable> *)textDroppableView proposalForDrop:(id<UITextDropRequest>)drop {
    say(@"field proposal same=%d action=%ld", drop.isSameView, (long)drop.suggestedProposal.dropAction);
    return drop.suggestedProposal;
}
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidEnd:(id<UIDropSession>)session {
    say(@"field text '%@'", self.field.text);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [ViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
