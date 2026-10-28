// isim CryptoTokenKit: PIN formats and secure PIN entry (adapted). A virtual reader with "pinPad": true stands in for a
// PIN pad reader: run() asks the user for the PIN in isim's PIN sheet (an alert with a secure field; for a change, the
// current PIN and the new one twice), puts it into the command APDU at the PIN byte offset in the PIN format (ASCII,
// BCD or binary, justified, with its length field), sends it to the card and reports resultSW / resultData.
// ISIM_SMARTCARD_PIN answers without the sheet (a change: "current,new"), for scripted tests.
import Foundation
import UIKit

@objc(TKSmartCardPINFormat) open class TKSmartCardPINFormat: NSObject, @unchecked Sendable {
    @objc(TKSmartCardPINCharset) public enum Charset: Int, Sendable { case numeric = 0, alphanumeric = 1, upperAlphanumeric = 2 }
    @objc(TKSmartCardPINEncoding) public enum Encoding: Int, Sendable { case binary = 0, ascii = 1, bcd = 2 }
    @objc(TKSmartCardPINJustification) public enum Justification: Int, Sendable { case left = 0, right = 1 }
    @objc open var charset: Charset = .numeric
    @objc open var encoding: Encoding = .ascii
    @objc open var minPINLength = 4
    @objc open var maxPINLength = 8
    @objc(PINBlockByteLength) open var pinBlockByteLength = 8
    @objc(PINJustification) open var pinJustification: Justification = .left
    @objc(PINBitOffset) open var pinBitOffset = 0
    @objc(PINLengthBitOffset) open var pinLengthBitOffset = 0
    @objc(PINLengthBitSize) open var pinLengthBitSize = 0
    public override init() { super.init() }

    func valid(_ pin: String) -> Bool {
        guard pin.count >= minPINLength, pin.count <= maxPINLength else { return false }
        switch charset {
        case .numeric: return pin.allSatisfy { $0.isASCII && $0.isNumber }
        case .alphanumeric: return pin.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        case .upperAlphanumeric: return pin.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
        }
    }
    /// the PIN block: the PIN's units (bytes for ASCII and binary, nibbles for BCD) at pinBitOffset, justified, the rest
    /// of the block 0xFF (ASCII) or 0 bits; its length in the length field when there is one
    func block(_ pin: String) -> [UInt8] {
        var bits = [Bool](repeating: encoding == .ascii, count: pinBlockByteLength * 8)
        func put(_ value: Int, width: Int, at: Int) {
            for k in 0..<width where at + k < bits.count { bits[at + k] = (value >> (width - 1 - k)) & 1 == 1 }
        }
        let units: [Int], width: Int
        switch encoding {
        case .ascii: units = pin.utf8.map(Int.init); width = 8
        case .bcd: units = pin.compactMap { $0.wholeNumberValue }; width = 4
        case .binary: units = pin.compactMap { $0.wholeNumberValue }; width = 8
        }
        let field = pinBlockByteLength * 8 - pinBitOffset
        let start = pinJustification == .left ? pinBitOffset : pinBitOffset + max(0, field - units.count * width)
        for (k, u) in units.enumerated() { put(u, width: width, at: start + k * width) }
        if pinLengthBitSize > 0 { put(units.count, width: pinLengthBitSize, at: pinLengthBitOffset) }
        return stride(from: 0, to: bits.count, by: 8).map { i in (0..<8).reduce(UInt8(0)) { $0 << 1 | (bits[i + $1] ? 1 : 0) } }
    }
}

@objc public protocol TKSmartCardUserInteractionDelegate: NSObjectProtocol {
    @objc(characterEnteredInUserInteraction:) optional func characterEntered(in interaction: TKSmartCardUserInteraction)
    @objc(correctionKeyPressedInUserInteraction:) optional func correctionKeyPressed(in interaction: TKSmartCardUserInteraction)
    @objc(validationKeyPressedInUserInteraction:) optional func validationKeyPressed(in interaction: TKSmartCardUserInteraction)
    @objc(invalidCharacterEnteredInUserInteraction:) optional func invalidCharacterEntered(in interaction: TKSmartCardUserInteraction)
    @objc(oldPINRequestedInUserInteraction:) optional func oldPINRequested(in interaction: TKSmartCardUserInteraction)
    @objc(newPINRequestedInUserInteraction:) optional func newPINRequested(in interaction: TKSmartCardUserInteraction)
    @objc(newPINConfirmationRequestedInUserInteraction:) optional func newPINConfirmationRequested(in interaction: TKSmartCardUserInteraction)
}

@objc(TKSmartCardUserInteraction) open class TKSmartCardUserInteraction: NSObject, @unchecked Sendable {
    @objc open weak var delegate: (any TKSmartCardUserInteractionDelegate)?
    @objc open var initialTimeout: TimeInterval = 0
    @objc open var interactionTimeout: TimeInterval = 0
    var cancelled = false
    weak var alert: UIAlertController?
    /// runs the interaction; reply(true) when it finished (see resultSW), false with the error otherwise
    @objc(runWithReply:) open func run(reply: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        DispatchQueue.global().async { reply(false, _tkError(.notImplemented)) }
    }
    /// cancels a running interaction (its sheet); false when none is running
    @objc open func cancel() -> Bool {
        guard let a = alert else { return false }
        cancelled = true
        DispatchQueue.main.async { a.dismiss(animated: true) }
        return true
    }
}

