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
    ASAuthorizationErrorCredentialImport = 1007,
    ASAuthorizationErrorCredentialExport = 1008,
    ASAuthorizationErrorPreferSignInWithApple = 1009,
    ASAuthorizationErrorDeviceNotConfiguredForPasskeyCreation = 1010,
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

/* ---- credential provider extensions (#400): the identity store, requests and credentials, the extension's view
   controller and context. isim runs the extension in the app that asks (see the Swift overlay's CredentialProvider.swift). */

FOUNDATION_EXPORT NSErrorDomain const ASExtensionErrorDomain;
typedef NS_ERROR_ENUM(ASExtensionErrorDomain, ASExtensionErrorCode) {
    ASExtensionErrorCodeFailed = 0,
    ASExtensionErrorCodeUserCanceled = 1,
    ASExtensionErrorCodeUserInteractionRequired = 100,
    ASExtensionErrorCodeCredentialIdentityNotFound = 101,
    ASExtensionErrorCodeMatchedExcludedCredential = 102,
};
FOUNDATION_EXPORT NSErrorUserInfoKey const ASExtensionLocalizedFailureReasonErrorKey;

FOUNDATION_EXPORT NSErrorDomain const ASCredentialIdentityStoreErrorDomain;
typedef NS_ERROR_ENUM(ASCredentialIdentityStoreErrorDomain, ASCredentialIdentityStoreErrorCode) {
    ASCredentialIdentityStoreErrorCodeInternalError = 0,
    ASCredentialIdentityStoreErrorCodeStoreDisabled = 1,
    ASCredentialIdentityStoreErrorCodeStoreBusy = 2,
};

typedef NS_ENUM(NSInteger, ASCredentialServiceIdentifierType) {
    ASCredentialServiceIdentifierTypeDomain = 0,
    ASCredentialServiceIdentifierTypeURL = 1,
    ASCredentialServiceIdentifierTypeApp = 2,
};

@interface ASCredentialServiceIdentifier : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithIdentifier:(NSString *)identifier type:(ASCredentialServiceIdentifierType)type;
- (instancetype)initWithIdentifier:(NSString *)identifier type:(ASCredentialServiceIdentifierType)type displayName:(NSString *)displayName;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly) ASCredentialServiceIdentifierType type;
@property (nonatomic, readonly, copy, nullable) NSString *displayName;
@end

@protocol ASCredentialIdentity <NSObject>
@property (nonatomic, readonly, strong) ASCredentialServiceIdentifier *serviceIdentifier;
@property (nonatomic, readonly, copy) NSString *user;
@property (nonatomic, readonly, copy, nullable) NSString *recordIdentifier;
@property (nonatomic) NSInteger rank;
@end

@interface ASPasswordCredentialIdentity : NSObject <ASCredentialIdentity, NSCopying, NSSecureCoding>
- (instancetype)initWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier user:(NSString *)user recordIdentifier:(nullable NSString *)recordIdentifier;
@end

@interface ASPasskeyCredentialIdentity : NSObject <ASCredentialIdentity, NSCopying, NSSecureCoding>
- (instancetype)initWithRelyingPartyIdentifier:(NSString *)relyingPartyIdentifier userName:(NSString *)userName credentialID:(NSData *)credentialID
                                    userHandle:(NSData *)userHandle recordIdentifier:(nullable NSString *)recordIdentifier;
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, readonly, copy) NSString *userName;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly, copy) NSData *userHandle;
@end

@interface ASOneTimeCodeCredentialIdentity : NSObject <ASCredentialIdentity, NSCopying, NSSecureCoding>
- (instancetype)initWithServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier label:(NSString *)label recordIdentifier:(nullable NSString *)recordIdentifier;
@property (nonatomic, readonly, copy) NSString *label;
@end

typedef NS_ENUM(NSUInteger, ASCredentialRequestType) {
    ASCredentialRequestTypePassword = 0,
    ASCredentialRequestTypePasskeyAssertion = 1,
    ASCredentialRequestTypePasskeyRegistration = 2,
    ASCredentialRequestTypeOneTimeCode = 3,
};

@protocol ASCredentialRequest <NSObject, NSCopying, NSSecureCoding>
@property (nonatomic, readonly) ASCredentialRequestType type;
@property (nonatomic, readonly) id<ASCredentialIdentity> credentialIdentity;
@end

@interface ASPasswordCredentialRequest : NSObject <ASCredentialRequest>
- (instancetype)initWithCredentialIdentity:(ASPasswordCredentialIdentity *)credentialIdentity;
@end

