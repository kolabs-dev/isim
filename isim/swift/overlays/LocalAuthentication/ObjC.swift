// isim LocalAuthentication for Objective-C (sdk-src/Frameworks/LocalAuthentication): the classes carry Apple's
// Objective-C names and these members Apple's selectors; Swift enums are their raw values (NS_ENUM integers).
import Foundation
import Security

extension LAContext {
    @objc(canEvaluatePolicy:error:) func _objc_canEvaluatePolicy(_ policy: Int, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        guard let p = LAPolicy(rawValue: policy) else { error?.pointee = LAError(.invalidContext) as NSError; return false }
        return canEvaluatePolicy(p, error: error)
    }
    @objc(evaluatePolicy:localizedReason:reply:)
    func _objc_evaluatePolicy(_ policy: Int, localizedReason: String, reply: @escaping @Sendable (Bool, Error?) -> Void) {
        guard let p = LAPolicy(rawValue: policy) else { reply(false, LAError(.invalidContext)); return }
        evaluatePolicy(p, localizedReason: localizedReason, reply: reply)
    }
    @objc(evaluateAccessControl:operation:localizedReason:reply:)
    func _objc_evaluateAccessControl(_ accessControl: SecAccessControl, operation: Int, localizedReason: String, reply: @escaping @Sendable (Bool, Error?) -> Void) {
        evaluateAccessControl(accessControl, operation: LAAccessControlOperation(rawValue: operation) ?? .useItem, localizedReason: localizedReason, reply: reply)
    }
    @objc(invalidate) func _objc_invalidate() { invalidate() }
    @objc(setCredential:type:) func _objc_setCredential(_ credential: Data?, type: Int) -> Bool {
        setCredential(credential, type: LACredentialType(rawValue: type) ?? .applicationPassword)
    }
    @objc(isCredentialSet:) func _objc_isCredentialSet(_ type: Int) -> Bool { isCredentialSet(LACredentialType(rawValue: type) ?? .applicationPassword) }
    @objc(localizedFallbackTitle) var _objc_localizedFallbackTitle: String? { get { localizedFallbackTitle } set { localizedFallbackTitle = newValue } }
    @objc(localizedCancelTitle) var _objc_localizedCancelTitle: String? { get { localizedCancelTitle } set { localizedCancelTitle = newValue } }
    @objc(localizedReason) var _objc_localizedReason: String { get { localizedReason } set { localizedReason = newValue } }
    @objc(touchIDAuthenticationAllowableReuseDuration) var _objc_reuseDuration: TimeInterval {
        get { touchIDAuthenticationAllowableReuseDuration } set { touchIDAuthenticationAllowableReuseDuration = newValue }
    }
    @objc(interactionNotAllowed) var _objc_interactionNotAllowed: Bool { get { interactionNotAllowed } set { interactionNotAllowed = newValue } }
    @objc(biometryType) var _objc_biometryType: Int { biometryType.rawValue }
    @objc(evaluatedPolicyDomainState) var _objc_evaluatedPolicyDomainState: Data? { evaluatedPolicyDomainState }
    @available(iOS 18.0, *)
    @objc(domainState) var _objc_domainState: LADomainState { domainState }
}

@available(iOS 18.0, *)
extension LADomainStateBiometry {
    @objc(biometryType) var _objc_biometryType: Int { biometryType.rawValue }
    @objc(stateHash) var _objc_stateHash: Data? { stateHash }
}
@available(iOS 18.0, *)
extension LADomainStateCompanion {
    @objc(availableCompanionTypes) var _objc_availableCompanionTypes: Set<NSNumber> { Set(availableCompanionTypes.map { NSNumber(value: $0.rawValue) }) }
    @objc(stateHash) var _objc_stateHash: Data? { stateHash }
    @objc(stateHashForCompanionType:) func _objc_stateHash(for type: Int) -> Data? { nil }
}
@available(iOS 18.0, *)
extension LADomainState {
    @objc(biometry) var _objc_biometry: LADomainStateBiometry { biometry }
    @objc(companion) var _objc_companion: LADomainStateCompanion { companion }
    @objc(stateHash) var _objc_stateHash: Data? { stateHash }
}

