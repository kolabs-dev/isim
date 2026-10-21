#pragma once
/* isim AuthenticationServices for Objective-C: the classes are the AuthenticationServices Swift overlay's
   (AuthenticationServices.framework re-exports libswiftAuthenticationServices.dylib), the same local simulation as in
   Swift: Sign in with Apple with the device's fake Apple Account and an unsigned identity token, real WebAuthn passkeys
   kept in the device data, passwords from isim's keychain, and ASWebAuthenticationSession on isim's WKWebView. Swift
   uses the overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

typedef UIWindow * ASPresentationAnchor;

@class ASAuthorizationController, ASAuthorization, ASWebAuthenticationSession;

/* errors */

FOUNDATION_EXPORT NSErrorDomain const ASAuthorizationErrorDomain;
typedef NS_ERROR_ENUM(ASAuthorizationErrorDomain, ASAuthorizationError) {
    ASAuthorizationErrorUnknown = 1000,
    ASAuthorizationErrorCanceled = 1001,
    ASAuthorizationErrorInvalidResponse = 1002,
    ASAuthorizationErrorNotHandled = 1003,
    ASAuthorizationErrorFailed = 1004,
    ASAuthorizationErrorNotInteractive = 1005,
    ASAuthorizationErrorMatchedExcludedCredential = 1006,
};

FOUNDATION_EXPORT NSErrorDomain const ASWebAuthenticationSessionErrorDomain;
typedef NS_ERROR_ENUM(ASWebAuthenticationSessionErrorDomain, ASWebAuthenticationSessionErrorCode) {
    ASWebAuthenticationSessionErrorCodeCanceledLogin = 1,
    ASWebAuthenticationSessionErrorCodePresentationContextNotProvided = 2,
    ASWebAuthenticationSessionErrorCodePresentationContextInvalid = 3,
};

/* ASAuthorization */

typedef NSString * ASAuthorizationScope NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationScope const ASAuthorizationScopeFullName;
FOUNDATION_EXPORT ASAuthorizationScope const ASAuthorizationScopeEmail;

typedef NSString * ASAuthorizationOpenIDOperation NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationOpenIDOperation const ASAuthorizationOperationImplicit;
FOUNDATION_EXPORT ASAuthorizationOpenIDOperation const ASAuthorizationOperationLogin;
FOUNDATION_EXPORT ASAuthorizationOpenIDOperation const ASAuthorizationOperationRefresh;
FOUNDATION_EXPORT ASAuthorizationOpenIDOperation const ASAuthorizationOperationLogout;

@protocol ASAuthorizationProvider <NSObject>
@end

@protocol ASAuthorizationCredential <NSObject>
@end

@interface ASAuthorization : NSObject
@property (nonatomic, readonly, strong) id<ASAuthorizationProvider> provider;
@property (nonatomic, readonly, strong) id<ASAuthorizationCredential> credential;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationRequest : NSObject
@property (nonatomic, readonly, strong) id<ASAuthorizationProvider> provider;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

/* ASAuthorizationController */

typedef NSString * ASAuthorizationCustomMethod NS_TYPED_ENUM;
FOUNDATION_EXPORT ASAuthorizationCustomMethod const ASAuthorizationCustomMethodVideoSubscriberAccount;
FOUNDATION_EXPORT ASAuthorizationCustomMethod const ASAuthorizationCustomMethodRestorePurchase;
FOUNDATION_EXPORT ASAuthorizationCustomMethod const ASAuthorizationCustomMethodOther;

@protocol ASAuthorizationControllerDelegate <NSObject>
@optional
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization;
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error;
@end

@protocol ASAuthorizationControllerPresentationContextProviding <NSObject>
@required
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller;
@end

typedef NS_OPTIONS(NSUInteger, ASAuthorizationControllerRequestOptions) {
    ASAuthorizationControllerRequestOptionPreferImmediatelyAvailableCredentials = 1 << 0,
};

