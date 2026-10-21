// isim CFNetwork: CFHost (adapted). A host is an Objective-C object (CFRetain / CFRelease work on it). Addresses and
// names come from the host's resolver through libSystem (getaddrinfo / getnameinfo, Darwin socket addresses);
// reachability is SystemConfiguration's. Without a client, CFHostStartInfoResolution resolves before it returns; with
// one, it resolves on a background queue and calls the client on the run loops the host is scheduled on (none: no
// callback, as on iOS).
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <netdb.h>
#include <sys/socket.h>

const CFStringRef kCFErrorDomainCFNetwork = CFSTR("kCFErrorDomainCFNetwork");
const CFStringRef kCFErrorDomainWinSock = CFSTR("kCFErrorDomainWinSock");
const CFStringRef kCFGetAddrInfoFailureKey = CFSTR("kCFGetAddrInfoFailureKey");
const SInt32 kCFStreamErrorDomainNetDB = 12;
const SInt32 kCFStreamErrorDomainSystemConfiguration = 13;

@interface ISIMCFHost : NSObject {
@public
    NSString *name;                    /* created with a name, or */
    NSData *address;                   /* with an address */
    NSArray *addresses, *names;
    NSData *reachability;
    CFHostClientCallBack client;
    CFHostClientContext context;
    NSMutableArray<NSArray *> *schedules;    /* (run loop, mode) */
    NSUInteger generation[3];          /* bumped by a cancel: a resolution of an older generation is dropped */
}
@end
@implementation ISIMCFHost
- (CFTypeID)_isimCFTypeID { return CFHostGetTypeID(); }
- (void)dealloc { if (context.release && context.info) context.release(context.info); }
- (NSString *)description {
    return [NSString stringWithFormat:@"<CFHost %p>{%@}", self, name ?: [NSString stringWithFormat:@"%lu-byte address", (unsigned long)address.length]];
}
@end

CFTypeID CFHostGetTypeID(void) { return 0x5C1; }

static ISIMCFHost *H(CFHostRef h) { return (__bridge ISIMCFHost *)h; }

CFHostRef CFHostCreateWithName(CFAllocatorRef allocator, CFStringRef hostname) {
    if (!hostname) return NULL;
    ISIMCFHost *h = [ISIMCFHost new];
    h->name = [(__bridge NSString *)hostname copy];
    return (CFHostRef)CFBridgingRetain(h);
}
CFHostRef CFHostCreateWithAddress(CFAllocatorRef allocator, CFDataRef addr) {
    if (!addr || CFDataGetLength(addr) < (CFIndex)sizeof(struct sockaddr)) return NULL;
    ISIMCFHost *h = [ISIMCFHost new];
    h->address = [(__bridge NSData *)addr copy];
    h->addresses = @[h->address];
    return (CFHostRef)CFBridgingRetain(h);
}
CFHostRef CFHostCreateCopy(CFAllocatorRef alloc, CFHostRef host) {
    ISIMCFHost *s = H(host);
    if (!s) return NULL;
    ISIMCFHost *h = [ISIMCFHost new];
    h->name = s->name; h->address = s->address;
    h->addresses = s->addresses; h->names = s->names; h->reachability = s->reachability;
    return (CFHostRef)CFBridgingRetain(h);
}

/* one resolution, off any lock: the result to store, or the error */
typedef struct { NSArray *addresses, *names; NSData *reachability; CFStreamError error; } resolution;

static resolution resolve(NSString *name, NSData *address, CFHostInfoType info) {
    resolution r = { 0 };
    if (info == kCFHostAddresses) {
        if (!name) { r.addresses = address ? @[address] : @[]; return r; }
        struct addrinfo hints = { 0 }, *res = NULL;
        hints.ai_family = AF_UNSPEC; hints.ai_socktype = SOCK_STREAM;
        int e = getaddrinfo(name.UTF8String, NULL, &hints, &res);
        if (e) { r.error = (CFStreamError){ kCFStreamErrorDomainNetDB, e }; return r; }
        NSMutableArray *list = [NSMutableArray array];
        for (struct addrinfo *a = res; a; a = a->ai_next) {
            NSData *d = [NSData dataWithBytes:a->ai_addr length:a->ai_addrlen];
            if (![list containsObject:d]) [list addObject:d];
        }
        freeaddrinfo(res);
        r.addresses = list;
    } else if (info == kCFHostNames) {
        if (!address) { r.names = name ? @[name] : @[]; return r; }
        char host[NI_MAXHOST];
        int e = getnameinfo(address.bytes, (socklen_t)address.length, host, sizeof host, NULL, 0, NI_NAMEREQD);
        if (e) { r.error = (CFStreamError){ kCFStreamErrorDomainNetDB, e }; return r; }
        r.names = @[@(host)];
    } else if (info == kCFHostReachability) {
        SCNetworkReachabilityRef reach = name ? SCNetworkReachabilityCreateWithName(NULL, name.UTF8String)
                                              : SCNetworkReachabilityCreateWithAddress(NULL, address.bytes);
        SCNetworkReachabilityFlags flags = 0;
        if (!reach || !SCNetworkReachabilityGetFlags(reach, &flags)) r.error = (CFStreamError){ kCFStreamErrorDomainSystemConfiguration, -1 };
        else r.reachability = [NSData dataWithBytes:&flags length:sizeof flags];
        if (reach) CFRelease(reach);
    } else r.error = (CFStreamError){ kCFStreamErrorDomainNetDB, EAI_FAIL };
    return r;
}
static void store(ISIMCFHost *h, CFHostInfoType info, resolution r) {
    @synchronized (h) {
        if (r.addresses) h->addresses = r.addresses;
        if (r.names) h->names = r.names;
        if (r.reachability) h->reachability = r.reachability;
    }
}

