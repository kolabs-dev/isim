// isim WatchConnectivity: like Apple's Simulator with no paired watch: the session activates, nothing is paired or
// reachable, and everything sent fails with the error iOS gives for it.
#import <WatchConnectivity/WatchConnectivity.h>

NSString * const WCErrorDomain = @"WCErrorDomain";

static NSError *wc_error(WCErrorCode code, NSString *what) {
    return [NSError errorWithDomain:WCErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: what }];
}

@implementation WCSessionFile { NSURL *_url; NSDictionary *_metadata; }
- (instancetype)initWithURL:(NSURL *)url metadata:(NSDictionary *)metadata {
    if ((self = [super init])) { _url = url; _metadata = [metadata copy]; }
    return self;
}
- (NSURL *)fileURL { return _url; }
- (NSDictionary *)metadata { return _metadata; }
@end

@implementation WCSessionFileTransfer { WCSessionFile *_file; NSProgress *_progress; }
- (instancetype)initWithFile:(WCSessionFile *)file {
    if ((self = [super init])) { _file = file; _progress = [NSProgress progressWithTotalUnitCount:1]; }
    return self;
}
- (WCSessionFile *)file { return _file; }
- (NSProgress *)progress { return _progress; }
- (BOOL)isTransferring { return NO; }
- (void)cancel {}
@end

@implementation WCSessionUserInfoTransfer { NSDictionary *_userInfo; BOOL _complication; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithUserInfo:(NSDictionary *)userInfo complication:(BOOL)complication {
    if ((self = [super init])) { _userInfo = [userInfo copy] ?: @{}; _complication = complication; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithUserInfo:[c decodeObjectOfClass:[NSDictionary class] forKey:@"userInfo"] complication:[c decodeBoolForKey:@"complication"]];
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_userInfo forKey:@"userInfo"]; [c encodeBool:_complication forKey:@"complication"]; }
- (NSDictionary *)userInfo { return _userInfo; }
- (BOOL)isCurrentComplicationInfo { return _complication; }
- (BOOL)isTransferring { return NO; }
- (void)cancel {}
@end

@implementation WCSession { WCSessionActivationState _state; NSDictionary *_context; }
+ (BOOL)isSupported { return YES; }
+ (WCSession *)defaultSession {
    static WCSession *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] initISIM]; });
    return s;
}
- (instancetype)initISIM { if ((self = [super init])) _context = @{}; return self; }
- (void)activateSession {
    id<WCSessionDelegate> d = self.delegate;
    if (!d) { NSLog(@"isim WatchConnectivity: activateSession needs a delegate (WCErrorCodeSessionMissingDelegate)"); return; }
    _state = WCSessionActivationStateActivated;
    NSLog(@"isim WatchConnectivity: session activated; no Apple Watch is paired (like the Simulator)");
    dispatch_async(dispatch_get_main_queue(), ^{ [d session:self activationDidCompleteWithState:WCSessionActivationStateActivated error:nil]; });
}
- (WCSessionActivationState)activationState { return _state; }
- (BOOL)hasContentPending { return NO; }
- (BOOL)isPaired { return NO; }
- (BOOL)isWatchAppInstalled { return NO; }
- (BOOL)isComplicationEnabled { return NO; }
- (NSUInteger)remainingComplicationUserInfoTransfers { return 0; }
- (NSURL *)watchDirectoryURL { return nil; }
- (BOOL)isReachable { return NO; }
- (BOOL)iOSDeviceNeedsUnlockAfterRebootForReachability { return NO; }
- (NSError *)notActivated { return _state == WCSessionActivationStateActivated ? nil : wc_error(WCErrorCodeSessionNotActivated, @"WatchConnectivity session has not been activated."); }
- (void)sendMessage:(NSDictionary *)message replyHandler:(void (^)(NSDictionary *))replyHandler errorHandler:(void (^)(NSError *))errorHandler {
    NSError *e = [self notActivated] ?: wc_error(WCErrorCodeNotReachable, @"WatchConnectivity session on paired device is not reachable.");
    if (errorHandler) dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ errorHandler(e); });
}
- (void)sendMessageData:(NSData *)data replyHandler:(void (^)(NSData *))replyHandler errorHandler:(void (^)(NSError *))errorHandler {
    NSError *e = [self notActivated] ?: wc_error(WCErrorCodeNotReachable, @"WatchConnectivity session on paired device is not reachable.");
    if (errorHandler) dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ errorHandler(e); });
}
- (NSDictionary *)applicationContext { return _context; }
- (NSDictionary *)receivedApplicationContext { return @{}; }
- (BOOL)updateApplicationContext:(NSDictionary *)applicationContext error:(NSError **)error {
    if (error) *error = [self notActivated] ?: wc_error(WCErrorCodeDeviceNotPaired, @"Device is not paired.");
    return NO;
}
- (void)finish:(id)transfer {
    id<WCSessionDelegate> d = self.delegate;
    NSError *e = [self notActivated] ?: wc_error(WCErrorCodeDeviceNotPaired, @"Device is not paired.");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([transfer isKindOfClass:[WCSessionUserInfoTransfer class]]) {
            if ([d respondsToSelector:@selector(session:didFinishUserInfoTransfer:error:)]) [d session:self didFinishUserInfoTransfer:transfer error:e];
        } else if ([d respondsToSelector:@selector(session:didFinishFileTransfer:error:)]) [d session:self didFinishFileTransfer:transfer error:e];
    });
}
- (WCSessionUserInfoTransfer *)transferUserInfo:(NSDictionary *)userInfo {
    WCSessionUserInfoTransfer *t = [[WCSessionUserInfoTransfer alloc] initWithUserInfo:userInfo complication:NO];
    [self finish:t];
    return t;
}
- (WCSessionUserInfoTransfer *)transferCurrentComplicationUserInfo:(NSDictionary *)userInfo {
    WCSessionUserInfoTransfer *t = [[WCSessionUserInfoTransfer alloc] initWithUserInfo:userInfo complication:YES];
    [self finish:t];
    return t;
}
- (NSArray *)outstandingUserInfoTransfers { return @[]; }
- (WCSessionFileTransfer *)transferFile:(NSURL *)file metadata:(NSDictionary *)metadata {
    WCSessionFileTransfer *t = [[WCSessionFileTransfer alloc] initWithFile:[[WCSessionFile alloc] initWithURL:file metadata:metadata]];
    [self finish:t];
    return t;
}
- (NSArray *)outstandingFileTransfers { return @[]; }
@end
