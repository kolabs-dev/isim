/* UICloudSharingController: iOS's sheet for managing a CloudKit share (adapted). Like iOS 17 and later it is a
 * navigation bar with the item's title and Done, a header with the item's thumbnail and title, and inset-grouped
 * sections: People (each participant, with their status and permission), Share Options (who can access, and their
 * permission, as availablePermissions allows), Copy Link and a red Stop Sharing. The bars follow the emulated iOS
 * version (Liquid Glass on 26 and later) through the navigation controller it hosts.
 *
 * CKShare is a Swift class in isim's CloudKit overlay; the sheet reads and changes it through the overlay's
 * Objective-C-visible helpers (SharingSheet.swift). Done and Stop Sharing post the notifications the overlay's
 * CKSystemSharingUIObserver hears: Done saves the options changed in the sheet, Stop Sharing deletes the share. Nothing
 * is sent: the share lives in the device's local CloudKit store. */
#import "UIKitPrivate.h"
#import <UIKit/UICloudSharingController.h>

/* CloudKit's CKShare helpers (SharingSheet.swift) */
@interface NSObject (ISIMCloudSharingSheet)
- (NSDictionary *)_isimSharingSheetInfo;
- (void)_isimSetSharingAnyone:(BOOL)anyone permission:(NSInteger)permission;
@end

/* CKShare's raw values */
enum { CKPermissionNone = 1, CKPermissionReadOnly = 2, CKPermissionReadWrite = 3 };
enum { CKRoleOwner = 1 };
enum { CKStatusAccepted = 2, CKStatusRemoved = 3 };

@interface UICloudSharingController ()
@property (nullable, nonatomic, readwrite) CKShare *share;
@property (nullable, nonatomic, readwrite) CKContainer *container;
@property (nonatomic, readonly) BOOL _isimAnyone;              /* Share Options: anyone with the link may open it */
@property (nonatomic, readonly) NSInteger _isimPermission;     /* ... with this CKShare.ParticipantPermission */
- (NSDictionary *)_isimInfo;
- (NSString *)_isimItemTitle;
- (void)_isimSetAnyone:(BOOL)anyone permission:(NSInteger)permission;
- (void)_isim_done;
- (void)_isim_stop;
@end

@interface _ISIMCloudSharingList : UITableViewController
@property (nonatomic, weak) UICloudSharingController *owner;
- (void)_reload;
@end

@interface _ISIMCloudSharingOptions : UITableViewController
@property (nonatomic, weak) UICloudSharingController *owner;
@end

@implementation UICloudSharingController {
    UICloudSharingControllerPreparationHandler _preparationHandler;
    UINavigationController *_nav;
    _ISIMCloudSharingList *_list;
    BOOL _changed;
}

- (instancetype)initWithShare:(CKShare *)share container:(CKContainer *)container {
    if ((self = [super init])) { _share = share; _container = container; _availablePermissions = UICloudSharingPermissionStandard; }
    return self;
}

- (instancetype)initWithPreparationHandler:(UICloudSharingControllerPreparationHandler)handler {
    if ((self = [super init])) { _preparationHandler = [handler copy]; _availablePermissions = UICloudSharingPermissionStandard; }
    return self;
}

- (NSDictionary *)_isimInfo {
    id s = self.share;
    return [s respondsToSelector:@selector(_isimSharingSheetInfo)] ? [s _isimSharingSheetInfo] : nil;
}
/* who can access and their permission, as the share has them */
- (void)_isimReadOptions {
    NSDictionary *info = [self _isimInfo];
    NSInteger pub = [info[@"publicPermission"] integerValue];
    __isimAnyone = pub > CKPermissionNone;
    __isimPermission = __isimAnyone ? pub : CKPermissionReadWrite;
    if (!__isimAnyone)
        for (NSDictionary *p in info[@"people"])
            if ([p[@"role"] integerValue] != CKRoleOwner && [p[@"permission"] integerValue] > CKPermissionNone) { __isimPermission = [p[@"permission"] integerValue]; break; }
}
- (NSString *)_isimItemTitle {
    id<UICloudSharingControllerDelegate> d = self.delegate;
    NSString *t = [d respondsToSelector:@selector(itemTitleForCloudSharingController:)] ? [d itemTitleForCloudSharingController:self] : nil;
    return t.length ? t : ([self _isimInfo][@"title"] ?: @"Shared Item");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self _isimReadOptions];
    _list = [[_ISIMCloudSharingList alloc] initWithStyle:UITableViewStyleInsetGrouped];
    _list.owner = self;
    _nav = [[UINavigationController alloc] initWithRootViewController:_list];
    [self addChildViewController:_nav];
    _nav.view.frame = self.view.bounds;
    _nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_nav.view];
    [_nav didMoveToParentViewController:self];
    if (!self.share && _preparationHandler) {
        __weak typeof(self) weakSelf = self;
        _preparationHandler(self, ^(CKShare *share, CKContainer *container, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UICloudSharingController *s = weakSelf;
                if (!s || error) return;
                s.share = share; s.container = container;
                [s _isimReadOptions];
                [s->_list _reload];
            });
        });
    }
}

