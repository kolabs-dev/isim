// isim AuthenticationServices for Objective-C (sdk-src/Frameworks/AuthenticationServices): the classes and protocols
// carry Apple's Objective-C names and these members Apple's selectors. Swift's struct-wrapped string and integer types
// (ASAuthorization.Scope, the button type, the user verification preference, ...) are their raw values here, as in
// Apple's headers (NS_TYPED_EXTENSIBLE_ENUM strings, NS_ENUM integers).
import UIKit
import CryptoKit

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
    @objc(customAuthorizationMethods) var _objc_customAuthorizationMethods: [String] {
        get { customAuthorizationMethods.map(\.rawValue) } set { customAuthorizationMethods = newValue.map(ASAuthorizationCustomMethod.init(rawValue:)) }
    }
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

// MARK: - WebAuthn extensions (Objective-C classes; Swift has the structs in Extensions.swift)

@objc(ASAuthorizationPublicKeyCredentialPRFAssertionInputValues) public final class __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues: NSObject {
    @objc public let saltInput1: Data
    @objc public let saltInput2: Data?
    @objc(initWithSaltInput1:saltInput2:) public init(saltInput1: Data, saltInput2: Data?) { self.saltInput1 = saltInput1; self.saltInput2 = saltInput2 }
    var values: ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues { .init(saltInput1: saltInput1, saltInput2: saltInput2) }
}

@objc(ASAuthorizationPublicKeyCredentialPRFAssertionInput) public final class __ASAuthorizationPublicKeyCredentialPRFAssertionInput: NSObject {
    @objc public let inputValues: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues?
    @objc public let perCredentialInputValues: [Data: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues]?
    @objc(initWithInputValues:perCredentialInputValues:)
    public init(inputValues: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues?, perCredentialInputValues: [Data: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues]?) {
        self.inputValues = inputValues; self.perCredentialInputValues = perCredentialInputValues
    }
    var swift: ASAuthorizationPublicKeyCredentialPRFAssertionInput { .init(inputValues?.values, perCredentialInputValues?.mapValues(\.values)) }
    convenience init?(_ s: ASAuthorizationPublicKeyCredentialPRFAssertionInput?) {
        guard let s else { return nil }
        func v(_ x: ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues) -> __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues {
            .init(saltInput1: x.saltInput1, saltInput2: x.saltInput2)
        }
        self.init(inputValues: s.inputValues.map(v), perCredentialInputValues: s.perCredentialInputValues?.mapValues(v))
    }
}

@objc(ASAuthorizationPublicKeyCredentialPRFRegistrationInput) public final class __ASAuthorizationPublicKeyCredentialPRFRegistrationInput: NSObject {
    @objc public let shouldCheckForSupport: Bool
    @objc public let inputValues: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues?
    init(check: Bool, values: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues?) { shouldCheckForSupport = check; inputValues = values }
    @objc(initWithInputValues:) public convenience init(inputValues: __ASAuthorizationPublicKeyCredentialPRFAssertionInputValues?) {
        self.init(check: inputValues == nil, values: inputValues)
    }
    @objc public class func checkForSupport() -> __ASAuthorizationPublicKeyCredentialPRFRegistrationInput { .init(check: true, values: nil) }
    var swift: ASAuthorizationPublicKeyCredentialPRFRegistrationInput { inputValues.map { .inputValues($0.values) } ?? .checkForSupport }
    convenience init?(_ s: ASAuthorizationPublicKeyCredentialPRFRegistrationInput?) {
        guard let s else { return nil }
        self.init(check: s.shouldCheckForSupport, values: s.inputValues.map { .init(saltInput1: $0.saltInput1, saltInput2: $0.saltInput2) })
    }
}

private func _keyData(_ k: SymmetricKey?) -> Data? { k?.withUnsafeBytes { Data($0) } }

@objc(ASAuthorizationPublicKeyCredentialPRFRegistrationOutput) public final class __ASAuthorizationPublicKeyCredentialPRFRegistrationOutput: NSObject {
    @objc public let isSupported: Bool
    @objc public let first: Data?
    @objc public let second: Data?
    init?(_ s: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?) {
        guard let s else { return nil }
        isSupported = s.isSupported; first = _keyData(s.first); second = _keyData(s.second)
    }
}

