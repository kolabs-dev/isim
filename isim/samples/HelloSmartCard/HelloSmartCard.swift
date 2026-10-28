// Sample: smart cards with CryptoTokenKit on isim's virtual card readers (issue #403). `isim smartcard insert --demo`
// puts a PIV card in "isim Virtual Reader" (a PIN pad reader); the app watches the slot (KVO) and the token watcher,
// reads the card's ATR and its compact-TLV historical bytes, selects the PIV applet, reads the CHUID (a BER-TLV object
// longer than one response: GET RESPONSE), finds the certificate object protected, verifies the PIN on the reader's
// PIN pad (isim's PIN sheet) and then reads it. Every step is printed ("sc ...").
import UIKit
import CryptoTokenKit

func log(_ s: String) { print("sc \(s)"); fflush(stdout) }
let reader = "isim Virtual Reader"
let pivAID = Data([0xA0, 0x00, 0x00, 0x03, 0x08, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00])
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined() }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: CardViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class CardViewController: UIViewController {
    var slot: TKSmartCardSlot?
    var observation: NSKeyValueObservation?
    let watcher = TKTokenWatcher()
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Smart Card"
        view.backgroundColor = .systemBackground
        status.frame = CGRect(x: 20, y: 110, width: view.bounds.width - 40, height: 60)
        status.numberOfLines = 0; status.accessibilityIdentifier = "status"
        view.addSubview(status)
        button("read", "Read Card", y: 190) { self.read() }
        button("verify", "Verify PIN", y: 240) { self.verify() }
        button("change", "Change PIN", y: 290) { self.change() }
        tlv()
        guard let manager = TKSmartCardSlotManager.default else { log("no slot manager"); return }
        log("slots \(manager.slotNames)")
        slot = manager.slotNamed(reader)
        observation = slot?.observe(\.state, options: [.initial, .new]) { [weak self] slot, _ in
            log("slot \(slot.name) state=\(slot.state.rawValue)")
            DispatchQueue.main.async { self?.status.text = slot.state == .validCard ? "Card in \(slot.name)" : "No card" }
            if slot.state == .validCard, let atr = slot.atr { self?.describe(atr) }
        }
        watcher.setInsertionHandler { [weak self] id in
            log("token inserted \(id) driver=\(self?.watcher.tokenInfo(forTokenID: id)?.driverName ?? "-")")
            self?.watcher.addRemovalHandler({ id in log("token removed \(id)") }, forTokenID: id)
        }
    }
    func button(_ id: String, _ title: String, y: CGFloat, _ action: @escaping () -> Void) {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.frame = CGRect(x: 20, y: y, width: 200, height: 40)
        b.accessibilityIdentifier = id
        b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        view.addSubview(b)
    }

    func describe(_ atr: TKSmartCardATR) {
        let hist = atr.historicalRecords?.map { "\($0.tag):\($0.value.count)" }.joined(separator: ",") ?? "-"
        log("atr \(hex(atr.bytes)) protocols=\(atr.protocols.map(\.intValue)) historical=\(atr.historicalBytes.count) records=\(hist) "
            + "group2=\(atr.interfaceGroup(at: 2)?.protocol?.intValue ?? -1) t1=\(atr.interfaceGroup(for: .t1) != nil)")
    }
    func tlv() {
        let inner = TKBERTLVRecord(tag: 0x5FC102, value: Data([1, 2, 3]))
        let outer = TKBERTLVRecord(tag: 0x53, records: [inner, TKBERTLVRecord(tag: 0x30, value: Data(repeating: 7, count: 200))])
        let back = TKBERTLVRecord.sequenceOfRecords(from: outer.value)?.map { String(format: "%llX", $0.tag) } ?? []
        let simple = TKSimpleTLVRecord(tag: 0x80, value: Data([9])), compact = TKCompactTLVRecord(tag: 4, value: Data([1, 2]))
        log("tlv outer=\(hex(outer.data.prefix(6))) inner=\(back) simple=\(hex(simple.data)) compact=\(hex(compact.data)) "
            + "parsed=\(TKBERTLVRecord(from: outer.data)?.tag == 0x53) bad=\(TKBERTLVRecord(from: Data([0x53, 0x05, 1])) == nil)")
    }

    func card() -> TKSmartCard? {
        guard let c = slot?.makeSmartCard() else { log("no card"); return nil }
        return c
    }
    func read() {
        guard let card = card() else { return }
        DispatchQueue.global().async {
            do {
                try card.withSession {
                    let sel = try card.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: pivAID, le: 0)
                    log(String(format: "select sw=%04X fci=%d protocol=%lu", sel.sw, sel.response.count, card.currentProtocol.rawValue))
                    let chuid = try card.send(ins: 0xCB, p1: 0x3F, p2: 0xFF, data: Data([0x5C, 0x03, 0x5F, 0xC1, 0x02]), le: 0)
                    let rec = TKBERTLVRecord(from: chuid.response)
                    log(String(format: "chuid sw=%04X bytes=%d tag=%llX value=%d", chuid.sw, chuid.response.count, rec?.tag ?? 0, rec?.value.count ?? 0))
                    let cert = try card.send(ins: 0xCB, p1: 0x3F, p2: 0xFF, data: Data([0x5C, 0x03, 0x5F, 0xC1, 0x05]), le: 0)
                    log(String(format: "certificate before PIN sw=%04X", cert.sw))
                    let tries = try card.send(ins: 0x20, p1: 0x00, p2: 0x80, data: nil, le: nil)
                    log(String(format: "pin status sw=%04X", tries.sw))
                }
            } catch { log("read failed \(error)") }
        }
    }
    func verify() {
        guard let card = card() else { return }
        let format = TKSmartCardPINFormat()
        format.minPINLength = 6
        let apdu = Data([0x00, 0x20, 0x00, 0x80, 0x08] + [UInt8](repeating: 0xFF, count: 8))
        guard let ui = card.userInteractionForSecurePINVerification(format, apdu: apdu, pinByteOffset: 5) else { log("no PIN pad"); return }
        card.beginSession { ok, error in
            guard ok else { log("session failed \(String(describing: error))"); return }
            card.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: pivAID, le: 0) { _, _, _ in
                ui.run { done, error in
                    log(String(format: "verify done=%d sw=%04X error=%@", done, ui.resultSW, error.map { "\(($0 as NSError).code)" } ?? "none"))
                    card.send(ins: 0xCB, p1: 0x3F, p2: 0xFF, data: Data([0x5C, 0x03, 0x5F, 0xC1, 0x05]), le: 0) { data, sw, _ in
                        log(String(format: "certificate after PIN sw=%04X bytes=%d", sw, data?.count ?? 0))
                        card.endSession()
                    }
                }
            }
        }
    }
    func change() {
        guard let card = card() else { return }
        let format = TKSmartCardPINFormat()
        format.minPINLength = 6
        let apdu = Data([0x00, 0x24, 0x00, 0x80, 0x10] + [UInt8](repeating: 0xFF, count: 16))
        guard let ui = card.userInteractionForSecurePINChange(format, apdu: apdu, currentPINByteOffset: 5, newPINByteOffset: 13) else { log("no PIN pad"); return }
        Task {
            do {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
                    card.beginSession { ok, e in ok ? c.resume() : c.resume(throwing: e!) }
                }
                _ = try await card.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: pivAID, le: 0)
                ui.run { done, error in
                    log(String(format: "change done=%d sw=%04X", done, ui.resultSW))
                    card.endSession()
                }
            } catch { log("change failed \(error)") }
        }
    }
}