/* the options chosen in Share Options, applied to the share (Done saves it) */
- (void)_isimSetAnyone:(BOOL)anyone permission:(NSInteger)permission {
    __isimAnyone = anyone; __isimPermission = permission; _changed = YES;
    id s = self.share;
    if ([s respondsToSelector:@selector(_isimSetSharingAnyone:permission:)]) [s _isimSetSharingAnyone:anyone permission:permission];
}

/* CloudKit's CKSystemSharingUIObserver hears these (userInfo: share, container, changed); stopping deletes the share there */
- (void)_isim_post:(NSString *)name {
    if (!self.share) return;
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:self.share forKey:@"share"];
    if (self.container) info[@"container"] = self.container;
    info[@"changed"] = @(_changed);
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:info];
}
- (void)_isim_done {
    if (self.share && [self.delegate respondsToSelector:@selector(cloudSharingControllerDidSaveShare:)]) [self.delegate cloudSharingControllerDidSaveShare:self];
    [self _isim_post:@"_isimCloudSharingControllerDidSaveShare"];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)_isim_stop {
    [self _isim_post:@"_isimCloudSharingControllerDidStopSharing"];
    if (self.share && [self.delegate respondsToSelector:@selector(cloudSharingControllerDidStopSharing:)]) [self.delegate cloudSharingControllerDidStopSharing:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

/* ---- the lists ---- */

static NSString *permission_text(NSInteger p) { return p == CKPermissionReadOnly ? @"View only" : @"Can make changes"; }
static NSString *access_text(BOOL anyone) { return anyone ? @"Anyone with the link" : @"Only invited people"; }

/* a contact's monogram, as in iOS's lists of people: up to two initials on a grey gradient circle */
static UIImage *monogram(NSString *name, CGFloat d) {
    NSMutableString *initials = [NSMutableString string];
    for (NSString *w in [name componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet])
        if (w.length && initials.length < 2 && [NSCharacterSet.letterCharacterSet characterIsMember:[w characterAtIndex:0]])
            [initials appendString:[w substringToIndex:1].uppercaseString];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        CGContextRef g = c.CGContext;
        CGContextAddEllipseInRect(g, CGRectMake(0, 0, d, d)); CGContextClip(g);
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat comps[] = { 0.659, 0.678, 0.722, 1,  0.529, 0.549, 0.596, 1 };      /* #A8ADB8 to #878C98 */
        CGFloat locs[] = { 0, 1 };
        CGGradientRef grad = CGGradientCreateWithColorComponents(cs, comps, locs, 2);
        CGContextDrawLinearGradient(g, grad, CGPointMake(0, 0), CGPointMake(0, d), 0);
        CGGradientRelease(grad); CGColorSpaceRelease(cs);
        NSDictionary *a = @{ NSFontAttributeName: [UIFont systemFontOfSize:d * 0.42 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: UIColor.whiteColor };
        NSString *t = initials.length ? initials : @"?";
        CGSize sz = [t sizeWithAttributes:a];
        [t drawAtPoint:CGPointMake((d - sz.width) / 2, (d - sz.height) / 2) withAttributes:a];
    }];
}

typedef NS_ENUM(NSInteger, ISIMSharingSection) { ISIMSharingPeople, ISIMSharingOptions, ISIMSharingLink, ISIMSharingStop };

@implementation _ISIMCloudSharingList {
    NSArray<NSDictionary *> *_people;
    NSURL *_url;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UICloudSharingController *o = self.owner;
    self.title = [o _isimItemTitle];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:o action:@selector(_isim_done)];
    done.accessibilityIdentifier = @"cloudSharing-done";
    self.navigationItem.rightBarButtonItem = done;
    [self _reload];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }
