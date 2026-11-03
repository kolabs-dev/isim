// Sample: WebKit from Objective-C (issue #200), used the way apps and binary SDKs (Google Mobile Ads...) use it: a
// WKUserContentController subclass, a category on WKWebView, script message handlers (plain and with a reply), a user
// script, the navigation delegate (action policy with a cancelled link, start/commit/finish), the UI delegate (alert),
// KVO on Apple's key paths (estimatedProgress, loading, title), evaluateJavaScript (page and an isolated world),
// callAsyncJavaScript, takeSnapshot, website data stores and WebKit's constants; LinkPresentation (a provider for a file
// URL, a link view, an unsupported scheme, a provider started twice); web extensions (issue #421: a match pattern, an
// extension's manifest, a context's permissions, a controller) and fullscreenState. Logs "HelloWebObjC: ...".
//   isim run out/apps/HelloWebObjC.app
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <LinkPresentation/LinkPresentation.h>

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

// a custom URL scheme served by the app (isim-objc://files/note.txt)
@interface NoteSchemeHandler : NSObject <WKURLSchemeHandler>
@end
@implementation NoteSchemeHandler
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)task {
    say([NSString stringWithFormat:@"scheme task %@ %@", task.request.HTTPMethod ?: @"GET", task.request.URL.absoluteString]);
    NSData *body = [@"a note served by an Objective-C scheme handler\n" dataUsingEncoding:NSUTF8StringEncoding];
    [task didReceiveResponse:[[NSHTTPURLResponse alloc] initWithURL:task.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1"
        headerFields:@{@"Content-Type": @"text/plain; charset=utf-8", @"Access-Control-Allow-Origin": @"*"}]];
    [task didReceiveData:body];
    [task didFinish];
}
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)task {}
@end

/* issue #791: a browser tab as web extensions see it */
API_AVAILABLE(ios(18.4))
@interface ObjCTab : NSObject <WKWebExtensionTab>
@end
@implementation ObjCTab
- (NSString *)titleForWebExtensionContext:(WKWebExtensionContext *)context { return @"Tab"; }
- (NSURL *)urlForWebExtensionContext:(WKWebExtensionContext *)context { return [NSURL URLWithString:@"https://notes.example/a"]; }
@end

@interface WebViewController : UIViewController <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply, WKDownloadDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) SampleContentController *contentController;
@property (nonatomic) BOOL ranChecks;
@property (nonatomic, copy) NSString *downloadName;
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
    NoteSchemeHandler *notes = [NoteSchemeHandler new];
    [config setURLSchemeHandler:notes forURLScheme:@"isim-objc"];
    say([NSString stringWithFormat:@"scheme handler kept %d", [config urlSchemeHandlerForURLScheme:@"isim-objc"] == notes]);
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
    [self linkPresentation];
    if (@available(iOS 18.4, *)) [self webExtensions];
    say([NSString stringWithFormat:@"fullscreenState %ld open panel %d", (long)self.webView.fullscreenState,
         [self respondsToSelector:@selector(webView:runOpenPanelWithParameters:initiatedByFrame:completionHandler:)]]);
}

