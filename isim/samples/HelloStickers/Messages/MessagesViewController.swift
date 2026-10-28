// The Messages extension's view controller (the Messages framework: issue #406): a tic-tac-toe message (a session,
// a URL with the board, a template layout) inserted into the compose field or sent at once, a sticker it draws
// itself (MSStickerView), a request to expand, and a late send that iOS refuses (no recent interaction). Every
// callback is printed ("stk ...").
import UIKit
import Messages

func log(_ s: String) { print("stk \(s)"); fflush(stdout) }

final class MessagesViewController: MSMessagesAppViewController {
    var session: MSSession?
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        log("messages extension loaded")
        var y: CGFloat = 8
        for (id, t) in [("stk-game", "Insert Game"), ("stk-send-now", "Send Move"), ("stk-expand", "Expand"), ("stk-send-late", "Send Later")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 16, y: y, width: 150, height: 36)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 40
        }
        status.frame = CGRect(x: 16, y: y, width: 300, height: 20)
        status.accessibilityIdentifier = "stk-status"
        view.addSubview(status)
        /* a sticker the extension draws: MSSticker checks the file (a text file is refused) */
        let dir = FileManager.default.temporaryDirectory
        let bad = dir.appendingPathComponent("not-a-sticker.txt")
        try? "hello".write(to: bad, atomically: true, encoding: .utf8)
        do { _ = try MSSticker(contentsOfFileURL: bad, localizedDescription: "Text") } catch let e as NSError {
            log("sticker refused \(e.domain == MSStickersErrorDomain) code=\(e.code)")
        }
        let png = dir.appendingPathComponent("smile.png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { _ in
            UIColor.systemYellow.setFill(); UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 112, height: 112)).fill()
            UIColor.black.setFill()
            UIBezierPath(ovalIn: CGRect(x: 36, y: 38, width: 12, height: 16)).fill(); UIBezierPath(ovalIn: CGRect(x: 72, y: 38, width: 12, height: 16)).fill()
            let mouth = UIBezierPath(); mouth.move(to: CGPoint(x: 34, y: 72)); mouth.addQuadCurve(to: CGPoint(x: 86, y: 72), controlPoint: CGPoint(x: 60, y: 100))
            mouth.lineWidth = 6; UIColor.black.setStroke(); mouth.stroke()
        }
        try? image.pngData()?.write(to: png)
        if let s = try? MSSticker(contentsOfFileURL: png, localizedDescription: "Smile") {
            let v = MSStickerView(frame: CGRect(x: 200, y: 8, width: 90, height: 90), sticker: s)
            v.accessibilityIdentifier = "stk-sticker"
            view.addSubview(v)
        }
    }

    func board(_ cells: String, caption: String) -> MSMessage {
        let s = session ?? MSSession()
        session = s
        let m = MSMessage(session: s)
        var c = URLComponents(string: "https://example.com/ttt")!
        c.queryItems = [URLQueryItem(name: "board", value: cells)]
        m.url = c.url
        let layout = MSMessageTemplateLayout()
        layout.caption = caption
        layout.subcaption = "Tic-Tac-Toe"
        layout.image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 180)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 180))
            UIColor.white.setStroke()
            for i in 1...2 {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 90 + i * 40, y: 30)); p.addLine(to: CGPoint(x: 90 + i * 40, y: 150))
                p.move(to: CGPoint(x: 90, y: 30 + i * 40)); p.addLine(to: CGPoint(x: 210, y: 30 + i * 40))
                p.lineWidth = 4; p.stroke()
            }
            for (k, ch) in cells.enumerated() where ch != "-" {
                let r = CGRect(x: 96 + (k % 3) * 40, y: 36 + (k / 3) * 40, width: 28, height: 28)
                (ch == "X" ? UIColor.white : UIColor.systemYellow).setStroke()
                let p = ch == "X" ? { let p = UIBezierPath(); p.move(to: r.origin); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                    p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); return p }() : UIBezierPath(ovalIn: r)
                p.lineWidth = 5; p.stroke()
            }
        }
        layout.imageTitle = "Tic-Tac-Toe"
        m.layout = layout
        m.summaryText = caption
        return m
    }

    func tap(_ id: String) {
        guard let c = activeConversation else { log("no conversation"); return }
        switch id {
        case "stk-game":
            c.insert(board("X--------", caption: "Your move")) { e in log("insert game \(e == nil ? "ok" : "\(e!)")") }
        case "stk-send-now":
            c.send(board("X---O----", caption: "Ana's move")) { e in log("send move \(e == nil ? "ok" : "\((e! as NSError).code)")") }
        case "stk-expand":
            requestPresentationStyle(.expanded)
        case "stk-send-late":
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                c.sendText("Too late") { e in log("late send \(e.map { "error \(($0 as NSError).code)" } ?? "ok")") }
            }
        default: break
        }
    }

    func describe(_ m: MSMessage?) -> String {
        guard let m else { return "none" }
        let board = m.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first?.value } ?? "-"
        return "\((m.layout as? MSMessageTemplateLayout)?.caption ?? "-") board=\(board) pending=\(m.isPending)"
    }
    override func willBecomeActive(with conversation: MSConversation) {
        log("will become active \(presentationStyle == .expanded ? "expanded" : "compact") selected=\(describe(conversation.selectedMessage)) remote=\(conversation.remoteParticipantIdentifiers.count)")
        if let s = conversation.selectedMessage?.session { session = s }
    }
    override func didBecomeActive(with conversation: MSConversation) { log("did become active") }
    override func willResignActive(with conversation: MSConversation) { log("will resign active") }
    override func didResignActive(with conversation: MSConversation) { log("did resign active") }
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) { log("will transition \(presentationStyle == .expanded ? "expanded" : "compact")") }
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) { log("did transition \(presentationStyle == .expanded ? "expanded" : "compact")") }
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) { log("did start sending \(describe(message))") }
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) { log("did cancel sending \(describe(message))") }
    override func didSelect(_ message: MSMessage, conversation: MSConversation) { log("did select \(describe(message))") }
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        log("did receive \(describe(message)) same session=\(message.session == session) from remote=\(conversation.remoteParticipantIdentifiers.contains(message.senderParticipantIdentifier))")
    }
}
