// isim PassKit: PKAddPassesViewController (the "Add to Wallet" sheet: the passes drawn from their pass.json — style,
// colors, logo, fields, barcode — with Cancel and Add), PKAddPassButton and SwiftUI's AddPassToWalletButton.
// Adapted: the buttons say "Add to Apple Wallet" in words where iOS draws Apple's Wallet artwork (not shipped).
import Foundation
import UIKit
import SwiftUI
import CoreImage

public protocol PKAddPassesViewControllerDelegate: NSObjectProtocol {
    @MainActor func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController)
}
@MainActor public extension PKAddPassesViewControllerDelegate {
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) { controller.dismiss(animated: true) }
}

/// The sheet that shows passes and lets the person add them to Wallet.
@objc(PKAddPassesViewController) @objcMembers open class PKAddPassesViewController: UIViewController {
    open weak var delegate: (any PKAddPassesViewControllerDelegate)?
    let passes: [PKPass]

    open class func canAddPasses() -> Bool { true }

    public convenience init?(pass: PKPass) { self.init(passes: [pass]) }
    public init?(passes: [PKPass]) {
        guard !passes.isEmpty else { return nil }
        self.passes = passes
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    public convenience init?(passesData: [Data]) {
        let list = passesData.compactMap { try? PKPass(data: $0) }
        guard list.count == passesData.count else { return nil }
        self.init(passes: list)
    }
    /// a .pkpasses archive (a ZIP of .pkpass files)
    public convenience init?(passesArchiveData data: Data) { self.init(passesData: PKPassLibrary.archivePasses(data)) }
    public convenience init?(passesArchiveAt url: URL) {
        guard let d = try? Data(contentsOf: url) else { return nil }
        self.init(passesArchiveData: d)
    }
    public convenience init?(passesArchiveAtFileURL url: URL) { self.init(passesArchiveAt: url) }
    public required init?(coder: NSCoder) { return nil }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let inWallet = passes.allSatisfy { PKPassLibrary().containsPass($0) }
        let h = UIHostingController(rootView: _PKAddPassesView(passes: passes, inWallet: inWallet, cancel: { [weak self] in self?.finish(added: false) },
                                                               add: { [weak self] in self?.finish(added: true) }))
        addChild(h)
        h.view.frame = view.bounds
        h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        h.view.backgroundColor = .systemGroupedBackground
        view.addSubview(h.view)
        h.didMove(toParent: self)
        NSLog("isim PassKit: add passes sheet: %@", passes.map { "\($0.passTypeIdentifier) \($0.serialNumber)" }.joined(separator: ", "))
    }

    var finished = false, added = false
    func finish(added: Bool) {
        guard !finished else { return }
        finished = true; self.added = added
        if added { _ = _PKWalletStore.add(passes) } else { NSLog("isim PassKit: add passes sheet canceled") }
        if let d = delegate { d.addPassesViewControllerDidFinish(self) } else { dismiss(animated: true) }
    }
}

struct _PKAddPassesView: View {
    let passes: [PKPass]
    let inWallet: Bool
    let cancel: () -> Void, add: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: cancel) { Text("Cancel").font(.system(size: 17)) }.accessibilityIdentifier("pk-pass-cancel")
                Spacer()
                Text(passes.count == 1 ? passes[0].organizationName : "\(passes.count) Passes").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: add) { Text(inWallet ? "Update" : "Add").font(.system(size: 17, weight: .semibold)) }.accessibilityIdentifier("pk-pass-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(passes.enumerated()), id: \.offset) { _, p in _PKPassCard(pass: p) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
    }
}

