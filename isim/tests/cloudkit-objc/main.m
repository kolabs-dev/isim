// CloudKit from Objective-C (CloudKitObjCTest.app, issue #573): #import <CloudKit/CloudKit.h>, -framework CloudKit, over
// isim's local CloudKit. The container and account, typed record values (strings, numbers, lists, dates, data, a
// location, a reference, an asset, an encrypted value), the database's convenience methods, a paged query, modify and
// fetch operations with a serverRecordChanged conflict and a partial failure, a custom zone with its changes and change
// tokens, database changes, subscriptions with an in-process push to the app delegate, a parsed notification, a share and
// its metadata, and the CKSyncEngine enums. The steps run in order on a background queue; results go to the log
// ("CloudKitObjC: ...").
#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>

static void say(NSString *s) { NSLog(@"CloudKitObjC: %@", s); }
#define WAIT(s) dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER)

@interface CloudKitTest : NSObject
@property (nonatomic, strong) CKContainer *container;
@property (nonatomic, strong) CKDatabase *db;
@property (nonatomic, strong) CKRecordZoneID *work;
@end

@implementation CloudKitTest

- (void)run {
    [self account];
    [self records];
    [self operations];
    [self query];
    [self zones];
    [self subscriptions];
    [self share];
    say([NSString stringWithFormat:@"sync engine enums %ld %ld %ld account notification %@", (long)CKSyncEngineEventTypeDidSendChanges,
         (long)CKSyncEngineAccountChangeTypeSwitchAccounts, (long)CKSyncEnginePendingDatabaseChangeTypeDeleteZone, CKAccountChangedNotification]);
    say(@"done");
}

- (void)account {
    self.container = [CKContainer defaultContainer];
    self.db = self.container.privateCloudDatabase;
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    __block CKAccountStatus status = CKAccountStatusCouldNotDetermine;
    [self.container accountStatusWithCompletionHandler:^(CKAccountStatus st, NSError *e) { status = st; dispatch_semaphore_signal(s); }];
    WAIT(s);
    __block CKRecordID *user = nil;
    [self.container fetchUserRecordIDWithCompletionHandler:^(CKRecordID *r, NSError *e) { user = r; dispatch_semaphore_signal(s); }];
    WAIT(s);
    CKContainer *other = [CKContainer containerWithIdentifier:@"iCloud.dev.isim.tests.other"];
    say([NSString stringWithFormat:@"container %@ account %ld user %d scopes %ld %ld %ld other %@", self.container.containerIdentifier, (long)status,
         user.recordName.length > 0, (long)self.db.databaseScope, (long)[self.container databaseWithDatabaseScope:CKDatabaseScopePublic].databaseScope,
         (long)self.container.sharedCloudDatabase.databaseScope, other.containerIdentifier]);
}

- (CKRecord *)note:(NSString *)name title:(NSString *)title count:(int)count zone:(CKRecordZoneID *)zone {
    CKRecordID *rid = zone ? [[CKRecordID alloc] initWithRecordName:name zoneID:zone] : [[CKRecordID alloc] initWithRecordName:name];
    CKRecord *r = [[CKRecord alloc] initWithRecordType:@"Note" recordID:rid];
    r[@"title"] = title;
    r[@"count"] = @(count);
    return r;
}

