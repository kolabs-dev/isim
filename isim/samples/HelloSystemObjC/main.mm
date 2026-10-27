// Sample: the C and Objective-C system APIs that binary SDKs (Google Mobile Ads, analytics, game engines) link from
// Objective-C and C++ (issue #200): JavaScriptCore (JSContext, blocks, JSExport, the C API), CoreMedia's CMTime,
// AVFoundation's Objective-C classes, Security (SecRandomCopyBytes, SecKey), SystemConfiguration reachability, CFNetwork's
// CFHost, CoreFoundation's streams and sockets, Network's path monitor, CoreTelephony, MobileCoreServices' UTType functions, CoreFoundation strings, zlib, libcompression and
// libc++ iostreams and locales. Logs "HelloSystemObjC: ...".
//   isim run out/apps/HelloSystemObjC.app
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <Network/Network.h>
#import <CoreTelephony/CoreTelephony.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AdSupport/AdSupport.h>
#import <StoreKit/StoreKit.h>
#include <netinet/in.h>
#include <zlib.h>
#include <compression.h>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <locale>
#include <regex>
#include <string>

static void say(NSString *s) { fprintf(stderr, "HelloSystemObjC: %s\n", s.UTF8String); }

/* an Objective-C object JavaScript can use through its JSExport protocol */
@protocol SampleCounterExports <JSExport>
@property (nonatomic) NSInteger count;
- (NSInteger)addValue:(NSInteger)v;
@end
@interface SampleCounter : NSObject <SampleCounterExports>
@property (nonatomic) NSInteger count;
@end
@implementation SampleCounter
- (NSInteger)addValue:(NSInteger)v { self.count += v; return self.count; }
@end

static void javascript(void) {
    JSContext *ctx = [JSContext new];
    __block NSString *thrown = nil;
    ctx.exceptionHandler = ^(JSContext *c, JSValue *e) { thrown = e.toString; };
    say([NSString stringWithFormat:@"js 6*7=%d str=%@", [ctx evaluateScript:@"6 * 7"].toInt32,
         [ctx evaluateScript:@"['a', 'b'].join('+')"].toString]);
    ctx[@"twice"] = ^(int v) { return v * 2; };
    ctx[@"native"] = ^NSString *(NSString *s) { return [NSString stringWithFormat:@"%@:%lu", s, (unsigned long)JSContext.currentArguments.count]; };
    say([NSString stringWithFormat:@"js block twice(21)=%@ native=%@", [ctx evaluateScript:@"twice(21)"].toNumber,
         [ctx evaluateScript:@"native('hi', 2)"].toString]);
    NSDictionary *d = [ctx evaluateScript:@"({name: 'isim', list: [1, 2, 3], nested: {ok: true}})"].toDictionary;
    say([NSString stringWithFormat:@"js object name=%@ list=%@ ok=%@", d[@"name"], [d[@"list"] componentsJoinedByString:@","], d[@"nested"][@"ok"]]);
    SampleCounter *counter = [SampleCounter new];
    ctx[@"counter"] = counter;
    [ctx evaluateScript:@"counter.addValue(5); counter.count = counter.count + 10;"];
    say([NSString stringWithFormat:@"js export count=%ld", (long)counter.count]);
    JSValue *f = [ctx evaluateScript:@"(function (a, b) { return a + b; })"];
    say([NSString stringWithFormat:@"js call=%@", [f callWithArguments:@[@40, @2]].toNumber]);
    [ctx evaluateScript:@"null.boom"];
    say([NSString stringWithFormat:@"js exception=%@", thrown ? @"TypeError" : @"none"]);
    JSGlobalContextRef g = JSGlobalContextCreate(NULL);
    JSStringRef src = JSStringCreateWithUTF8CString("Math.max(3, 9)");
    JSValueRef v = JSEvaluateScript(g, src, NULL, NULL, 0, NULL);
    say([NSString stringWithFormat:@"js C api max=%g", JSValueToNumber(g, v, NULL)]);
    JSStringRelease(src);
    JSGlobalContextRelease(g);
}

