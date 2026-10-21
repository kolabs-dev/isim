// isim AuthenticationServices for Objective-C (sdk-src/Frameworks/AuthenticationServices): the classes and protocols
// carry Apple's Objective-C names and these members Apple's selectors. Swift's struct-wrapped string and integer types
// (ASAuthorization.Scope, the button type, the user verification preference, ...) are their raw values here, as in
// Apple's headers (NS_TYPED_EXTENSIBLE_ENUM strings, NS_ENUM integers).
import UIKit

/// Apps built before 0.27 implement the presentation protocols under the selector Swift gave them then,
/// presentationAnchorFor:; the overlay asks for it when the provider lacks Apple's selector.
enum _ASLegacy {
    @MainActor static func anchor(_ provider: NSObjectProtocol, _ selector: String, _ sender: AnyObject) -> ASPresentationAnchor? {
        let old = Selector(("presentationAnchorFor:"))
        guard !provider.responds(to: Selector(selector)), provider.responds(to: old) else { return nil }
        return provider.perform(old, with: sender)?.takeUnretainedValue() as? ASPresentationAnchor
    }
}

// MARK: - Authorization

extension ASAuthorizationRequest {
    @objc(provider) var _objc_provider: ASAuthorizationProvider { provider }
}

extension ASAuthorization {
    @objc(provider) var _objc_provider: ASAuthorizationProvider { provider }
    @objc(credential) var _objc_credential: ASAuthorizationCredential { credential }
}

extension ASAuthorizationController {
    @objc(initWithAuthorizationRequests:) convenience init(_objcRequests requests: [ASAuthorizationRequest]) { self.init(authorizationRequests: requests) }
    @objc(authorizationRequests) var _objc_authorizationRequests: [ASAuthorizationRequest] { authorizationRequests }
    @objc(delegate) var _objc_delegate: ASAuthorizationControllerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(presentationContextProvider) var _objc_presentationContextProvider: ASAuthorizationControllerPresentationContextProviding? {
        get { presentationContextProvider } set { presentationContextProvider = newValue }
    }
    @objc(customAuthorizationMethods) var _objc_customAuthorizationMethods: [Any] { get { customAuthorizationMethods } set { customAuthorizationMethods = newValue } }
    @objc(performRequests) func _objc_performRequests() { performRequests() }
    @objc(performRequestsWithOptions:) func _objc_performRequests(options: UInt) { performRequests(options: RequestOptions(rawValue: options)) }
    @objc(performAutoFillAssistedRequests) func _objc_performAutoFillAssistedRequests() { performAutoFillAssistedRequests() }
    @objc(cancel) func _objc_cancel() { cancel() }
}

// MARK: - Sign in with Apple

extension ASAuthorizationOpenIDRequest {
    @objc(requestedScopes) var _objc_requestedScopes: [String]? {
        get { requestedScopes?.map(\.rawValue) } set { requestedScopes = newValue?.map(ASAuthorization.Scope.init(rawValue:)) }
    }
    @objc(state) var _objc_state: String? { get { state } set { state = newValue } }
    @objc(nonce) var _objc_nonce: String? { get { nonce } set { nonce = newValue } }
    @objc(requestedOperation) var _objc_requestedOperation: String {
        get { requestedOperation.rawValue } set { requestedOperation = ASAuthorization.OpenIDOperation(rawValue: newValue) }
    }
}

extension ASAuthorizationAppleIDRequest {
    @objc(user) var _objc_user: String? { get { user } set { user = newValue } }
}

extension ASAuthorizationAppleIDProvider {
    @objc(createRequest) func _objc_createRequest() -> ASAuthorizationAppleIDRequest { createRequest() }
    @objc(getCredentialStateForUserID:completion:)
    func _objc_getCredentialState(forUserID userID: String, completion: @escaping @Sendable (Int, Error?) -> Void) {
        getCredentialState(forUserID: userID) { state, error in completion(state.rawValue, error) }
    }
}

extension ASAuthorizationAppleIDCredential {
    @objc(user) var _objc_user: String { user }
    @objc(state) var _objc_state: String? { state }
    @objc(authorizedScopes) var _objc_authorizedScopes: [String] { authorizedScopes.map(\.rawValue) }
    @objc(authorizationCode) var _objc_authorizationCode: Data? { authorizationCode }
    @objc(identityToken) var _objc_identityToken: Data? { identityToken }
    @objc(email) var _objc_email: String? { email }
    @objc(fullName) var _objc_fullName: NSPersonNameComponents? { fullName.map { $0 as NSPersonNameComponents } }
    @objc(realUserStatus) var _objc_realUserStatus: Int { realUserStatus.rawValue }
}

extension ASAuthorizationAppleIDButton {
    @objc(buttonWithType:style:) class func _objc_button(type: Int, style: Int) -> ASAuthorizationAppleIDButton {
        ASAuthorizationAppleIDButton(_objcType: type, style: style)
    }
    @objc(initWithAuthorizationButtonType:authorizationButtonStyle:) convenience init(_objcType type: Int, style: Int) {
        self.init(authorizationButtonType: ButtonType(rawValue: type), authorizationButtonStyle: Style(rawValue: style) ?? .black)
    }
    @objc(cornerRadius) var _objc_cornerRadius: CGFloat { get { cornerRadius } set { cornerRadius = newValue } }
}

// MARK: - Passwords

extension ASAuthorizationPasswordProvider {
    @objc(createRequest) func _objc_createRequest() -> ASAuthorizationPasswordRequest { createRequest() }
}

