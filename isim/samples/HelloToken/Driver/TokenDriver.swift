// Sample: a persistent token extension for PIV cards (issue #743). The driver makes a token for a card with the PIV
// applet: it reads the PIV Authentication certificate (object 5FC105) and offers it and its key (key reference 9A) to the
// keychain. A token session signs (ECDSA over the digest) and agrees on keys (ECDH) with the card's GENERAL AUTHENTICATE;
// when the card wants its PIN (SW 6982) the session asks for authentication with a PIN operation (VERIFY).
import Foundation
import CryptoTokenKit
import Security

let pivAID = Data([0xA0, 0x00, 0x00, 0x03, 0x08, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00])

final class TokenDriver: TKSmartCardTokenDriver, TKSmartCardTokenDriverDelegate {
    func tokenDriver(_ driver: TKSmartCardTokenDriver, createTokenFor smartCard: TKSmartCard, aid AID: Data?) throws -> TKSmartCardToken {
        try PIVToken(smartCard: smartCard, aid: AID, tokenDriver: self)
    }
}

final class PIVToken: TKSmartCardToken, TKTokenDelegate {
    init(smartCard: TKSmartCard, aid: Data?, tokenDriver: TKSmartCardTokenDriver) throws {
        guard try smartCard.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: pivAID, le: 0).sw == 0x9000 else { throw TKError(.communicationError) }
        let (sw, object) = try smartCard.send(ins: 0xCB, p1: 0x3F, p2: 0xFF, data: Data([0x5C, 0x03, 0x5F, 0xC1, 0x05]), le: 0)
        guard sw == 0x9000, let outer = TKBERTLVRecord(from: object), let fields = TKBERTLVRecord.sequenceOfRecords(from: outer.value),
              let der = fields.first(where: { $0.tag == 0x70 })?.value, let cert = SecCertificateCreateWithData(nil, der as CFData) else {
            throw TKError(.corruptedData)
        }
        let serial = (SecCertificateCopySerialNumberData(cert, nil) as Data?)?.map { String(format: "%02X", $0) }.joined() ?? "0"
        super.init(smartCard: smartCard, aid: aid, instanceID: "piv-\(serial)", tokenDriver: tokenDriver)
        let certItem = TKTokenKeychainCertificate(certificate: cert, objectID: "cert-9A")
        certItem?.label = "PIV Authentication"
        let keyItem = TKTokenKeychainKey(certificate: cert, objectID: Data([0x9A]))
        keyItem?.label = "PIV Authentication Key"
        keyItem?.canSign = true
        keyItem?.canPerformKeyExchange = true
        keyItem?.isSuitableForLogin = true
        keyItem?.constraints = [NSNumber(value: TKTokenOperation.signData.rawValue): "PIN",
                                NSNumber(value: TKTokenOperation.performKeyExchange.rawValue): "PIN"]
        keychainContents?.fill(with: [certItem, keyItem].compactMap { $0 })
    }
    func createSession(_ token: TKToken) throws -> TKTokenSession { PIVSession(token: self) }
}

final class PIVSession: TKSmartCardTokenSession, TKTokenSessionDelegate {
    private var selected = false

    func tokenSession(_ session: TKTokenSession, supports operation: TKTokenOperation, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) -> Bool {
        switch operation {
        case .signData: return algorithm.supportsAlgorithm(.ecdsaSignatureDigestX962)
        case .performKeyExchange: return algorithm.supportsAlgorithm(.ecdhKeyExchangeStandard)
        default: return false
        }
    }
    func tokenSession(_ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation {
        let pin = TKTokenSmartCardPINAuthOperation()
        pin.pinFormat.charset = .numeric
        pin.pinFormat.minPINLength = 6
        pin.pinFormat.maxPINLength = 8
        pin.apduTemplate = Data([0x00, 0x20, 0x00, 0x80, 0x08] + [UInt8](repeating: 0xFF, count: 8))   // VERIFY the PIV PIN
        pin.pinByteOffset = 5
        pin.smartCard = smartCard
        return pin
    }
    func tokenSession(_ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        try generalAuthenticate(0x81, dataToSign)
    }
    func tokenSession(_ session: TKTokenSession, performKeyExchange otherPartyPublicKeyData: Data, keyObjectID objectID: Any,
                      algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data {
        try generalAuthenticate(0x85, otherPartyPublicKeyData)
    }
    /// PIV GENERAL AUTHENTICATE with key 9A (ECC P-256): 7C { 82 00, <tag> <data> } -> 7C { 82 <result> }
    private func generalAuthenticate(_ tag: UInt8, _ data: Data) throws -> Data {
        if !selected {
            guard try smartCard.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: pivAID, le: 0).sw == 0x9000 else { throw TKError(.communicationError) }
            selected = true
        }
        let inner = TKBERTLVRecord(tag: 0x82, value: Data()).data + TKBERTLVRecord(tag: TKTLVTag(tag), value: data).data
        let (sw, response) = try smartCard.send(ins: 0x87, p1: 0x11, p2: 0x9A, data: TKBERTLVRecord(tag: 0x7C, value: inner).data, le: 0)
        if sw == 0x6982 { throw TKError(.authenticationNeeded) }
        guard sw == 0x9000, let outer = TKBERTLVRecord(from: response),
              let result = TKBERTLVRecord.sequenceOfRecords(from: outer.value)?.first(where: { $0.tag == 0x82 })?.value else {
            throw TKError(.corruptedData)
        }
        return result
    }
}