static void media(void) {
    CMTime a = CMTimeMake(3, 2), b = CMTimeMakeWithSeconds(0.25, 600);
    CMTime sum = CMTimeAdd(a, b);
    say([NSString stringWithFormat:@"cmtime sum=%.2f cmp=%d valid=%d", CMTimeGetSeconds(sum), CMTimeCompare(a, b), CMTIME_IS_VALID(sum)]);
    AVAudioSession *s = AVAudioSession.sharedInstance;
    NSError *err = nil;
    [s setCategory:AVAudioSessionCategoryAmbient error:&err];
    say([NSString stringWithFormat:@"avaudiosession category=%@ error=%@", s.category, err ? @"yes" : @"none"]);
    AVPlayer *player = [AVPlayer playerWithPlayerItem:nil];
    say([NSString stringWithFormat:@"avplayer time=%.1f class=%@", CMTimeGetSeconds(player.currentTime), NSStringFromClass(player.class)]);
}

static void security(void) {
    uint8_t bytes[16] = {0};
    int r = SecRandomCopyBytes(kSecRandomDefault, sizeof bytes, bytes);
    int nonzero = 0;
    for (size_t i = 0; i < sizeof bytes; i++) nonzero |= bytes[i];
    NSDictionary *params = @{(__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom, (__bridge id)kSecAttrKeySizeInBits: @256};
    CFErrorRef e = NULL;
    SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)params, &e);
    SecKeyRef pub = key ? SecKeyCopyPublicKey(key) : NULL;
    NSData *msg = [@"signed" dataUsingEncoding:NSUTF8StringEncoding];
    CFDataRef sig = key ? SecKeyCreateSignature(key, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)msg, &e) : NULL;
    BOOL ok = sig && SecKeyVerifySignature(pub, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)msg, sig, &e);
    say([NSString stringWithFormat:@"security random=%d nonzero=%d key=%d verified=%d", r, nonzero != 0, key != NULL, ok]);
    if (sig) CFRelease(sig);
    if (pub) CFRelease(pub);
    if (key) CFRelease(key);
}