@objc(TKSmartCardUserInteractionForPINOperation) open class TKSmartCardUserInteractionForPINOperation: TKSmartCardUserInteraction, @unchecked Sendable {
    public struct Completion: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var maxLength: Completion { Completion(rawValue: 1 << 0) }
        public static var key: Completion { Completion(rawValue: 1 << 1) }
        public static var timeout: Completion { Completion(rawValue: 1 << 2) }
    }
    open var pinCompletion: Completion = .key
    @objc(PINMessageIndices) open var pinMessageIndices: [NSNumber]?
    @objc open var locale: Locale! = Locale.current
    @objc open var resultSW: UInt16 = 0
    @objc open var resultData: Data?

    let card: TKSmartCard, format: TKSmartCardPINFormat, apdu: [UInt8], offsets: [Int]
    init(card: TKSmartCard, format: TKSmartCardPINFormat, apdu: [UInt8], offsets: [Int]) {
        self.card = card; self.format = format; self.apdu = apdu; self.offsets = offsets
        super.init()
    }
    /// the PIN(s) the user enters: one for a verification, the current one and the new one for a change
    var prompts: [String] { ["PIN"] }

    open override func run(reply: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        cancelled = false
        if let answer = ProcessInfo.processInfo.environment["ISIM_SMARTCARD_PIN"] {
            let pins = answer.split(separator: ",").map(String.init)
            card.queue.async { self.finish(pins, reply) }
            return
        }
        DispatchQueue.main.async { self.ask(reply) }
    }
    private func ask(_ reply: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        guard let top = _tkTopController() else { card.queue.async { reply(false, _tkError(.canceledByUser, "no window for the PIN sheet")) }; return }
        let change = prompts.count > 1
        let a = UIAlertController(title: change ? "Change PIN" : "Enter PIN",
                                  message: "\(card.slot.name) asks for the smart card's \(change ? "current and new PIN" : "PIN").",
                                  preferredStyle: .alert)
        for (i, p) in (change ? ["Current PIN", "New PIN", "Confirm New PIN"] : prompts).enumerated() {
            a.addTextField { f in
                f.placeholder = p; f.isSecureTextEntry = true
                f.keyboardType = self.format.charset == .numeric ? .numberPad : .asciiCapable
                f.accessibilityIdentifier = "isim-smartcard-pin-\(i)"
            }
        }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            NSLog("isim CryptoTokenKit: PIN entry canceled")
            self.card.queue.async { reply(false, _tkError(.canceledByUser)) }
        })
        a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in
            let fields = a?.textFields?.map { $0.text ?? "" } ?? []
            if change, fields.count == 3, fields[1] != fields[2] {
                NSLog("isim CryptoTokenKit: the new PINs do not match")
                self.card.queue.async { reply(false, _tkError(.authenticationFailed, "the new PIN and its confirmation differ")) }
                return
            }
            self.card.queue.async { self.finish(Array(fields.prefix(change ? 2 : 1)), reply) }
        })
        a.view.accessibilityIdentifier = "isim-smartcard-pin"
        alert = a
        top.present(a, animated: true)
        NSLog("isim CryptoTokenKit: PIN sheet for %@", card.slot.name)
    }
    func finish(_ pins: [String], _ reply: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        guard !cancelled else { reply(false, _tkError(.canceledByUser)); return }
        guard pins.count == offsets.count, pins.allSatisfy(format.valid) else {
            reply(false, _tkError(.badParameter, "the PIN does not match the PIN format")); return
        }
        var a = apdu
        for (pin, off) in zip(pins, offsets) {
            let b = format.block(pin)
            guard off >= 0, off + b.count <= a.count else { reply(false, _tkError(.badParameter, "the PIN does not fit the APDU")); return }
            a.replaceSubrange(off..<(off + b.count), with: b)
        }
        do {
            let r = try card.exchange(a)
            guard r.count >= 2 else { reply(false, _tkError(.corruptedData)); return }
            resultSW = UInt16(r[r.count - 2]) << 8 | UInt16(r[r.count - 1])
            resultData = r.count > 2 ? Data(r.dropLast(2)) : nil
            reply(true, nil)
        } catch { reply(false, error) }
    }
}

@objc(TKSmartCardUserInteractionForSecurePINVerification) open class TKSmartCardUserInteractionForSecurePINVerification: TKSmartCardUserInteractionForPINOperation, @unchecked Sendable {}

@objc(TKSmartCardUserInteractionForSecurePINChange) open class TKSmartCardUserInteractionForSecurePINChange: TKSmartCardUserInteractionForPINOperation, @unchecked Sendable {
    public struct Confirmation: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var new: Confirmation { Confirmation(rawValue: 1 << 0) }
        public static var current: Confirmation { Confirmation(rawValue: 1 << 1) }
    }
    open var pinConfirmation: Confirmation = []
    override var prompts: [String] { ["Current PIN", "New PIN"] }
}

func _tkTopController() -> UIViewController? {
    let windows = UIApplication.shared.windows
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let p = top?.presentedViewController, !p.isBeingDismissed { top = p }
    return top
}
