// isim SystemConfiguration: SCNetworkReachability from the host's connectivity (isim_net_path). A reachability object is
// an Objective-C object (CFRetain / CFRelease work on it); with a callback and a dispatch queue it reports the current
// flags, then every change (polled every two seconds).
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <isim_host.h>

@interface ISIMReachability : NSObject {
@public
    BOOL local;
    SCNetworkReachabilityCallBack callout;
    SCNetworkReachabilityContext context;
    dispatch_queue_t queue;
    dispatch_source_t timer;
    SCNetworkReachabilityFlags last;
}
@end
@implementation ISIMReachability
- (void)dealloc {
    if (timer) dispatch_source_cancel(timer);
    if (context.release && context.info) context.release(context.info);
}
@end

static SCNetworkReachabilityFlags current_flags(ISIMReachability *r) {
    int flags = 0;
    if (r->local) return kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsLocalAddress | kSCNetworkReachabilityFlagsIsDirect;
    return isim_net_path(&flags) ? kSCNetworkReachabilityFlagsReachable : 0;
}
static SCNetworkReachabilityRef make(BOOL local) {
    ISIMReachability *r = [ISIMReachability new];
    r->local = local;
    return (SCNetworkReachabilityRef)CFBridgingRetain(r);
}
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName(CFAllocatorRef a, const char *name) {
    return name ? make(!strcmp(name, "localhost") || !strcmp(name, "127.0.0.1") || !strcmp(name, "::1")) : NULL;
}
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress(CFAllocatorRef a, const struct sockaddr *addr) {
    if (!addr) return NULL;
    BOOL local = NO;
    if (addr->sa_family == AF_INET) local = ((const uint8_t *)addr)[4] == 127;   /* sin_addr's first byte */
    return make(local);
}
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddressPair(CFAllocatorRef a, const struct sockaddr *l, const struct sockaddr *r) {
    return SCNetworkReachabilityCreateWithAddress(a, r ? r : l);
}
Boolean SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef t, SCNetworkReachabilityFlags *flags) {
    if (!t || !flags) return false;
    *flags = current_flags((__bridge ISIMReachability *)t);
    return true;
}
static void fire(ISIMReachability *r, SCNetworkReachabilityFlags f) {
    if (r->callout) r->callout((__bridge SCNetworkReachabilityRef)r, f, r->context.info);
}
static void reschedule(ISIMReachability *r) {
    if (r->timer) { dispatch_source_cancel(r->timer); r->timer = nil; }
    if (!r->callout || !r->queue) return;
    r->last = current_flags(r);
    __weak ISIMReachability *weak = r;
    SCNetworkReachabilityFlags first = r->last;
    dispatch_async(r->queue, ^{ ISIMReachability *s = weak; if (s) fire(s, first); });
    r->timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, r->queue);
    dispatch_source_set_timer(r->timer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 2 * NSEC_PER_SEC, NSEC_PER_SEC / 10);
    dispatch_source_set_event_handler(r->timer, ^{
        ISIMReachability *s = weak;
        if (!s) return;
        SCNetworkReachabilityFlags f = current_flags(s);
        if (f != s->last) { s->last = f; fire(s, f); }
    });
    dispatch_resume(r->timer);
}
Boolean SCNetworkReachabilitySetCallback(SCNetworkReachabilityRef t, SCNetworkReachabilityCallBack callout, SCNetworkReachabilityContext *ctx) {
    ISIMReachability *r = (__bridge ISIMReachability *)t;
    if (!r) return false;
    if (r->context.release && r->context.info) r->context.release(r->context.info);
    r->callout = callout;
    r->context = ctx ? *ctx : (SCNetworkReachabilityContext){ 0 };
    if (r->context.retain && r->context.info) r->context.info = (void *)r->context.retain(r->context.info);
    reschedule(r);
    return true;
}
Boolean SCNetworkReachabilitySetDispatchQueue(SCNetworkReachabilityRef t, dispatch_queue_t queue) {
    ISIMReachability *r = (__bridge ISIMReachability *)t;
    if (!r) return false;
    r->queue = queue;
    reschedule(r);
    return true;
}
CFTypeID SCNetworkReachabilityGetTypeID(void) { return 0x5C0; }
