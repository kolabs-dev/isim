// LocalAuthenticationView (SwiftUI, iOS 17): a button with the Face ID / Touch ID glyph that authenticates the device
// owner (biometry or the passcode) with the given reason, or, made with a context alone, the glyph for an evaluation the
// app runs on that context. The glyph turns blue while the scan runs, green on success.
import Foundation
import UIKit
@_spi(isim) import SwiftUI

public struct LocalAuthenticationView<Label: View>: View {
    let reason: Text?
    let context: LAContext?
    let result: ((Result<Void, any Error>) -> Void)?
    let label: Label
    @State private var phase = 0          // 0 idle, 1 scanning, 2 authenticated, 3 failed

    public init(reason: Text, context: LAContext? = nil, result: @escaping (Result<Void, any Error>) -> Void, @ViewBuilder label: () -> Label) {
        self.reason = reason; self.context = context; self.result = result; self.label = label()
    }
    public init(context: LAContext, @ViewBuilder label: () -> Label) {
        reason = nil; self.context = context; result = nil; self.label = label()
    }

    var glyph: String { _LADevice.biometry == .faceID ? "faceid" : "touchid" }
    var tint: Color { phase == 2 ? .green : phase == 3 ? .red : phase == 1 ? .blue : .primary }

    public var body: some View {
        Button(action: authenticate) {
            HStack(spacing: 10) {
                Image(systemName: glyph).font(.system(size: 22, weight: .regular)).foregroundStyle(tint)
                label
            }
            .padding(.horizontal, 16).frame(minHeight: 44)
        }
        .disabled(reason == nil || phase == 1)
        .accessibilityIdentifier("la-authentication-view")
        .onReceive(NotificationCenter.default.publisher(for: _LAEvaluation.name)) { n in   // the app's own evaluations of the context
            guard let context, (n.object as AnyObject?) === context, let p = n.userInfo?["phase"] as? Int else { return }
            phase = p
        }
    }

    func authenticate() {
        guard let reason else { return }
        let ctx = context ?? LAContext()
        phase = 1
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason._isimPlainString) { ok, error in
            DispatchQueue.main.async {
                phase = ok ? 2 : 3
                result?(ok ? .success(()) : .failure(error ?? LAError(.authenticationFailed)))
            }
        }
    }
}

extension LocalAuthenticationView where Label == SwiftUI.Label<Text, Image> {
    static func defaultLabel(_ title: Text) -> SwiftUI.Label<Text, Image> {
        SwiftUI.Label { title } icon: { Image(systemName: _LADevice.biometry == .faceID ? "faceid" : "touchid") }
    }
    public init<S: StringProtocol>(_ title: S, reason: Text, context: LAContext? = nil, result: @escaping (Result<Void, any Error>) -> Void) {
        self.init(reason: reason, context: context, result: result) { Self.defaultLabel(Text(title)) }
    }
    public init(_ titleKey: LocalizedStringKey, reason: Text, context: LAContext? = nil, result: @escaping (Result<Void, any Error>) -> Void) {
        self.init(reason: reason, context: context, result: result) { Self.defaultLabel(Text(titleKey)) }
    }
    public init(_ title: Text, reason: Text, context: LAContext? = nil, result: @escaping (Result<Void, any Error>) -> Void) {
        self.init(reason: reason, context: context, result: result) { Self.defaultLabel(title) }
    }
    public init(_ title: LocalizedStringResource, reason: Text, context: LAContext? = nil, result: @escaping (Result<Void, any Error>) -> Void) {
        self.init(reason: reason, context: context, result: result) { Self.defaultLabel(Text(title)) }
    }
    public init<S: StringProtocol>(_ title: S, context: LAContext) { self.init(context: context) { Self.defaultLabel(Text(title)) } }
    public init(_ titleKey: LocalizedStringKey, context: LAContext) { self.init(context: context) { Self.defaultLabel(Text(titleKey)) } }
    public init(_ title: LocalizedStringResource, context: LAContext) { self.init(context: context) { Self.defaultLabel(Text(title)) } }
}
