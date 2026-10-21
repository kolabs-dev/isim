// isim AccessorySetupKit: like Apple's Simulator, no accessory is ever nearby or set up.
#import <AccessorySetupKit/AccessorySetupKit.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   // the framework implements what iOS 18 declares

NSErrorDomain const ASErrorDomain = @"com.apple.AccessorySetupKit.ErrorDomain";

static NSError *as_error(ASErrorCode code, NSString *what) {
    return [NSError errorWithDomain:ASErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: what }];
}

@implementation ASDiscoveryDescriptor
@synthesize bluetoothServiceUUID = _bluetoothServiceUUID;
@end

@implementation ASAccessory
- (ASAccessoryState)state { return ASAccessoryStateUnauthorized; }
- (NSUUID *)bluetoothIdentifier { return nil; }
- (NSString *)displayName { return @""; }
- (NSString *)SSID { return nil; }
- (ASDiscoveryDescriptor *)descriptor { return [ASDiscoveryDescriptor new]; }
@end

@implementation ASPickerDisplayItem { NSString *_name; UIImage *_image; ASDiscoveryDescriptor *_descriptor; }
- (instancetype)initWithName:(NSString *)name productImage:(UIImage *)productImage descriptor:(ASDiscoveryDescriptor *)descriptor {
    if ((self = [super init])) { _name = [name copy]; _image = productImage; _descriptor = descriptor; }
    return self;
}
- (NSString *)name { return _name; }
- (UIImage *)productImage { return _image; }
- (ASDiscoveryDescriptor *)descriptor { return _descriptor; }
@end

@implementation ASAccessoryEvent { ASAccessoryEventType _type; NSError *_error; }
- (instancetype)initWithType:(ASAccessoryEventType)type error:(NSError *)error {
    if ((self = [super init])) { _type = type; _error = error; }
    return self;
}
- (ASAccessoryEventType)eventType { return _type; }
- (ASAccessory *)accessory { return nil; }
- (NSError *)error { return _error; }
@end

@implementation ASAccessorySession { dispatch_queue_t _queue; void (^_handler)(ASAccessoryEvent *); BOOL _active; }
- (NSArray *)accessories { return @[]; }
- (void)send:(ASAccessoryEventType)type error:(NSError *)error {
    void (^h)(ASAccessoryEvent *) = _handler;
    if (!h) return;
    ASAccessoryEvent *e = [[ASAccessoryEvent alloc] initWithType:type error:error];
    dispatch_async(_queue ?: dispatch_get_main_queue(), ^{ h(e); });
}
- (void)activateWithQueue:(dispatch_queue_t)queue eventHandler:(void (^)(ASAccessoryEvent *))eventHandler {
    _queue = queue; _handler = [eventHandler copy]; _active = YES;
    NSLog(@"isim AccessorySetupKit: session activated; no accessories (like the Simulator)");
    [self send:ASAccessoryEventTypeActivated error:nil];
}
- (void)invalidate {
    if (!_active) return;
    _active = NO;
    [self send:ASAccessoryEventTypeInvalidated error:nil];
    _handler = nil;
}
- (void)showPickerForDisplayItems:(NSArray<ASPickerDisplayItem *> *)displayItems completionHandler:(void (^)(NSError *))completionHandler {
    void (^done)(NSError *) = [completionHandler copy];
    NSError *e = _active ? as_error(ASErrorCodeDiscoveryTimeout, @"No accessories found.") : as_error(ASErrorCodeActivationFailed, @"The session is not activated.");
    NSLog(@"isim AccessorySetupKit: the picker found none of %lu accessory kind(s)", (unsigned long)displayItems.count);
    dispatch_async(_queue ?: dispatch_get_main_queue(), ^{ if (done) done(e); });
}
- (void)removeAccessory:(ASAccessory *)accessory completionHandler:(void (^)(NSError *))completionHandler {
    void (^done)(NSError *) = [completionHandler copy];
    dispatch_async(_queue ?: dispatch_get_main_queue(), ^{ if (done) done(as_error(ASErrorCodeInvalidRequest, @"The accessory was not set up by this app.")); });
}
- (void)renameAccessory:(ASAccessory *)accessory options:(ASAccessoryRenameOptions)renameOptions completionHandler:(void (^)(NSError *))completionHandler {
    void (^done)(NSError *) = [completionHandler copy];
    dispatch_async(_queue ?: dispatch_get_main_queue(), ^{ if (done) done(as_error(ASErrorCodeInvalidRequest, @"The accessory was not set up by this app.")); });
}
@end