@interface ASOneTimeCodeCredentialRequest : NSObject <ASCredentialRequest>
- (instancetype)initWithCredentialIdentity:(ASOneTimeCodeCredentialIdentity *)credentialIdentity;
@end

@interface ASPasskeyCredentialRequest : NSObject <ASCredentialRequest>
@property (nonatomic, readonly) NSData *clientDataHash;
@property (nonatomic, readonly) ASAuthorizationPublicKeyCredentialUserVerificationPreference userVerificationPreference;
@property (nonatomic, readonly) NSArray<NSNumber *> *supportedAlgorithms;
@end

@interface ASPasskeyCredentialRequestParameters : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly, copy) NSString *relyingPartyIdentifier;
@property (nonatomic, readonly) NSData *clientDataHash;
@property (nonatomic, readonly) NSArray<NSData *> *allowedCredentials;
@end

@interface ASPasskeyAssertionCredential : NSObject <ASAuthorizationCredential, NSCopying, NSSecureCoding>
- (instancetype)initWithUserHandle:(NSData *)userHandle relyingParty:(NSString *)relyingParty signature:(NSData *)signature
                    clientDataHash:(NSData *)clientDataHash authenticatorData:(NSData *)authenticatorData credentialID:(NSData *)credentialID;
@property (nonatomic, readonly, copy) NSData *userHandle;
@property (nonatomic, readonly, copy) NSString *relyingParty;
@property (nonatomic, readonly, copy) NSData *signature;
@property (nonatomic, readonly, copy) NSData *clientDataHash;
@property (nonatomic, readonly, copy) NSData *authenticatorData;
@property (nonatomic, readonly, copy) NSData *credentialID;
@end

@interface ASPasskeyRegistrationCredential : NSObject <ASAuthorizationCredential, NSCopying, NSSecureCoding>
- (instancetype)initWithRelyingParty:(NSString *)relyingParty clientDataHash:(NSData *)clientDataHash credentialID:(NSData *)credentialID
                   attestationObject:(NSData *)attestationObject;
@property (nonatomic, readonly, copy) NSString *relyingParty;
@property (nonatomic, readonly, copy) NSData *clientDataHash;
@property (nonatomic, readonly, copy) NSData *credentialID;
@property (nonatomic, readonly, copy) NSData *attestationObject;
@end

@interface ASOneTimeCodeCredential : NSObject <ASAuthorizationCredential, NSCopying, NSSecureCoding>
- (instancetype)initWithCode:(NSString *)code;
@property (nonatomic, readonly, copy) NSString *code;
@end

@interface ASCredentialIdentityStoreState : NSObject
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) BOOL supportsIncrementalUpdates;
@end

@interface ASCredentialIdentityStore : NSObject
@property (class, nonatomic, readonly) ASCredentialIdentityStore *sharedStore;
- (void)getCredentialIdentityStoreStateWithCompletion:(void (^)(ASCredentialIdentityStoreState *state))completion;
- (void)saveCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)saveCredentialIdentityEntries:(NSArray<id<ASCredentialIdentity>> *)credentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)removeCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)removeCredentialIdentityEntries:(NSArray<id<ASCredentialIdentity>> *)credentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)removeAllCredentialIdentitiesWithCompletion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)replaceCredentialIdentitiesWithIdentities:(NSArray<ASPasswordCredentialIdentity *> *)newCredentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)replaceCredentialIdentityEntries:(NSArray<id<ASCredentialIdentity>> *)newCredentialIdentities completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASSettingsHelper : NSObject
+ (void)openCredentialProviderAppSettingsWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
+ (void)openVerificationCodeAppSettingsWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
+ (void)requestToTurnOnCredentialProviderExtensionWithCompletionHandler:(void (^)(BOOL appWasEnabledForAutoFill))completionHandler;
@end

@interface ASCredentialProviderExtensionContext : NSExtensionContext
- (void)completeRequestWithSelectedCredential:(ASPasswordCredential *)credential completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler;
- (void)completeAssertionRequestWithSelectedPasskeyCredential:(ASPasskeyAssertionCredential *)credential completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler;
- (void)completeRegistrationRequestWithSelectedPasskeyCredential:(ASPasskeyRegistrationCredential *)credential completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler;
- (void)completeOneTimeCodeRequestWithSelectedCredential:(ASOneTimeCodeCredential *)credential completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler;
- (void)completeRequestWithTextToInsert:(NSString *)text completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler;
- (void)completeExtensionConfigurationRequest;
@end

