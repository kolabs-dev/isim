// The Sign in with Apple buttons (UIKit ASAuthorizationAppleIDButton, SwiftUI SignInWithAppleButton) in the
// iOS look: black / white / white-outline, logo + "Sign in with Apple" / "Continue with Apple" / "Sign up with Apple".
// The logo is isim's own vector approximation, drawn at run time.
import Foundation
import UIKit
import SwiftUI

/// the logo outline in a 100 x 120 box: (start, [curves (c1, c2, end)]) per closed shape
enum _ASLogo {
    typealias P = (CGFloat, CGFloat)
    static let shapes: [(P, [(P, P, P)])] = [
        ((50, 33), [((58, 27), (72, 24), (82, 30)), ((87, 33), (90, 37), (92, 40)), ((79, 48), (77, 67), (95, 77)),
                    ((90, 92), (81, 110), (70, 112)), ((62, 114), (58, 108), (50, 108)), ((42, 108), (38, 114), (30, 112)),
                    ((17, 110), (4, 88), (4, 66)), ((4, 42), (20, 28), (35, 28)), ((41, 28), (45, 32), (50, 33))]),
        ((50, 26), [((50, 14), (58, 4), (70, 2)), ((70, 14), (62, 24), (50, 26))]),
    ]
    static let aspect: CGFloat = 100.0 / 120.0
    static func path(in r: CGRect) -> UIBezierPath {
        let p = UIBezierPath()
        let s = min(r.width / 100, r.height / 120)
        let ox = r.midX - 50 * s, oy = r.midY - 60 * s
        func pt(_ q: P) -> CGPoint { CGPoint(x: ox + q.0 * s, y: oy + q.1 * s) }
        for (start, curves) in shapes {
            p.move(to: pt(start))
            for c in curves { p.addCurve(to: pt(c.2), controlPoint1: pt(c.0), controlPoint2: pt(c.1)) }
            p.close()
        }
        return p
    }
}

final class _ASLogoView: UIView {
    var color: UIColor = .white { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        color.setFill()
        _ASLogo.path(in: bounds).fill()
    }
}

open class ASAuthorizationAppleIDButton: UIControl {
    public struct ButtonType: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let signIn = ButtonType(rawValue: 0)
        public static let `continue` = ButtonType(rawValue: 1)
        public static let signUp = ButtonType(rawValue: 2)
        public static let `default` = signIn
        var title: String { [1: "Continue with Apple", 2: "Sign up with Apple"][rawValue] ?? "Sign in with Apple" }
    }
    public enum Style: Int, Sendable { case white = 0, whiteOutline = 1, black = 2 }

    private let label = UILabel()
    private let logo = _ASLogoView(frame: .zero)
    private let type: ButtonType, style: Style
    open var cornerRadius: CGFloat = 6 { didSet { layer.cornerRadius = cornerRadius } }

    public init(authorizationButtonType type: ButtonType, authorizationButtonStyle style: Style) {
        self.type = type; self.style = style
        super.init(frame: CGRect(x: 0, y: 0, width: 260, height: 44))
        let fg: UIColor = style == .black ? .white : .black
        backgroundColor = style == .black ? .black : .white
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        if style == .whiteOutline { layer.borderWidth = 1; layer.borderColor = UIColor.black.cgColor }
        label.text = type.title
        label.textColor = fg
        label.textAlignment = .left
        logo.color = fg
        addSubview(logo); addSubview(label)
        isAccessibilityElement = true
        accessibilityLabel = type.title
    }
    public convenience init() { self.init(authorizationButtonType: .default, authorizationButtonStyle: .black) }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported on isim") }

    open override var intrinsicContentSize: CGSize { CGSize(width: 260, height: 44) }
    open override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        label.font = .systemFont(ofSize: max(12, round(h * 0.4)), weight: .medium)
        label.sizeToFit()
        let lh = round(h * 0.38), lw = round(lh * _ASLogo.aspect), gap = round(h * 0.1)
        let total = lw + gap + label.bounds.width
        let x0 = round((bounds.width - total) / 2)
        logo.frame = CGRect(x: x0, y: round((h - lh) / 2) - round(h * 0.02), width: lw, height: lh)
        label.frame = CGRect(x: x0 + lw + gap, y: round((h - label.bounds.height) / 2), width: label.bounds.width + 8, height: label.bounds.height)
    }
    open override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }
}

// MARK: - SwiftUI

struct _ASLogoShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width / 100, r.height / 120)
        let ox = r.midX - 50 * s, oy = r.midY - 60 * s
        func pt(_ q: _ASLogo.P) -> CGPoint { CGPoint(x: ox + q.0 * s, y: oy + q.1 * s) }
        for (start, curves) in _ASLogo.shapes {
            p.move(to: pt(start))
            for c in curves { p.addCurve(to: pt(c.2), control1: pt(c.0), control2: pt(c.1)) }
            p.closeSubpath()
        }
        return p
    }
}

public struct SignInWithAppleButton: View {
    public enum Label: Sendable { case signIn, `continue`, signUp
        var title: String { switch self { case .signIn: "Sign in with Apple"; case .continue: "Continue with Apple"; case .signUp: "Sign up with Apple" } }
    }
    public struct Style: Equatable, Sendable {
        let kind: Int
        public static let black = Style(kind: 2)
        public static let white = Style(kind: 0)
        public static let whiteOutline = Style(kind: 1)
    }
    let label: Label
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    @Environment(\._asSignInWithAppleStyle) var style

    public init(_ label: Label = .signIn, onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void, onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.label = label; self.onRequest = onRequest; self.onCompletion = onCompletion
    }

    public var body: some View {
        let fg: Color = style == .black ? .white : .black
        let bg: Color = style == .black ? .black : .white
        Button(action: start) {
            HStack(spacing: 5) {
                _ASLogoShape().fill(fg).frame(width: 14, height: 17).offset(y: -1)
                Text(verbatim: label.title).font(.system(size: 18, weight: .medium)).foregroundStyle(fg).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 30, maxHeight: .infinity)
            .background(bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(style == .whiteOutline ? Color.black : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label.title))
    }

    func start() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        onRequest(request)
        let c = ASAuthorizationController(authorizationRequests: [request])
        let d = _ASButtonDelegate(onCompletion)
        c.delegate = d
        _ASButtonDelegate.live.append(d)
        c.performRequests()
    }
}

final class _ASButtonDelegate: NSObject, ASAuthorizationControllerDelegate {
    nonisolated(unsafe) static var live: [_ASButtonDelegate] = []
    let done: (Result<ASAuthorization, Error>) -> Void
    init(_ done: @escaping (Result<ASAuthorization, Error>) -> Void) { self.done = done }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        done(.success(authorization)); _ASButtonDelegate.live.removeAll { $0 === self }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        done(.failure(error)); _ASButtonDelegate.live.removeAll { $0 === self }
    }
}

struct _ASSignInWithAppleStyleKey: EnvironmentKey { static let defaultValue = SignInWithAppleButton.Style.black }
extension EnvironmentValues {
    var _asSignInWithAppleStyle: SignInWithAppleButton.Style {
        get { self[_ASSignInWithAppleStyleKey.self] }
        set { self[_ASSignInWithAppleStyleKey.self] = newValue }
    }
}
extension View {
    public func signInWithAppleButtonStyle(_ style: SignInWithAppleButton.Style) -> some View {
        environment(\._asSignInWithAppleStyle, style)
    }
}
