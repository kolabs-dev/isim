// isim Image Playground (self-authored, Apple's API names): ImagePlaygroundViewController, the SwiftUI sheet,
// ImageCreator and their concepts, styles and options. Apple's image model is part of Apple Intelligence; isim has
// none (a host backend, stable-diffusion.cpp, is possible later), so Image Playground is unavailable, honestly:
// ImagePlaygroundViewController.isAvailable and the supportsImagePlayground environment value are false, ImageCreator
// throws .notSupported on devices without Apple Intelligence and .unavailable on the others, and the controller and
// the sheet, if presented anyway, say Image Playground is unavailable and end as a cancellation.
import Foundation
import UIKit
import SwiftUI
import CoreGraphics
import PencilKit

/// whether the device could run Apple Intelligence (the iPhone 15 Pro and later, iPads with an M chip or the A17 Pro)
enum _IsimImagePlayground {
    static var deviceIsEligible: Bool {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iPhone17,1"
        func ver(_ p: String) -> (Int, Int)? {
            guard model.hasPrefix(p) else { return nil }
            let parts = model.dropFirst(p.count).split(separator: ",").compactMap { Int($0) }
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }
        if let (a, b) = ver("iPhone") { return a > 16 || (a == 16 && b >= 1) }
        if let (a, b) = ver("iPad") { return a >= 16 || (a == 14 && b >= 8) || (a == 13 && b >= 4) }
        return false
    }
    static let title = "Image Playground Unavailable"
    static var message: String {
        deviceIsEligible ? "Image Playground needs an image model, and this simulated device has none."
                         : "Image Playground needs Apple Intelligence, which this device does not support."
    }
}

// MARK: - concepts, styles, options

/// A style of image.
@available(iOS 18.1, *)
public struct ImagePlaygroundStyle: Hashable, Sendable, Identifiable {
    public let id: String
    public static let animation = ImagePlaygroundStyle(id: "animation")
    public static let illustration = ImagePlaygroundStyle(id: "illustration")
    public static let sketch = ImagePlaygroundStyle(id: "sketch")
    @available(iOS 18.4, *) public static let emoji = ImagePlaygroundStyle(id: "emoji")
    @available(iOS 26.0, *) public static let externalProvider = ImagePlaygroundStyle(id: "externalProvider")
    @available(iOS 27.0, *) public static let any = ImagePlaygroundStyle(id: "any")
    /// the image styles (animation, illustration, sketch)
    @available(iOS 18.4, *) public static var all: [ImagePlaygroundStyle] { [.animation, .illustration, .sketch] }
}

/// What an image shows: text, text to extract ideas from, a drawing or an image.
@available(iOS 18.1, *)
public struct ImagePlaygroundConcept: Sendable {
    enum Kind: @unchecked Sendable { case text(String), extracted(String, String?), drawing(PKDrawing), image(CGImage) }
    let kind: Kind
    public static func text(_ text: String) -> ImagePlaygroundConcept { ImagePlaygroundConcept(kind: .text(text)) }
    public static func extracted(from text: String, title: String? = nil) -> ImagePlaygroundConcept { ImagePlaygroundConcept(kind: .extracted(text, title)) }
    @available(iOS 18.4, *) public static func drawing(_ drawing: PKDrawing) -> ImagePlaygroundConcept { ImagePlaygroundConcept(kind: .drawing(drawing)) }
    @available(iOS 18.4, *) public static func image(_ image: CGImage) -> ImagePlaygroundConcept { ImagePlaygroundConcept(kind: .image(image)) }
    /// nil when the URL is not a readable image
    @available(iOS 18.4, *) public static func image(_ url: URL) -> ImagePlaygroundConcept? {
        guard let data = try? Data(contentsOf: url), let cg = UIImage(data: data)?.cgImage else { return nil }
        return ImagePlaygroundConcept(kind: .image(cg))
    }
}

/// Whether Image Playground may use the person's appearance.
@available(iOS 18.1, *)
@objc public enum ImagePlaygroundPersonalizationPolicy: Int, Sendable {
    case automatic = 0, enabled, disabled
}

