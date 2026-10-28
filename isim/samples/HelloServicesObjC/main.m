// Sample: the system frameworks ad, login and VoIP SDKs use from Objective-C (issue #231): PushKit and CallKit (a VoIP
// push reports an incoming call; the provider's delegate runs on its own queue; outgoing calls through
// CXCallController; CXCallObserver), BackgroundTasks (a refresh task launched on a dispatch queue), CoreSpotlight
// (indexing), SafariServices (SFSafariViewController, the Reading List) and MultipeerConnectivity (an advertiser and a
// browser in this app connect and exchange data) and Messages (an iMessage app's controller subclass, a message and a
// refused sticker) and BackgroundAssets (an essential download refused outside the downloader extension). Each step prints a "sy ..." line the test checks.
#import <UIKit/UIKit.h>
#import <PushKit/PushKit.h>
#import <CallKit/CallKit.h>
#import <BackgroundTasks/BackgroundTasks.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <SafariServices/SafariServices.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <Messages/Messages.h>
#import <BackgroundAssets/BackgroundAssets.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("sy %s\n", s.UTF8String); fflush(stdout);
}
static NSString *errText(NSError *e) { return e ? [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code] : @"nil"; }
static NSString *const RefreshTask = @"dev.isim.samples.HelloServicesObjC.refresh";
static const char *QueueKey = "svcobjc.queue";

@interface Calls : NSObject <PKPushRegistryDelegate, CXProviderDelegate, CXCallObserverDelegate>
@property (nonatomic, strong) PKPushRegistry *registry;
@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXCallController *controller;
@property (nonatomic, strong) dispatch_queue_t queue;   // ARC retains dispatch objects (#459)
@property (nonatomic, strong) NSUUID *outgoing;
@end

@implementation Calls
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("dev.isim.svcobjc.calls", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, QueueKey, (void *)QueueKey, NULL);
        CXProviderConfiguration *c = [[CXProviderConfiguration alloc] init];
        c.supportsVideo = NO;
        c.maximumCallGroups = 1;
        c.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypeGeneric)];
        _provider = [[CXProvider alloc] initWithConfiguration:c];
        [_provider setDelegate:self queue:_queue];
        _controller = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
        [_controller.callObserver setDelegate:self queue:nil];
        _registry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        _registry.delegate = self;
        _registry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    }
    return self;
}
static BOOL onCallsQueue(void) { return dispatch_get_specific(QueueKey) == QueueKey; }

/* PushKit */
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    say(@"voip token %lu bytes type=%@ same=%d", (unsigned long)credentials.token.length, type,
        [[registry pushTokenForType:PKPushTypeVoIP] isEqualToData:credentials.token]);
}
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type
    withCompletionHandler:(void (^)(void))completion {
    NSDictionary *d = payload.dictionaryPayload;
    say(@"push %@ caller=%@ main=%d", type, d[@"caller"], [NSThread isMainThread]);
    CXCallUpdate *u = [[CXCallUpdate alloc] init];
    u.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:d[@"caller"]];
    u.localizedCallerName = d[@"caller"];
    u.supportsHolding = YES;
    [self.provider reportNewIncomingCallWithUUID:[[NSUUID alloc] initWithUUIDString:d[@"uuid"]] update:u completion:^(NSError *error) {
        say(@"reported incoming error=%@", errText(error));
        completion();
    }];
}
/* CallKit: the provider (its delegate runs on self.queue) */
- (void)providerDidReset:(CXProvider *)provider { say(@"provider reset"); }
- (void)providerDidBegin:(CXProvider *)provider { say(@"provider began queue=%d", onCallsQueue()); }
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    say(@"perform answer %@ queue=%d", action.callUUID.UUIDString, onCallsQueue());
    [action fulfillWithDateConnected:[NSDate date]];
}
- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    say(@"perform start %@ handle=%@ queue=%d", action.callUUID.UUIDString, action.handle.value, onCallsQueue());
    [action fulfillWithDateStarted:[NSDate date]];
    [provider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:[NSDate date]];
}
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    say(@"perform end %@ queue=%d", action.callUUID.UUIDString, onCallsQueue());
    [action fulfillWithDateEnded:[NSDate date]];
}
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    say(@"perform mute %d", action.muted);
    [action fulfill];
}
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession { say(@"audio session activated"); }
/* CallKit: the observer (main queue) */
- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
    say(@"observer %@ outgoing=%d connected=%d ended=%d main=%d", [call.UUID.UUIDString substringToIndex:8], call.outgoing,
        call.hasConnected, call.hasEnded, [NSThread isMainThread]);
    if (call.outgoing && call.hasConnected && !call.hasEnded) [self endCalls];      // hang up the outgoing call from the app
}
- (void)startCall {
    self.outgoing = [NSUUID UUID];
    CXHandle *h = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Cy"];
    CXStartCallAction *a = [[CXStartCallAction alloc] initWithCallUUID:self.outgoing handle:h];
    [self.controller requestTransaction:[[CXTransaction alloc] initWithAction:a] completion:^(NSError *error) {
        say(@"start requested error=%@ main=%d", errText(error), [NSThread isMainThread]);
    }];
}
- (void)endCalls {
    NSMutableArray *actions = [NSMutableArray array];
    for (CXCall *c in self.controller.callObserver.calls) [actions addObject:[[CXEndCallAction alloc] initWithCallUUID:c.UUID]];
    [self.controller requestTransactionWithActions:actions completion:^(NSError *error) {
        say(@"end requested %lu error=%@", (unsigned long)actions.count, errText(error));
    }];
}
- (void)badRequest {
    CXEndCallAction *a = [[CXEndCallAction alloc] initWithCallUUID:[NSUUID UUID]];
    [self.controller requestTransactionWithAction:a completion:^(NSError *error) { say(@"unknown call error=%@", errText(error)); }];
}
@end

