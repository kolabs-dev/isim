// isim Foundation Models: the transcript's iOS 27 entries and segments (issue #859): reasoning, data entries, image
// and data attachments, metadata on prompts / responses / tool calls, the context options a prompt was sent with,
// and the history view (the conversation without its instructions).
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, *)
extension Transcript {
    /// The model's reasoning before it answered.
    public struct Reasoning: Sendable, Identifiable, Equatable, CustomStringConvertible {
        public var id: String
        public var segments: [Segment]
        public var signature: Data?
        public var metadata: [String: GeneratedContent]
        public init(id: String = UUID().uuidString, metadata: [String: any ConvertibleToGeneratedContent] = [:], segments: [Segment], signature: Data? = nil) {
            self.id = id; self.metadata = _isimGenerated(metadata); self.segments = segments; self.signature = signature
        }
        public var description: String { segments.map(\._text).joined() }
        public static func == (a: Reasoning, b: Reasoning) -> Bool { a.id == b.id }
    }
    /// Data (a file) an entry of the transcript holds.
    public struct DataEntry: Sendable, Identifiable, Equatable {
        public var id: String
        public var contentType: UTType
        public var content: Data
        public var metadata: GeneratedContent
        public init(id: String = UUID().uuidString, contentType: UTType, content: Data, metadata: GeneratedContent = GeneratedContent(properties: [:])) {
            self.id = id; self.contentType = contentType; self.content = content; self.metadata = metadata
        }
        public static func == (a: DataEntry, b: DataEntry) -> Bool { a.id == b.id }
    }
    /// Data attached to a prompt or a response.
    public struct DataAttachment: Sendable, Equatable {
        public var contentType: UTType
        public var content: Data
        public var metadata: GeneratedContent
        public init(contentType: UTType, content: Data, metadata: GeneratedContent = GeneratedContent(properties: [:])) {
            self.contentType = contentType; self.content = content; self.metadata = metadata
        }
    }
    /// An image attached to a prompt or a response.
    public struct ImageAttachment: @unchecked Sendable, Equatable {
        let _image: CGImage?
        public let url: URL?
        public let orientation: CGImagePropertyOrientation
        public init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil) {
            _image = cgImage; url = nil; self.orientation = orientation ?? .up
        }
        public init(imageURL: URL, orientation: CGImagePropertyOrientation? = nil) {
            _image = nil; url = imageURL; self.orientation = orientation ?? .up
        }
        /// the image (decoded from its URL when it was attached by URL)
        public var cgImage: CGImage {
            if let _image { return _image }
            if let url, let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) { return img }
            let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return ctx.makeImage()!
        }
        public var ciImage: CIImage { CIImage(cgImage: cgImage) }
        public static func == (a: ImageAttachment, b: ImageAttachment) -> Bool { a.url == b.url && a._image === b._image }
    }
    /// What an attachment segment carries.
    public enum Attachment: Sendable, Equatable {
        case image(ImageAttachment)
        case data(DataAttachment)
    }
    /// An attachment in a prompt's or a response's segments.
    public struct AttachmentSegment: Sendable, Identifiable, Equatable {
        public var id: String
        public var content: Attachment
        public var label: String?
        public init(id: String = UUID().uuidString, content: Attachment, label: String? = nil) { self.id = id; self.content = content; self.label = label }
        public static func == (a: AttachmentSegment, b: AttachmentSegment) -> Bool { a.id == b.id }
    }

    /// The conversation: the transcript's entries after its instructions.
    public struct HistoryView: RandomAccessCollection, RangeReplaceableCollection, MutableCollection, ExpressibleByArrayLiteral, Sendable, Equatable {
        public typealias Element = Transcript.Entry
        public typealias ArrayLiteralElement = Transcript.Entry
        public typealias SubSequence = HistoryView
        public struct Index: Comparable, Hashable, Sendable, Strideable {
            let _offset: Int
            public static func < (a: Index, b: Index) -> Bool { a._offset < b._offset }
            public func distance(to other: Index) -> Int { other._offset - _offset }
            public func advanced(by n: Int) -> Index { Index(_offset: _offset + n) }
        }
        var _entries: [Transcript.Entry]
        public init() { _entries = [] }
        public init(arrayLiteral elements: Transcript.Entry...) { _entries = elements }
        init(_ entries: [Transcript.Entry]) { _entries = entries }
        public var startIndex: Index { Index(_offset: 0) }
        public var endIndex: Index { Index(_offset: _entries.count) }
        public func index(after i: Index) -> Index { Index(_offset: i._offset + 1) }
        public func index(before i: Index) -> Index { Index(_offset: i._offset - 1) }
        public subscript(position: Index) -> Transcript.Entry {
            get { _entries[position._offset] }
            set { _entries[position._offset] = newValue }
        }
        public subscript(bounds: Range<Index>) -> HistoryView {
            get { HistoryView(Array(_entries[bounds.lowerBound._offset..<bounds.upperBound._offset])) }
            set { _entries.replaceSubrange(bounds.lowerBound._offset..<bounds.upperBound._offset, with: newValue._entries) }
        }
        public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C) where C.Element == Transcript.Entry {
            _entries.replaceSubrange(subrange.lowerBound._offset..<subrange.upperBound._offset, with: newElements)
        }
        public mutating func append(_ newElement: Transcript.Entry) { _entries.append(newElement) }
        public mutating func append(contentsOf newElements: some Sequence<Transcript.Entry>) { _entries.append(contentsOf: newElements) }
        public static func == (a: HistoryView, b: HistoryView) -> Bool { a._entries.map(\.id) == b._entries.map(\.id) }
    }
    /// the conversation after the instructions; setting it keeps the instructions
    public var history: HistoryView {
        get { HistoryView(_entries.filter { if case .instructions = $0 { return false }; return true }) }
        set { _entries = _entries.filter { if case .instructions = $0 { return true }; return false } + newValue._entries }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension Transcript.Prompt {
    public var metadata: [String: GeneratedContent] { get { _metadata } set { _metadata = newValue } }
}
@available(iOS 27.0, macOS 27.0, *)
extension Transcript.Prompt {
    public var contextOptions: ContextOptions { get { _context as? ContextOptions ?? ContextOptions() } set { _context = newValue } }
    public init(id: String = UUID().uuidString, metadata: [String: any ConvertibleToGeneratedContent] = [:], segments: [Transcript.Segment],
                options: GenerationOptions = GenerationOptions(), responseFormat: Transcript.ResponseFormat? = nil, contextOptions: ContextOptions = ContextOptions()) {
        self.init(id: id, segments: segments, options: options, responseFormat: responseFormat)
        _metadata = _isimGenerated(metadata); _context = contextOptions
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension Transcript.Response {
    public var metadata: [String: GeneratedContent] { _metadata }
    public init(id: String = UUID().uuidString, metadata: [String: any ConvertibleToGeneratedContent] = [:], segments: [Transcript.Segment]) {
        self.init(id: id, assetIDs: [], segments: segments)
        _metadata = _isimGenerated(metadata)
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension Transcript.ToolCall {
    public var metadata: [String: GeneratedContent] { get { _metadata } set { _metadata = newValue } }
    public init(id: String, metadata: [String: any ConvertibleToGeneratedContent], toolName: String, arguments: GeneratedContent) {
        self.init(id: id, toolName: toolName, arguments: arguments)
        _metadata = _isimGenerated(metadata)
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension Transcript.ToolDefinition {
    public var parameters: GenerationSchema { get { _parameters } set { _parameters = newValue } }
}
@available(iOS 26.0, macOS 26.0, *)
extension Transcript.ResponseFormat {
    /// what the response must follow
    public enum Kind: Sendable { case schema(GenerationSchema) }
    public var kind: Kind { .schema(_schema) }
}

// MARK: - attachments in prompts

/// What an image attachment holds.
@available(iOS 27.0, macOS 27.0, *)
public struct ImageAttachmentContent: Sendable { let _image: Transcript.ImageAttachment }

/// A value that can travel as a data attachment.
@available(iOS 27.0, macOS 27.0, *)
public protocol DataAttachmentRepresentable: Sendable {
    init(_ attachment: Transcript.DataAttachment) throws
    var transcriptRepresentation: Transcript.DataAttachment { get }
}
/// A value that can travel as a data entry.
@available(iOS 27.0, macOS 27.0, *)
public protocol DataEntryRepresentable: Sendable {
    init(_ entry: Transcript.DataEntry) throws
    var transcriptRepresentation: Transcript.DataEntry { get }
}

/// An attachment to put in a prompt (`Prompt { "Describe this"; Attachment(image) }`).
@available(iOS 27.0, macOS 27.0, *)
public struct Attachment<Content>: PromptRepresentable, @unchecked Sendable {
    let _segment: Transcript.AttachmentSegment
    init(_attachment: Transcript.Attachment, label: String? = nil) { _segment = Transcript.AttachmentSegment(content: _attachment, label: label) }
    public func label(_ label: String) -> Attachment<Content> { Attachment(_attachment: _segment.content, label: label) }
    public var promptRepresentation: Prompt { Prompt("[attachment \(_segment.label ?? _segment.id)]") }
}
@available(iOS 27.0, macOS 27.0, *)
extension Attachment where Content == ImageAttachmentContent {
    public init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init(_attachment: .image(Transcript.ImageAttachment(cgImage, orientation: orientation)))
    }
    public init(imageURL: URL, orientation: CGImagePropertyOrientation? = nil) {
        self.init(_attachment: .image(Transcript.ImageAttachment(imageURL: imageURL, orientation: orientation)))
    }
}
@available(iOS 27.0, macOS 27.0, *)
extension Attachment where Content: DataAttachmentRepresentable {
    public init(_ content: Content) { self.init(_attachment: .data(content.transcriptRepresentation)) }
}

/// A Generable reference to an image attachment by its label (a model's answer can point at an image).
@available(iOS 27.0, macOS 27.0, *)
public struct ImageReference: Generable, Sendable, Equatable {
    public let attachmentLabel: String
    public nonisolated struct PartiallyGenerated: ConvertibleFromGeneratedContent, Sendable {
        public var attachmentLabel: String.PartiallyGenerated?
        public init(_ content: GeneratedContent) throws {
            attachmentLabel = try? content.value(String.PartiallyGenerated.self, forProperty: "attachmentLabel")
        }
    }
    public init(_ content: GeneratedContent) throws { attachmentLabel = try content.value(String.self, forProperty: "attachmentLabel") }
    public var generatedContent: GeneratedContent { GeneratedContent(properties: ["attachmentLabel": attachmentLabel]) }
    public static var generationSchema: GenerationSchema {
        GenerationSchema(type: ImageReference.self, description: "A reference to an image attachment by its label",
                         properties: [GenerationSchema.Property(name: "attachmentLabel", type: String.self)])
    }
    /// the image this label names in the transcript
    public func resolved(in transcript: some Sequence<Transcript.Entry>) -> Transcript.ImageAttachment? {
        for e in transcript {
            let segments: [Transcript.Segment]
            switch e {
            case .prompt(let p): segments = p.segments
            case .response(let r): segments = r.segments
            default: continue
            }
            for case .attachment(let a) in segments where a.label == attachmentLabel { if case .image(let i) = a.content { return i } }
        }
        return nil
    }
}