/// How images are made (iOS 26.4).
@available(iOS 26.4, *)
public struct ImagePlaygroundOptions: Hashable, Sendable {
    public struct SizeSpecification: Hashable, Sendable {
        let size: CGSize
        public static func closest(to size: CGSize) -> SizeSpecification { SizeSpecification(size: size) }
        public static func == (a: SizeSpecification, b: SizeSpecification) -> Bool { a.size == b.size }
        public func hash(into h: inout Hasher) { h.combine(size.width); h.combine(size.height) }
    }
    public enum CreationStrategy: Hashable, Sendable { case automatic, editExisting, generateNew }
    public enum CreationVariety: Hashable, Sendable { case automatic, high, low }
    public enum Personalization: Hashable, Sendable { case automatic, enabled, disabled }
    public var creationStrategy: CreationStrategy = .automatic
    public var creationVariety: CreationVariety = .automatic
    public var personalization: Personalization = .automatic
    public var sizeSpecification: SizeSpecification = .closest(to: CGSize(width: 1024, height: 1024))
    public init() {}
}

// MARK: - ImageCreator

/// Makes images from concepts without UI (iOS 18.4). isim has no image model: init throws.
@available(iOS 18.4, *)
public final class ImageCreator: @unchecked Sendable {
    public enum Error: Swift.Error, Equatable, Sendable, LocalizedError {
        case notSupported, unavailable, creationCancelled, faceInImageTooSmall, unsupportedLanguage, unsupportedInputImage,
             backgroundCreationForbidden, creationFailed, conceptsRequirePersonIdentity
        public var errorDescription: String? {
            switch self {
            case .notSupported: return "Image creation is not supported on this device."
            case .unavailable: return "Image creation is unavailable: this simulated device has no image model."
            case .creationCancelled: return "Image creation was cancelled."
            case .faceInImageTooSmall: return "The face in the image is too small."
            case .unsupportedLanguage: return "The language is not supported."
            case .unsupportedInputImage: return "The input image is not supported."
            case .backgroundCreationForbidden: return "Images cannot be created in the background."
            case .creationFailed: return "Image creation failed."
            case .conceptsRequirePersonIdentity: return "The concepts need a person's identity."
            }
        }
    }
    /// An image ImageCreator made.
    public struct CreatedImage: @unchecked Sendable {
        public let cgImage: CGImage
    }
    public let availableStyles: [ImagePlaygroundStyle]

    public init() async throws {
        throw _IsimImagePlayground.deviceIsEligible ? Error.unavailable : Error.notSupported
    }
    public func images(for concepts: [ImagePlaygroundConcept], style: ImagePlaygroundStyle, limit: Int) -> some AsyncSequence<CreatedImage, any Swift.Error> {
        AsyncThrowingStream<CreatedImage, any Swift.Error> { $0.finish(throwing: Error.unavailable) }
    }
    @available(iOS 26.4, *)
    public func images(for concepts: [ImagePlaygroundConcept], style: ImagePlaygroundStyle, options: ImagePlaygroundOptions,
                       limit: Int) -> some AsyncSequence<CreatedImage, any Swift.Error> {
        AsyncThrowingStream<CreatedImage, any Swift.Error> { $0.finish(throwing: Error.unavailable) }
    }
}

// MARK: - the view controller