- (void)records {
    CKRecord *r = [self note:@"n1" title:@"First" count:1 zone:nil];
    r[@"tags"] = @[@"isim", @"objc"];
    r[@"rating"] = @1.5;
    [r setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:1000] forKey:@"when"];
    r[@"blob"] = [@"bytes" dataUsingEncoding:NSUTF8StringEncoding];
    r[@"where"] = [[CLLocation alloc] initWithLatitude:38.33 longitude:-122.0];
    CKRecord *other = [[CKRecord alloc] initWithRecordType:@"Tag"];
    r[@"ref"] = [[CKReference alloc] initWithRecord:other action:CKReferenceActionDeleteSelf];
    NSURL *file = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"asset.txt"]];
    [@"asset bytes" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
    r[@"file"] = [[CKAsset alloc] initWithFileURL:file];
    r.encryptedValues[@"secret"] = @"hidden";
    [r setParentReferenceFromRecordID:other.recordID];
    say([NSString stringWithFormat:@"record %@ %@ keys %@ changed %lu parent %d zone %@", r.recordType, r.recordID.recordName,
         [r.allKeys componentsJoinedByString:@","], (unsigned long)r.changedKeys.count, [r.parent.recordID isEqual:other.recordID], r.recordID.zoneID.zoneName]);

    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    __block CKRecord *saved = nil;
    [self.db saveRecord:r completionHandler:^(CKRecord *rec, NSError *e) { saved = rec; dispatch_semaphore_signal(s); }];
    WAIT(s);
    __block CKRecord *f = nil;
    [self.db fetchRecordWithID:r.recordID completionHandler:^(CKRecord *rec, NSError *e) { f = rec; dispatch_semaphore_signal(s); }];
    WAIT(s);
    CKReference *ref = f[@"ref"];
    CKAsset *asset = f[@"file"];
    CLLocation *loc = f[@"where"];
    NSString *assetText = [NSString stringWithContentsOfURL:asset.fileURL encoding:NSUTF8StringEncoding error:nil];
    say([NSString stringWithFormat:@"saved tag %d fetched title=%@ count=%d rating=%.1f tags=%@ when=%.0f blob=%lu lat=%.2f ref=%d action=%lu asset=%@ secret=%@ created %d",
         saved.recordChangeTag != nil, f[@"title"], [f[@"count"] intValue], [f[@"rating"] doubleValue], [f[@"tags"] componentsJoinedByString:@"+"],
         [f[@"when"] timeIntervalSinceReferenceDate], (unsigned long)[f[@"blob"] length], loc.coordinate.latitude, [ref.recordID isEqual:other.recordID],
         (unsigned long)ref.referenceAction, assetText, f.encryptedValues[@"secret"], f.creationDate != nil]);

    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [f encodeSystemFieldsWithCoder:a];
    [a finishEncoding];
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:a.encodedData error:nil];
    u.requiresSecureCoding = NO;
    CKRecord *restored = [[CKRecord alloc] initWithCoder:u];
    __block NSError *missing = nil;
    [self.db fetchRecordWithID:[[CKRecordID alloc] initWithRecordName:@"nope"] completionHandler:^(CKRecord *rec, NSError *e) { missing = e; dispatch_semaphore_signal(s); }];
    WAIT(s);
    say([NSString stringWithFormat:@"system fields %@ tag %d keys %lu missing %@ %ld", restored.recordID.recordName, [restored.recordChangeTag isEqual:f.recordChangeTag],
         (unsigned long)restored.allKeys.count, missing.domain, (long)missing.code]);
}

