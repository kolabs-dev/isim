// Sample: AuthenticationServices from Objective-C (issue #305), as AppAuth, GoogleSignIn and Facebook Login use it:
// Sign in with Apple from an ASAuthorizationAppleIDButton (sheet, credential, credential state), a passkey registered and
// then asserted from the chooser sheet alongside a password request, preferImmediatelyAvailableCredentials with nothing
// saved (notInteractive), and ASWebAuthenticationSession (the consent alert, cancelled), once with a presentation
// provider that has Apple's selector and once with one that has only the selector Swift apps built before isim 0.27
// implement. Each step prints an "au ..." line the test checks.
#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("au %s\n", s.UTF8String); fflush(stdout);
}
static NSString *errText(NSError *e) { return e ? [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code] : @"nil"; }
static NSData *bytes(const char *s) { return [NSData dataWithBytes:s length:strlen(s)]; }
static NSString *text(NSData *d) { return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]; }
static NSString *const RP = @"objc.example.com";

/* a presentation provider as an app built before isim 0.27 has it: only the selector Swift gave the method then */
@interface LegacyAnchor : NSObject
@property (nonatomic, weak) UIWindow *window;
@end
@implementation LegacyAnchor
- (UIWindow *)presentationAnchorFor:(id)sender {
    say(@"legacy anchor for %@", NSStringFromClass([sender class]));
    return self.window;
}
@end

@interface ViewController : UIViewController <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding,
                                              ASWebAuthenticationPresentationContextProviding>
@property (nonatomic, strong) ASAuthorizationAppleIDProvider *appleID;
@property (nonatomic, strong) ASAuthorizationController *controller;
@property (nonatomic, strong) ASWebAuthenticationSession *session;
@property (nonatomic, strong) LegacyAnchor *legacy;
@property (nonatomic, copy) NSData *challenge;
@property (nonatomic) CGFloat y;
@end

@implementation ViewController
- (UIButton *)button:(NSString *)title id:(NSString *)ident action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.accessibilityIdentifier = ident;
    b.frame = CGRectMake(40, self.y, self.view.bounds.size.width - 80, 44);
    self.y += 54;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.y = 160;
    ASAuthorizationAppleIDButton *siwa = [ASAuthorizationAppleIDButton buttonWithType:ASAuthorizationAppleIDButtonTypeContinue
                                                                                style:ASAuthorizationAppleIDButtonStyleBlack];
    siwa.cornerRadius = 12;
    siwa.frame = CGRectMake(40, self.y, self.view.bounds.size.width - 80, 50);
    siwa.accessibilityIdentifier = @"objc-siwa";
    [siwa addTarget:self action:@selector(signInWithApple) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:siwa];
    self.y += 70;
    [self button:@"Save a passkey" id:@"passkey-register" action:@selector(registerPasskey)];
    [self button:@"Sign in with a passkey" id:@"passkey-signin" action:@selector(signIn)];
    [self button:@"Web sign-in" id:@"web" action:@selector(webSignIn)];
    [self button:@"Web sign-in (legacy provider)" id:@"web-legacy" action:@selector(webSignInLegacy)];
    say(@"button %@ radius=%.0f", NSStringFromClass([siwa class]), siwa.cornerRadius);

    self.appleID = [[ASAuthorizationAppleIDProvider alloc] init];
    [self.appleID getCredentialStateForUserID:@"000000.unknown.0000" completion:^(ASAuthorizationAppleIDProviderCredentialState state, NSError *error) {
        say(@"unknown user state=%ld error=%@", (long)state, errText(error));
    }];
    ASWebAuthenticationSessionCallback *cb = [ASWebAuthenticationSessionCallback callbackWithCustomScheme:@"HelloAuthObjC"];
    ASWebAuthenticationSessionCallback *https = [ASWebAuthenticationSessionCallback callbackWithHTTPSHost:@"login.objc.example" path:@"/done"];
    say(@"callbacks scheme=%d other=%d https=%d wrongPath=%d", [cb matchesURL:[NSURL URLWithString:@"helloauthobjc://auth?code=1"]],
        [cb matchesURL:[NSURL URLWithString:@"other://auth"]], [https matchesURL:[NSURL URLWithString:@"https://login.objc.example/done?x=1"]],
        [https matchesURL:[NSURL URLWithString:@"https://login.objc.example/other"]]);
    [self quickSignIn];
}

#pragma mark presentation
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller {
    say(@"anchor for controller requests=%lu", (unsigned long)controller.authorizationRequests.count);
    return self.view.window;
}
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    say(@"anchor for web session");
    return self.view.window;
}

