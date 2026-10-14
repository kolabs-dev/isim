// Sample: WebKit from Objective-C (issue #200), used the way apps and binary SDKs (Google Mobile Ads...) use it: a
// WKUserContentController subclass, a category on WKWebView, script message handlers (plain and with a reply), a user
// script, the navigation delegate (action policy with a cancelled link, start/commit/finish), the UI delegate (alert),
// KVO on Apple's key paths (estimatedProgress, loading, title), evaluateJavaScript (page and an isolated world),
// callAsyncJavaScript, takeSnapshot, website data stores and WebKit's constants. Logs "HelloWebObjC: ...".
//   isim run out/apps/HelloWebObjC.app
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static void say(NSString *s) { fprintf(stderr, "HelloWebObjC: %s\n", s.UTF8String); }

/* an SDK-style subclass of a WebKit class, overriding one of its methods */
@interface SampleContentController : WKUserContentController
@property (nonatomic) NSInteger scriptsAdded;
@end
@implementation SampleContentController
- (void)addUserScript:(WKUserScript *)userScript {
    self.scriptsAdded++;
    [super addUserScript:userScript];
}
@end

/* a category on WKWebView */
@interface WKWebView (Sample)
- (NSString *)sample_summary;
@end
@implementation WKWebView (Sample)
- (NSString *)sample_summary { return [NSString stringWithFormat:@"%@ loading=%d", self.URL.absoluteString ?: @"(none)", self.isLoading]; }
@end

static NSString *const kHTML =
    @"<!doctype html><html><head><meta name=viewport content='width=device-width'><title>ObjC page</title></head>"
    @"<body style='margin:0;font:17px sans-serif'>"
    @"<h1 style='margin:8px 16px;font-size:26px'>WebKit from Objective-C</h1>"
    @"<div id=box style='position:absolute;left:16px;top:60px;width:120px;height:120px;background:rgb(255,0,0)'></div>"
    @"<a id=blocked href='https://blocked.example/' style='position:absolute;left:16px;top:200px;font-size:20px'>Blocked link</a>"
    @"<div id=out style='position:absolute;left:16px;top:240px;font-size:20px'>ready</div>"
    @"<script>function show(s){document.getElementById('out').textContent=s}</script></body></html>";

@interface WebViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) SampleContentController *contentController;
@property (nonatomic) BOOL ranChecks;
@end

@implementation WebViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    say([NSString stringWithFormat:@"classes %@ %@ %@ domain=%@", NSStringFromClass([WKWebView class]), NSStringFromClass([WKWebViewConfiguration class]),
         NSStringFromClass([SampleContentController superclass]), WKErrorDomain]);

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.contentController = [SampleContentController new];
    config.userContentController = self.contentController;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    config.defaultWebpagePreferences.preferredContentMode = WKContentModeMobile;
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:@"window.webkit.messageHandlers.native.postMessage({kind:'script', href: location.href})"
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.contentController addUserScript:script];
    [self.contentController addScriptMessageHandler:self name:@"native"];
    [self.contentController addScriptMessageHandlerWithReply:self contentWorld:WKContentWorld.pageWorld name:@"calc"];
    say([NSString stringWithFormat:@"config media=%lu inline=%d persistent=%d scripts=%ld", (unsigned long)config.mediaTypesRequiringUserActionForPlayback,
         config.allowsInlineMediaPlayback, config.websiteDataStore.isPersistent, (long)self.contentController.scriptsAdded]);

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.customUserAgent = nil;
    self.webView.accessibilityIdentifier = @"web";
    [self.view addSubview:self.webView];
    for (NSString *key in @[@"estimatedProgress", @"loading", @"title"])
        [self.webView addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
    [self.webView loadHTMLString:kHTML baseURL:[NSURL URLWithString:@"https://objc.example/"]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"] && self.webView.estimatedProgress >= 1.0) say(@"kvo estimatedProgress=1.0");
    else if ([keyPath isEqualToString:@"loading"]) say([NSString stringWithFormat:@"kvo loading=%d", self.webView.isLoading]);
    else if ([keyPath isEqualToString:@"title"]) say([NSString stringWithFormat:@"kvo title=%@", self.webView.title]);
}

#pragma mark WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    BOOL blocked = [action.request.URL.host isEqualToString:@"blocked.example"];
    say([NSString stringWithFormat:@"policy %@ type=%ld main=%d -> %@", action.request.URL.absoluteString, (long)action.navigationType,
         action.targetFrame.isMainFrame, blocked ? @"cancel" : @"allow"]);
    decisionHandler(blocked ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation { say(@"didStartProvisionalNavigation"); }
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation { say(@"didCommitNavigation"); }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    say([NSString stringWithFormat:@"didFinishNavigation %@", [webView sample_summary]]);
    if (self.ranChecks) return;
    self.ranChecks = YES;
    [webView evaluateJavaScript:@"document.title + ' / ' + (6 * 7)" completionHandler:^(id result, NSError *error) {
        say([NSString stringWithFormat:@"evaluateJavaScript: %@ error=%@", result, error.domain ?: @"none"]);
    }];
    [webView evaluateJavaScript:@"throw new Error('boom')" completionHandler:^(id result, NSError *error) {
        say([NSString stringWithFormat:@"exception: domain=%@ code=%ld", error.domain, (long)error.code]);
    }];
    [webView evaluateJavaScript:@"typeof show" inFrame:nil inContentWorld:[WKContentWorld worldWithName:@"sample"] completionHandler:^(id result, NSError *error) {
        say([NSString stringWithFormat:@"isolated world: typeof show = %@", result]);
    }];
    [webView callAsyncJavaScript:@"return await Promise.resolve(a + b)" arguments:@{@"a": @40, @"b": @2} inFrame:nil
                  inContentWorld:WKContentWorld.pageWorld completionHandler:^(id result, NSError *error) {
        say([NSString stringWithFormat:@"callAsyncJavaScript: %@", result]);
    }];
    [webView takeSnapshotWithConfiguration:nil completionHandler:^(UIImage *image, NSError *error) {
        say([NSString stringWithFormat:@"snapshot %.0fx%.0f", image.size.width, image.size.height]);
    }];
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    say([NSString stringWithFormat:@"didFailProvisionalNavigation %@ %ld", error.domain, (long)error.code]);
}

#pragma mark WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame
        completionHandler:(void (^)(void))completionHandler {
    say([NSString stringWithFormat:@"alert: %@ from %@", message, frame.request.URL.host]);
    completionHandler();
}

#pragma mark script messages
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *body = message.body;
    say([NSString stringWithFormat:@"message %@: kind=%@ href=%@ controller=%@", message.name, body[@"kind"], body[@"href"],
         NSStringFromClass([controller class])]);
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message
                 replyHandler:(void (^)(id, NSString *))replyHandler {
    NSDictionary *body = message.body;
    replyHandler(@([body[@"a"] integerValue] * [body[@"b"] integerValue]), nil);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [WebViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