- (void)operations {
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    // a stale copy of n1, then n1 changes on the "server"
    __block CKRecord *stale = nil;
    [self.db fetchRecordWithID:[[CKRecordID alloc] initWithRecordName:@"n1"] completionHandler:^(CKRecord *rec, NSError *e) { stale = rec; dispatch_semaphore_signal(s); }];
    WAIT(s);
    CKRecord *fresh = [stale copy];
    fresh[@"title"] = @"First (phone)";
    [self.db saveRecord:fresh completionHandler:^(CKRecord *rec, NSError *e) { dispatch_semaphore_signal(s); }];
    WAIT(s);
    stale[@"title"] = @"First (stale)";

    CKModifyRecordsOperation *op = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[[self note:@"n2" title:@"Second" count:2 zone:nil],
                                                                                              [self note:@"n3" title:@"Third" count:3 zone:nil], stale]
                                                                         recordIDsToDelete:nil];
    op.savePolicy = CKRecordSaveIfServerRecordUnchanged;
    op.atomic = NO;
    op.qualityOfService = NSQualityOfServiceUserInitiated;
    NSMutableArray *events = [NSMutableArray array];
    __block NSString *conflict = @"none";
    op.perRecordSaveBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *e) {
        @synchronized (events) { [events addObject:[NSString stringWithFormat:@"%@:%@", rid.recordName, e ? @(e.code) : @"ok"]]; }
        if (e.code == CKErrorServerRecordChanged) {
            CKRecord *server = e.userInfo[CKRecordChangedErrorServerRecordKey];
            CKRecord *client = e.userInfo[CKRecordChangedErrorClientRecordKey];
            conflict = [NSString stringWithFormat:@"server=%@ client=%@", server[@"title"], client[@"title"]];
        }
    };
    __block NSError *opError = nil;
    __block NSUInteger savedCount = 0;
    op.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> *saved, NSArray<CKRecordID *> *deleted, NSError *e) {
        savedCount = saved.count; opError = e; dispatch_semaphore_signal(s);
    };
    [self.db addOperation:op];
    WAIT(s);
    NSDictionary *partial = opError.userInfo[CKPartialErrorsByItemIDKey];
    say([NSString stringWithFormat:@"modify %@ saved %lu error %ld partial %lu conflict %@ atomic %d qos %ld", [events componentsJoinedByString:@","],
         (unsigned long)savedCount, (long)opError.code, (unsigned long)partial.count, conflict, op.isAtomic, (long)op.qualityOfService]);

    CKFetchRecordsOperation *fetch = [[CKFetchRecordsOperation alloc] initWithRecordIDs:@[[[CKRecordID alloc] initWithRecordName:@"n2"],
                                                                                          [[CKRecordID alloc] initWithRecordName:@"gone"]]];
    fetch.desiredKeys = @[@"title"];
    NSMutableArray *per = [NSMutableArray array];
    fetch.perRecordCompletionBlock = ^(CKRecord *rec, CKRecordID *rid, NSError *e) {
        @synchronized (per) { [per addObject:[NSString stringWithFormat:@"%@:%@", rid.recordName, e ? @(e.code) : rec[@"title"]]]; }
    };
    __block NSDictionary *found = nil;
    fetch.fetchRecordsCompletionBlock = ^(NSDictionary<CKRecordID *, CKRecord *> *byID, NSError *e) { found = byID; opError = e; dispatch_semaphore_signal(s); };
    [self.db addOperation:fetch];
    WAIT(s);
    CKRecord *n2 = found[[[CKRecordID alloc] initWithRecordName:@"n2"]];
    say([NSString stringWithFormat:@"fetch %@ found %lu error %ld desired %@ count %@", [per componentsJoinedByString:@","], (unsigned long)found.count,
         (long)opError.code, n2[@"title"], n2[@"count"] ?: @"nil"]);

    CKModifyRecordsOperation *del = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:@[[[CKRecordID alloc] initWithRecordName:@"n3"]]];
    __block NSString *deleted = @"?";
    del.perRecordDeleteBlock = ^(CKRecordID *rid, NSError *e) { deleted = [NSString stringWithFormat:@"%@:%@", rid.recordName, e ? @(e.code) : @"ok"]; };
    del.modifyRecordsCompletionBlock = ^(NSArray *saved, NSArray *gone, NSError *e) { dispatch_semaphore_signal(s); };
    [self.container addOperation:del];
    WAIT(s);
    say([NSString stringWithFormat:@"delete %@", deleted]);
}

- (void)query {
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    CKQuery *q = [[CKQuery alloc] initWithRecordType:@"Note" predicate:[NSPredicate predicateWithFormat:@"count > 0"]];
    q.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]];
    CKQueryOperation *op = [[CKQueryOperation alloc] initWithQuery:q];
    op.resultsLimit = 1;
    NSMutableArray *titles = [NSMutableArray array];
    op.recordMatchedBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *e) { [titles addObject:rec[@"title"]]; };
    __block CKQueryCursor *cursor = nil;
    op.queryCompletionBlock = ^(CKQueryCursor *c, NSError *e) { cursor = c; dispatch_semaphore_signal(s); };
    [self.db addOperation:op];
    WAIT(s);
    CKQueryOperation *next = [[CKQueryOperation alloc] initWithCursor:cursor];
    next.recordMatchedBlock = op.recordMatchedBlock;
    __block BOOL more = YES;
    next.queryCompletionBlock = ^(CKQueryCursor *c, NSError *e) { more = c != nil; dispatch_semaphore_signal(s); };
    [self.db addOperation:next];
    WAIT(s);
    say([NSString stringWithFormat:@"query %@ cursor %d more %d max %lu", [titles componentsJoinedByString:@","], cursor != nil, more,
         (unsigned long)CKQueryOperationMaximumResults]);
}