@interface ASAuthorizationController : NSObject
@property (nonatomic, readonly, strong) NSArray<ASAuthorizationRequest *> *authorizationRequests;
@property (nonatomic, weak, nullable) id<ASAuthorizationControllerDelegate> delegate;
@property (nonatomic, weak, nullable) id<ASAuthorizationControllerPresentationContextProviding> presentationContextProvider;
@property (nonatomic, copy) NSArray<ASAuthorizationCustomMethod> *customAuthorizationMethods;   /* tvOS only */
- (instancetype)initWithAuthorizationRequests:(NSArray<ASAuthorizationRequest *> *)authorizationRequests NS_DESIGNATED_INITIALIZER;
/* a sheet offers the saved passkeys and passwords, or Sign in with Apple */
- (void)performRequests;
- (void)performRequestsWithOptions:(ASAuthorizationControllerRequestOptions)options;
/* passkeys in the QuickType bar of username fields, no sheet */
- (void)performAutoFillAssistedRequests;
- (void)cancel;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

/* Sign in with Apple (local simulation: the device's fake Apple Account, an unsigned identity token) */

@interface ASAuthorizationOpenIDRequest : ASAuthorizationRequest
@property (nonatomic, copy, nullable) NSArray<ASAuthorizationScope> *requestedScopes;
@property (nonatomic, copy, nullable) NSString *state;
@property (nonatomic, copy, nullable) NSString *nonce;
@property (nonatomic, copy) ASAuthorizationOpenIDOperation requestedOperation;
@end

@interface ASAuthorizationAppleIDRequest : ASAuthorizationOpenIDRequest
@property (nonatomic, copy, nullable) NSString *user;
@end

typedef NS_ENUM(NSInteger, ASAuthorizationAppleIDProviderCredentialState) {
    ASAuthorizationAppleIDProviderCredentialRevoked = 0,
    ASAuthorizationAppleIDProviderCredentialAuthorized = 1,
    ASAuthorizationAppleIDProviderCredentialNotFound = 2,
    ASAuthorizationAppleIDProviderCredentialTransferred = 3,
};

/* posted when the user stops using Sign in with Apple for the app (`isim appleid <app> revoke`), once a provider exists */
FOUNDATION_EXPORT NSNotificationName const ASAuthorizationAppleIDProviderCredentialRevokedNotification;

@interface ASAuthorizationAppleIDProvider : NSObject <ASAuthorizationProvider>
- (ASAuthorizationAppleIDRequest *)createRequest;
- (void)getCredentialStateForUserID:(NSString *)userID
                         completion:(void (^)(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError * _Nullable error))completion;
@end

typedef NS_ENUM(NSInteger, ASUserDetectionStatus) {
    ASUserDetectionStatusUnsupported = 0,
    ASUserDetectionStatusUnknown = 1,
    ASUserDetectionStatusLikelyReal = 2,
};

@interface ASAuthorizationAppleIDCredential : NSObject <ASAuthorizationCredential>
@property (nonatomic, readonly, copy) NSString *user;
@property (nonatomic, readonly, copy, nullable) NSString *state;
@property (nonatomic, readonly, copy) NSArray<ASAuthorizationScope> *authorizedScopes;
@property (nonatomic, readonly, copy, nullable) NSData *authorizationCode;
@property (nonatomic, readonly, copy, nullable) NSData *identityToken;
@property (nonatomic, readonly, copy, nullable) NSString *email;
@property (nonatomic, readonly, copy, nullable) NSPersonNameComponents *fullName;
@property (nonatomic, readonly) ASUserDetectionStatus realUserStatus;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, ASAuthorizationAppleIDButtonType) {
    ASAuthorizationAppleIDButtonTypeSignIn = 0,
    ASAuthorizationAppleIDButtonTypeContinue = 1,
    ASAuthorizationAppleIDButtonTypeSignUp = 2,
    ASAuthorizationAppleIDButtonTypeDefault = ASAuthorizationAppleIDButtonTypeSignIn,
};

typedef NS_ENUM(NSInteger, ASAuthorizationAppleIDButtonStyle) {
    ASAuthorizationAppleIDButtonStyleWhite = 0,
    ASAuthorizationAppleIDButtonStyleWhiteOutline = 1,
    ASAuthorizationAppleIDButtonStyleBlack = 2,
};