extension ASPasswordCredential {
    @objc(initWithUser:password:) convenience init(_objcUser user: String, password: String) { self.init(user: user, password: password) }
    @objc(credentialWithUser:password:) class func _objc_credential(user: String, password: String) -> ASPasswordCredential {
        ASPasswordCredential(user: user, password: password)
    }
    @objc(user) var _objc_user: String { user }
    @objc(password) var _objc_password: String { password }
}

// MARK: - Passkeys

extension ASAuthorizationPlatformPublicKeyCredentialDescriptor {
    @objc(initWithCredentialID:) convenience init(_objcCredentialID id: Data) { self.init(credentialID: id) }
    @objc(credentialID) var _objc_credentialID: Data { get { credentialID } set { credentialID = newValue } }
}

extension ASAuthorizationPlatformPublicKeyCredentialProvider {
    @objc(initWithRelyingPartyIdentifier:) convenience init(_objcRelyingPartyIdentifier rp: String) { self.init(relyingPartyIdentifier: rp) }
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(createCredentialRegistrationRequestWithChallenge:name:userID:)
    func _objc_createRegistration(challenge: Data, name: String, userID: Data) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
    }
    @objc(createCredentialAssertionRequestWithChallenge:)
    func _objc_createAssertion(challenge: Data) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        createCredentialAssertionRequest(challenge: challenge)
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(challenge) var _objc_challenge: Data { get { challenge } set { challenge = newValue } }
    @objc(name) var _objc_name: String { get { name } set { name = newValue } }
    @objc(displayName) var _objc_displayName: String? { get { displayName } set { displayName = newValue } }
    @objc(userID) var _objc_userID: Data { get { userID } set { userID = newValue } }
    @objc(userVerificationPreference) var _objc_userVerificationPreference: String {
        get { userVerificationPreference.rawValue } set { userVerificationPreference = .init(rawValue: newValue) }
    }
    @objc(attestationPreference) var _objc_attestationPreference: String {
        get { attestationPreference.rawValue } set { attestationPreference = .init(rawValue: newValue) }
    }
    @objc(excludedCredentials) var _objc_excludedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] {
        get { excludedCredentials } set { excludedCredentials = newValue }
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(challenge) var _objc_challenge: Data { get { challenge } set { challenge = newValue } }
    @objc(allowedCredentials) var _objc_allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] {
        get { allowedCredentials } set { allowedCredentials = newValue }
    }
    @objc(userVerificationPreference) var _objc_userVerificationPreference: String {
        get { userVerificationPreference.rawValue } set { userVerificationPreference = .init(rawValue: newValue) }
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialRegistration {
    @objc(rawAttestationObject) var _objc_rawAttestationObject: Data? { rawAttestationObject }
    @objc(rawClientDataJSON) var _objc_rawClientDataJSON: Data { rawClientDataJSON }
    @objc(credentialID) var _objc_credentialID: Data { credentialID }
    @objc(attachment) var _objc_attachment: Int { attachment.rawValue }
}

extension ASAuthorizationPlatformPublicKeyCredentialAssertion {
    @objc(rawAuthenticatorData) var _objc_rawAuthenticatorData: Data { rawAuthenticatorData }
    @objc(rawClientDataJSON) var _objc_rawClientDataJSON: Data { rawClientDataJSON }
    @objc(credentialID) var _objc_credentialID: Data { credentialID }
    @objc(signature) var _objc_signature: Data { signature }
    @objc(userID) var _objc_userID: Data { userID }
    @objc(attachment) var _objc_attachment: Int { attachment.rawValue }
}

// MARK: - Web authentication

extension ASWebAuthenticationSession.Callback {
    @objc(callbackWithCustomScheme:) class func _objc_callback(customScheme: String) -> ASWebAuthenticationSession.Callback { Self.customScheme(customScheme) }
    @objc(callbackWithHTTPSHost:path:) class func _objc_callback(httpsHost host: String, path: String) -> ASWebAuthenticationSession.Callback {
        https(host: host, path: path)
    }
    @objc(matchesURL:) func _objc_matchesURL(_ url: URL) -> Bool { matchesURL(url) }
}

extension ASWebAuthenticationSession {
    @objc(initWithURL:callbackURLScheme:completionHandler:)
    convenience init(_objcURL url: URL, callbackURLScheme: String?, completionHandler: @escaping (URL?, Error?) -> Void) {
        self.init(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
    }
    @objc(initWithURL:callback:completionHandler:)
    convenience init(_objcURL url: URL, callback: Callback, completionHandler: @escaping (URL?, Error?) -> Void) {
        self.init(url: url, callback: callback, completionHandler: completionHandler)
    }
    @objc(presentationContextProvider) var _objc_presentationContextProvider: ASWebAuthenticationPresentationContextProviding? {
        get { presentationContextProvider } set { presentationContextProvider = newValue }
    }
    @objc(prefersEphemeralWebBrowserSession) var _objc_prefersEphemeralWebBrowserSession: Bool {
        get { prefersEphemeralWebBrowserSession } set { prefersEphemeralWebBrowserSession = newValue }
    }
    @objc(additionalHeaderFields) var _objc_additionalHeaderFields: [String: String]? {
        get { additionalHeaderFields } set { additionalHeaderFields = newValue }
    }
    @objc(canStart) var _objc_canStart: Bool { canStart }
    @objc(start) func _objc_start() -> Bool { start() }
    @objc(cancel) func _objc_cancel() { cancel() }
}