@interface Peers : NSObject <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>
@property (nonatomic, strong) MCPeerID *ann, *ben;
@property (nonatomic, strong) MCSession *annSession, *benSession;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@end

@implementation Peers
- (void)start {
    self.ann = [[MCPeerID alloc] initWithDisplayName:@"Ann"];
    self.ben = [[MCPeerID alloc] initWithDisplayName:@"Ben"];
    self.annSession = [[MCSession alloc] initWithPeer:self.ann securityIdentity:nil encryptionPreference:MCEncryptionRequired];
    self.benSession = [[MCSession alloc] initWithPeer:self.ben];
    self.annSession.delegate = self; self.benSession.delegate = self;
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.ben discoveryInfo:@{@"room": @"objc"} serviceType:@"isim-svcobjc"];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.ann serviceType:@"isim-svcobjc"];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
    say(@"mc started service=%@ delegate=%d", self.browser.serviceType, self.browser.delegate == self);
}
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *, NSString *> *)info {
    if (![peerID.displayName isEqualToString:@"Ben"]) return;
    say(@"mc found %@ room=%@", peerID.displayName, info[@"room"]);
    [browser stopBrowsingForPeers];
    [browser invitePeer:peerID toSession:self.annSession withContext:[@"hello" dataUsingEncoding:NSUTF8StringEncoding] timeout:5];
}
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {}
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context
    invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler {
    say(@"mc invitation from %@ context=%@", peerID.displayName, [[NSString alloc] initWithData:context encoding:NSUTF8StringEncoding]);
    invitationHandler(YES, self.benSession);
}
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state != MCSessionStateConnected) return;
    say(@"mc %@ connected to %@", session.myPeerID.displayName, peerID.displayName);
    if (session == self.annSession) {
        NSError *e = nil;
        BOOL ok = [session sendData:[@"ping" dataUsingEncoding:NSUTF8StringEncoding] toPeers:@[peerID] withMode:MCSessionSendDataReliable error:&e];
        say(@"mc sent ok=%d error=%@", ok, errText(e));
    }
}
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    say(@"mc %@ received %@ from %@", session.myPeerID.displayName, s, peerID.displayName);
    if ([s isEqualToString:@"ping"])
        [session sendData:[@"pong" dataUsingEncoding:NSUTF8StringEncoding] toPeers:@[peerID] withMode:MCSessionSendDataReliable error:NULL];
}
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {}
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID
    withProgress:(NSProgress *)progress {}
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID
    atURL:(NSURL *)localURL withError:(NSError *)error {}
@end

@interface ViewController : UIViewController <SFSafariViewControllerDelegate>
@end

