// isim SwiftUI (iOS 27): URL-based documents — `ReadableDocument`, `WritableDocument`, `Document`, their readers and
// writers (`DocumentReader`, `DocumentWriter`, `FileWrapperDocumentReader`, `FileWrapperDocumentWriter`),
// `URLDocumentConfiguration`, `DocumentCreationContext` / `DocumentCreationSource`, and the DocumentGroup
// initializers that make them (`init(allowCreating:editor:makeDocument:)`, `init(viewer:makeReadableDocument:)`).
// Signatures from Apple's documentation (`@ContentBuilder` closures are `@ViewBuilder` here: isim's Swift 6.2
// toolchain has no ContentBuilder). On the same UIKit document machinery as FileDocument (Documents.swift): the
// document is made and read when it opens (reader, then `apply(snapshot:previous:)`), and saves take a snapshot
// and hand it to the writer with the previous one. Not provided: `URLDocumentConfiguration.makeFileCoordinator()`
// (isim has no NSFileCoordinator), the SwiftData forms.
import UIKit
import UniformTypeIdentifiers

@available(iOS 27.0, *)
public struct DocumentReadConfiguration: Sendable {
    /// the type of the file being read (one of the document's readable types)
    public var contentType: UTType
}
@available(iOS 27.0, *)
public struct DocumentWriteConfiguration: Sendable {
    /// the type of the file being written (one of the document's writable types)
    public var contentType: UTType
}

/// Reads a document's content from a file into a snapshot.
@available(iOS 27.0, *)
public protocol DocumentReader<Snapshot> {
    associatedtype Snapshot
    associatedtype Source = URL
    func read(from source: sending Source, progress: consuming Subprogress) async throws -> sending Snapshot
}
/// Writes a snapshot of a document's content to a file.
@available(iOS 27.0, *)
public protocol DocumentWriter<Snapshot> {
    associatedtype Snapshot
    associatedtype Destination = URL
    func write(snapshot: sending Snapshot, to destination: sending Destination, previous: sending Snapshot?, progress: consuming Subprogress) async throws
}

/// A reader that turns the file's FileWrapper into a snapshot.
@available(iOS 27.0, *)
public struct FileWrapperDocumentReader<Snapshot>: DocumentReader {
    public typealias ReadConfiguration = DocumentReadConfiguration
    let makeSnapshot: (FileWrapper) async throws -> Snapshot
    public init(_ configuration: sending ReadConfiguration, makeSnapshot: @escaping (FileWrapper) async throws -> sending Snapshot) {
        self.makeSnapshot = makeSnapshot
    }
    public func read(from source: sending URL, progress: consuming Subprogress) async throws -> sending Snapshot {
        let p = progress.start(totalCount: 1)
        let wrapper = try FileWrapper(url: source, options: .immediate)
        let s = try await makeSnapshot(wrapper)
        p.complete(count: 1)
        return s
    }
}
/// A writer that turns a snapshot into a FileWrapper (given the file's current one) and writes it.
@available(iOS 27.0, *)
public struct FileWrapperDocumentWriter<Snapshot>: DocumentWriter {
    public typealias WriteConfiguration = DocumentWriteConfiguration
    let makeFileWrapper: (Snapshot, FileWrapper?) async throws -> FileWrapper
    public init(_ configuration: sending WriteConfiguration, makeFileWrapper: @escaping (Snapshot, FileWrapper?) async throws -> FileWrapper) {
        self.makeFileWrapper = makeFileWrapper
    }
    public func write(snapshot: sending Snapshot, to destination: sending URL, previous: sending Snapshot?, progress: consuming Subprogress) async throws {
        let p = progress.start(totalCount: 1)
        let existing = try? FileWrapper(url: destination, options: .immediate)
        let w = try await makeFileWrapper(snapshot, existing)
        try w.write(to: destination, options: .atomic, originalContentsURL: existing == nil ? nil : destination)
        p.complete(count: 1)
    }
}

/// A document read from a file (a reader makes a snapshot, the document applies it).
@available(iOS 27.0, *)
public protocol ReadableDocument: AnyObject {
    static var readableContentTypes: [UTType] { get }
    static var writableContentTypes: [UTType] { get }
    typealias ReadConfiguration = DocumentReadConfiguration
    associatedtype Reader: DocumentReader
    func reader(configuration: sending ReadConfiguration) -> sending Reader
    func apply(snapshot: sending Reader.Snapshot, previous: sending Reader.Snapshot?) async throws
}
@available(iOS 27.0, *)
extension ReadableDocument {
    public static var writableContentTypes: [UTType] { [] }
}
/// A document written to a file (a snapshot of it, by a writer).
@available(iOS 27.0, *)
public protocol WritableDocument: AnyObject {
    static var writableContentTypes: [UTType] { get }
    typealias WriteConfiguration = DocumentWriteConfiguration
    associatedtype Writer: DocumentWriter
    func writer(configuration: sending WriteConfiguration) -> sending Writer
    func snapshot(contentType: UTType) async throws -> sending Writer.Snapshot
}
/// A document that is read and written.
@available(iOS 27.0, *)
public protocol Document: ReadableDocument, WritableDocument {}
@available(iOS 27.0, *)
extension Document {
    public static var writableContentTypes: [UTType] { readableContentTypes }
}

