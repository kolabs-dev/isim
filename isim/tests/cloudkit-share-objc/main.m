// CloudKit share links from Objective-C (issue #575): CloudKitShareObjCTest (an app delegate, no scenes) and
// CloudKitShareSceneObjCTest (UIApplicationSceneManifest, ShareSceneDelegate) build this file. On a normal launch the app
// saves a share in its container (iCloud.<bundle ID>) and logs its link; the test then opens the link in the running
// app, and relaunches the app with it (isim-cloudkit-share:<link>, as the home screen does). UIKit hands the share's
// metadata to the app: in the launch options (UIApplicationLaunchOptionsCloudKitShareMetadataKey) and
// application:userDidAcceptCloudKitShareWithMetadata:, or the scene's connection options and
// windowScene:userDidAcceptCloudKitShareWithMetadata:. The app accepts it. Results go to the log ("CKShareLink: ...").
#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>

static void say(NSString *s) { NSLog(@"CKShareLink: %@", s); }
static NSString *describe(CKShareMetadata *m) {
    if (!m) return @"none";
    return [NSString stringWithFormat:@"%@ role %ld container %d root %@", m.share[CKShareTitleKey], (long)m.participantRole,
            [m.containerIdentifier isEqualToString:CKContainer.defaultContainer.containerIdentifier], m.hierarchicalRootRecordID.recordName ?: m.share.recordID.recordName];
}
static void accept(CKShareMetadata *m, NSString *who) {
    say([NSString stringWithFormat:@"%@ share %@", who, describe(m)]);
    [CKContainer.defaultContainer acceptShareMetadata:m completionHandler:^(CKShare *share, NSError *e) {
        say([NSString stringWithFormat:@"%@ accepted %@ error %ld", who, NSStringFromClass(share.class), (long)e.code]);
    }];
}
static void makeShare(void) {
    CKDatabase *db = CKContainer.defaultContainer.privateCloudDatabase;
    CKRecordZoneID *zid = [[CKRecordZoneID alloc] initWithZoneName:@"Shared" ownerName:CKCurrentUserDefaultName];
    CKModifyRecordZonesOperation *z = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[[[CKRecordZone alloc] initWithZoneID:zid]] recordZoneIDsToDelete:nil];
    z.modifyRecordZonesCompletionBlock = ^(NSArray *saved, NSArray *deleted, NSError *e) {
        CKRecord *root = [[CKRecord alloc] initWithRecordType:@"List" recordID:[[CKRecordID alloc] initWithRecordName:@"groceries" zoneID:zid]];
        root[@"title"] = @"Groceries";
        CKShare *share = [[CKShare alloc] initWithRootRecord:root];
        share[CKShareTitleKey] = @"Groceries";
        share.publicPermission = CKShareParticipantPermissionReadOnly;
        CKModifyRecordsOperation *op = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[root, share] recordIDsToDelete:nil];
        __block NSURL *url = nil;
        op.perRecordSaveBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *err) { if ([rec isKindOfClass:CKShare.class]) url = ((CKShare *)rec).URL; };
        op.modifyRecordsCompletionBlock = ^(NSArray *a, NSArray *d, NSError *err) { say([NSString stringWithFormat:@"share url %@", url.absoluteString]); };
        [db addOperation:op];
    };
    [db addOperation:z];
}

@interface ShareSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation ShareSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.window makeKeyAndVisible];
    say([NSString stringWithFormat:@"scene options share %@", describe(options.cloudKitShareMetadata)]);
    if (options.cloudKitShareMetadata) accept(options.cloudKitShareMetadata, @"scene launch");
    else makeShare();
}
- (void)windowScene:(UIWindowScene *)windowScene userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata {
    accept(cloudKitShareMetadata, @"scene delegate");
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"]) return YES;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.window makeKeyAndVisible];
    CKShareMetadata *m = launchOptions[UIApplicationLaunchOptionsCloudKitShareMetadataKey];
    say([NSString stringWithFormat:@"launch options share %@", describe(m)]);
    if (!m) makeShare();
    return YES;
}
- (void)application:(UIApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata {
    accept(cloudKitShareMetadata, @"app delegate");
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