@interface ASAuthorizationAppleIDButton : UIControl
+ (instancetype)buttonWithType:(ASAuthorizationAppleIDButtonType)type style:(ASAuthorizationAppleIDButtonStyle)style;
- (instancetype)initWithAuthorizationButtonType:(ASAuthorizationAppleIDButtonType)type
                       authorizationButtonStyle:(ASAuthorizationAppleIDButtonStyle)style NS_DESIGNATED_INITIALIZER;
@property (nonatomic) CGFloat cornerRadius;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end

/* passwords (the app's internet passwords in isim's keychain) */

@interface ASAuthorizationPasswordRequest : ASAuthorizationRequest
@end

@interface ASAuthorizationPasswordProvider : NSObject <ASAuthorizationProvider>
- (ASAuthorizationPasswordRequest *)createRequest;
@end

@interface ASPasswordCredential : NSObject <ASAuthorizationCredential>
- (instancetype)initWithUser:(NSString *)user password:(NSString *)password;
+ (instancetype)credentialWithUser:(NSString *)user password:(NSString *)password;
@property (nonatomic, readonly, copy) NSString *user;
@property (nonatomic, readonly, copy) NSString *password;
@end

/* passkeys (WebAuthn: ECDSA P-256, attestation "none"; kept in the device data, not synced) */

typedef NSString * ASAuthorizationPublicKeyCredentialUserVerificationPreference NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferencePreferred;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceRequired;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceDiscouraged;

typedef NSString * ASAuthorizationPublicKeyCredentialAttestationKind NS_TYPED_ENUM;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindNone;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindDirect;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindIndirect;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindEnterprise;

typedef NS_ENUM(NSInteger, ASAuthorizationPublicKeyCredentialAttachment) {
    ASAuthorizationPublicKeyCredentialAttachmentPlatform = 0,
    ASAuthorizationPublicKeyCredentialAttachmentCrossPlatform = 1,
};

/* WebAuthn extensions: PRF (hmac-secret) and largeBlob (passkeys only) */

@interface ASAuthorizationPublicKeyCredentialPRFAssertionInputValues : NSObject
- (instancetype)initWithSaltInput1:(NSData *)saltInput1 saltInput2:(nullable NSData *)saltInput2;
@property (nonatomic, readonly) NSData *saltInput1;
@property (nonatomic, nullable, readonly) NSData *saltInput2;
@end

@interface ASAuthorizationPublicKeyCredentialPRFAssertionInput : NSObject
- (instancetype)initWithInputValues:(nullable ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *)inputValues
           perCredentialInputValues:(nullable NSDictionary<NSData *, ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *> *)perCredentialInputValues;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *inputValues;
@property (nonatomic, nullable, readonly) NSDictionary<NSData *, ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *> *perCredentialInputValues;
@end

@interface ASAuthorizationPublicKeyCredentialPRFAssertionOutput : NSObject
@property (nonatomic, readonly) NSData *first;
@property (nonatomic, nullable, readonly) NSData *second;
@end

@interface ASAuthorizationPublicKeyCredentialPRFRegistrationInput : NSObject
+ (instancetype)checkForSupport;
- (instancetype)initWithInputValues:(nullable ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *)inputValues;
@property (nonatomic, readonly) BOOL shouldCheckForSupport;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFAssertionInputValues *inputValues;
@end

@interface ASAuthorizationPublicKeyCredentialPRFRegistrationOutput : NSObject
@property (nonatomic, readonly) BOOL isSupported;
@property (nonatomic, nullable, readonly) NSData *first;
@property (nonatomic, nullable, readonly) NSData *second;
@end

typedef NS_ENUM(NSInteger, ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirement) {
    ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirementRequired = 0,
    ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirementPreferred = 1,
};

@interface ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput : NSObject
- (instancetype)initWithSupportRequirement:(ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirement)requirement;
@property (nonatomic) ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirement supportRequirement;
@end

@interface ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput : NSObject
@property (nonatomic, readonly) BOOL isSupported;
@end

typedef NS_ENUM(NSInteger, ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperation) {
    ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperationRead = 0,
    ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperationWrite = 1,
};

@interface ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput : NSObject
- (instancetype)initWithOperation:(ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperation)operation;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperation operation;
@property (nonatomic, nullable, copy) NSData *dataToWrite;
@end

@interface ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput : NSObject
@property (nonatomic, nullable, readonly, copy) NSData *readData;
@property (nonatomic, readonly) BOOL didWrite;
@end