@objc(ASAuthorizationPublicKeyCredentialPRFAssertionOutput) public final class __ASAuthorizationPublicKeyCredentialPRFAssertionOutput: NSObject {
    @objc public let first: Data
    @objc public let second: Data?
    init?(_ s: ASAuthorizationPublicKeyCredentialPRFAssertionOutput?) {
        guard let s else { return nil }
        first = _keyData(s.first) ?? Data(); second = _keyData(s.second)
    }
}

@objc(ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput) public final class __ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput: NSObject {
    /// ASAuthorizationPublicKeyCredentialLargeBlobSupportRequirement: 0 required, 1 preferred
    @objc public var supportRequirement: Int
    @objc(initWithSupportRequirement:) public init(supportRequirement: Int) { self.supportRequirement = supportRequirement }
    var swift: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput { supportRequirement == 0 ? .supportRequired : .supportPreferred }
    convenience init?(_ s: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput?) {
        guard let s else { return nil }
        self.init(supportRequirement: s.supportRequirement == .required ? 0 : 1)
    }
}

@objc(ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput) public final class __ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput: NSObject {
    @objc public let isSupported: Bool
    init?(_ s: ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput?) { guard let s else { return nil }; isSupported = s.isSupported }
}

@objc(ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput) public final class __ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput: NSObject {
    /// ASAuthorizationPublicKeyCredentialLargeBlobAssertionOperation: 0 read, 1 write (of dataToWrite)
    @objc public let operation: Int
    @objc public var dataToWrite: Data?
    @objc(initWithOperation:) public init(operation: Int) { self.operation = operation }
    var swift: ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput { operation == 1 ? .write(dataToWrite ?? Data()) : .read }
    convenience init?(_ s: ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput?) {
        guard let s else { return nil }
        switch s.operation {
        case .read: self.init(operation: 0)
        case .write(let d): self.init(operation: 1); dataToWrite = d
        }
    }
}