- (void)zones {
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    self.work = [[CKRecordZoneID alloc] initWithZoneName:@"Work" ownerName:CKCurrentUserDefaultName];
    CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneID:self.work];
    CKModifyRecordZonesOperation *mz = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[zone] recordZoneIDsToDelete:nil];
    __block NSString *savedZone = @"?";
    mz.perRecordZoneSaveBlock = ^(CKRecordZoneID *zid, CKRecordZone *z, NSError *e) { savedZone = [NSString stringWithFormat:@"%@ caps %lu", zid.zoneName, (unsigned long)z.capabilities]; };
    mz.modifyRecordZonesCompletionBlock = ^(NSArray *saved, NSArray *deleted, NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:mz];
    WAIT(s);
    CKFetchRecordZonesOperation *fz = [CKFetchRecordZonesOperation fetchAllRecordZonesOperation];
    __block NSArray *names = nil;
    __block int perZone = 0;
    fz.perRecordZoneCompletionBlock = ^(CKRecordZoneID *zid, CKRecordZone *z, NSError *e) { perZone++; };
    fz.fetchRecordZonesCompletionBlock = ^(NSDictionary<CKRecordZoneID *, CKRecordZone *> *byID, NSError *e) {
        NSMutableArray *n = [NSMutableArray array];
        for (CKRecordZoneID *zid in byID) [n addObject:zid.zoneName];
        names = [n sortedArrayUsingSelector:@selector(compare:)];
        dispatch_semaphore_signal(s);
    };
    [self.db addOperation:fz];
    WAIT(s);
    say([NSString stringWithFormat:@"zones saved %@ all %@ per %d default %@", savedZone, [names componentsJoinedByString:@","], perZone,
         CKRecordZone.defaultRecordZone.zoneID.zoneName]);

    CKModifyRecordsOperation *put = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[[self note:@"w1" title:@"Work one" count:1 zone:self.work],
                                                                                               [self note:@"w2" title:@"Work two" count:2 zone:self.work]]
                                                                          recordIDsToDelete:nil];
    put.modifyRecordsCompletionBlock = ^(NSArray *saved, NSArray *deleted, NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:put];
    WAIT(s);
    CKFetchRecordZoneChangesOperation *ch = [[CKFetchRecordZoneChangesOperation alloc] initWithRecordZoneIDs:@[self.work] configurationsByRecordZoneID:nil];
    NSMutableArray *changed = [NSMutableArray array];
    ch.recordWasChangedBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *e) { [changed addObject:rid.recordName]; };
    __block CKServerChangeToken *token = nil;
    __block BOOL moreComing = YES;
    ch.recordZoneFetchCompletionBlock = ^(CKRecordZoneID *zid, CKServerChangeToken *t, NSData *client, BOOL more, NSError *e) { token = t; moreComing = more; };
    ch.fetchRecordZoneChangesCompletionBlock = ^(NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:ch];
    WAIT(s);

    CKModifyRecordsOperation *del = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:@[[[CKRecordID alloc] initWithRecordName:@"w2" zoneID:self.work]]];
    del.modifyRecordsCompletionBlock = ^(NSArray *saved, NSArray *deleted, NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:del];
    WAIT(s);
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:token requiringSecureCoding:NO error:nil];
    CKServerChangeToken *kept = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
    CKFetchRecordZoneChangesConfiguration *cfg = [[CKFetchRecordZoneChangesConfiguration alloc] init];
    cfg.previousServerChangeToken = kept;
    CKFetchRecordZoneChangesOperation *since = [[CKFetchRecordZoneChangesOperation alloc] initWithRecordZoneIDs:@[self.work] configurationsByRecordZoneID:@{self.work: cfg}];
    __block int changedSince = 0;
    NSMutableArray *gone = [NSMutableArray array];
    since.recordWasChangedBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *e) { changedSince++; };
    since.recordWithIDWasDeletedBlock = ^(CKRecordID *rid, CKRecordType type) { [gone addObject:[NSString stringWithFormat:@"%@:%@", rid.recordName, type]]; };
    since.fetchRecordZoneChangesCompletionBlock = ^(NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:since];
    WAIT(s);
    say([NSString stringWithFormat:@"zone changes %@ token %d more %d since: changed %d deleted %@", [[changed sortedArrayUsingSelector:@selector(compare:)]
         componentsJoinedByString:@","], kept != nil, moreComing, changedSince, [gone componentsJoinedByString:@","]]);

    CKFetchDatabaseChangesOperation *dbc = [[CKFetchDatabaseChangesOperation alloc] initWithPreviousServerChangeToken:nil];
    NSMutableArray *zonesChanged = [NSMutableArray array];
    dbc.recordZoneWithIDChangedBlock = ^(CKRecordZoneID *zid) { [zonesChanged addObject:zid.zoneName]; };
    __block BOOL dbToken = NO;
    dbc.fetchDatabaseChangesCompletionBlock = ^(CKServerChangeToken *t, BOOL more, NSError *e) { dbToken = t != nil; dispatch_semaphore_signal(s); };
    [self.db addOperation:dbc];
    WAIT(s);
    say([NSString stringWithFormat:@"database changes %@ token %d", [[zonesChanged sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","], dbToken]);
}

