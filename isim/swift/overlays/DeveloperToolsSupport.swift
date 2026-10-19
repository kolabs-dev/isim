// isim DeveloperToolsSupport overlay (self-authored): the types behind `#Preview`. The macro (isim's PreviewsMacros
// plugin, swift/macro-support/PreviewsMacros.swift) turns each `#Preview` into a type conforming to PreviewRegistry,
// like Xcode's. isim has no preview canvas: previews compile and type-check, their content can be built at run time
// (`_isimMakeContent`), and `isim preview` renders one (UIKit's preview mode). Re-exported by UIKit (and so SwiftUI).
// Also the asset catalog resources (`ImageResource`, `ColorResource`) that Xcode's generated asset symbols
// (GeneratedAssetSymbols.swift, which `isim build` generates too) name; UIKit and SwiftUI load them.
import CoreGraphics
import Foundation

/// One `#Preview`: its name, traits and content (a SwiftUI view, a UIView or a UIViewController).
public struct Preview {
    /// The traits of previews of views (orientation, layout).
    public struct ViewTraits {}

    public let name: String?
    public let traits: [PreviewTrait<ViewTraits>]
    let content: @MainActor () -> Any
    /// isim: makes a view controller showing the content (SwiftUI sets it for views; UIKit wraps UIViews itself)
    public var _isimController: (@MainActor () -> AnyObject)? = nil

    /// isim: what the `#Preview` expansions build (SwiftUI and UIKit add typed initializers).
    public init(_isimName name: String?, traits: [PreviewTrait<ViewTraits>], content: @escaping @MainActor () -> Any) {
        self.name = name; self.traits = traits; self.content = content
    }

    /// isim: builds the preview's content (the closure given to `#Preview`).
    @MainActor public func _isimMakeContent() -> Any { content() }
}

/// A preview trait (`.landscapeLeft`, `.sizeThatFitsLayout`, ...); `isim preview` applies the layouts.
public struct PreviewTrait<T> {
    public enum _Kind: Equatable {
        case orientation(String), sizeThatFitsLayout, defaultLayout, fixedLayout(width: CGFloat, height: CGFloat)
        /// several traits as one (`PreviewTrait(_:...)`), a SwiftUI PreviewModifier (`.modifier(_:)`, in `_isimPayload`)
        case combined, modifier
    }
    public let _kind: _Kind
    /// the traits of `.combined`, the modifier of `.modifier`
    public var _isimPayload: Any? = nil
    public init(_isimKind kind: _Kind) { _kind = kind }
    public init(_isimKind kind: _Kind, payload: Any?) { _kind = kind; _isimPayload = payload }
    /// One trait made of several (they apply in order).
    public init(_ traits: PreviewTrait<T>...) { _kind = .combined; _isimPayload = traits }
    /// isim: this trait and the ones it combines, in order
    public var _isimFlattened: [PreviewTrait<T>] {
        _kind == .combined ? ((_isimPayload as? [PreviewTrait<T>]) ?? []).flatMap(\._isimFlattened) : [self]
    }
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

// MARK: - Xcode's library (no library on isim: the items compile, nothing shows them)

/// A view or modifier offered in Xcode's library.
public struct LibraryItem {
    public struct Category: Equatable, Sendable {
        let id: Int
        public static let control = Category(id: 0), effect = Category(id: 1), layout = Category(id: 2), other = Category(id: 3)
    }
    public let title: String?
    public let category: Category
    public let isVisible: Bool
    public let matchingSignature: String?
    public init<SnippetExpressionType>(_ snippet: @autoclosure () -> SnippetExpressionType, visible: Bool = true, title: String? = nil,
                                       category: Category = .other, matchingSignature: String? = nil) {
        self.title = title; self.category = category; isVisible = visible; self.matchingSignature = matchingSignature
    }
}
@resultBuilder public struct LibraryContentBuilder {
    public static func buildBlock(_ segments: [LibraryItem]...) -> [LibraryItem] { segments.flatMap { $0 } }
    public static func buildExpression(_ expression: LibraryItem) -> [LibraryItem] { [expression] }
    public static func buildExpression(_ expression: [LibraryItem]) -> [LibraryItem] { expression }
}
/// The views and modifiers a module offers in Xcode's library.
public protocol LibraryContentProvider {
    associatedtype ModifierBase = Any
    @LibraryContentBuilder var views: [LibraryItem] { get }
    @LibraryContentBuilder func modifiers(base: ModifierBase) -> [LibraryItem]
}
extension LibraryContentProvider {
    public var views: [LibraryItem] { [] }
    public func modifiers(base: ModifierBase) -> [LibraryItem] { [] }
}

/// The body of a `#Preview` of UIKit views and view controllers: one expression of its content type (so a
/// SwiftUI body with several statements is not taken for one).
@resultBuilder public struct PreviewMacroBodyBuilder<Content> {
    public static func buildBlock(_ content: Content) -> Content { content }
}

/// What a `#Preview` expands to: where it is written and how to make it.
public protocol PreviewRegistry {
    static var fileID: String { get }
    static var line: Int { get }
    static var column: Int { get }
    @MainActor static func makePreview() throws -> Preview
}

// MARK: - Asset catalog resources (iOS 17; usable with older deployment targets, as Xcode 15+ generates them)

/// An image in an asset catalog: its name and the bundle holding the catalog. `UIImage(resource:)` and SwiftUI's
/// `Image(_:)` load it like `UIImage(named:in:with:)`.
public struct ImageResource: Hashable, @unchecked Sendable {      // (a Bundle does not change)
    /// isim: the asset's name and bundle (what UIKit and SwiftUI load)
    public let _isimName: String
    public let _isimBundle: Bundle
    public init(name: String, bundle: Bundle) { _isimName = name; _isimBundle = bundle }
}

/// A color in an asset catalog: its name and the bundle holding the catalog. `UIColor(resource:)` and SwiftUI's
/// `Color(_:)` load it like `UIColor(named:in:compatibleWith:)` (light, dark and high-contrast variants).
public struct ColorResource: Hashable, @unchecked Sendable {      // (a Bundle does not change)
    /// isim: the asset's name and bundle (what UIKit and SwiftUI load)
    public let _isimName: String
    public let _isimBundle: Bundle
    public init(name: String, bundle: Bundle) { _isimName = name; _isimBundle = bundle }
}