@interface ASAuthorizationPlatformPublicKeyCredentialDescriptor : NSObject
- (instancetype)initWithCredentialID:(NSData *)credentialID;
@property (nonatomic, copy) NSData *credentialID;
@end

typedef NS_ENUM(NSInteger, ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyle) {
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyleStandard = 0,
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyleConditional = 1,
} API_AVAILABLE(ios(18.0));

@interface ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest : ASAuthorizationRequest
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, copy) NSData *challenge;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy) NSData *userID;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialUserVerificationPreference userVerificationPreference;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialAttestationKind attestationPreference;
@property (nonatomic, copy) NSArray<ASAuthorizationPlatformPublicKeyCredentialDescriptor *> *excludedCredentials;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialPRFRegistrationInput *prf;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput *largeBlob;
/* iOS 18: conditional creates the passkey without a sheet, for an account the user has a saved password for */
@property (nonatomic) ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyle requestStyle API_AVAILABLE(ios(18.0));
@end

@interface ASAuthorizationPlatformPublicKeyCredentialAssertionRequest : ASAuthorizationRequest
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, copy) NSData *challenge;
@property (nonatomic, copy) NSArray<ASAuthorizationPlatformPublicKeyCredentialDescriptor *> *allowedCredentials;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialUserVerificationPreference userVerificationPreference;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialPRFAssertionInput *prf;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput *largeBlob;
@end

@interface ASAuthorizationPlatformPublicKeyCredentialProvider : NSObject <ASAuthorizationProvider>
- (instancetype)initWithRelyingPartyIdentifier:(NSString *)relyingPartyIdentifier NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
- (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *)createCredentialRegistrationRequestWithChallenge:(NSData *)challenge
                                                                                                              name:(NSString *)name
                                                                                                            userID:(NSData *)userID;
- (ASAuthorizationPlatformPublicKeyCredentialAssertionRequest *)createCredentialAssertionRequestWithChallenge:(NSData *)challenge;
- (ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *)createCredentialRegistrationRequestWithChallenge:(NSData *)challenge
    name:(NSString *)name userID:(NSData *)userID requestStyle:(ASAuthorizationPlatformPublicKeyCredentialRegistrationRequestStyle)requestStyle
    API_AVAILABLE(ios(18.0));
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationPlatformPublicKeyCredentialRegistration : NSObject <ASAuthorizationCredential>
@property (nonatomic, readonly, copy, nullable) NSData *rawAttestationObject;
@property (nonatomic, readonly, copy) NSData *rawClientDataJSON;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialAttachment attachment;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFRegistrationOutput *prf;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput *largeBlob;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationPlatformPublicKeyCredentialAssertion : NSObject <ASAuthorizationCredential>
@property (nonatomic, readonly, copy) NSData *rawAuthenticatorData;
@property (nonatomic, readonly, copy) NSData *rawClientDataJSON;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly, copy) NSData *signature;
@property (nonatomic, readonly, copy) NSData *userID;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialAttachment attachment;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFAssertionOutput *prf;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput *largeBlob;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

/* security keys (a virtual USB key whose credentials are in the device data) */

typedef NSInteger ASCOSEAlgorithmIdentifier NS_TYPED_EXTENSIBLE_ENUM;
static const ASCOSEAlgorithmIdentifier ASCOSEAlgorithmIdentifierES256 = -7;

typedef NSString * ASAuthorizationPublicKeyCredentialResidentKeyPreference NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialResidentKeyPreference const ASAuthorizationPublicKeyCredentialResidentKeyPreferenceDiscouraged;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialResidentKeyPreference const ASAuthorizationPublicKeyCredentialResidentKeyPreferencePreferred;
FOUNDATION_EXPORT ASAuthorizationPublicKeyCredentialResidentKeyPreference const ASAuthorizationPublicKeyCredentialResidentKeyPreferenceRequired;

typedef NSString * ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportUSB;
FOUNDATION_EXPORT ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportNFC;
FOUNDATION_EXPORT ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportBluetooth;
FOUNDATION_EXPORT NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport> *ASAuthorizationAllSupportedPublicKeyCredentialDescriptorTransports(void);

