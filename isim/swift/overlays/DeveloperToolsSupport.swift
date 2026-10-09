// isim DeveloperToolsSupport overlay (self-authored): the types behind `#Preview`. The macro (isim's PreviewsMacros
// plugin, swift/macro-support/PreviewsMacros.swift) turns each `#Preview` into a type conforming to PreviewRegistry,
// like Xcode's. isim has no preview canvas: previews compile and type-check, and their content can be built at run time
// (`_isimMakeContent`), but nothing shows them by itself. Re-exported by UIKit (and so SwiftUI).
import CoreGraphics

/// One `#Preview`: its name, traits and content (a SwiftUI view, a UIView or a UIViewController).
public struct Preview {
    /// The traits of previews of views (orientation, layout).
    public struct ViewTraits {}

    public let name: String?
    public let traits: [PreviewTrait<ViewTraits>]
    let content: @MainActor () -> Any

    /// isim: what the `#Preview` expansions build (SwiftUI and UIKit add typed initializers).
    public init(_isimName name: String?, traits: [PreviewTrait<ViewTraits>], content: @escaping @MainActor () -> Any) {
        self.name = name; self.traits = traits; self.content = content
    }

    /// isim: builds the preview's content (the closure given to `#Preview`).
    @MainActor public func _isimMakeContent() -> Any { content() }
}

/// A preview trait (`.landscapeLeft`, `.sizeThatFitsLayout`, ...). isim records it; nothing renders previews.
public struct PreviewTrait<T> {
    public enum _Kind: Equatable {
        case orientation(String), sizeThatFitsLayout, defaultLayout, fixedLayout(width: CGFloat, height: CGFloat)
    }
    public let _kind: _Kind
    public init(_isimKind kind: _Kind) { _kind = kind }
}

extension PreviewTrait where T == Preview.ViewTraits {
    public static var portrait: PreviewTrait { PreviewTrait(_isimKind: .orientation("portrait")) }
    public static var portraitUpsideDown: PreviewTrait { PreviewTrait(_isimKind: .orientation("portraitUpsideDown")) }
    public static var landscapeLeft: PreviewTrait { PreviewTrait(_isimKind: .orientation("landscapeLeft")) }
    public static var landscapeRight: PreviewTrait { PreviewTrait(_isimKind: .orientation("landscapeRight")) }
    public static var sizeThatFitsLayout: PreviewTrait { PreviewTrait(_isimKind: .sizeThatFitsLayout) }
    public static var defaultLayout: PreviewTrait { PreviewTrait(_isimKind: .defaultLayout) }
    public static func fixedLayout(width: CGFloat, height: CGFloat) -> PreviewTrait {
        PreviewTrait(_isimKind: .fixedLayout(width: width, height: height))
    }
}

/// What a `#Preview` expands to: where it is written and how to make it.
public protocol PreviewRegistry {
    static var fileID: String { get }
    static var line: Int { get }
    static var column: Int { get }
    @MainActor static func makePreview() throws -> Preview
}