@available(iOS 18.0, *)
extension LAEnvironment {
    @objc(currentUser) class var _objc_currentUser: LAEnvironment { currentUser }
    @objc(state) var _objc_state: State { state }
    @objc(addObserver:) func _objc_addObserver(_ o: Observer) { addObserver(o) }
    @objc(removeObserver:) func _objc_removeObserver(_ o: Observer) { removeObserver(o) }
}
@available(iOS 18.0, *)
extension LAEnvironment.Mechanism {
    @objc(isUsable) var _objc_isUsable: Bool { isUsable }
    @objc(localizedName) var _objc_localizedName: String { localizedName }
    @objc(iconSystemName) var _objc_iconSystemName: String { iconSystemName }
}
@available(iOS 18.0, *)
extension LAEnvironment.MechanismBiometry {
    @objc(biometryType) var _objc_biometryType: Int { biometryType.rawValue }
    @objc(isEnrolled) var _objc_isEnrolled: Bool { isEnrolled }
    @objc(isLockedOut) var _objc_isLockedOut: Bool { isLockedOut }
    @objc(stateHash) var _objc_stateHash: Data { stateHash }
    @objc(builtInSensorInaccessible) var _objc_builtInSensorInaccessible: Bool { builtInSensorInaccessible }
}
@available(iOS 18.0, *)
extension LAEnvironment.MechanismUserPassword {
    @objc(isSet) var _objc_isSet: Bool { isSet }
}
@available(iOS 18.0, *)
extension LAEnvironment.MechanismCompanion {
    @objc(type) var _objc_type: Int { type.rawValue }
    @objc(stateHash) var _objc_stateHash: Data? { stateHash }
}
@available(iOS 18.0, *)
extension LAEnvironment.State {
    @objc(biometry) var _objc_biometry: LAEnvironment.MechanismBiometry? { biometry }
    @objc(userPassword) var _objc_userPassword: LAEnvironment.MechanismUserPassword? { userPassword }
    @objc(companions) var _objc_companions: [LAEnvironment.MechanismCompanion] { companions }
    @objc(allMechanisms) var _objc_allMechanisms: [LAEnvironment.Mechanism] { allMechanisms }
}

extension LABiometryFallbackRequirement {
    @objc(defaultRequirement) class var _objc_default: LABiometryFallbackRequirement { .default }
    @objc(devicePasscodeRequirement) class var _objc_devicePasscode: LABiometryFallbackRequirement { .devicePasscode }
}
extension LAAuthenticationRequirement {
    @objc(defaultRequirement) class var _objc_default: LAAuthenticationRequirement { .default }
    @objc(biometryRequirement) class var _objc_biometry: LAAuthenticationRequirement { .biometry }
    @objc(biometryCurrentSetRequirement) class var _objc_biometryCurrentSet: LAAuthenticationRequirement { .biometryCurrentSet }
    @objc(biometryRequirementWithFallback:) class func _objc_biometry(fallback: LABiometryFallbackRequirement) -> LAAuthenticationRequirement {
        LAAuthenticationRequirement(_isimKind: "biometry", fallback: fallback.passcode)
    }
}

extension LARight {
    @objc(initWithRequirement:) convenience init(_objcRequirement r: LAAuthenticationRequirement) { self.init(requirement: r) }
    @objc(tag) var _objc_tag: Int { get { tag } set { tag = newValue } }
    @objc(authorizeWithLocalizedReason:completion:)
    func _objc_authorize(localizedReason: String, completion: @escaping @Sendable (Error?) -> Void) { authorize(localizedReason: localizedReason, completion: completion) }
    @objc(checkCanAuthorizeWithCompletion:) func _objc_checkCanAuthorize(completion: @escaping @Sendable (Error?) -> Void) { checkCanAuthorize(completion: completion) }
    @objc(deauthorizeWithCompletion:) func _objc_deauthorize(completion: @escaping @Sendable () -> Void) { deauthorize(completion: completion) }
}

extension LAPersistedRight {
    @objc(key) var _objc_key: LAPrivateKey { key }
    @objc(secret) var _objc_secret: LASecret { secret }
}

extension LASecret {
    @objc(loadDataWithCompletion:) func _objc_loadData(completion: @escaping @Sendable (Data?, Error?) -> Void) { loadData(completion: completion) }
}