- (void)subscriptions {
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    CKQuerySubscription *sub = [[CKQuerySubscription alloc] initWithRecordType:@"Note" predicate:[NSPredicate predicateWithFormat:@"title BEGINSWITH 'Urgent'"]
                                                                subscriptionID:@"urgent" options:CKQuerySubscriptionOptionsFiresOnRecordCreation];
    CKNotificationInfo *info = [[CKNotificationInfo alloc] init];
    info.alertBody = @"An urgent note";
    info.shouldSendContentAvailable = YES;
    sub.notificationInfo = info;
    CKRecordZoneSubscription *zs = [[CKRecordZoneSubscription alloc] initWithZoneID:self.work];
    CKModifySubscriptionsOperation *ms = [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[sub, zs] subscriptionIDsToDelete:nil];
    NSMutableArray *saved = [NSMutableArray array];
    ms.perSubscriptionSaveBlock = ^(CKSubscriptionID sid, CKSubscription *x, NSError *e) { @synchronized (saved) { [saved addObject:@(x.subscriptionType)]; } };
    ms.modifySubscriptionsCompletionBlock = ^(NSArray *a, NSArray *d, NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:ms];
    WAIT(s);
    CKFetchSubscriptionsOperation *fs = [CKFetchSubscriptionsOperation fetchAllSubscriptionsOperation];
    __block NSDictionary *all = nil;
    fs.fetchSubscriptionCompletionBlock = ^(NSDictionary<CKSubscriptionID, CKSubscription *> *byID, NSError *e) { all = byID; dispatch_semaphore_signal(s); };
    [self.db addOperation:fs];
    WAIT(s);
    CKQuerySubscription *back = all[@"urgent"];
    say([NSString stringWithFormat:@"subscriptions types %@ all %lu urgent %@ options %lu alert %@", [[saved sortedArrayUsingSelector:@selector(compare:)]
         componentsJoinedByString:@","], (unsigned long)all.count, back.recordType, (unsigned long)back.querySubscriptionOptions, back.notificationInfo.alertBody]);

    // a matching record: the push goes to the app delegate (in-process, no APNs)
    [self.db saveRecord:[self note:@"u1" title:@"Urgent: call back" count:9 zone:nil] completionHandler:^(CKRecord *r, NSError *e) { dispatch_semaphore_signal(s); }];
    WAIT(s);
    NSDictionary *payload = @{@"ck": @{@"cid": @"iCloud.x", @"qry": @{@"sid": @"urgent", @"fo": @3, @"rid": @"n9", @"dbs": @2}}, @"aps": @{}};
    CKNotification *n = [CKNotification notificationFromRemoteNotificationDictionary:payload];
    CKQueryNotification *qn = (CKQueryNotification *)n;
    say([NSString stringWithFormat:@"parsed %@ type %ld sub %@ reason %ld record %@ scope %ld pruned %d bogus %@", NSStringFromClass(n.class), (long)n.notificationType,
         n.subscriptionID, (long)qn.queryNotificationReason, qn.recordID.recordName, (long)qn.databaseScope, n.isPruned,
         [CKNotification notificationFromRemoteNotificationDictionary:@{@"aps": @{}}] ?: @"nil"]);
    __block NSString *deleted = nil;
    [self.db deleteSubscriptionWithID:@"urgent" completionHandler:^(CKSubscriptionID sid, NSError *e) { deleted = sid; dispatch_semaphore_signal(s); }];
    WAIT(s);
    say([NSString stringWithFormat:@"subscription deleted %@", deleted]);
}