Boolean CFHostStartInfoResolution(CFHostRef theHost, CFHostInfoType info, CFStreamError *error) {
    ISIMCFHost *h = H(theHost);
    if (error) *error = (CFStreamError){ 0, 0 };
    if (!h || info < kCFHostAddresses || info > kCFHostReachability) return false;
    NSString *name = h->name; NSData *address = h->address;
    if (!h->client) {                                              /* synchronous */
        resolution r = resolve(name, address, info);
        if (r.error.domain) { if (error) *error = r.error; return false; }
        store(h, info, r);
        return true;
    }
    NSUInteger gen;
    @synchronized (h) { gen = h->generation[info]; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        resolution r = resolve(name, address, info);
        NSArray *schedules;
        @synchronized (h) {
            if (h->generation[info] != gen) return;                /* cancelled */
            schedules = [h->schedules copy];
        }
        if (!r.error.domain) store(h, info, r);
        CFStreamError err = r.error;
        for (NSArray *s in schedules) {
            CFRunLoopRef rl = (__bridge CFRunLoopRef)s[0];
            CFRunLoopPerformBlock(rl, (__bridge CFStringRef)s[1], ^{
                @synchronized (h) { if (h->generation[info] != gen || !h->client) return; }
                h->client((__bridge CFHostRef)h, info, &err, h->context.info);
            });
            CFRunLoopWakeUp(rl);
        }
    });
    return true;
}

CFArrayRef CFHostGetAddressing(CFHostRef theHost, Boolean *hasBeenResolved) {
    ISIMCFHost *h = H(theHost);
    @synchronized (h) {
        if (hasBeenResolved) *hasBeenResolved = h && h->addresses != nil;
        return h ? (__bridge CFArrayRef)h->addresses : NULL;
    }
}
CFArrayRef CFHostGetNames(CFHostRef theHost, Boolean *hasBeenResolved) {
    ISIMCFHost *h = H(theHost);
    @synchronized (h) {
        if (hasBeenResolved) *hasBeenResolved = h && h->names != nil;
        return h ? (__bridge CFArrayRef)h->names : NULL;
    }
}
CFDataRef CFHostGetReachability(CFHostRef theHost, Boolean *hasBeenResolved) {
    ISIMCFHost *h = H(theHost);
    @synchronized (h) {
        if (hasBeenResolved) *hasBeenResolved = h && h->reachability != nil;
        return h ? (__bridge CFDataRef)h->reachability : NULL;
    }
}

void CFHostCancelInfoResolution(CFHostRef theHost, CFHostInfoType info) {
    ISIMCFHost *h = H(theHost);
    if (!h || info < kCFHostAddresses || info > kCFHostReachability) return;
    @synchronized (h) { h->generation[info]++; }
}
Boolean CFHostSetClient(CFHostRef theHost, CFHostClientCallBack clientCB, CFHostClientContext *clientContext) {
    ISIMCFHost *h = H(theHost);
    if (!h) return false;
    @synchronized (h) {
        if (h->context.release && h->context.info) h->context.release(h->context.info);
        h->client = clientCB;
        h->context = clientCB && clientContext ? *clientContext : (CFHostClientContext){ 0 };
        if (h->context.retain && h->context.info) h->context.info = (void *)h->context.retain(h->context.info);
        if (!clientCB) for (int i = 0; i < 3; i++) h->generation[i]++;   /* removing the client cancels resolutions */
    }
    return true;
}
void CFHostScheduleWithRunLoop(CFHostRef theHost, CFRunLoopRef runLoop, CFStringRef runLoopMode) {
    ISIMCFHost *h = H(theHost);
    if (!h || !runLoop || !runLoopMode) return;
    @synchronized (h) {
        if (!h->schedules) h->schedules = [NSMutableArray array];
        NSArray *s = @[(__bridge id)runLoop, (__bridge NSString *)runLoopMode];
        if (![h->schedules containsObject:s]) [h->schedules addObject:s];
    }
}
void CFHostUnscheduleFromRunLoop(CFHostRef theHost, CFRunLoopRef runLoop, CFStringRef runLoopMode) {
    ISIMCFHost *h = H(theHost);
    if (!h || !runLoop || !runLoopMode) return;
    @synchronized (h) { [h->schedules removeObject:@[(__bridge id)runLoop, (__bridge NSString *)runLoopMode]]; }
}
