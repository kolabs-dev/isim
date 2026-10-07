// isim MessageUI: MFMailComposeViewController and MFMessageComposeViewController.
//
// Like the Simulator, the device has no mail account and cannot send messages: canSendMail() and
// canSendText() are false, and presenting a composer then shows nothing (logged; the delegate is not called).
// ISIM_MAIL=1 / ISIM_MESSAGES=1 give the device an account: the composers show iOS 17-style sheets (Cancel,
// To/Cc/Bcc/Subject fields or the Messages recipient row, body, Send). Nothing leaves the machine: a sent mail
// is written to $ISIM_DATA/Library/Mail/Outbox/<n>.eml (saved drafts: Mail/Drafts) and a sent message to $ISIM_DATA/Library/SMS/Outbox/<n>.json.
import UIKit

@objc public protocol MFMailComposeViewControllerDelegate: NSObjectProtocol {
    @MainActor @objc optional func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
}
@objc public protocol MFMessageComposeViewControllerDelegate: NSObjectProtocol {
    @MainActor func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult)
}

@objc public enum MFMailComposeResult: Int, Sendable { case cancelled = 0, saved, sent, failed }
@objc public enum MessageComposeResult: Int, Sendable { case cancelled = 0, sent, failed }

public let MFMailComposeErrorDomain = "MFMailComposeErrorDomain"
public struct MFMailComposeError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case saveFailed = 0, sendFailed }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { MFMailComposeErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var saveFailed: Code { .saveFailed }
    public static var sendFailed: Code { .sendFailed }
}

public extension Notification.Name {
    static let MFMessageComposeViewControllerTextMessageAvailabilityDidChange = Notification.Name("MFMessageComposeViewControllerTextMessageAvailabilityDidChangeNotification")
}
public let MFMessageComposeViewControllerTextMessageAvailabilityKey = "MFMessageComposeViewControllerTextMessageAvailabilityKey"
public let MFMessageComposeViewControllerAttachmentURL = "MFMessageComposeViewControllerAttachmentURL"
public let MFMessageComposeViewControllerAttachmentAlternateFilename = "MFMessageComposeViewControllerAttachmentAlternateFilename"

enum _MFDevice {
    static func enabled(_ key: String) -> Bool { ProcessInfo.processInfo.environment[key] == "1" }
    static func outbox(_ sub: String) -> URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? (NSHomeDirectory() as NSString).appendingPathComponent(".local/share/isim")
        let dir = URL(fileURLWithPath: data).appendingPathComponent("Library").appendingPathComponent(sub)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    static func nextFile(_ dir: URL, _ ext: String) -> URL {
        let n = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).count + 1
        return dir.appendingPathComponent("\(n).\(ext)")
    }
}

/// a "To:"-style row: grey label, editable text field, hairline below
@MainActor final class _MFFieldRow: UIView {
    let label = UILabel(), field = UITextField(), line = UIView()
    init(_ title: String, id: String) {
        super.init(frame: .zero)
        label.text = title; label.textColor = .secondaryLabel; label.font = .systemFont(ofSize: 16)
        field.font = .systemFont(ofSize: 16); field.accessibilityIdentifier = id
        field.autocapitalizationType = .none
        line.backgroundColor = .separator
        for v in [label, field, line] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16), label.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 6), field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            field.centerYAnchor.constraint(equalTo: centerYAnchor), field.heightAnchor.constraint(equalToConstant: 36),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16), line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor), line.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        label.setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// a plain tinted text button for the navigation bar (with an accessibility identifier)
@MainActor final class _MFBarTextButton: UIButton {
    convenience init(_ title: String, id: String, target: Any, action: Selector) {
        self.init(type: .system)
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 17)
        accessibilityIdentifier = id
        addTarget(target, action: action, for: .touchUpInside)
        frame = CGRect(x: 0, y: 0, width: 64, height: 32)
    }
}