@implementation ViewController
- (UIButton *)button:(NSString *)title id:(NSString *)ident y:(CGFloat)y action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:20];
    b.accessibilityIdentifier = ident;
    b.frame = CGRectMake(20, y, self.view.bounds.size.width - 40, 44);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 40)];
    title.text = @"System frameworks (Objective-C)";
    title.font = [UIFont boldSystemFontOfSize:22];
    [self.view addSubview:title];
    [self button:@"Open in Safari View" id:@"safari" y:150 action:@selector(openSafari)];
    [self button:@"Start a call" id:@"call-start" y:210 action:@selector(startCall)];
}
- (void)openSafari {
    SFSafariViewControllerConfiguration *c = [[SFSafariViewControllerConfiguration alloc] init];
    c.barCollapsingEnabled = NO;
    NSString *url = [NSProcessInfo.processInfo.environment objectForKey:@"SYSOBJC_URL"] ?: @"https://example.com/";
    SFSafariViewController *s = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url] configuration:c];
    s.delegate = self;
    s.preferredControlTintColor = UIColor.systemOrangeColor;
    s.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleClose;
    say(@"safari present collapsing=%d delegate=%d", s.configuration.barCollapsingEnabled, s.delegate == self);
    [self presentViewController:s animated:YES completion:nil];
}
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    say(@"safari initial load %d", didLoadSuccessfully);
}
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller { say(@"safari finished"); }
- (void)startCall { [(id)UIApplication.sharedApplication.delegate performSelector:@selector(startCall)]; }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) Calls *calls;
@property (nonatomic, strong) Peers *peers;
@end

/* an iMessage app's view controller, subclassed in Objective-C */
@interface GameController : MSMessagesAppViewController
@end
@implementation GameController
- (void)didBecomeActiveWithConversation:(MSConversation *)conversation { say(@"messages active"); }
@end

@implementation AppDelegate
- (void)startCall { [self.calls startCall]; }

- (void)backgroundTasks {
    BGTaskScheduler *s = BGTaskScheduler.sharedScheduler;
    dispatch_queue_t q = dispatch_queue_create("dev.isim.svcobjc.bg", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(q, QueueKey, (void *)QueueKey, NULL);
    BOOL registered = [s registerForTaskWithIdentifier:RefreshTask usingQueue:q launchHandler:^(__kindof BGTask *task) {
        say(@"bg task %@ refresh=%d queue=%d", task.identifier, [task isKindOfClass:[BGAppRefreshTask class]], onCallsQueue());
        task.expirationHandler = ^{ say(@"bg expired"); };
        [task setTaskCompletedWithSuccess:YES];
    }];
    BOOL other = [s registerForTaskWithIdentifier:@"not.permitted" usingQueue:nil launchHandler:^(BGTask *task) {}];
    BGAppRefreshTaskRequest *r = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:RefreshTask];
    r.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:60];
    NSError *e = nil;
    BOOL ok = [s submitTaskRequest:r error:&e];
    NSError *e2 = nil;
    BOOL bad = [s submitTaskRequest:[[BGProcessingTaskRequest alloc] initWithIdentifier:@"not.permitted"] error:&e2];
    say(@"bg registered=%d other=%d submitted=%d error=%@ refused=%d error=%@", registered, other, ok, errText(e), !bad, errText(e2));
    [s getPendingTaskRequestsWithCompletionHandler:^(NSArray<BGTaskRequest *> *requests) {
        say(@"bg pending %lu first=%@ date=%d", (unsigned long)requests.count, requests.firstObject.identifier,
            requests.firstObject.earliestBeginDate != nil);
    }];
}

- (void)spotlight {
    CSSearchableItemAttributeSet *a = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.text"];
    a.title = @"Objective-C note";
    a.contentDescription = @"Indexed from Objective-C";
    a.keywords = @[@"objc", @"note"];
    CSSearchableItem *item = [[CSSearchableItem alloc] initWithUniqueIdentifier:@"note-1" domainIdentifier:@"notes" attributeSet:a];
    say(@"spotlight available=%d expires=%d", [CSSearchableIndex isIndexingAvailable], item.expirationDate != nil);
    [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:@[item] completionHandler:^(NSError *error) {
        say(@"spotlight indexed %@ error=%@ activity=%@", item.uniqueIdentifier, errText(error), CSSearchableItemActionType);
    }];
}