extension LAPublicKey {
    @objc(exportBytesWithCompletion:) func _objc_exportBytes(completion: @escaping @Sendable (Data?, Error?) -> Void) { exportBytes(completion: completion) }
    @objc(encryptData:secKeyAlgorithm:completion:)
    func _objc_encrypt(_ d: Data, algorithm: String, completion: @escaping @Sendable (Data?, Error?) -> Void) {
        encrypt(d, algorithm: SecKeyAlgorithm(rawValue: algorithm as CFString), completion: completion)
    }
    @objc(canEncryptUsingSecKeyAlgorithm:) func _objc_canEncrypt(_ algorithm: String) -> Bool { canEncrypt(using: SecKeyAlgorithm(rawValue: algorithm as CFString)) }
    @objc(verifyData:signature:secKeyAlgorithm:completion:)
    func _objc_verify(_ d: Data, signature: Data, algorithm: String, completion: @escaping @Sendable (Error?) -> Void) {
        verify(d, signature: signature, algorithm: SecKeyAlgorithm(rawValue: algorithm as CFString), completion: completion)
    }
    @objc(canVerifyUsingSecKeyAlgorithm:) func _objc_canVerify(_ algorithm: String) -> Bool { canVerify(using: SecKeyAlgorithm(rawValue: algorithm as CFString)) }
}

extension LAPrivateKey {
    @objc(publicKey) var _objc_publicKey: LAPublicKey { publicKey }
    @objc(signData:secKeyAlgorithm:completion:)
    func _objc_sign(_ d: Data, algorithm: String, completion: @escaping @Sendable (Data?, Error?) -> Void) { sign(d, algorithm: SecKeyAlgorithm(rawValue: algorithm as CFString), completion: completion) }
    @objc(canSignUsingSecKeyAlgorithm:) func _objc_canSign(_ algorithm: String) -> Bool { canSign(using: SecKeyAlgorithm(rawValue: algorithm as CFString)) }
    @objc(decryptData:secKeyAlgorithm:completion:)
    func _objc_decrypt(_ d: Data, algorithm: String, completion: @escaping @Sendable (Data?, Error?) -> Void) { decrypt(d, algorithm: SecKeyAlgorithm(rawValue: algorithm as CFString), completion: completion) }
    @objc(canDecryptUsingSecKeyAlgorithm:) func _objc_canDecrypt(_ algorithm: String) -> Bool { canDecrypt(using: SecKeyAlgorithm(rawValue: algorithm as CFString)) }
    @objc(exchangeKeysWithPublicKey:secKeyAlgorithm:secKeyParameters:completion:)
    func _objc_exchange(_ pub: Data, algorithm: String, parameters: [AnyHashable: Any], completion: @escaping @Sendable (Data?, Error?) -> Void) {
        exchangeKeys(publicKey: pub, algorithm: SecKeyAlgorithm(rawValue: algorithm as CFString), parameters: parameters, completion: completion)
    }
    @objc(canExchangeKeysUsingSecKeyAlgorithm:) func _objc_canExchange(_ algorithm: String) -> Bool { canExchangeKeys(using: SecKeyAlgorithm(rawValue: algorithm as CFString)) }
}

extension LARightStore {
    @objc(sharedStore) class var _objc_shared: LARightStore { shared }
    @objc(rightForIdentifier:completion:)
    func _objc_right(_ id: String, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) { right(forIdentifier: id, completion: completion) }
    @objc(saveRight:identifier:completion:)
    func _objc_save(_ r: LARight, identifier: String, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) {
        saveRight(r, identifier: identifier, completion: completion)
    }
    @objc(saveRight:identifier:secret:completion:)
    func _objc_save(_ r: LARight, identifier: String, secret: Data, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) {
        saveRight(r, identifier: identifier, secret: secret, completion: completion)
    }
    @objc(removeRight:completion:) func _objc_remove(_ r: LAPersistedRight, completion: @escaping @Sendable (Error?) -> Void) { removeRight(r, completion: completion) }
    @objc(removeRightForIdentifier:completion:)
    func _objc_remove(identifier: String, completion: @escaping @Sendable (Error?) -> Void) { removeRight(forIdentifier: identifier, completion: completion) }
    @objc(removeAllRightsWithCompletion:) func _objc_removeAll(completion: @escaping @Sendable (Error?) -> Void) { removeAllRights(completion: completion) }
}