/// How a new document was created.
@available(iOS 27.0, *)
public struct DocumentCreationSource: Hashable, Sendable {
    let id: String
    public init(id: String) { self.id = id }
}
@available(iOS 27.0, *)
public struct DocumentCreationContext: Sendable {
    public var creationSource: DocumentCreationSource?
}
/// The open document's file and metadata.
@available(iOS 27.0, *)
@MainActor public final class URLDocumentConfiguration {
    public internal(set) var fileURL: URL?
    public internal(set) var lastContentModificationDate: Date?
    public internal(set) var creationSource: DocumentCreationSource?
    init(fileURL: URL?, creationSource: DocumentCreationSource?) {
        self.fileURL = fileURL; self.creationSource = creationSource
        if let u = fileURL { lastContentModificationDate = (try? FileManager.default.attributesOfItem(atPath: u.path))?[.modificationDate] as? Date }
    }
}

/// An open iOS 27 document: how to save it, and its editor.
@MainActor final class _AsyncDocumentState {
    var save: ((URL, UTType) async throws -> Void)?
    var editor: () -> AnyView = { AnyView(EmptyView()) }
}

@available(iOS 27.0, *)
extension DocumentGroup where Document: SwiftUI.Document {
    /// Documents made by `makeDocument` (opened ones read from their file), edited in `editor`.
    public init(allowCreating: Bool = true, @ViewBuilder editor: @escaping (Document) -> Content,
                makeDocument: @escaping @MainActor (URLDocumentConfiguration, DocumentCreationContext) async throws -> Document) {
        var s = _DocumentSpec(readable: Document.readableContentTypes, writable: Document.writableContentTypes, editable: true, newFile: nil, open: nil)
        s.asyncOpen = { url, type in try await _openAsyncDocument(url, type, make: makeDocument, editor: editor, writes: true) }
        if allowCreating {
            s.asyncNewFile = { url, type in
                let doc = try await makeDocument(URLDocumentConfiguration(fileURL: nil, creationSource: nil), DocumentCreationContext(creationSource: nil))
                try await _writeAsyncDocument(doc, to: url, type: type, previous: nil)
            }
        }
        spec = s
    }
}
@available(iOS 27.0, *)
extension DocumentGroup where Document: ReadableDocument {
    /// Read-only documents made by `makeReadableDocument` and read from their file.
    public init(@ViewBuilder viewer: @escaping (Document) -> Content,
                makeReadableDocument: @escaping @MainActor (URLDocumentConfiguration, DocumentCreationContext) async throws -> Document) {
        var s = _DocumentSpec(readable: Document.readableContentTypes, writable: [], editable: false, newFile: nil, open: nil)
        s.asyncOpen = { url, type in try await _openAsyncDocument(url, type, make: makeReadableDocument, editor: viewer, writes: false) }
        spec = s
    }
}

@available(iOS 27.0, *)
@MainActor func _writeAsyncDocument<D: WritableDocument>(_ doc: D, to url: URL, type: UTType, previous: D.Writer.Snapshot?) async throws {
    let snapshot = try await doc.snapshot(contentType: type)
    let writer = doc.writer(configuration: DocumentWriteConfiguration(contentType: type))
    guard let destination = url as? D.Writer.Destination else { throw CocoaError(.fileWriteUnknown) }
    try await writer.write(snapshot: snapshot, to: destination, previous: previous, progress: ProgressManager(totalCount: 1).subprogress(assigningCount: 1))
}
/// Makes the document for a file, reads it (reader, then apply) and returns how to save it and its editor.
@available(iOS 27.0, *)
@MainActor func _openAsyncDocument<D: ReadableDocument, C: View>(_ url: URL, _ type: UTType, make: @MainActor (URLDocumentConfiguration, DocumentCreationContext) async throws -> D,
                                                                 editor: @escaping (D) -> C, writes: Bool) async throws -> _AsyncDocumentState {
    let doc = try await make(URLDocumentConfiguration(fileURL: url, creationSource: nil), DocumentCreationContext(creationSource: nil))
    let reader = doc.reader(configuration: DocumentReadConfiguration(contentType: type))
    guard let source = url as? D.Reader.Source else { throw CocoaError(.fileReadUnsupportedScheme) }
    let snapshot = try await reader.read(from: source, progress: ProgressManager(totalCount: 1).subprogress(assigningCount: 1))
    try await doc.apply(snapshot: snapshot, previous: nil)
    let s = _AsyncDocumentState()
    s.editor = { AnyView(editor(doc)) }
    if writes, let w = doc as? any WritableDocument { s.save = _saver(w, initial: snapshot) }
    return s
}
/// Saving a writable document: each save hands the writer the snapshot it wrote before (first: the one read).
@available(iOS 27.0, *)
@MainActor func _saver<W: WritableDocument>(_ w: W, initial: Any) -> (URL, UTType) async throws -> Void {
    var previous = initial as? W.Writer.Snapshot
    return { url, type in
        let snapshot = try await w.snapshot(contentType: type)
        let writer = w.writer(configuration: DocumentWriteConfiguration(contentType: type))
        guard let destination = url as? W.Writer.Destination else { throw CocoaError(.fileWriteUnknown) }
        let kept = snapshot
        try await writer.write(snapshot: snapshot, to: destination, previous: previous, progress: ProgressManager(totalCount: 1).subprogress(assigningCount: 1))
        previous = kept
    }
}