@interface ASCredentialProviderViewController : UIViewController
@property (nonatomic, readonly, strong) ASCredentialProviderExtensionContext *extensionContext;
- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers;
- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers requestParameters:(ASPasskeyCredentialRequestParameters *)requestParameters;
- (void)prepareOneTimeCodeCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers;
- (void)provideCredentialWithoutUserInteractionForRequest:(id<ASCredentialRequest>)credentialRequest;
- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity;
- (void)prepareInterfaceToProvideCredentialForRequest:(id<ASCredentialRequest>)credentialRequest;
- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity;
- (void)prepareInterfaceForPasskeyRegistration:(id<ASCredentialRequest>)registrationRequest;
- (void)performPasskeyRegistrationWithoutUserInteractionIfPossible:(ASPasskeyCredentialRequest *)registrationRequest;
- (void)prepareInterfaceForExtensionConfiguration;
- (void)prepareInterfaceForUserChoosingTextToInsert;
@end

/* ---- single sign-on (#400): the app's request, and the SSO extension's side */

typedef NSString * ASAuthorizationProviderAuthorizationOperation NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT ASAuthorizationProviderAuthorizationOperation const ASAuthorizationProviderAuthorizationOperationConfigurationRemoved;
FOUNDATION_EXPORT ASAuthorizationProviderAuthorizationOperation const ASAuthorizationProviderAuthorizationOperationDirectRequest;

@class ASAuthorizationSingleSignOnRequest;
@interface ASAuthorizationSingleSignOnProvider : NSObject <ASAuthorizationProvider>
+ (instancetype)authorizationProviderWithIdentityProviderURL:(NSURL *)url;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) BOOL canPerformAuthorization;
- (ASAuthorizationSingleSignOnRequest *)createRequest;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ASAuthorizationSingleSignOnRequest : ASAuthorizationOpenIDRequest
@property (nonatomic, copy) NSArray<NSURLQueryItem *> *authorizationOptions;
@property (nonatomic, getter=isUserInterfaceEnabled) BOOL userInterfaceEnabled;
@end

@interface ASAuthorizationSingleSignOnCredential : NSObject <ASAuthorizationCredential, NSSecureCoding>
@property (nonatomic, readonly, copy, nullable) NSString *state;
@property (nonatomic, readonly, copy, nullable) NSData *accessToken;
@property (nonatomic, readonly, copy, nullable) NSData *identityToken;
@property (nonatomic, readonly, copy) NSArray<ASAuthorizationScope> *authorizedScopes;
@property (nonatomic, readonly, copy, nullable) NSHTTPURLResponse *authenticatedResponse;
@end

@interface ASAuthorizationProviderExtensionAuthorizationResult : NSObject
- (instancetype)initWithHTTPAuthorizationHeaders:(NSDictionary<NSString *, NSString *> *)httpAuthorizationHeaders;
- (instancetype)initWithHTTPResponse:(NSHTTPURLResponse *)httpResponse httpBody:(nullable NSData *)httpBody;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *httpAuthorizationHeaders;
@property (nonatomic, copy, nullable) NSHTTPURLResponse *httpResponse;
@property (nonatomic, copy, nullable) NSData *httpBody;
@end

@interface ASAuthorizationProviderExtensionAuthorizationRequest : NSObject
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) ASAuthorizationProviderAuthorizationOperation requestedOperation;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *httpHeaders;
@property (nonatomic, readonly) NSData *httpBody;
@property (nonatomic, readonly) NSString *realm;
@property (nonatomic, readonly) NSDictionary *extensionData;
@property (nonatomic, readonly) NSString *callerBundleIdentifier;
@property (nonatomic, readonly) NSString *callerTeamIdentifier;
@property (nonatomic, readonly) NSString *localizedCallerDisplayName;
@property (nonatomic, readonly) NSDictionary *authorizationOptions;
@property (nonatomic, readonly, getter=isCallerManaged) BOOL callerManaged;
@property (nonatomic, readonly, getter=isUserInterfaceEnabled) BOOL userInterfaceEnabled;
- (void)doNotHandle;
- (void)cancel;
- (void)complete;
- (void)completeWithHTTPAuthorizationHeaders:(NSDictionary<NSString *, NSString *> *)httpAuthorizationHeaders;
- (void)completeWithHTTPResponse:(NSHTTPURLResponse *)httpResponse httpBody:(nullable NSData *)httpBody;
- (void)completeWithAuthorizationResult:(ASAuthorizationProviderExtensionAuthorizationResult *)authorizationResult;
- (void)completeWithError:(NSError *)error;
- (void)presentAuthorizationViewControllerWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
@end

