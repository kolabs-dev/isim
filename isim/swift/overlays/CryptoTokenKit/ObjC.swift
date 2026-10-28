// isim CryptoTokenKit for Objective-C: the option sets Swift sees as structs, under Apple's selectors
// (sdk-src/Frameworks/CryptoTokenKit).
import Foundation

extension TKSmartCard {
    @objc(allowedProtocols) var _objcAllowedProtocols: UInt {
        get { allowedProtocols.rawValue }
        set { allowedProtocols = TKSmartCardProtocol(rawValue: newValue) }
    }
    @objc(currentProtocol) var _objcCurrentProtocol: UInt { currentProtocol.rawValue }
}
extension TKSmartCardATR {
    @objc(interfaceGroupForProtocol:) func _objcInterfaceGroup(for p: UInt) -> InterfaceGroup? { interfaceGroup(for: TKSmartCardProtocol(rawValue: p)) }
}
extension TKSmartCardUserInteractionForPINOperation {
    @objc(PINCompletion) var _objcPINCompletion: UInt {
        get { pinCompletion.rawValue }
        set { pinCompletion = Completion(rawValue: newValue) }
    }
}
extension TKSmartCardUserInteractionForSecurePINChange {
    @objc(PINConfirmation) var _objcPINConfirmation: UInt {
        get { pinConfirmation.rawValue }
        set { pinConfirmation = Confirmation(rawValue: newValue) }
    }
}