/// a round arrow-up "Send" button, iOS 17 Mail/Messages style
@MainActor final class _MFSendButton: UIControl {
    var color: UIColor = .systemBlue { didSet { setNeedsDisplay() } }
    override var isEnabled: Bool { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let s = min(bounds.width, bounds.height), r = CGRect(x: bounds.midX - s / 2, y: bounds.midY - s / 2, width: s, height: s)
        (isEnabled ? color : UIColor.systemGray3).setFill()
        UIBezierPath(ovalIn: r).fill()
        UIColor.white.setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: r.midX, y: r.minY + s * 0.26)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY - s * 0.24))
        p.move(to: CGPoint(x: r.midX - s * 0.2, y: r.minY + s * 0.44)); p.addLine(to: CGPoint(x: r.midX, y: r.minY + s * 0.25))
        p.addLine(to: CGPoint(x: r.midX + s * 0.2, y: r.minY + s * 0.44))
        p.lineWidth = s * 0.09; p.stroke()
    }
}

// MARK: - Mail

@MainActor
open class MFMailComposeViewController: UINavigationController {
    open weak var mailComposeDelegate: MFMailComposeViewControllerDelegate?
    open class func canSendMail() -> Bool { _MFDevice.enabled("ISIM_MAIL") }
    var to: [String] = [], cc: [String] = [], bcc: [String] = [], subject = "", body = "", isHTML = false, from: String?
    var attachments: [(Data, String, String)] = []
    let editor = _MFMailEditor()

    public init() {
        super.init(nibName: nil, bundle: nil)
        editor.owner = self
        viewControllers = [editor]
        modalPresentationStyle = .pageSheet
        if !MFMailComposeViewController.canSendMail() {
            print("isim: MFMailComposeViewController: this device has no mail account (canSendMail() is false, like the Simulator; ISIM_MAIL=1 adds one)")
        }
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil) }
    open func setSubject(_ subject: String) { self.subject = subject }
    open func setToRecipients(_ toRecipients: [String]?) { to = toRecipients ?? [] }
    open func setCcRecipients(_ ccRecipients: [String]?) { cc = ccRecipients ?? [] }
    open func setBccRecipients(_ bccRecipients: [String]?) { bcc = bccRecipients ?? [] }
    open func setMessageBody(_ body: String, isHTML: Bool) { self.body = body; self.isHTML = isHTML }
    open func addAttachmentData(_ attachment: Data, mimeType: String, fileName filename: String) { attachments.append((attachment, mimeType, filename)) }
    open func setPreferredSendingEmailAddress(_ emailAddress: String) { from = emailAddress }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !MFMailComposeViewController.canSendMail() {    /* like presenting a nil composer on the Simulator: nothing to show */
            print("isim: MFMailComposeViewController presented without a mail account; dismissing")
            dismiss(animated: false)
        }
    }

    func finish(_ r: MFMailComposeResult, _ e: Error? = nil) {
        print("isim: mail compose finished: \(["cancelled", "saved", "sent", "failed"][r.rawValue])")
        if let d = mailComposeDelegate, d.responds(to: #selector(MFMailComposeViewControllerDelegate.mailComposeController(_:didFinishWith:error:))) {
            d.mailComposeController?(self, didFinishWith: r, error: e)
        } else { dismiss(animated: true) }    /* iOS: without a delegate the composer stays up; dismissing is friendlier */
    }

    func eml(draft: Bool) -> String {
        func list(_ a: [String]) -> String { a.joined(separator: ", ") }
        var s = "From: \(from ?? "Me <me@isim.local>")\r\nTo: \(list(to))\r\n"
        if !cc.isEmpty { s += "Cc: \(list(cc))\r\n" }
        if !bcc.isEmpty { s += "Bcc: \(list(bcc))\r\n" }
        s += "Subject: \(subject)\r\nX-Mailer: isim MessageUI\(draft ? " (draft)" : "")\r\nMIME-Version: 1.0\r\n"
        let ctype = isHTML ? "text/html" : "text/plain"
        if attachments.isEmpty {
            s += "Content-Type: \(ctype); charset=utf-8\r\n\r\n\(body)\r\n"
        } else {
            let b = "isim-boundary"
            s += "Content-Type: multipart/mixed; boundary=\"\(b)\"\r\n\r\n--\(b)\r\nContent-Type: \(ctype); charset=utf-8\r\n\r\n\(body)\r\n"
            for (d, mime, name) in attachments {
                s += "--\(b)\r\nContent-Type: \(mime); name=\"\(name)\"\r\nContent-Disposition: attachment; filename=\"\(name)\"\r\nContent-Transfer-Encoding: base64\r\n\r\n\(d.base64EncodedString())\r\n"
            }
            s += "--\(b)--\r\n"
        }
        return s
    }
}

