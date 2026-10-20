/* isim Foundation (ARC): NSURLProtocol, the base class of URL protocols (Objective-C subclasses, and Swift's URLProtocol
   in the overlay, which overrides these methods with its Swift-typed ones). The requests, tasks and responses are the
   overlay's classes, reached through the runtime; a request keeps its protocol properties (the overlay's URLRequest),
   read and written here through private selectors. URLSession calls the isim_url_protocol_* functions. */
#import <Foundation/Foundation.h>

@interface NSObject (IsimURLProtocolRequest)
- (NSDictionary *)_isimProtocolProperties;
- (void)_isimSetProtocolProperty:(id)value forKey:(NSString *)key;
- (id)currentRequest;
- (id)originalRequest;
@end

static NSMutableArray *registered;
static NSLock *registry_lock;

@implementation NSURLProtocol {
    id _request, _cachedResponse, _client;
    __weak id _task;
}
+ (void)initialize { if (self == [NSURLProtocol class]) { registered = [NSMutableArray array]; registry_lock = [NSLock new]; } }
- (instancetype)init { return [self initWithIsimRequest:(id _Nonnull)nil cachedResponse:nil client:nil]; }
- (instancetype)initWithRequest:(id)request cachedResponse:(id)cachedResponse client:(id)client {
    return [self initWithIsimRequest:request cachedResponse:cachedResponse client:client];
}
/* the designated initializer: Swift's URLProtocol defines initWithRequest:cachedResponse:client: itself and calls this one */
- (instancetype)initWithIsimRequest:(id)request cachedResponse:(id)cachedResponse client:(id)client {
    if ((self = [super init])) { _request = [request copy]; _cachedResponse = cachedResponse; _client = client; }
    return self;
}
- (instancetype)initWithTask:(id)task cachedResponse:(id)cachedResponse client:(id)client {
    if ((self = [self initWithRequest:[task currentRequest] ?: [task originalRequest] cachedResponse:cachedResponse client:client])) _task = task;
    return self;
}
- (id)client { return _client; }
- (id)request { return _request; }
- (id)cachedResponse { return _cachedResponse; }
- (id)task { return _task; }
+ (BOOL)canInitWithRequest:(id)request { return NO; }
+ (BOOL)canInitWithTask:(id)task {
    id r = [task currentRequest] ?: [task originalRequest];
    return r ? [self canInitWithRequest:r] : NO;
}
+ (id)canonicalRequestForRequest:(id)request { return request; }
+ (BOOL)requestIsCacheEquivalent:(id)a toRequest:(id)b {
    return [[self canonicalRequestForRequest:a] isEqual:[self canonicalRequestForRequest:b]];
}
- (void)startLoading {}
- (void)stopLoading {}

+ (id)propertyForKey:(NSString *)key inRequest:(id)request {
    return [request respondsToSelector:@selector(_isimProtocolProperties)] ? [request _isimProtocolProperties][key] : nil;
}
+ (void)setProperty:(id)value forKey:(NSString *)key inRequest:(id)request {
    if ([request respondsToSelector:@selector(_isimSetProtocolProperty:forKey:)]) [request _isimSetProtocolProperty:value forKey:key];
}
+ (void)removePropertyForKey:(NSString *)key inRequest:(id)request {
    if ([request respondsToSelector:@selector(_isimSetProtocolProperty:forKey:)]) [request _isimSetProtocolProperty:nil forKey:key];
}

/* the shared session asks the registered classes, the latest first */
+ (BOOL)registerClass:(Class)cls {
    if (!cls || ![cls isSubclassOfClass:[NSURLProtocol class]]) return NO;
    [registry_lock lock];
    [registered removeObject:cls];
    [registered insertObject:cls atIndex:0];
    [registry_lock unlock];
    return YES;
}
+ (void)unregisterClass:(Class)cls {
    [registry_lock lock];
    [registered removeObject:cls];
    [registry_lock unlock];
}
@end

NSArray *isim_url_protocol_registered(void) {
    [NSURLProtocol class];
    [registry_lock lock];
    NSArray *a = [registered copy];
    [registry_lock unlock];
    return a;
}
BOOL isim_url_protocol_can_init(Class cls, id task) {
    return [cls isSubclassOfClass:[NSURLProtocol class]] && [cls canInitWithTask:task];
}
id isim_url_protocol_canonical(Class cls, id request) { return [cls canonicalRequestForRequest:request] ?: request; }
NSURLProtocol *isim_url_protocol_create(Class cls, id task, id cachedResponse, id client) {
    return [[cls alloc] initWithTask:task cachedResponse:cachedResponse client:client];
}