/// A pass drawn like Wallet's front: logo and logo text, header fields, primary, secondary and auxiliary fields, barcode.
struct _PKPassCard: View {
    let pass: PKPass
    var bg: Color { Color(pass.color("backgroundColor") ?? UIColor(white: 0.95, alpha: 1)) }
    var fg: Color { Color(pass.color("foregroundColor") ?? .black) }
    var label: Color { Color(pass.color("labelColor") ?? UIColor(white: 0.35, alpha: 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                if let logo = pass.logo { Image(uiImage: logo).resizable().frame(width: min(120, logo.size.width * 50 / max(logo.size.height, 1)), height: 50) }
                if let t = pass.string("logoText") { Text(t).font(.system(size: 17, weight: .semibold)).foregroundColor(fg) }
                Spacer()
                ForEach(Array(pass.fields("headerFields").enumerated()), id: \.offset) { _, f in field(f, align: .trailing) }
            }
            ForEach(Array(pass.fields("primaryFields").enumerated()), id: \.offset) { _, f in
                VStack(alignment: .leading, spacing: 2) {
                    if let l = f.label { Text(l.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(label) }
                    Text(f.value).font(.system(size: 28, weight: .regular)).foregroundColor(fg).accessibilityIdentifier("pk-pass-\(f.key)")
                }
            }
            row(pass.fields("secondaryFields"))
            row(pass.fields("auxiliaryFields"))
            if let b = pass.barcode {
                VStack(spacing: 4) {
                    if let img = _PKBarcode.image(b.format, b.message) {
                        Image(uiImage: img).interpolation(.none).resizable().frame(width: b.format.contains("QR") || b.format.contains("Aztec") ? 130 : 220,
                                                              height: b.format.contains("QR") || b.format.contains("Aztec") ? 130 : 60)
                    }
                    if let alt = b.alt { Text(alt).font(.system(size: 12)).foregroundColor(.black) }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("pk-pass-barcode")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(bg))
        .accessibilityIdentifier("pk-pass-\(pass.serialNumber)")
    }

    func row(_ fields: [PKPass.Field]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(Array(fields.enumerated()), id: \.offset) { i, f in
                field(f, align: i == fields.count - 1 && fields.count > 1 ? .trailing : .leading)
                if i < fields.count - 1 { Spacer() }
            }
        }
    }
    func field(_ f: PKPass.Field, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            if let l = f.label { Text(l.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(label) }
            Text(f.value).font(.system(size: 15)).foregroundColor(fg).accessibilityIdentifier("pk-pass-\(f.key)")
        }
    }
}

enum _PKBarcode {
    /// the barcode as Wallet shows it, drawn with Core Image's generators
    static func image(_ format: String, _ message: String) -> UIImage? {
        let name: String
        switch format {
        case "PKBarcodeFormatQR": name = "CIQRCodeGenerator"
        case "PKBarcodeFormatPDF417": name = "CIPDF417BarcodeGenerator"
        case "PKBarcodeFormatAztec": name = "CIAztecCodeGenerator"
        case "PKBarcodeFormatCode128": name = "CICode128BarcodeGenerator"
        default: return nil
        }
        guard let f = CIFilter(name: name) else { return nil }
        f.setValue(Data(message.utf8), forKey: "inputMessage")
        guard let out = f.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Buttons

public enum PKAddPassButtonStyle: Int, Sendable {
    case black = 0, blackOutline
}

/// The "Add to Apple Wallet" button.
@objc(PKAddPassButton) @objcMembers open class PKAddPassButton: UIButton {
    open var addPassButtonStyle: PKAddPassButtonStyle { didSet { restyle() } }

    public init(addPassButtonStyle style: PKAddPassButtonStyle) {
        addPassButtonStyle = style
        super.init(frame: CGRect(x: 0, y: 0, width: 260, height: 48))
        setTitle("Add to Apple Wallet", for: .normal)
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        layer.cornerRadius = 8
        layer.masksToBounds = true
        accessibilityLabel = "Add to Apple Wallet"
        restyle()
    }
    public required init?(coder: NSCoder) {
        addPassButtonStyle = .black
        super.init(coder: coder)
    }
    func restyle() {
        backgroundColor = .black
        setTitleColor(.white, for: .normal)
        setTitleColor(UIColor(white: 1, alpha: 0.6), for: .highlighted)
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = addPassButtonStyle == .blackOutline ? 1 : 0
    }
    open override var intrinsicContentSize: CGSize { CGSize(width: 260, height: 48) }
}

/// The colors of an AddPassToWalletButton.
public struct AddPassToWalletButtonStyle: Equatable, Sendable {
    let outline: Bool
    public static let black = AddPassToWalletButtonStyle(outline: false)
    public static let blackOutline = AddPassToWalletButtonStyle(outline: true)
}
struct _PKAddPassStyleKey: EnvironmentKey { static let defaultValue = AddPassToWalletButtonStyle.black }
extension EnvironmentValues {
    var _pkAddPassStyle: AddPassToWalletButtonStyle { get { self[_PKAddPassStyleKey.self] } set { self[_PKAddPassStyleKey.self] = newValue } }
}
public extension View {
    func addPassToWalletButtonStyle(_ style: AddPassToWalletButtonStyle) -> some View { environment(\._pkAddPassStyle, style) }
}

/// The SwiftUI "Add to Apple Wallet" button: adds passes (showing them first, as iOS does), or runs an action.
public struct AddPassToWalletButton<Fallback: View>: View {
    let passes: [PKPass]?
    let action: (() -> Void)?
    let onCompletion: ((Bool) -> Void)?
    let fallback: Fallback?
    @Environment(\._pkAddPassStyle) var style

    public init(_ passes: [PKPass], onCompletion: @escaping (Bool) -> Void, @ViewBuilder fallback: () -> Fallback) {
        self.passes = passes; action = nil; self.onCompletion = onCompletion; self.fallback = fallback()
    }

    public var body: some View {
        if let fallback, !PKAddPassesViewController.canAddPasses() {
            fallback
        } else {
            Button(action: tapped) {
                Text("Add to Apple Wallet")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: style.outline ? 1 : 0))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to Apple Wallet")
        }
    }

    func tapped() {
        if let action { action(); return }
        guard let passes, let vc = PKAddPassesViewController(passes: passes), let top = _PKSheet.topController() else { onCompletion?(false); return }
        let d = _PKAddPassesButtonDelegate(passes: passes, onCompletion: onCompletion)
        d.retain = d
        vc.delegate = d
        top.present(vc, animated: true)
    }
}

public extension AddPassToWalletButton where Fallback == EmptyView {
    init(_ passes: [PKPass], onCompletion: @escaping (Bool) -> Void) {
        self.passes = passes; action = nil; self.onCompletion = onCompletion; fallback = nil
    }
    init(action: @escaping () -> Void) {
        passes = nil; self.action = action; onCompletion = nil; fallback = nil
    }
}

final class _PKAddPassesButtonDelegate: NSObject, PKAddPassesViewControllerDelegate {
    let passes: [PKPass]
    let onCompletion: ((Bool) -> Void)?
    var retain: _PKAddPassesButtonDelegate?
    init(passes: [PKPass], onCompletion: ((Bool) -> Void)?) { self.passes = passes; self.onCompletion = onCompletion }
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        let added = controller.added
        controller.dismiss(animated: true) { [self] in
            onCompletion?(added)
            retain = nil
        }
    }
}