- (void)readingList {
    NSError *e = nil;
    BOOL ok = [[SSReadingList defaultReadingList] addReadingListItemWithURL:[NSURL URLWithString:@"https://example.com/article"]
                                                                      title:@"Article" previewText:nil error:&e];
    NSError *e2 = nil;
    BOOL bad = [[SSReadingList defaultReadingList] addReadingListItemWithURL:[NSURL URLWithString:@"ftp://example.com/file"]
                                                                       title:nil previewText:nil error:&e2];
    say(@"reading list ok=%d refused=%d error=%@ supports=%d", ok, !bad, errText(e2),
        [SSReadingList supportsURL:[NSURL URLWithString:@"https://example.com"]]);
    // no content blocker extension in this app: SFErrorNoExtensionFound
    [SFContentBlockerManager getStateOfContentBlockerWithIdentifier:@"dev.isim.samples.HelloServicesObjC.Blocker"
                                                  completionHandler:^(SFContentBlockerState *state, NSError *error) {
        [SFContentBlockerManager reloadContentBlockerWithIdentifier:@"dev.isim.samples.HelloServicesObjC.Blocker"
                                                  completionHandler:^(NSError *reloadError) {
            say(@"content blocker state=%d error=%@ reload=%@ missing=%d", state != nil, errText(error), errText(reloadError),
                [reloadError.domain isEqual:SFErrorDomain] && reloadError.code == SFErrorNoExtensionFound);
        }];
    }];
}

/* BackgroundAssets from Objective-C (issue #407): an essential download is the downloader extension's at install */
- (void)backgroundAssets {
    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/level.bin"]];
    BAURLDownload *d = [[BAURLDownload alloc] initWithIdentifier:@"level" request:r essential:YES fileSize:4096
                                      applicationGroupIdentifier:@"group.dev.isim.samples.helloservicesobjc" priority:BADownloaderPriorityDefault];
    NSError *e = nil;
    BOOL ok = [BADownloadManager.sharedManager scheduleDownload:d error:&e];
    BADownload *plain = [d removingEssential];
    say(@"assets scheduled=%d error=%@ state=%ld essential=%d plain=%d same=%d priority=%ld", ok,
        [e.domain isEqual:BAErrorDomain] && e.code == BAErrorCodeDownloadEssentialDownloadNotPermitted ? @"essential" : errText(e),
        (long)d.state, d.isEssential, plain.isEssential, [plain.identifier isEqual:d.identifier], (long)d.priority);
}

/* Messages from Objective-C (issue #406): an iMessage app's controller subclass, a message in a session with a
   template layout (copied and archived), a sticker file iOS refuses */
- (void)messages {
    MSSession *session = [[MSSession alloc] init];
    MSMessage *m = [[MSMessage alloc] initWithSession:session];
    MSMessageTemplateLayout *layout = [[MSMessageTemplateLayout alloc] init];
    layout.caption = @"Your move";
    m.layout = layout;
    m.URL = [NSURL URLWithString:@"https://example.com/ttt?board=X--------"];
    m.summaryText = @"Your move";
    MSMessage *copy = [m copy];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:m requiringSecureCoding:YES error:NULL];
    MSMessage *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[MSMessage class] fromData:archive error:NULL];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"not-a-sticker.txt"];
    [@"hello" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSError *e = nil;
    MSSticker *sticker = [[MSSticker alloc] initWithContentsOfFileURL:[NSURL fileURLWithPath:path] localizedDescription:@"Text" error:&e];
    GameController *vc = [[GameController alloc] initWithNibName:nil bundle:nil];
    say(@"messages caption=%@ copy=%@ session=%d archived=%@ sameSession=%d pending=%d sticker=%d error=%@ style=%lu active=%d",
        ((MSMessageTemplateLayout *)m.layout).caption, ((MSMessageTemplateLayout *)copy.layout).caption, copy.session == session,
        back.URL.query, [back.session isEqual:session], m.isPending, sticker != nil,
        [e.domain isEqual:MSStickersErrorDomain] && e.code == MSMessageErrorCodeStickerFileImproperFileFormat ? @"format" : errText(e),
        (unsigned long)vc.presentationStyle, vc.activeConversation != nil);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.calls = [[Calls alloc] init];
    [self backgroundTasks];
    if (application.applicationState == UIApplicationStateBackground) return YES;   // launched for a push or a task
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self spotlight];
    [self readingList];
    [self messages];
    [self backgroundAssets];
    [self.calls badRequest];
    self.peers = [[Peers alloc] init];
    [self.peers start];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