- (void)_reload {
    NSDictionary *info = [self.owner _isimInfo];
    _people = info[@"people"] ?: @[];
    _url = info[@"url"];
    self.title = [self.owner _isimItemTitle];
    self.tableView.tableHeaderView = [self _header:info];
    [self.tableView reloadData];
}
/* the shared item: its thumbnail (the delegate's, else the share's, else a document symbol) and title */
- (UIView *)_header:(NSDictionary *)info {
    UICloudSharingController *o = self.owner;
    id<UICloudSharingControllerDelegate> d = o.delegate;
    NSData *thumb = [d respondsToSelector:@selector(itemThumbnailDataForCloudSharingController:)] ? [d itemThumbnailDataForCloudSharingController:o] : info[@"thumbnail"];
    NSString *type = [d respondsToSelector:@selector(itemTypeForCloudSharingController:)] ? [d itemTypeForCloudSharingController:o] : nil;
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 148)];
    UIImageView *iv = [UIImageView new];
    UIImage *img = thumb.length ? [UIImage imageWithData:thumb] : nil;
    if (img) { iv.image = img; iv.contentMode = UIViewContentModeScaleAspectFill; }
    else {
        iv.image = [UIImage systemImageNamed:@"doc.text.fill"];
        iv.contentMode = UIViewContentModeCenter; iv.tintColor = UIColor.secondaryLabelColor;
        iv.backgroundColor = UIColor.tertiarySystemFillColor;
    }
    iv.layer.cornerRadius = 14; iv.clipsToBounds = YES;
    iv.accessibilityIdentifier = @"cloudSharing-thumbnail";
    UILabel *title = [UILabel new];
    title.text = [o _isimItemTitle]; title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter; title.accessibilityIdentifier = @"cloudSharing-title";
    UILabel *sub = [UILabel new];
    NSString *owner = nil;
    for (NSDictionary *p in _people) if ([p[@"role"] integerValue] == CKRoleOwner && ![p[@"me"] boolValue]) owner = p[@"name"];
    sub.text = owner ? [NSString stringWithFormat:@"Shared by %@", owner] : (type.length ? type : @"Shared with people you invite");
    sub.font = [UIFont systemFontOfSize:13]; sub.textColor = UIColor.secondaryLabelColor; sub.textAlignment = NSTextAlignmentCenter;
    for (UIView *v in @[iv, title, sub]) { v.translatesAutoresizingMaskIntoConstraints = NO; [h addSubview:v]; }
    [NSLayoutConstraint activateConstraints:@[
        [iv.topAnchor constraintEqualToAnchor:h.topAnchor constant:16], [iv.centerXAnchor constraintEqualToAnchor:h.centerXAnchor],
        [iv.widthAnchor constraintEqualToConstant:64], [iv.heightAnchor constraintEqualToConstant:64],
        [title.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:h.leadingAnchor constant:20], [title.trailingAnchor constraintEqualToAnchor:h.trailingAnchor constant:-20],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [sub.leadingAnchor constraintEqualToAnchor:h.leadingAnchor constant:20], [sub.trailingAnchor constraintEqualToAnchor:h.trailingAnchor constant:-20]]];
    return h;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case ISIMSharingPeople: return (NSInteger)_people.count;
        case ISIMSharingLink: return _url ? 1 : 0;
        default: return 1;
    }
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return s == ISIMSharingPeople && _people.count ? @"People" : nil;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s != ISIMSharingOptions) return nil;
    UICloudSharingController *o = self.owner;
    return [NSString stringWithFormat:@"%@ %@.", o._isimAnyone ? @"Anyone with the link" : @"Only people you invite",
            o._isimPermission == CKPermissionReadOnly ? @"can view" : @"can make changes"];
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == ISIMSharingPeople ? 60 : 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UICloudSharingController *o = self.owner;
    UITableViewCell *c;
    switch (ip.section) {
        case ISIMSharingPeople: {
            NSDictionary *p = _people[(NSUInteger)ip.row];
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            NSString *name = p[@"name"];
            c.textLabel.text = [p[@"me"] boolValue] ? [name stringByAppendingString:@" (Me)"] : name;
            NSInteger role = [p[@"role"] integerValue], status = [p[@"status"] integerValue], perm = [p[@"permission"] integerValue];
            NSString *state = role == CKRoleOwner ? @"Owner" : status == CKStatusAccepted ? @"Accepted" : status == CKStatusRemoved ? @"Removed" : @"Invited";
            c.detailTextLabel.text = role == CKRoleOwner ? state : [NSString stringWithFormat:@"%@ · %@", state, permission_text(perm)];
            c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            c.imageView.image = monogram(name, 40);
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            c.accessibilityIdentifier = [NSString stringWithFormat:@"cloudSharing-person-%ld", (long)ip.row];
            break;
        }
        case ISIMSharingOptions:
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            c.textLabel.text = @"Share Options";
            c.detailTextLabel.text = access_text(o._isimAnyone);
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            c.accessibilityIdentifier = @"cloudSharing-options";
            break;
        case ISIMSharingLink:
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            c.textLabel.text = @"Copy Link"; c.textLabel.textColor = self.view.tintColor;
            c.imageView.image = [UIImage systemImageNamed:@"link"]; c.imageView.tintColor = self.view.tintColor;
            c.accessibilityIdentifier = @"cloudSharing-copyLink";
            break;
        default:
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            c.textLabel.text = @"Stop Sharing"; c.textLabel.textColor = UIColor.systemRedColor;
            c.accessibilityIdentifier = @"cloudSharing-stop";
            break;
    }
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UICloudSharingController *o = self.owner;
    switch (ip.section) {
        case ISIMSharingOptions: {
            _ISIMCloudSharingOptions *opts = [[_ISIMCloudSharingOptions alloc] initWithStyle:UITableViewStyleInsetGrouped];
            opts.owner = o;
            [self.navigationController pushViewController:opts animated:YES];
            break;
        }
        case ISIMSharingLink:
            UIPasteboard.generalPasteboard.URL = _url;
            NSLog(@"isim UIKit: sharing sheet copied the share link");
            break;
        case ISIMSharingStop:
            [o _isim_stop];
            break;
        default: break;
    }
}
@end