/// Image Playground's UI (iOS 18.1). isim has no image model: isAvailable is false, and presented anyway it says so;
/// closing it is a cancellation.
@available(iOS 18.1, *)
@MainActor @objc(ImagePlaygroundViewController) open class ImagePlaygroundViewController: UIViewController {
    @objc(ImageGenerationViewControllerDelegate) public protocol Delegate: NSObjectProtocol {
        @objc(imagePlaygroundViewController:didCreateImageAtURL:)
        func imagePlaygroundViewController(_ imagePlaygroundViewController: ImagePlaygroundViewController, didCreateImageAt imageURL: URL)
        @objc(imagePlaygroundViewControllerDidCancel:)
        optional func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController)
        @available(iOS 18.4, *) @objc(imagePlaygroundViewController:didCreateAdaptiveImageGlyph:)
        optional func imagePlaygroundViewController(_ imagePlaygroundViewController: ImagePlaygroundViewController, didCreate adaptiveImageGlyph: NSAdaptiveImageGlyph)
    }
    @objc open class var isAvailable: Bool { false }
    open weak var delegate: (any Delegate)?
    open var concepts: [ImagePlaygroundConcept] = []
    @objc open var sourceImage: UIImage?
    open var selectedGenerationStyle: ImagePlaygroundStyle = .animation
    open var allowedGenerationStyles: [ImagePlaygroundStyle] = [.animation, .illustration, .sketch]
    @objc open var personalizationPolicy: ImagePlaygroundPersonalizationPolicy = .automatic
    @available(iOS 26.4, *)
    open var options: ImagePlaygroundOptions {
        get { (_options as? ImagePlaygroundOptions) ?? ImagePlaygroundOptions() }
        set { _options = newValue }
    }
    var _options: Any?
    var _cancelled = false

    @objc public convenience init() { self.init(nibName: nil, bundle: nil) }
    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        super.modalPresentationStyle = .pageSheet
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    open override var isModalInPresentation: Bool { get { false } set {} }
    open override var modalPresentationStyle: UIModalPresentationStyle { get { super.modalPresentationStyle } set { super.modalPresentationStyle = newValue } }
    open override var preferredContentSize: CGSize { get { CGSize(width: 540, height: 620) } set {} }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let symbol = UIImageView(image: UIImage(systemName: "photo"))
        symbol.tintColor = .secondaryLabel
        symbol.contentMode = .scaleAspectFit
        let title = UILabel(), message = UILabel()
        title.text = _IsimImagePlayground.title
        title.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        title.textAlignment = .center
        title.accessibilityIdentifier = "imageplayground-unavailable"
        message.text = _IsimImagePlayground.message
        message.font = .preferredFont(forTextStyle: .body)
        message.textColor = .secondaryLabel
        message.numberOfLines = 0
        message.textAlignment = .center
        let close = UIButton(type: .system)
        close.setTitle("Cancel", for: .normal)
        close.titleLabel?.font = .preferredFont(forTextStyle: .body)
        close.accessibilityIdentifier = "imageplayground-cancel"
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        for v in [symbol, title, message, close] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            symbol.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            symbol.bottomAnchor.constraint(equalTo: title.topAnchor, constant: -16),
            symbol.widthAnchor.constraint(equalToConstant: 56), symbol.heightAnchor.constraint(equalToConstant: 56),
            title.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            title.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            message.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            message.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: title.trailingAnchor),
        ])
    }
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NSLog("isim ImagePlayground: unavailable (%@)", _IsimImagePlayground.message)
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !_cancelled, isBeingDismissed || presentingViewController == nil else { return }
        _cancelled = true
        delegate?.imagePlaygroundViewControllerDidCancel?(self)
    }
}

extension UIFont {
    fileprivate func withTraits(_ t: UIFontDescriptor.SymbolicTraits) -> UIFont {
        fontDescriptor.withSymbolicTraits(t).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}

// MARK: - SwiftUI

@available(iOS 18.1, *)
struct _SupportsImagePlaygroundKey: EnvironmentKey { static let defaultValue = false }
@available(iOS 18.1, *)
struct _ImagePlaygroundStyleKey: EnvironmentKey { static let defaultValue = ImagePlaygroundStyle.animation }
@available(iOS 18.1, *)
struct _ImagePlaygroundStylesKey: EnvironmentKey { static let defaultValue: [ImagePlaygroundStyle] = [.animation, .illustration, .sketch] }
@available(iOS 18.1, *)
struct _ImagePlaygroundPolicyKey: EnvironmentKey { static let defaultValue = ImagePlaygroundPersonalizationPolicy.automatic }
@available(iOS 18.1, *)
struct _ImagePlaygroundOptionsKey: EnvironmentKey { static let defaultValue: AnyHashable? = nil }

@available(iOS 18.1, *)
extension EnvironmentValues {
    /// false on isim: there is no image model
    public var supportsImagePlayground: Bool { self[_SupportsImagePlaygroundKey.self] }
    public var imagePlaygroundSelectedGenerationStyle: ImagePlaygroundStyle {
        get { self[_ImagePlaygroundStyleKey.self] } set { self[_ImagePlaygroundStyleKey.self] = newValue }
    }
    public var imagePlaygroundAllowedGenerationStyles: [ImagePlaygroundStyle] {
        get { self[_ImagePlaygroundStylesKey.self] } set { self[_ImagePlaygroundStylesKey.self] = newValue }
    }
    public var imagePlaygroundPersonalizationPolicy: ImagePlaygroundPersonalizationPolicy {
        get { self[_ImagePlaygroundPolicyKey.self] } set { self[_ImagePlaygroundPolicyKey.self] = newValue }
    }
    @available(iOS 26.4, *)
    public var imagePlaygroundOptions: ImagePlaygroundOptions {
        get { self[_ImagePlaygroundOptionsKey.self] as? ImagePlaygroundOptions ?? ImagePlaygroundOptions() }
        set { self[_ImagePlaygroundOptionsKey.self] = AnyHashable(newValue) }
    }
}

/// the sheet: Image Playground is unavailable; Cancel ends it
@available(iOS 18.1, *)
struct _ImagePlaygroundUnavailable: View {
    let close: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "photo").font(.system(size: 48)).foregroundStyle(.secondary)
                Text(_IsimImagePlayground.title).font(.title2.bold()).accessibilityIdentifier("imageplayground-unavailable")
                Text(_IsimImagePlayground.message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: close).accessibilityIdentifier("imageplayground-cancel") }
            }
        }
    }
}

