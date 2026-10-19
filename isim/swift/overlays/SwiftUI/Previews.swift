// isim SwiftUI: previews. `#Preview` (isim's PreviewsMacros plugin) and `PreviewProvider` compile and type-check like in
// Xcode; `isim preview APP [NAME]` renders a `#Preview` to a screenshot (UIKit's preview mode); the PreviewProvider
// modifiers record nothing and change nothing (adapted: isim has no canvas). `@Previewable` state and PreviewModifier
// traits work in `isim preview`.

import UIKit

@freestanding(declaration)
public macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>..., @ViewBuilder body: @escaping @MainActor () -> any View) =
    #externalMacro(module: "PreviewsMacros", type: "SwiftUIView")

/// Lets a #Preview declare the state its content uses: `@Previewable @State var on = true` in the preview's body.
/// The #Preview expansion moves those declarations into a view that wraps the rest of the body.
@attached(peer)
public macro Previewable() = #externalMacro(module: "PreviewsMacros", type: "PreviewableMacro")

extension Preview {
    public init(_isimView name: String?, traits: [PreviewTrait<ViewTraits>], @ViewBuilder body: @escaping @MainActor () -> any View) {
        self.init(_isimName: name, traits: traits, content: body)
        let modifiers = traits.flatMap(\._isimFlattened).compactMap { $0._isimPayload as? _AnyPreviewModifier }
        _isimController = { modifiers.isEmpty ? _SUIHostingController(root: body) : _previewModified(body, modifiers) }
    }
}

// MARK: - PreviewModifier

/// Wraps previews in shared setup: `makeSharedContext()` runs once per modifier type for all the previews that use it;
/// `body(content:context:)` wraps each preview's content (`#Preview(traits: .modifier(SampleData()))`).
@available(iOS 18.0, *)
@MainActor @preconcurrency public protocol PreviewModifier {
    associatedtype Context = Void
    associatedtype Body: View
    typealias Content = PreviewModifierContent
    static func makeSharedContext() async throws -> Context
    @ViewBuilder func body(content: Content, context: Context) -> Body
}
@available(iOS 18.0, *)
extension PreviewModifier where Context == Void {
    public static func makeSharedContext() async throws -> Void {}
}
/// The content a PreviewModifier wraps.
@available(iOS 18.0, *)
public struct PreviewModifierContent: View, _PrimitiveView {
    let content: AnyView
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _resolve(content, ctx.child("pmc")) }
}
@available(iOS 18.0, *)
extension PreviewTrait where T == Preview.ViewTraits {
    /// Wraps the preview's content in `modifier` (with its shared context).
    public static func modifier(_ modifier: some PreviewModifier) -> PreviewTrait<T> {
        PreviewTrait(_isimKind: .modifier, payload: _PreviewModifierBox(modifier))
    }
}
protocol _AnyPreviewModifier { @MainActor func wrap(_ content: AnyView) async throws -> AnyView }
/// A modifier and its type's shared context (made once, for every preview using the type).
@available(iOS 18.0, *)
struct _PreviewModifierBox<M: PreviewModifier>: _AnyPreviewModifier {
    let modifier: M
    init(_ m: M) { modifier = m }
    @MainActor static var contexts: [ObjectIdentifier: Any] { get { _previewContexts } set { _previewContexts = newValue } }
    @MainActor func wrap(_ content: AnyView) async throws -> AnyView {
        let key = ObjectIdentifier(M.self)
        let context: M.Context
        if let c = Self.contexts[key] as? M.Context { context = c }
        else { context = try await M.makeSharedContext(); Self.contexts[key] = context }
        return AnyView(modifier.body(content: PreviewModifierContent(content: content), context: context))
    }
}
@MainActor var _previewContexts: [ObjectIdentifier: Any] = [:]
/// The preview's content once its modifiers (outermost first) have their contexts.
@MainActor func _previewModified(_ body: @escaping @MainActor () -> any View, _ modifiers: [any _AnyPreviewModifier]) -> UIViewController {
    final class Box { var view: AnyView? }
    let box = Box()
    let host = _SUIHostingController(root: { box.view ?? AnyView(EmptyView()) })
    Task { @MainActor in
        var v = AnyView(body())
        do {
            for m in modifiers.reversed() { v = try await m.wrap(v) }
        } catch { NSLog("isim: preview modifier failed: %@", "\(error)") }
        box.view = v
        host.graph.invalidate()
    }
    return host
}

/// The platform a `PreviewProvider` previews on.
public enum PreviewPlatform: Sendable { case iOS, macOS, tvOS, watchOS, visionOS }

/// Xcode's previews before `#Preview`: a type whose `previews` are shown by the canvas (not on isim).
@MainActor @preconcurrency
public protocol PreviewProvider {
    associatedtype Previews: View
    @ViewBuilder static var previews: Previews { get }
    static var platform: PreviewPlatform? { get }
}
extension PreviewProvider {
    public static var platform: PreviewPlatform? { nil }
}

/// A device for `previewDevice(_:)` (by name, like "iPhone 15 Pro").
public struct PreviewDevice: RawRepresentable, ExpressibleByStringLiteral, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
}

/// The layout of a preview.
public enum PreviewLayout: Sendable {
    case device, sizeThatFits
    case fixed(width: CGFloat, height: CGFloat)
}

/// The orientation of a preview's interface.
public struct InterfaceOrientation: CaseIterable, Identifiable, Equatable, Sendable {
    public let id: String
    public static let portrait = InterfaceOrientation(id: "portrait")
    public static let portraitUpsideDown = InterfaceOrientation(id: "portraitUpsideDown")
    public static let landscapeLeft = InterfaceOrientation(id: "landscapeLeft")
    public static let landscapeRight = InterfaceOrientation(id: "landscapeRight")
    public static var allCases: [InterfaceOrientation] { [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight] }
}

extension View {
    /// isim: no preview canvas; the view is unchanged.
    public func previewDevice(_ value: PreviewDevice?) -> some View { self }
    /// isim: no preview canvas; the view is unchanged.
    public func previewDisplayName(_ value: String?) -> some View { self }
    /// isim: no preview canvas; the view is unchanged.
    public func previewLayout(_ value: PreviewLayout) -> some View { self }
    /// isim: no preview canvas; the view is unchanged.
    public func previewInterfaceOrientation(_ value: InterfaceOrientation) -> some View { self }
}
