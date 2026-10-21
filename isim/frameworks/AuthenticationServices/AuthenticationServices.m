// isim AuthenticationServices for Objective-C: the C constants (the classes are the AuthenticationServices Swift
// overlay's). The values are the overlay's.
#import <AuthenticationServices/AuthenticationServices.h>

NSErrorDomain const ASAuthorizationErrorDomain = @"com.apple.AuthenticationServices.AuthorizationError";
NSErrorDomain const ASWebAuthenticationSessionErrorDomain = @"com.apple.AuthenticationServices.WebAuthenticationSession";

ASAuthorizationScope const ASAuthorizationScopeFullName = @"full_name";
ASAuthorizationScope const ASAuthorizationScopeEmail = @"email";

ASAuthorizationOpenIDOperation const ASAuthorizationOperationImplicit = @"";
ASAuthorizationOpenIDOperation const ASAuthorizationOperationLogin = @"login";
ASAuthorizationOpenIDOperation const ASAuthorizationOperationRefresh = @"refresh";
ASAuthorizationOpenIDOperation const ASAuthorizationOperationLogout = @"logout";

NSNotificationName const ASAuthorizationAppleIDProviderCredentialRevokedNotification = @"ASAuthorizationAppleIDProviderCredentialRevokedNotification";

ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferencePreferred = @"preferred";
ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceRequired = @"required";
ASAuthorizationPublicKeyCredentialUserVerificationPreference const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceDiscouraged = @"discouraged";

ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindNone = @"none";
ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindDirect = @"direct";
ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindIndirect = @"indirect";
ASAuthorizationPublicKeyCredentialAttestationKind const ASAuthorizationPublicKeyCredentialAttestationKindEnterprise = @"enterprise";