/* issue #421: an extension written to a temporary directory, loaded into a controller with one host granted */
- (void)webExtensions API_AVAILABLE(ios(18.4)) {
    NSError *error = nil;
    WKWebExtensionMatchPattern *pattern = [[WKWebExtensionMatchPattern alloc] initWithString:@"*://*.example.com/docs/*" error:&error];
    WKWebExtensionMatchPattern *bad = [[WKWebExtensionMatchPattern alloc] initWithString:@"gopher://x/" error:&error];
    say([NSString stringWithFormat:@"pattern %@ host=%@ matches=%d,%d bad=%@ error=%@/%ld all=%d", pattern.string, pattern.host,
         [pattern matchesURL:[NSURL URLWithString:@"https://www.example.com/docs/a.html"]], [pattern matchesURL:[NSURL URLWithString:@"https://example.com/blog/"]],
         bad, error.domain, (long)error.code, [WKWebExtensionMatchPattern allURLsMatchPattern].matchesAllURLs]);
    NSURL *dir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"ObjCExtension"]];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *manifest = @"{\"manifest_version\": 2, \"name\": \"Notes\", \"version\": \"3.0\", \"permissions\": [\"tabs\", \"https://notes.example/*\"],"
                          "\"background\": {\"scripts\": [\"bg.js\"]}, \"options_page\": \"options.html\", \"browser_action\": {\"default_title\": \"Jot\"},"
                          "\"commands\": {\"_execute_browser_action\": {\"suggested_key\": {\"default\": \"Alt+J\"}}}}";
    [manifest writeToURL:[dir URLByAppendingPathComponent:@"manifest.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [WKWebExtension extensionWithResourceBaseURL:dir completionHandler:^(WKWebExtension *extension, NSError *loadError) {
        WKWebExtensionContext *context = [WKWebExtensionContext contextForExtension:extension];
        [context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionTabs expirationDate:nil];
        WKWebExtensionController *controller = [[WKWebExtensionController alloc] initWithConfiguration:WKWebExtensionControllerConfiguration.nonPersistentConfiguration];
        NSError *e = nil;
        BOOL loaded = [controller loadExtensionContext:context error:&e];
        say([NSString stringWithFormat:@"extension %@ %@ mv=%.0f persistentBackground=%d options=%d permissions=%@ hosts=%lu tabs=%ld notes=%ld loaded=%d contexts=%lu options=%@",
             extension.displayName, extension.version, extension.manifestVersion, extension.hasPersistentBackgroundContent, extension.hasOptionsPage,
             [extension.requestedPermissions.allObjects componentsJoinedByString:@","], (unsigned long)extension.requestedPermissionMatchPatterns.count,
             (long)[context permissionStatusForPermission:WKWebExtensionPermissionTabs],
             (long)[context permissionStatusForURL:[NSURL URLWithString:@"https://notes.example/a"]], loaded && context.isLoaded,
             (unsigned long)controller.extensionContexts.count, context.optionsPageURL.lastPathComponent]);
        [WKWebExtension extensionWithResourceBaseURL:[NSURL fileURLWithPath:@"/nonexistent"] completionHandler:^(WKWebExtension *none, NSError *missing) {
            say([NSString stringWithFormat:@"missing extension %@ %@/%ld", none, missing.domain, (long)missing.code]);
        }];
        // issue #791: an Objective-C tab, the action, a command, data types and data records
        ObjCTab *tab = [ObjCTab new];
        [context didOpenTab:tab];
        NSUInteger open = context.openTabs.count;
        BOOL gesture = [context hasActiveUserGestureInTab:tab];
        [context userGesturePerformedInTab:tab];
        BOOL gestured = [context hasActiveUserGestureInTab:tab];
        [context didCloseTab:tab windowIsClosing:NO];
        WKWebExtensionAction *action = [context actionForTab:nil];
        WKWebExtensionCommand *command = context.commands.firstObject;
        NSSet<WKWebExtensionDataType> *types = WKWebExtensionController.allExtensionDataTypes;
        [controller fetchDataRecordsOfTypes:types completionHandler:^(NSArray<WKWebExtensionDataRecord *> *records) {
            say([NSString stringWithFormat:@"extension tabs %lu then %lu gesture %d %d action %@ popup %d command %@ %@ alt %d types %lu local %d records %lu",
                 (unsigned long)open, (unsigned long)context.openTabs.count, gesture, gestured, action.label, action.presentsPopup, command.title,
                 command.activationKey, (command.modifierFlags & UIKeyModifierAlternate) != 0, (unsigned long)types.count,
                 [types containsObject:WKWebExtensionDataTypeLocal], (unsigned long)records.count]);
        }];
    }];
}
- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame
        completionHandler:(void (^)(NSArray<NSURL *> *))completionHandler API_AVAILABLE(ios(18.4)) {
    completionHandler(nil);
}

- (void)linkPresentation {
    LPMetadataProvider *provider = [LPMetadataProvider new];
    NSURL *file = [NSBundle.mainBundle URLForResource:@"Info" withExtension:@"plist"];
    [provider startFetchingMetadataForURL:file completionHandler:^(LPLinkMetadata *metadata, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LPLinkView *card = [[LPLinkView alloc] initWithMetadata:metadata];
            CGSize size = [card sizeThatFits:CGSizeMake(300, CGFLOAT_MAX)];
            say([NSString stringWithFormat:@"link metadata title=%@ file=%d subresources=%d timeout=%.0f view=%@ height=%.0f", metadata.title,
                 metadata.URL.isFileURL, provider.shouldFetchSubresources, provider.timeout, NSStringFromClass(card.class), size.height]);
        });
    }];
    @try {
        [provider startFetchingMetadataForURL:file completionHandler:^(LPLinkMetadata *m, NSError *e) {}];
        say(@"link provider started twice");
    } @catch (NSException *e) {
        say([NSString stringWithFormat:@"link provider one-shot: %@", e.name]);
    }
    [[LPMetadataProvider new] startFetchingMetadataForURL:[NSURL URLWithString:@"ftp://example.com/x"] completionHandler:^(LPLinkMetadata *m, NSError *e) {
        say([NSString stringWithFormat:@"link ftp error %@ %ld failed=%d", e.domain, (long)e.code,
             [e.domain isEqual:LPErrorDomain] && e.code == LPErrorMetadataFetchFailed]);
    }];
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
    // the custom scheme from the page, and a download saved where the download delegate says
    [webView callAsyncJavaScript:@"return await (await fetch('isim-objc://files/note.txt')).text()" arguments:nil inFrame:nil
                  inContentWorld:WKContentWorld.pageWorld completionHandler:^(id result, NSError *error) {
        say([NSString stringWithFormat:@"fetched: %@", [result stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet]]);
    }];
    [webView startDownloadUsingRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"data:text/plain;charset=utf-8,a%20downloaded%20note%0A"]]
                     completionHandler:^(WKDownload *download) {
        say([NSString stringWithFormat:@"download started %@ user=%d", download.originalRequest.URL.absoluteString, download.isUserInitiated]);
        download.delegate = self;
    }];
}
- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename
        completionHandler:(void (^)(NSURL *))completionHandler {
    NSURL *dest = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:suggestedFilename];
    [NSFileManager.defaultManager removeItemAtURL:dest error:nil];
    say([NSString stringWithFormat:@"download destination %@", suggestedFilename]);
    self.downloadName = suggestedFilename;
    completionHandler(dest);
}
- (void)downloadDidFinish:(WKDownload *)download {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:self.downloadName ?: @"-"];
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    say([NSString stringWithFormat:@"download finished: %@ progress=%.0f", [text stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet],
         download.progress.fractionCompleted]);
}
- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData {
    say([NSString stringWithFormat:@"download failed %@", error]);
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