- (void)share {
    dispatch_semaphore_t s = dispatch_semaphore_create(0);
    CKRecord *root = [self note:@"shared" title:@"Shared note" count:1 zone:self.work];
    CKShare *share = [[CKShare alloc] initWithRootRecord:root];
    share[CKShareTitleKey] = @"Notes";
    share.publicPermission = CKShareParticipantPermissionReadOnly;
    CKModifyRecordsOperation *op = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[root, share] recordIDsToDelete:nil];
    __block CKShare *saved = nil;
    op.perRecordSaveBlock = ^(CKRecordID *rid, CKRecord *rec, NSError *e) { if ([rec isKindOfClass:CKShare.class]) saved = (CKShare *)rec; };
    op.modifyRecordsCompletionBlock = ^(NSArray *a, NSArray *d, NSError *e) { dispatch_semaphore_signal(s); };
    [self.db addOperation:op];
    WAIT(s);
    __block CKShareMetadata *meta = nil;
    [self.container fetchShareMetadataWithURL:saved.URL completionHandler:^(CKShareMetadata *m, NSError *e) { meta = m; dispatch_semaphore_signal(s); }];
    WAIT(s);
    say([NSString stringWithFormat:@"share %@ url %d title %@ public %ld owner role %ld status %ld participants %lu root %@ metadata role %ld permission %ld container %d",
         NSStringFromClass(saved.class), saved.URL != nil, saved[CKShareTitleKey], (long)saved.publicPermission, (long)saved.owner.role,
         (long)saved.owner.acceptanceStatus, (unsigned long)saved.participants.count, root.parent.recordID.recordName, (long)meta.participantRole,
         (long)meta.participantPermission, [meta.containerIdentifier isEqual:self.container.containerIdentifier]]);
    CKAllowedSharingOptions *opts = [[CKAllowedSharingOptions alloc] initWithAllowedParticipantPermissionOptions:CKSharingParticipantPermissionOptionReadOnly
                                                                                 allowedParticipantAccessOptions:CKSharingParticipantAccessOptionAny];
    say([NSString stringWithFormat:@"sharing options %lu %lu standard %lu", (unsigned long)opts.allowedParticipantPermissionOptions,
         (unsigned long)opts.allowedParticipantAccessOptions, (unsigned long)CKAllowedSharingOptions.standardOptions.allowedParticipantPermissionOptions]);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CloudKitTest *test;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.window makeKeyAndVisible];
    self.test = [[CloudKitTest alloc] init];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [self.test run]; });
    return YES;
}
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    CKNotification *n = [CKNotification notificationFromRemoteNotificationDictionary:userInfo];
    if (n.notificationType == CKNotificationTypeQuery) {
        CKQueryNotification *q = (CKQueryNotification *)n;
        say([NSString stringWithFormat:@"push %@ subscription %@ reason %ld record %@ alert %@", NSStringFromClass(n.class), n.subscriptionID,
             (long)q.queryNotificationReason, q.recordID.recordName, n.alertBody]);
    } else {
        say([NSString stringWithFormat:@"push %@ subscription %d", NSStringFromClass(n.class), n.subscriptionID.length > 0]);
    }
    completionHandler(UIBackgroundFetchResultNewData);
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