@protocol ASAuthorizationProviderExtensionAuthorizationRequestHandler <NSObject>
- (void)beginAuthorizationWithRequest:(ASAuthorizationProviderExtensionAuthorizationRequest *)request;
@optional
- (void)cancelAuthorizationWithRequest:(ASAuthorizationProviderExtensionAuthorizationRequest *)request;
@end

/* ---- account modification (#400) */

@interface ASAccountAuthenticationModificationRequest : NSObject
@end
@interface ASAccountAuthenticationModificationUpgradePasswordToStrongPasswordRequest : ASAccountAuthenticationModificationRequest
- (instancetype)initWithUser:(NSString *)user serviceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier userInfo:(nullable NSDictionary *)userInfo;
@property (nonatomic, readonly, copy) NSString *user;
@property (nonatomic, readonly, copy) ASCredentialServiceIdentifier *serviceIdentifier;
@property (nonatomic, readonly, copy, nullable) NSDictionary *userInfo;
@end
@interface ASAccountAuthenticationModificationReplacePasswordWithSignInWithAppleRequest : ASAccountAuthenticationModificationRequest
- (instancetype)initWithUser:(NSString *)user serviceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier userInfo:(nullable NSDictionary *)userInfo;
@property (nonatomic, readonly, copy) NSString *user;
@property (nonatomic, readonly, copy) ASCredentialServiceIdentifier *serviceIdentifier;
@property (nonatomic, readonly, copy, nullable) NSDictionary *userInfo;
@end

@class ASAccountAuthenticationModificationController;
@protocol ASAccountAuthenticationModificationControllerDelegate <NSObject>
@optional
- (void)accountAuthenticationModificationController:(ASAccountAuthenticationModificationController *)controller
                   didSuccessfullyCompleteRequest:(ASAccountAuthenticationModificationRequest *)request withUserInfo:(nullable NSDictionary *)userInfo;
- (void)accountAuthenticationModificationController:(ASAccountAuthenticationModificationController *)controller
                                   didFailRequest:(ASAccountAuthenticationModificationRequest *)request withError:(NSError *)error;
@end
@protocol ASAccountAuthenticationModificationControllerPresentationContextProviding <NSObject>
- (ASPresentationAnchor)presentationAnchorForAccountAuthenticationModificationController:(ASAccountAuthenticationModificationController *)controller;
@end

@interface ASAccountAuthenticationModificationController : NSObject
@property (nonatomic, weak, nullable) id<ASAccountAuthenticationModificationControllerDelegate> delegate;
@property (nonatomic, weak, nullable) id<ASAccountAuthenticationModificationControllerPresentationContextProviding> presentationContextProvider;
- (void)performRequest:(ASAccountAuthenticationModificationRequest *)request;
@end

@interface ASAccountAuthenticationModificationExtensionContext : NSExtensionContext
- (void)getSignInWithAppleUpgradeAuthorizationWithState:(nullable NSString *)state nonce:(nullable NSString *)nonce
                                      completionHandler:(void (^)(ASAuthorizationAppleIDCredential * _Nullable authorization, NSError * _Nullable error))completionHandler;
- (void)completeUpgradeToSignInWithAppleWithUserInfo:(nullable NSDictionary *)userInfo;
- (void)completeChangePasswordRequestWithUpdatedCredential:(ASPasswordCredential *)updatedCredential userInfo:(nullable NSDictionary *)userInfo;
@end

@interface ASAccountAuthenticationModificationViewController : UIViewController
@property (nonatomic, readonly, strong) ASAccountAuthenticationModificationExtensionContext *extensionContext;
- (void)convertAccountToSignInWithAppleWithoutUserInteractionForServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                                              existingCredential:(ASPasswordCredential *)existingCredential userInfo:(nullable NSDictionary *)userInfo;
- (void)prepareInterfaceToConvertAccountToSignInWithAppleForServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier
                                                          existingCredential:(ASPasswordCredential *)existingCredential userInfo:(nullable NSDictionary *)userInfo;
- (void)changePasswordWithoutUserInteractionForServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier existingCredential:(ASPasswordCredential *)existingCredential
                                                     newPassword:(NSString *)newPassword userInfo:(nullable NSDictionary *)userInfo;
- (void)prepareInterfaceToChangePasswordForServiceIdentifier:(ASCredentialServiceIdentifier *)serviceIdentifier existingCredential:(ASPasswordCredential *)existingCredential
                                                 newPassword:(NSString *)newPassword userInfo:(nullable NSDictionary *)userInfo;
- (void)cancelRequest;
@end

NS_ASSUME_NONNULL_END
#endif
