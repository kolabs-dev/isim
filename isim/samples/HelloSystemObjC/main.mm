// Sample: the C and Objective-C system APIs that binary SDKs (Google Mobile Ads, analytics, game engines) link from
// Objective-C and C++ (issue #200): JavaScriptCore (JSContext, blocks, JSExport, the C API), CoreMedia's CMTime,
// AVFoundation's Objective-C classes, Security (SecRandomCopyBytes, SecKey), SystemConfiguration reachability, Network's
// path monitor, CoreTelephony, MobileCoreServices' UTType functions, CoreFoundation strings, zlib, libcompression and
// libc++ iostreams and locales. Logs "HelloSystemObjC: ...".
//   isim run out/apps/HelloSystemObjC.app
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <Network/Network.h>
#import <CoreTelephony/CoreTelephony.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AdSupport/AdSupport.h>
#import <StoreKit/StoreKit.h>
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

static void reachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {}

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
    CTTelephonyNetworkInfo *info = [CTTelephonyNetworkInfo new];
    say([NSString stringWithFormat:@"telephony carriers=%lu", (unsigned long)info.serviceSubscriberCellularProviders.count]);
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