@available(iOS 18.1, *)
struct _ImagePlaygroundSheet: ViewModifier {
    let isPresented: Binding<Bool>
    let onCancellation: (() -> Void)?
    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented, onDismiss: { onCancellation?() }) {
            _ImagePlaygroundUnavailable { isPresented.wrappedValue = false }
                .onAppear { NSLog("isim ImagePlayground: unavailable (%@)", _IsimImagePlayground.message) }
        }
    }
}

@available(iOS 18.1, *)
extension View {
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concept: String, sourceImage: Image? = nil,
                                     onCompletion: @escaping (URL) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concepts: [ImagePlaygroundConcept] = [], sourceImage: Image? = nil,
                                     onCompletion: @escaping (URL) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concept: String, sourceImageURL: URL,
                                     onCompletion: @escaping (URL) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concepts: [ImagePlaygroundConcept] = [], sourceImageURL: URL,
                                     onCompletion: @escaping (URL) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    @available(iOS 18.4, *)
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concept: String, sourceImage: Image? = nil, onCompletion: @escaping (URL) -> Void,
                                     onAdaptiveImageGlyphCreation: @escaping (NSAdaptiveImageGlyph) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    @available(iOS 18.4, *)
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concepts: [ImagePlaygroundConcept] = [], sourceImage: Image? = nil,
                                     onCompletion: @escaping (URL) -> Void, onAdaptiveImageGlyphCreation: @escaping (NSAdaptiveImageGlyph) -> Void,
                                     onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    @available(iOS 18.4, *)
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concept: String, sourceImageURL: URL, onCompletion: @escaping (URL) -> Void,
                                     onAdaptiveImageGlyphCreation: @escaping (NSAdaptiveImageGlyph) -> Void, onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    @available(iOS 18.4, *)
    public func imagePlaygroundSheet(isPresented: Binding<Bool>, concepts: [ImagePlaygroundConcept] = [], sourceImageURL: URL,
                                     onCompletion: @escaping (URL) -> Void, onAdaptiveImageGlyphCreation: @escaping (NSAdaptiveImageGlyph) -> Void,
                                     onCancellation: (() -> Void)? = nil) -> some View {
        modifier(_ImagePlaygroundSheet(isPresented: isPresented, onCancellation: onCancellation))
    }
    public func imagePlaygroundGenerationStyle(_ style: ImagePlaygroundStyle, in styles: [ImagePlaygroundStyle] = ImagePlaygroundStyle._allDefault) -> some View {
        environment(\.imagePlaygroundSelectedGenerationStyle, style).environment(\.imagePlaygroundAllowedGenerationStyles, styles)
    }
    public func imagePlaygroundPersonalizationPolicy(_ policy: ImagePlaygroundPersonalizationPolicy) -> some View {
        environment(\.imagePlaygroundPersonalizationPolicy, policy)
    }
    @available(iOS 26.4, *)
    public func imagePlaygroundOptions(_ options: ImagePlaygroundOptions) -> some View {
        environment(\.imagePlaygroundOptions, options)
    }
}
@available(iOS 18.1, *)
extension ImagePlaygroundStyle {
    public static var _allDefault: [ImagePlaygroundStyle] { [.animation, .illustration, .sketch] }
}
