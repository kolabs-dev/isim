// isim SwiftUI: previews. `#Preview` (isim's PreviewsMacros plugin) and `PreviewProvider` compile and type-check like in
// Xcode; isim has no preview canvas, so the preview modifiers record nothing and change nothing (adapted).

@freestanding(declaration)
public macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>..., body: @escaping @MainActor () -> any View) =
    #externalMacro(module: "PreviewsMacros", type: "SwiftUIView")

extension Preview {
    public init(_isimView name: String?, traits: [PreviewTrait<ViewTraits>], body: @escaping @MainActor () -> any View) {
        self.init(_isimName: name, traits: traits, content: body)
    }
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