#pragma mark requests
- (void)perform:(NSArray<ASAuthorizationRequest *> *)requests options:(ASAuthorizationControllerRequestOptions)options {
    self.controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:requests];
    self.controller.delegate = self;
    self.controller.presentationContextProvider = self;
    [self.controller performRequestsWithOptions:options];
}
- (void)quickSignIn {   // nothing saved yet: no sheet, notInteractive
    [self perform:@[[[[ASAuthorizationPasswordProvider alloc] init] createRequest]]
          options:ASAuthorizationControllerRequestOptionPreferImmediatelyAvailableCredentials];
}
- (void)signInWithApple {
    ASAuthorizationAppleIDRequest *r = [self.appleID createRequest];
    r.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
    r.nonce = @"objc-nonce";
    r.state = @"objc-state";
    say(@"apple id request scopes=%@ operation=%@ provider=%d", [r.requestedScopes componentsJoinedByString:@","],
        r.requestedOperation.length ? r.requestedOperation : @"implicit", r.provider == self.appleID);
    [self perform:@[r] options:0];
}
- (void)registerPasskey {
    ASAuthorizationPlatformPublicKeyCredentialProvider *p = [[ASAuthorizationPlatformPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:RP];
    self.challenge = bytes("objc-registration-challenge-0001");
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *r =
        [p createCredentialRegistrationRequestWithChallenge:self.challenge name:@"casey" userID:bytes("user-7")];
    r.displayName = @"Casey Objc";
    r.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreferenceRequired;
    say(@"registration rp=%@ attestation=%@ verification=%@", r.relyingPartyIdentifier, r.attestationPreference, r.userVerificationPreference);
    [self perform:@[r] options:0];
}
- (void)signIn {
    ASAuthorizationPlatformPublicKeyCredentialProvider *p = [[ASAuthorizationPlatformPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:RP];
    self.challenge = bytes("objc-assertion-challenge-0002");
    ASAuthorizationPlatformPublicKeyCredentialAssertionRequest *a = [p createCredentialAssertionRequestWithChallenge:self.challenge];
    [self perform:@[a, [[[ASAuthorizationPasswordProvider alloc] init] createRequest]] options:0];
}

#pragma mark ASAuthorizationControllerDelegate
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization {
    id<ASAuthorizationCredential> c = authorization.credential;
    if ([c isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        ASAuthorizationAppleIDCredential *a = (ASAuthorizationAppleIDCredential *)c;
        NSString *name = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:a.fullName
                                                                                           style:NSPersonNameComponentsFormatterStyleDefault options:0];
        NSArray *token = [text(a.identityToken) componentsSeparatedByString:@"."];
        say(@"apple id credential name=%@ email=%@ state=%@ scopes=%@ realUser=%ld code=%d token=%lu parts provider=%d",
            name, a.email, a.state, [a.authorizedScopes componentsJoinedByString:@","], (long)a.realUserStatus,
            a.authorizationCode.length > 0, (unsigned long)token.count, authorization.provider == self.appleID);
        [self.appleID getCredentialStateForUserID:a.user completion:^(ASAuthorizationAppleIDProviderCredentialState state, NSError *error) {
            say(@"apple id state=%ld authorized=%d error=%@", (long)state, state == ASAuthorizationAppleIDProviderCredentialAuthorized, errText(error));
        }];
    } else if ([c isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialRegistration class]]) {
        ASAuthorizationPlatformPublicKeyCredentialRegistration *r = (ASAuthorizationPlatformPublicKeyCredentialRegistration *)c;
        NSDictionary *client = [NSJSONSerialization JSONObjectWithData:r.rawClientDataJSON options:0 error:nil];
        say(@"passkey registered id=%lu attestation=%d type=%@ attachment=%ld", (unsigned long)r.credentialID.length,
            r.rawAttestationObject.length > 0, client[@"type"], (long)r.attachment);
    } else if ([c isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialAssertion class]]) {
        ASAuthorizationPlatformPublicKeyCredentialAssertion *a = (ASAuthorizationPlatformPublicKeyCredentialAssertion *)c;
        NSDictionary *client = [NSJSONSerialization JSONObjectWithData:a.rawClientDataJSON options:0 error:nil];
        say(@"passkey assertion user=%@ authData=%lu signature=%d type=%@ origin=%@", text(a.userID), (unsigned long)a.rawAuthenticatorData.length,
            a.signature.length > 0, client[@"type"], client[@"origin"]);
    } else if ([c isKindOfClass:[ASPasswordCredential class]]) {
        say(@"password credential user=%@", ((ASPasswordCredential *)c).user);
    } else {
        say(@"other credential %@", NSStringFromClass([(NSObject *)c class]));
    }
}
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error {
    say(@"authorization error=%@ notInteractive=%d canceled=%d", errText(error), error.code == ASAuthorizationErrorNotInteractive,
        error.code == ASAuthorizationErrorCanceled);
}

#pragma mark ASWebAuthenticationSession
- (void)startSession:(id<ASWebAuthenticationPresentationContextProviding>)provider label:(NSString *)label {
    NSURL *url = [NSURL URLWithString:@"https://login.objc.example/authorize?redirect_uri=helloauthobjc%3A%2F%2Fauth"];
    self.session = [[ASWebAuthenticationSession alloc] initWithURL:url callbackURLScheme:@"helloauthobjc"
                                                completionHandler:^(NSURL *callbackURL, NSError *error) {
        say(@"%@ done url=%@ error=%@ canceled=%d", label, callbackURL, errText(error),
            [error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] && error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin);
    }];
    self.session.presentationContextProvider = provider;
    self.session.additionalHeaderFields = @{@"X-Sample": @"objc"};
    BOOL can = self.session.canStart;
    BOOL started = [self.session start];
    say(@"%@ canStart=%d start=%d running=%d", label, can, started, !self.session.canStart);
}
- (void)webSignIn { [self startSession:self label:@"web"]; }
- (void)webSignInLegacy {
    self.legacy = [[LegacyAnchor alloc] init];
    self.legacy.window = self.view.window;
    [self startSession:(id<ASWebAuthenticationPresentationContextProviding>)self.legacy label:@"web legacy"];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