@interface ASAuthorizationPublicKeyCredentialParameters : NSObject
- (instancetype)initWithAlgorithm:(ASCOSEAlgorithmIdentifier)algorithm;
@property (nonatomic, readonly) ASCOSEAlgorithmIdentifier algorithm;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor : NSObject
- (instancetype)initWithCredentialID:(NSData *)credentialID transports:(NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport> *)allowedTransports;
@property (nonatomic, copy) NSData *credentialID;
@property (nonatomic, copy) NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport> *transports;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest : ASAuthorizationRequest
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, copy) NSData *challenge;
@property (nonatomic, nullable, copy) NSString *displayName;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSData *userID;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialUserVerificationPreference userVerificationPreference;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialAttestationKind attestationPreference;
@property (nonatomic, copy) NSArray<ASAuthorizationPublicKeyCredentialParameters *> *credentialParameters;
@property (nonatomic, copy) NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor *> *excludedCredentials;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialResidentKeyPreference residentKeyPreference;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialPRFRegistrationInput *prf;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest : ASAuthorizationRequest
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, copy) NSData *challenge;
@property (nonatomic, copy) NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor *> *allowedCredentials;
@property (nonatomic, copy) ASAuthorizationPublicKeyCredentialUserVerificationPreference userVerificationPreference;
@property (nonatomic, nullable, copy) NSString *appID;
@property (nonatomic, nullable) ASAuthorizationPublicKeyCredentialPRFAssertionInput *prf;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialProvider : NSObject <ASAuthorizationProvider>
- (instancetype)initWithRelyingPartyIdentifier:(NSString *)relyingPartyIdentifier NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
- (ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest *)createCredentialRegistrationRequestWithChallenge:(NSData *)challenge
    displayName:(NSString *)displayName name:(NSString *)name userID:(NSData *)userID;
- (ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest *)createCredentialAssertionRequestWithChallenge:(NSData *)challenge;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialRegistration : NSObject <ASAuthorizationCredential>
@property (nonatomic, readonly, copy, nullable) NSData *rawAttestationObject;
@property (nonatomic, readonly, copy) NSData *rawClientDataJSON;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialAttachment attachment;
@property (nonatomic, readonly) NSArray<ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransport> *transports;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFRegistrationOutput *prf;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationSecurityKeyPublicKeyCredentialAssertion : NSObject <ASAuthorizationCredential>
@property (nonatomic, readonly, copy) NSData *rawAuthenticatorData;
@property (nonatomic, readonly, copy) NSData *rawClientDataJSON;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly, copy) NSData *signature;
@property (nonatomic, readonly, copy) NSData *userID;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialAttachment attachment;
@property (nonatomic, readonly) BOOL appID;
@property (nonatomic, nullable, readonly) ASAuthorizationPublicKeyCredentialPRFAssertionOutput *prf;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

/* ASWebAuthenticationSession (web sign-in in a browser sheet on isim's WKWebView) */

typedef void (^ASWebAuthenticationSessionCompletionHandler)(NSURL * _Nullable callbackURL, NSError * _Nullable error);

@protocol ASWebAuthenticationPresentationContextProviding <NSObject>
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session;
@end

@interface ASWebAuthenticationSessionCallback : NSObject
+ (instancetype)callbackWithCustomScheme:(NSString *)customScheme;
+ (instancetype)callbackWithHTTPSHost:(NSString *)host path:(NSString *)path;
- (BOOL)matchesURL:(NSURL *)url;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASWebAuthenticationSession : NSObject
- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(nullable NSString *)callbackURLScheme
          completionHandler:(ASWebAuthenticationSessionCompletionHandler)completionHandler;
- (instancetype)initWithURL:(NSURL *)URL callback:(ASWebAuthenticationSessionCallback *)callback
          completionHandler:(ASWebAuthenticationSessionCompletionHandler)completionHandler;
@property (nonatomic, weak, nullable) id<ASWebAuthenticationPresentationContextProviding> presentationContextProvider;
@property (nonatomic) BOOL prefersEphemeralWebBrowserSession;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *additionalHeaderFields;
@property (nonatomic, readonly) BOOL canStart;
- (BOOL)start;
- (void)cancel;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