/* Share Options: who can access and their permission, as availablePermissions allows (all of them by default) */
@implementation _ISIMCloudSharingOptions
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Share Options";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}
- (NSArray<NSNumber *> *)_access {
    UICloudSharingPermissionOptions a = self.owner.availablePermissions;
    BOOL pub = (a & UICloudSharingPermissionAllowPublic) != 0, priv = (a & UICloudSharingPermissionAllowPrivate) != 0;
    if (!pub && !priv) pub = priv = YES;
    NSMutableArray *r = [NSMutableArray array];
    if (priv) [r addObject:@NO];
    if (pub) [r addObject:@YES];
    return r;
}
- (NSArray<NSNumber *> *)_permissions {
    UICloudSharingPermissionOptions a = self.owner.availablePermissions;
    BOOL ro = (a & UICloudSharingPermissionAllowReadOnly) != 0, rw = (a & UICloudSharingPermissionAllowReadWrite) != 0;
    if (!ro && !rw) ro = rw = YES;
    NSMutableArray *r = [NSMutableArray array];
    if (rw) [r addObject:@(CKPermissionReadWrite)];
    if (ro) [r addObject:@(CKPermissionReadOnly)];
    return r;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)(s == 0 ? [self _access] : [self _permissions]).count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Who Can Access" : @"Permission"; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UICloudSharingController *o = self.owner;
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (ip.section == 0) {
        BOOL anyone = [[self _access][(NSUInteger)ip.row] boolValue];
        c.textLabel.text = access_text(anyone);
        c.accessoryType = anyone == o._isimAnyone ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        c.accessibilityIdentifier = anyone ? @"cloudSharing-access-anyone" : @"cloudSharing-access-invited";
    } else {
        NSInteger p = [[self _permissions][(NSUInteger)ip.row] integerValue];
        c.textLabel.text = permission_text(p);
        c.accessoryType = p == o._isimPermission ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        c.accessibilityIdentifier = p == CKPermissionReadOnly ? @"cloudSharing-permission-readOnly" : @"cloudSharing-permission-readWrite";
    }
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UICloudSharingController *o = self.owner;
    if (ip.section == 0) [o _isimSetAnyone:[[self _access][(NSUInteger)ip.row] boolValue] permission:o._isimPermission];
    else [o _isimSetAnyone:o._isimAnyone permission:[[self _permissions][(NSUInteger)ip.row] integerValue]];
    NSLog(@"isim UIKit: sharing sheet options: %@, %@", access_text(o._isimAnyone), permission_text(o._isimPermission));
    [tv reloadData];
}
@end