@MainActor final class _MFMailEditor: UIViewController {
    weak var owner: MFMailComposeViewController?
    let toRow = _MFFieldRow("To:", id: "mail-to"), ccRow = _MFFieldRow("Cc/Bcc, From:", id: "mail-cc"), subjectRow = _MFFieldRow("Subject:", id: "mail-subject")
    let bodyView = UITextView()
    let send = _MFSendButton(frame: .zero)
    let attachmentsLabel = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        guard let o = owner else { return }
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: _MFBarTextButton("Cancel", id: "mail-cancel", target: self, action: #selector(cancel)))
        send.accessibilityIdentifier = "mail-send"
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        send.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: send)
        toRow.field.keyboardType = .emailAddress
        subjectRow.field.addTarget(self, action: #selector(subjectChanged), for: .editingChanged)
        toRow.field.addTarget(self, action: #selector(validate), for: .editingChanged)
        bodyView.font = .systemFont(ofSize: 16)
        bodyView.accessibilityIdentifier = "mail-body"
        attachmentsLabel.font = .systemFont(ofSize: 13); attachmentsLabel.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [toRow, ccRow, subjectRow])
        stack.axis = .vertical
        for v in [stack, bodyView, attachmentsLabel] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: g.topAnchor), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bodyView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 8), bodyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bodyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), bodyView.heightAnchor.constraint(equalToConstant: 200),
            attachmentsLabel.topAnchor.constraint(equalTo: bodyView.bottomAnchor, constant: 8), attachmentsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])
        _ = o
    }
    var filled = false
    /* the app configures the composer after creating it: show its values when the sheet appears */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !filled, let o = owner else { return }
        filled = true
        title = o.subject.isEmpty ? "New Message" : o.subject
        toRow.field.text = o.to.joined(separator: ", ")
        ccRow.field.text = (o.cc + o.bcc).joined(separator: ", ")
        subjectRow.field.text = o.subject
        bodyView.text = o.isHTML ? o.body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) : o.body
        attachmentsLabel.text = o.attachments.isEmpty ? nil : "📎 " + o.attachments.map(\.2).joined(separator: ", ")
        validate()
    }
    @objc func subjectChanged() { title = (subjectRow.field.text ?? "").isEmpty ? "New Message" : subjectRow.field.text }
    @objc func validate() { send.isEnabled = !(toRow.field.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    func collect() {
        guard let o = owner else { return }
        func split(_ s: String?) -> [String] { (s ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        o.to = split(toRow.field.text)
        let ccs = split(ccRow.field.text); o.cc = ccs.filter { !o.bcc.contains($0) }
        o.subject = subjectRow.field.text ?? ""
        if !o.isHTML { o.body = bodyView.text ?? "" }
    }
    @objc func cancel() {
        view.endEditing(true)
        let a = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        a.addAction(UIAlertAction(title: "Delete Draft", style: .destructive) { [weak self] _ in self?.owner?.finish(.cancelled) })
        a.addAction(UIAlertAction(title: "Save Draft", style: .default) { [weak self] _ in
            guard let self, let o = self.owner else { return }
            self.collect()
            let f = _MFDevice.nextFile(_MFDevice.outbox("Mail/Drafts"), "eml")
            try? o.eml(draft: true).write(to: f, atomically: true, encoding: .utf8)
            o.finish(.saved)
        })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }
    @objc func sendTapped() {
        guard let o = owner else { return }
        view.endEditing(true)
        collect()
        let f = _MFDevice.nextFile(_MFDevice.outbox("Mail/Outbox"), "eml")
        do {
            try o.eml(draft: false).write(to: f, atomically: true, encoding: .utf8)
            print("isim: mail queued in \(f.path) (not sent anywhere)")
            o.finish(.sent)
        } catch { o.finish(.failed, MFMailComposeError(.sendFailed)) }
    }
}

// MARK: - Messages

@MainActor
open class MFMessageComposeViewController: UINavigationController {
    open weak var messageComposeDelegate: MFMessageComposeViewControllerDelegate?
    open var recipients: [String]?
    open var body: String?
    open var subject: String?
    open var message: AnyObject?
    var attachments: [(Data, String, String)] = []
    open class func canSendText() -> Bool { _MFDevice.enabled("ISIM_MESSAGES") }
    open class func canSendSubject() -> Bool { false }
    open class func canSendAttachments() -> Bool { canSendText() }
    open class func isSupportedAttachmentUTI(_ uti: String) -> Bool { canSendText() }
    open func disableUserAttachments() {}
    @discardableResult open func addAttachmentData(_ attachmentData: Data, typeIdentifier uti: String, filename: String) -> Bool {
        attachments.append((attachmentData, uti, filename)); return MFMessageComposeViewController.canSendAttachments()
    }
    @discardableResult open func addAttachmentURL(_ attachmentURL: URL, withAlternateFilename alternateFilename: String?) -> Bool {
        guard let d = try? Data(contentsOf: attachmentURL) else { return false }
        attachments.append((d, "public.data", alternateFilename ?? attachmentURL.lastPathComponent)); return MFMessageComposeViewController.canSendAttachments()
    }
    open var attachmentsList: [[String: Any]]? { attachments.map { [MFMessageComposeViewControllerAttachmentAlternateFilename: $0.2] } }
    let editor = _MFMessageEditor()
    public init() {
        super.init(nibName: nil, bundle: nil)
        editor.owner = self
        viewControllers = [editor]
        modalPresentationStyle = .pageSheet
        if !MFMessageComposeViewController.canSendText() {
            print("isim: MFMessageComposeViewController: this device cannot send messages (canSendText() is false, like the Simulator; ISIM_MESSAGES=1 enables it)")
        }
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil) }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !MFMessageComposeViewController.canSendText() {
            print("isim: MFMessageComposeViewController presented on a device that cannot send messages; dismissing")
            dismiss(animated: false)
        }
    }
    func finish(_ r: MessageComposeResult) {
        print("isim: message compose finished: \(["cancelled", "sent", "failed"][r.rawValue])")
        if let d = messageComposeDelegate { d.messageComposeViewController(self, didFinishWith: r) } else { dismiss(animated: true) }
    }
}

@MainActor final class _MFMessageEditor: UIViewController {
    weak var owner: MFMessageComposeViewController?
    let toRow = _MFFieldRow("To:", id: "message-to")
    let input = UITextField()
    let send = _MFSendButton(frame: .zero)
    let bubble = UIView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Message"
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: _MFBarTextButton("Cancel", id: "message-cancel", target: self, action: #selector(cancel)))
        toRow.field.keyboardType = .phonePad
        input.placeholder = "iMessage"
        input.font = .systemFont(ofSize: 17)
        input.accessibilityIdentifier = "message-body"
        input.addTarget(self, action: #selector(validate), for: .editingChanged)
        bubble.layer.cornerRadius = 18
        bubble.layer.borderWidth = 1
        bubble.layer.borderColor = UIColor.systemGray4.cgColor
        send.color = .systemGreen
        send.accessibilityIdentifier = "message-send"
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        for v in [toRow, bubble, input, send] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toRow.topAnchor.constraint(equalTo: g.topAnchor), toRow.leadingAnchor.constraint(equalTo: view.leadingAnchor), toRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bubble.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), bubble.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bubble.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8), bubble.heightAnchor.constraint(equalToConstant: 36),
            input.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14), input.trailingAnchor.constraint(equalTo: send.leadingAnchor, constant: -6),
            input.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
            send.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -4), send.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
            send.widthAnchor.constraint(equalToConstant: 28), send.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
    var filled = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !filled, let o = owner else { return }
        filled = true
        toRow.field.text = (o.recipients ?? []).joined(separator: ", ")
        input.text = o.body
        validate()
    }
    @objc func validate() {
        send.isEnabled = !(input.text ?? "").isEmpty || !(owner?.attachments.isEmpty ?? true)
        // iMessage-style: a phone number or address in "To:" sends as iMessage, plain text otherwise
        send.color = (toRow.field.text ?? "").contains("@") ? .systemBlue : .systemGreen
    }
    @objc func cancel() { view.endEditing(true); owner?.finish(.cancelled) }
    @objc func sendTapped() {
        guard let o = owner else { return }
        view.endEditing(true)
        o.recipients = (toRow.field.text ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        o.body = input.text
        let f = _MFDevice.nextFile(_MFDevice.outbox("SMS/Outbox"), "json")
        let rec: [String: Any] = ["recipients": o.recipients ?? [], "body": o.body ?? "", "attachments": o.attachments.map(\.2)]
        if let d = try? JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys]), (try? d.write(to: f)) != nil {
            print("isim: message queued in \(f.path) (not sent anywhere)")
            o.finish(.sent)
        } else { o.finish(.failed) }
    }
}