// Network's C API: a TCP echo listener advertised over Bonjour, a browser that finds it, a connection to the service
// that echoes a message, a host endpoint, and TLS against the plain echo server (fails with a TLS error)
static nw_listener_t echoListener;
static nw_browser_t echoBrowser;
static void echo(nw_connection_t c) {
    nw_connection_receive(c, 1, 65536, ^(dispatch_data_t content, nw_content_context_t context, bool complete, nw_error_t error) {
        if (content) nw_connection_send(c, content, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, NW_CONNECTION_SEND_IDEMPOTENT_CONTENT);
        if (complete || error) nw_connection_cancel(c); else echo(c);
    });
}
static void tlsAttempt(uint16_t port) {
    char p[8];
    snprintf(p, sizeof p, "%u", port);
    nw_endpoint_t host = nw_endpoint_create_host("127.0.0.1", p);
    nw_parameters_t tls = nw_parameters_create_secure_tcp(NW_PARAMETERS_DEFAULT_CONFIGURATION, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_connection_t c = nw_connection_create(host, tls);
    nw_connection_set_queue(c, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(c, ^(nw_connection_state_t state, nw_error_t error) {
        if (state == nw_connection_state_failed) {
            say([NSString stringWithFormat:@"nw tls failed domain=%d", nw_error_get_error_domain(error)]);
            nw_connection_cancel(c);
        } else if (state == nw_connection_state_cancelled) {
            nw_listener_cancel(echoListener);
            echoListener = nil;
        }
    });
    nw_connection_start(c);
}
static void talk(nw_endpoint_t service, uint16_t port) {
    nw_parameters_t tcp = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, ^(nw_protocol_options_t options) {
        nw_tcp_options_set_no_delay(options, true);
    });
    nw_connection_t c = nw_connection_create(service, tcp);
    nw_connection_set_queue(c, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(c, ^(nw_connection_state_t state, nw_error_t error) {
        if (state == nw_connection_state_ready) {
            nw_path_t path = nw_connection_copy_current_path(c);
            nw_endpoint_t remote = path ? nw_path_copy_effective_remote_endpoint(path) : nil;
            say([NSString stringWithFormat:@"nw connected type=%d remote port=%d", nw_endpoint_get_type(remote), remote && nw_endpoint_get_port(remote) == port]);
            const char *text = "hello over nw";
            dispatch_data_t d = dispatch_data_create(text, strlen(text), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
            nw_connection_send(c, d, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t sendError) {
                say([NSString stringWithFormat:@"nw sent error=%d", sendError != nil]);
            });
            nw_connection_receive(c, 13, 13, ^(dispatch_data_t content, nw_content_context_t context, bool complete, nw_error_t receiveError) {
                const void *bytes = NULL; size_t n = 0;
                dispatch_data_t map = content ? dispatch_data_create_map(content, &bytes, &n) : nil;
                say([NSString stringWithFormat:@"nw echo %.*s final=%d", (int)n, (const char *)bytes,
                     nw_content_context_get_is_final(NW_CONNECTION_FINAL_MESSAGE_CONTEXT)]);
                (void)map;
                nw_connection_cancel(c);
                tlsAttempt(port);
            });
        } else if (state == nw_connection_state_failed) {
            say([NSString stringWithFormat:@"nw connection failed domain=%d code=%d", nw_error_get_error_domain(error), nw_error_get_error_code(error)]);
        }
    });
    nw_connection_start(c);
}
static void networkC(void) {
    nw_endpoint_t host = nw_endpoint_create_host("example.com", "https");
    nw_endpoint_t address = nw_endpoint_create_host("127.0.0.1", "8080");
    char *addressString = nw_endpoint_copy_address_string(address);
    say([NSString stringWithFormat:@"nw endpoint host=%s port=%d type=%d address=%s type=%d", nw_endpoint_get_hostname(host),
         nw_endpoint_get_port(host), nw_endpoint_get_type(host), addressString, nw_endpoint_get_type(address)]);
    free(addressString);
    nw_content_context_t first = nw_content_context_create("first"), second = nw_content_context_create("second");
    nw_content_context_set_antecedent(second, first);
    say([NSString stringWithFormat:@"nw context %s after %s", nw_content_context_get_identifier(second),
         nw_content_context_get_identifier(nw_content_context_copy_antecedent(second))]);

    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_reuse_local_address(parameters, true);
    echoListener = nw_listener_create(parameters);
    nw_advertise_descriptor_t advertise = nw_advertise_descriptor_create_bonjour_service("isim echo", "_isimecho._tcp", NULL);
    nw_listener_set_advertise_descriptor(echoListener, advertise);
    nw_listener_set_queue(echoListener, dispatch_get_main_queue());
    nw_listener_set_new_connection_handler(echoListener, ^(nw_connection_t connection) {
        nw_connection_set_queue(connection, dispatch_get_main_queue());
        nw_connection_start(connection);
        echo(connection);
    });
    nw_listener_set_state_changed_handler(echoListener, ^(nw_listener_state_t state, nw_error_t error) {
        if (state != nw_listener_state_ready) return;
        uint16_t port = nw_listener_get_port(echoListener);
        say([NSString stringWithFormat:@"nw listener ready port=%d", port > 0]);
        nw_browse_descriptor_t d = nw_browse_descriptor_create_bonjour_service("_isimecho._tcp", NULL);
        echoBrowser = nw_browser_create(d, NULL);
        nw_browser_set_queue(echoBrowser, dispatch_get_main_queue());
        nw_browser_set_browse_results_changed_handler(echoBrowser, ^(nw_browse_result_t old, nw_browse_result_t found, bool batchComplete) {
            if (!(nw_browse_result_get_changes(old, found) & nw_browse_result_change_result_added)) return;
            nw_endpoint_t service = nw_browse_result_copy_endpoint(found);
            if (strcmp(nw_endpoint_get_bonjour_service_name(service), "isim echo") != 0) return;
            say([NSString stringWithFormat:@"nw browse found %s %s batch=%d browsing=%s", nw_endpoint_get_bonjour_service_name(service),
                 nw_endpoint_get_bonjour_service_type(service), batchComplete,
                 nw_browse_descriptor_get_bonjour_service_type(nw_browser_copy_browse_descriptor(echoBrowser))]);
            nw_browser_cancel(echoBrowser);
            echoBrowser = nil;
            talk(service, port);
        });
        nw_browser_start(echoBrowser);
    });
    nw_listener_start(echoListener);
}

static void reachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {}

/* CFNetwork's CFHost (Google Mobile Ads resolves its ad servers with it, #606): a name, an address, an unknown name,
   and a resolution in the background whose client runs on the main run loop */
static BOOL has_loopback(CFArrayRef addrs) {
    for (CFIndex i = 0; addrs && i < CFArrayGetCount(addrs); i++) {
        const struct sockaddr *sa = (const struct sockaddr *)CFDataGetBytePtr((CFDataRef)CFArrayGetValueAtIndex(addrs, i));
        if (sa->sa_family == AF_INET && ((const struct sockaddr_in *)sa)->sin_addr.s_addr == htonl(INADDR_LOOPBACK)) return YES;
    }
    return NO;
}
static void hostResolved(CFHostRef host, CFHostInfoType type, const CFStreamError *error, void *info) {
    Boolean resolved = false;
    CFArrayRef addrs = CFHostGetAddressing(host, &resolved);
    say([NSString stringWithFormat:@"cfhost async type=%d resolved=%d loopback=%d error=%ld main=%d", type, resolved, has_loopback(addrs),
         (long)error->domain, NSThread.isMainThread]);
    CFHostUnscheduleFromRunLoop(host, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    CFHostSetClient(host, NULL, NULL);
    CFRelease(host);
}
static void cfhost(void) {
    CFHostRef h = CFHostCreateWithName(NULL, CFSTR("localhost"));
    CFStreamError err = {0, 0};
    Boolean before = true, resolved = false;
    CFHostGetAddressing(h, &before);
    Boolean ok = CFHostStartInfoResolution(h, kCFHostAddresses, &err);
    CFArrayRef addrs = CFHostGetAddressing(h, &resolved);
    say([NSString stringWithFormat:@"cfhost localhost ok=%d before=%d resolved=%d loopback=%d typeid=%d", ok, before, resolved, has_loopback(addrs),
         CFGetTypeID(h) == CFHostGetTypeID()]);
    CFRelease(h);
    CFHostRef unknown = CFHostCreateWithName(NULL, CFSTR("no-such-host.invalid"));
    ok = CFHostStartInfoResolution(unknown, kCFHostAddresses, &err);
    say([NSString stringWithFormat:@"cfhost unknown ok=%d netdb=%d", ok, err.domain == kCFStreamErrorDomainNetDB && err.error != 0]);
    CFRelease(unknown);
    struct sockaddr_in sin = {};
    sin.sin_len = sizeof sin; sin.sin_family = AF_INET; sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    CFDataRef data = CFDataCreate(NULL, (const UInt8 *)&sin, sizeof sin);
    CFHostRef byAddress = CFHostCreateWithAddress(NULL, data);
    ok = CFHostStartInfoResolution(byAddress, kCFHostNames, &err);
    CFArrayRef names = CFHostGetNames(byAddress, NULL);
    say([NSString stringWithFormat:@"cfhost 127.0.0.1 names=%d addresses=%ld", ok && names && CFArrayGetCount(names) > 0,
         (long)CFArrayGetCount(CFHostGetAddressing(byAddress, NULL))]);
    CFRelease(byAddress); CFRelease(data);
    CFHostRef later = CFHostCreateWithName(NULL, CFSTR("localhost"));
    CFHostClientContext ctx = {0, NULL, NULL, NULL, NULL};
    CFHostSetClient(later, hostResolved, &ctx);
    CFHostScheduleWithRunLoop(later, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    CFHostStartInfoResolution(later, kCFHostAddresses, &err);
}

/* CoreFoundation's streams and sockets (SocketRocket and CocoaAsyncSocket use them): data, memory, file and bound
   streams, a CFSocket listener whose accepted connections echo upper-cased over CFStreamCreatePairWithSocket streams,
   clients to it by host name and by socket signature, a UDP data socket and a refused connection */
static NSString *read_all(CFReadStreamRef r) {
    NSMutableString *out = [NSMutableString string];
    UInt8 buf[64];
    CFIndex n;
    while (CFReadStreamHasBytesAvailable(r) && (n = CFReadStreamRead(r, buf, sizeof buf)) > 0)
        [out appendString:[[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSUTF8StringEncoding]];
    return out;
}
static void echoRead(CFReadStreamRef r, CFStreamEventType type, void *info) {
    CFWriteStreamRef w = (CFWriteStreamRef)info;
    if (type == kCFStreamEventHasBytesAvailable) {
        NSData *up = [[read_all(r) uppercaseString] dataUsingEncoding:NSUTF8StringEncoding];
        CFWriteStreamWrite(w, (const UInt8 *)up.bytes, (CFIndex)up.length);
    } else if (type == kCFStreamEventEndEncountered || type == kCFStreamEventErrorOccurred) {
        CFReadStreamSetClient(r, kCFStreamEventNone, NULL, NULL);
        CFReadStreamClose(r); CFWriteStreamClose(w);
        CFRelease(r); CFRelease(w);
    }
}
static void accepted(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    static int count;
    if (count++ == 0)
        say([NSString stringWithFormat:@"cfsocket accepted address=%d main=%d", address && CFDataGetLength(address) >= (CFIndex)sizeof(struct sockaddr_in),
             NSThread.isMainThread]);
    CFReadStreamRef r; CFWriteStreamRef w;
    CFStreamCreatePairWithSocket(NULL, *(const CFSocketNativeHandle *)data, &r, &w);
    CFReadStreamSetProperty(r, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    CFStreamClientContext ctx = {0, (void *)w, NULL, NULL, NULL};
    CFReadStreamSetClient(r, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred, echoRead, &ctx);
    CFReadStreamScheduleWithRunLoop(r, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    CFReadStreamOpen(r); CFWriteStreamOpen(w);
}
/* a client: writes its message once it can, logs the echo */
@interface StreamClient : NSObject { @public CFReadStreamRef r; CFWriteStreamRef w; NSString *message, *label; BOOL sent; }
@end
@implementation StreamClient @end
static void clientWrite(CFWriteStreamRef w, CFStreamEventType type, void *info) {
    StreamClient *c = (__bridge StreamClient *)info;
    if (type == kCFStreamEventCanAcceptBytes && !c->sent) {
        c->sent = YES;
        NSData *d = [c->message dataUsingEncoding:NSUTF8StringEncoding];
        CFWriteStreamWrite(w, (const UInt8 *)d.bytes, (CFIndex)d.length);
    }
}
static void clientRead(CFReadStreamRef r, CFStreamEventType type, void *info) {
    StreamClient *c = (__bridge StreamClient *)info;
    if (type == kCFStreamEventOpenCompleted && [c->label isEqualToString:@"tcp"]) {
        NSString *host = CFBridgingRelease(CFReadStreamCopyProperty(r, kCFStreamPropertySocketRemoteHostName));
        NSNumber *port = CFBridgingRelease(CFReadStreamCopyProperty(r, kCFStreamPropertySocketRemotePortNumber));
        NSData *fd = CFBridgingRelease(CFReadStreamCopyProperty(r, kCFStreamPropertySocketNativeHandle));
        say([NSString stringWithFormat:@"cfstream tcp open=%d remote=%@:%d handle=%d", CFReadStreamGetStatus(r) == kCFStreamStatusOpen, host,
             port.intValue > 0, fd.length == sizeof(CFSocketNativeHandle)]);
    } else if (type == kCFStreamEventHasBytesAvailable) {
        say([NSString stringWithFormat:@"cfstream %@ echo=%@", c->label, read_all(r)]);
        CFReadStreamSetClient(r, kCFStreamEventNone, NULL, NULL); CFWriteStreamSetClient(c->w, kCFStreamEventNone, NULL, NULL);
        CFReadStreamClose(r); CFWriteStreamClose(c->w);
        CFRelease(r); CFRelease(c->w);
        CFBridgingRelease((__bridge CFTypeRef)c);
    } else if (type == kCFStreamEventErrorOccurred) {
        CFStreamError e = CFReadStreamGetError(r);
        CFErrorRef err = CFReadStreamCopyError(r);
        say([NSString stringWithFormat:@"cfstream %@ error=%@ posix=%d copied=%d", c->label, e.domain == kCFStreamErrorDomainPOSIX ? @"posix" : @"other",
             e.error == ECONNREFUSED, err != NULL]);
        if (err) CFRelease(err);
        CFReadStreamClose(r); CFWriteStreamClose(c->w);
        CFRelease(r); CFRelease(c->w);
        CFBridgingRelease((__bridge CFTypeRef)c);
    }
}
static void start_client(NSString *label, NSString *message, CFReadStreamRef r, CFWriteStreamRef w) {
    StreamClient *c = [StreamClient new];
    c->r = r; c->w = w; c->label = label; c->message = message;
    CFStreamClientContext ctx = {0, (void *)CFBridgingRetain(c), NULL, NULL, NULL};
    CFOptionFlags all = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes |
                        kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
    CFReadStreamSetClient(r, all, clientRead, &ctx);
    CFWriteStreamSetClient(w, all, clientWrite, &ctx);
    CFReadStreamScheduleWithRunLoop(r, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    CFWriteStreamScheduleWithRunLoop(w, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    CFReadStreamOpen(r); CFWriteStreamOpen(w);
}
static void datagram(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    NSData *d = (__bridge NSData *)data;
    say([NSString stringWithFormat:@"cfsocket udp data=%@ address=%d type=%d", [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding],
         address != NULL, type == kCFSocketDataCallBack]);
    CFSocketInvalidate(s);
    CFRelease(s);
}
static CFDataRef loopback(UInt16 port) {
    struct sockaddr_in sin = {};
    sin.sin_len = sizeof sin; sin.sin_family = AF_INET; sin.sin_port = htons(port); sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    return CFDataCreate(NULL, (const UInt8 *)&sin, sizeof sin);
}
static UInt16 port_of(CFDataRef a) { return ntohs(((const struct sockaddr_in *)CFDataGetBytePtr(a))->sin_port); }
static void cfstreams(void) {
    static const char hello[] = "hello";
    CFReadStreamRef data = CFReadStreamCreateWithBytesNoCopy(NULL, (const UInt8 *)hello, 5, kCFAllocatorNull);
    CFReadStreamOpen(data);
    CFIndex got = 0;
    const UInt8 *buf = CFReadStreamGetBuffer(data, 2, &got);
    NSString *rest = read_all(data);
    say([NSString stringWithFormat:@"cfstream data buffer=%.*s read=%@ status=%ld typeid=%d bridged=%d", (int)got, buf, rest, (long)CFReadStreamGetStatus(data),
         CFGetTypeID(data) == CFReadStreamGetTypeID(), [(__bridge id)data isKindOfClass:[NSInputStream class]]]);
    CFReadStreamClose(data); CFRelease(data);

    CFWriteStreamRef mem = CFWriteStreamCreateWithAllocatedBuffers(NULL, NULL);
    CFWriteStreamOpen(mem);
    CFWriteStreamWrite(mem, (const UInt8 *)"abc", 3);
    NSData *written = CFBridgingRelease(CFWriteStreamCopyProperty(mem, kCFStreamPropertyDataWritten));
    say([NSString stringWithFormat:@"cfstream memory written=%@ typeid=%d", [[NSString alloc] initWithData:written encoding:NSUTF8StringEncoding],
         CFGetTypeID(mem) == CFWriteStreamGetTypeID()]);
    CFWriteStreamClose(mem); CFRelease(mem);

    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"cfstream.txt"]];
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    for (NSString *part in @[@"one", @"two"]) {
        CFWriteStreamRef f = CFWriteStreamCreateWithFile(NULL, (__bridge CFURLRef)url);
        CFWriteStreamSetProperty(f, kCFStreamPropertyAppendToFile, kCFBooleanTrue);
        CFWriteStreamOpen(f);
        CFWriteStreamWrite(f, (const UInt8 *)part.UTF8String, 3);
        CFWriteStreamClose(f); CFRelease(f);
    }
    CFReadStreamRef fr = CFReadStreamCreateWithFile(NULL, (__bridge CFURLRef)url);
    CFReadStreamOpen(fr);
    NSString *fileText = read_all(fr);
    NSNumber *offset = CFBridgingRelease(CFReadStreamCopyProperty(fr, kCFStreamPropertyFileCurrentOffset));
    say([NSString stringWithFormat:@"cfstream file appended=%@ offset=%@", fileText, offset]);
    CFReadStreamClose(fr); CFRelease(fr);

    CFReadStreamRef br; CFWriteStreamRef bw;
    CFStreamCreateBoundPair(NULL, &br, &bw, 64);
    dispatch_queue_t q = dispatch_queue_create("cfstream.bound", DISPATCH_QUEUE_SERIAL);
    CFStreamClientContext bctx = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(br, kCFStreamEventHasBytesAvailable, [](CFReadStreamRef r, CFStreamEventType t, void *) {
        NSString *text = read_all(r);
        BOOL onQueue = !NSThread.isMainThread;
        say([NSString stringWithFormat:@"cfstream bound read=%@ queue=%d", text, onQueue]);
        CFReadStreamSetClient(r, kCFStreamEventNone, NULL, NULL);
    }, &bctx);
    CFReadStreamSetDispatchQueue(br, q);
    CFReadStreamOpen(br); CFWriteStreamOpen(bw);
    CFWriteStreamWrite(bw, (const UInt8 *)"xyz", 3);

    /* the echo server */
    CFSocketRef listener = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, accepted, NULL);
    CFDataRef any = loopback(0);
    CFSocketError bound = CFSocketSetAddress(listener, any);
    CFRelease(any);
    CFDataRef addr = CFSocketCopyAddress(listener);
    UInt16 port = port_of(addr);
    CFRelease(addr);
    CFRunLoopSourceRef src = CFSocketCreateRunLoopSource(NULL, listener, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes);
    CFRelease(src);
    say([NSString stringWithFormat:@"cfsocket listening bound=%d port=%d typeid=%d valid=%d", bound == kCFSocketSuccess, port > 0,
         CFGetTypeID(listener) == CFSocketGetTypeID(), CFSocketIsValid(listener)]);

    CFReadStreamRef r; CFWriteStreamRef w;
    CFStreamCreatePairWithSocketToHost(NULL, CFSTR("127.0.0.1"), port, &r, &w);
    start_client(@"tcp", @"ping", r, w);
    CFDataRef peer = loopback(port);
    CFSocketSignature sig = {PF_INET, SOCK_STREAM, IPPROTO_TCP, peer};
    CFStreamCreatePairWithPeerSocketSignature(NULL, &sig, &r, &w);
    start_client(@"signature", @"pong", r, w);
    CFRelease(peer);

    /* UDP: a data callback for a datagram sent with CFSocketSendData */
    CFSocketRef receiver = CFSocketCreate(NULL, PF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketDataCallBack, datagram, NULL);
    any = loopback(0);
    CFSocketSetAddress(receiver, any);
    CFRelease(any);
    CFDataRef raddr = CFSocketCopyAddress(receiver);
    CFRunLoopSourceRef rsrc = CFSocketCreateRunLoopSource(NULL, receiver, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), rsrc, kCFRunLoopDefaultMode);
    CFRelease(rsrc);
    CFSocketRef sender = CFSocketCreate(NULL, PF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketNoCallBack, NULL, NULL);
    NSData *dgram = [@"datagram" dataUsingEncoding:NSUTF8StringEncoding];
    CFSocketError sent = CFSocketSendData(sender, raddr, (__bridge CFDataRef)dgram, 1);
    say([NSString stringWithFormat:@"cfsocket udp sent=%d", sent == kCFSocketSuccess]);
    CFSocketInvalidate(sender); CFRelease(sender); CFRelease(raddr);

    /* a refused connection: a port nothing listens on */
    CFSocketRef closed = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketNoCallBack, NULL, NULL);
    any = loopback(0);
    CFSocketSetAddress(closed, any);
    CFRelease(any);
    CFDataRef caddr = CFSocketCopyAddress(closed);
    UInt16 dead = port_of(caddr);
    CFRelease(caddr);
    CFSocketInvalidate(closed); CFRelease(closed);
    CFStreamCreatePairWithSocketToHost(NULL, CFSTR("127.0.0.1"), dead, &r, &w);
    start_client(@"refused", @"x", r, w);
}

static void network(void) {
    SCNetworkReachabilityRef r = SCNetworkReachabilityCreateWithName(NULL, "example.com");
    SCNetworkReachabilityFlags flags = 0;
    Boolean got = SCNetworkReachabilityGetFlags(r, &flags);
    SCNetworkReachabilityContext ctx = {0, NULL, NULL, NULL, NULL};
    Boolean cb = SCNetworkReachabilitySetCallback(r, reachabilityChanged, &ctx);
    say([NSString stringWithFormat:@"reachability flags=%d callback=%d", got, cb]);
    SCNetworkReachabilitySetCallback(r, NULL, NULL);
    CFRelease(r);
    nw_path_monitor_t m = nw_path_monitor_create();
    nw_path_monitor_set_queue(m, dispatch_get_main_queue());
    __block nw_path_monitor_t keep = m;
    nw_path_monitor_set_update_handler(m, ^(nw_path_t path) {
        say([NSString stringWithFormat:@"path status=%d ipv4=%d", nw_path_get_status(path), nw_path_has_ipv4(path)]);
        nw_path_monitor_cancel(keep);
        keep = nil;
    });
    nw_path_monitor_start(m);
    networkC();
    cfhost();
    cfstreams();
    CTTelephonyNetworkInfo *info = [CTTelephonyNetworkInfo new];
    say([NSString stringWithFormat:@"telephony carriers=%lu", (unsigned long)info.serviceSubscriberCellularProviders.count]);
    CTCellularData *cellular = [CTCellularData new];
    CTError err = {kCTErrorDomainNoError, 0};
    say([NSString stringWithFormat:@"telephony restricted=%lu subscribers=%lu error domain=%d", (unsigned long)cellular.restrictedState,
         (unsigned long)CTSubscriberInfo.subscribers.count, err.domain]);
    CTCellularPlanProvisioningRequest *plan = [CTCellularPlanProvisioningRequest new];
    plan.address = @"sm-dp.example.com";
    plan.matchingID = @"ABC-123";
    [[CTCellularPlanProvisioning new] addPlanWith:plan completionHandler:^(CTCellularPlanProvisioningAddPlanResult result) {
        say([NSString stringWithFormat:@"telephony add plan result=%ld fail=%d", (long)result, result == CTCellularPlanProvisioningAddPlanResultFail]);
    }];
}

static void types(void) {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, CFSTR("png"), NULL);
    say([NSString stringWithFormat:@"uttype png=%@ image=%d", (__bridge NSString *)uti, UTTypeConformsTo(uti, kUTTypeImage)]);
    CFRelease(uti);
    CFStringRef s = CFStringCreateWithCString(NULL, "core foundation", kCFStringEncodingUTF8);
    char buf[64];
    CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8);
    say([NSString stringWithFormat:@"cfstring length=%ld text=%s", (long)CFStringGetLength(s), buf]);
    CFRelease(s);
    say([NSString stringWithFormat:@"idfa zero=%d", [ASIdentifierManager.sharedManager.advertisingIdentifier.UUIDString hasPrefix:@"00000000"]]);
    say([NSString stringWithFormat:@"skadnetwork class=%@", NSStringFromClass(SKAdNetwork.class)]);
}

static void compressionAndZlib(void) {
    const char *text = "isim isim isim isim isim isim isim isim";
    uLongf zlen = compressBound(strlen(text));
    Bytef z[256];
    compress(z, &zlen, (const Bytef *)text, strlen(text));
    char back[128] = {0};
    uLongf blen = sizeof back;
    uncompress((Bytef *)back, &blen, z, zlen);
    uint8_t c[256], d[128] = {0};
    size_t clen = compression_encode_buffer(c, sizeof c, (const uint8_t *)text, strlen(text), NULL, COMPRESSION_ZLIB);
    size_t dlen = compression_decode_buffer(d, sizeof d, c, clen, NULL, COMPRESSION_ZLIB);
    say([NSString stringWithFormat:@"zlib %s crc=%08lx roundtrip=%d compression=%d", zlibVersion(), crc32(0, (const Bytef *)text, (uInt)strlen(text)),
         !strcmp(back, text), dlen == strlen(text) && !memcmp(d, text, dlen)]);
}
/* every libcompression algorithm, and NSData's compression */
static void compressionAlgorithms(void) {
    NSMutableString *list = [NSMutableString string];
    const struct { compression_algorithm alg; const char *name; } algs[] = {
        { COMPRESSION_LZFSE, "lzfse" }, { COMPRESSION_LZ4, "lz4" }, { COMPRESSION_LZMA, "lzma" }, { COMPRESSION_BROTLI, "brotli" } };
    NSData *text = [[@"" stringByPaddingToLength:4000 withString:@"isim compresses " startingAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding];
    for (const auto &a : algs) {
        uint8_t c[8192], d[8192];
        size_t clen = compression_encode_buffer(c, sizeof c, (const uint8_t *)text.bytes, text.length, NULL, a.alg);
        size_t dlen = compression_decode_buffer(d, sizeof d, c, clen, NULL, a.alg);
        [list appendFormat:@" %s=%d", a.name, clen > 0 && clen < text.length && dlen == text.length && !memcmp(d, text.bytes, dlen)];
    }
    NSData *z = [text compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:NULL];
    [list appendFormat:@" nsdata=%d", [[z decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:NULL] isEqualToData:text]];
    say([@"compression" stringByAppendingString:list]);
}

static void cxx(void) {
    std::ostringstream out;
    out << "pi=" << std::fixed << std::setprecision(3) << 3.14159 << " hex=" << std::hex << 255 << std::dec;
    std::istringstream in("12 34.5 word");
    int i = 0; double x = 0; std::string w;
    in >> i >> x >> w;
    out << " read=" << i << "," << x << "," << w;
    std::regex re("([a-z]+)-([0-9]+)");
    std::smatch mm;
    std::string subject = "build-42";
    out << " regex=" << (std::regex_match(subject, mm, re) ? mm[2].str() : "none");
    out << " upper=" << std::use_facet<std::ctype<char>>(std::locale::classic()).toupper('q');
    say([NSString stringWithFormat:@"c++ %s", out.str().c_str()]);
    std::cerr << "HelloSystemObjC: c++ cerr ok" << std::endl;
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *label = [UILabel new];
    label.text = @"System APIs from Objective-C";
    label.frame = CGRectMake(16, 120, 360, 30);
    [vc.view addSubview:label];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    javascript();
    media();
    security();
    network();
    types();
    compressionAndZlib();
    compressionAlgorithms();
    cxx();
    say(@"done");
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