@objc(ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput) public final class __ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput: NSObject {
    @objc public let readData: Data?
    @objc public let didWrite: Bool
    init?(_ s: ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput?) {
        guard let s else { return nil }
        switch s.result {
        case .read(let d): readData = d; didWrite = false
        case .write(let ok): readData = nil; didWrite = ok
        }
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialProvider {
    @objc(createCredentialRegistrationRequestWithChallenge:name:userID:requestStyle:)
    func _objc_createRegistration(challenge: Data, name: String, userID: Data, requestStyle: Int) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        let r = createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
        r._requestStyle = requestStyle
        return r
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
    @objc(requestStyle) var _objc_requestStyle: Int { get { _requestStyle } set { _requestStyle = newValue } }
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFRegistrationInput? {
        get { .init(prf) } set { prf = newValue?.swift }
    }
    @objc(largeBlob) var _objc_largeBlob: __ASAuthorizationPublicKeyCredentialLargeBlobRegistrationInput? {
        get { .init(largeBlob) } set { largeBlob = newValue?.swift }
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFAssertionInput? { get { .init(prf) } set { prf = newValue?.swift } }
    @objc(largeBlob) var _objc_largeBlob: __ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput? {
        get { .init(largeBlob) } set { largeBlob = newValue?.swift }
    }
}

extension ASAuthorizationPlatformPublicKeyCredentialRegistration {
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFRegistrationOutput? { .init(prf) }
    @objc(largeBlob) var _objc_largeBlob: __ASAuthorizationPublicKeyCredentialLargeBlobRegistrationOutput? { .init(largeBlob) }
}

extension ASAuthorizationPlatformPublicKeyCredentialAssertion {
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFAssertionOutput? { .init(prf) }
    @objc(largeBlob) var _objc_largeBlob: __ASAuthorizationPublicKeyCredentialLargeBlobAssertionOutput? { .init(largeBlob) }
}

// MARK: - Security keys

extension ASAuthorizationPublicKeyCredentialParameters {
    @objc(initWithAlgorithm:) convenience init(_objcAlgorithm a: Int) { self.init(algorithm: ASCOSEAlgorithmIdentifier(rawValue: a)) }
    @objc(algorithm) var _objc_algorithm: Int { algorithm.rawValue }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor {
    @objc(initWithCredentialID:transports:) convenience init(_objcCredentialID id: Data, transports: [String]) {
        self.init(credentialID: id, transports: transports.map(Transport.init(rawValue:)))
    }
    @objc(credentialID) var _objc_credentialID: Data { get { credentialID } set { credentialID = newValue } }
    @objc(transports) var _objc_transports: [String] { get { transports.map(\.rawValue) } set { transports = newValue.map(Transport.init(rawValue:)) } }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialProvider {
    @objc(initWithRelyingPartyIdentifier:) convenience init(_objcRelyingPartyIdentifier rp: String) { self.init(relyingPartyIdentifier: rp) }
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(createCredentialRegistrationRequestWithChallenge:displayName:name:userID:)
    func _objc_createRegistration(challenge: Data, displayName: String, name: String, userID: Data) -> ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest {
        createCredentialRegistrationRequest(challenge: challenge, displayName: displayName, name: name, userID: userID)
    }
    @objc(createCredentialAssertionRequestWithChallenge:)
    func _objc_createAssertion(challenge: Data) -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {
        createCredentialAssertionRequest(challenge: challenge)
    }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest {
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(challenge) var _objc_challenge: Data { get { challenge } set { challenge = newValue } }
    @objc(displayName) var _objc_displayName: String? { get { displayName } set { displayName = newValue } }
    @objc(name) var _objc_name: String { get { name } set { name = newValue } }
    @objc(userID) var _objc_userID: Data { get { userID } set { userID = newValue } }
    @objc(userVerificationPreference) var _objc_userVerificationPreference: String {
        get { userVerificationPreference.rawValue } set { userVerificationPreference = .init(rawValue: newValue) }
    }
    @objc(attestationPreference) var _objc_attestationPreference: String {
        get { attestationPreference.rawValue } set { attestationPreference = .init(rawValue: newValue) }
    }
    @objc(credentialParameters) var _objc_credentialParameters: [ASAuthorizationPublicKeyCredentialParameters] {
        get { credentialParameters } set { credentialParameters = newValue }
    }
    @objc(excludedCredentials) var _objc_excludedCredentials: [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor] {
        get { excludedCredentials } set { excludedCredentials = newValue }
    }
    @objc(residentKeyPreference) var _objc_residentKeyPreference: String {
        get { residentKeyPreference.rawValue } set { residentKeyPreference = .init(rawValue: newValue) }
    }
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFRegistrationInput? { get { .init(prf) } set { prf = newValue?.swift } }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {
    @objc(relyingPartyIdentifier) var _objc_relyingPartyIdentifier: String { relyingPartyIdentifier }
    @objc(challenge) var _objc_challenge: Data { get { challenge } set { challenge = newValue } }
    @objc(allowedCredentials) var _objc_allowedCredentials: [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor] {
        get { allowedCredentials } set { allowedCredentials = newValue }
    }
    @objc(userVerificationPreference) var _objc_userVerificationPreference: String {
        get { userVerificationPreference.rawValue } set { userVerificationPreference = .init(rawValue: newValue) }
    }
    @objc(appID) var _objc_appID: String? { get { appID } set { appID = newValue } }
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFAssertionInput? { get { .init(prf) } set { prf = newValue?.swift } }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
    @objc(rawAttestationObject) var _objc_rawAttestationObject: Data? { rawAttestationObject }
    @objc(rawClientDataJSON) var _objc_rawClientDataJSON: Data { rawClientDataJSON }
    @objc(credentialID) var _objc_credentialID: Data { credentialID }
    @objc(attachment) var _objc_attachment: Int { attachment.rawValue }
    @objc(transports) var _objc_transports: [String] { transports.map(\.rawValue) }
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFRegistrationOutput? { .init(prf) }
}

extension ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
    @objc(rawAuthenticatorData) var _objc_rawAuthenticatorData: Data { rawAuthenticatorData }
    @objc(rawClientDataJSON) var _objc_rawClientDataJSON: Data { rawClientDataJSON }
    @objc(credentialID) var _objc_credentialID: Data { credentialID }
    @objc(signature) var _objc_signature: Data { signature }
    @objc(userID) var _objc_userID: Data { userID }
    @objc(attachment) var _objc_attachment: Int { attachment.rawValue }
    @objc(appID) var _objc_appID: Bool { appID }
    @objc(prf) var _objc_prf: __ASAuthorizationPublicKeyCredentialPRFAssertionOutput? { .init(prf) }
}
