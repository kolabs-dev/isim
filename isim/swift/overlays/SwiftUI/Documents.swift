// isim SwiftUI: document-based apps — `DocumentGroup` (new documents and viewing) with `FileDocument` (a value) or
// `ReferenceFileDocument` (an ObservableObject with snapshots), `FileDocumentConfiguration` /
// `ReferenceFileDocumentConfiguration`, `\.documentConfiguration`, `\.undoManager`.
// On UIKit's document machinery: the group's window shows a UIDocumentViewController (iOS 18: the launch view with
// the app's name, Create Document and the document browser; before: the empty state and its Documents button);
// documents open as a UIDocument whose contents are FileWrappers, the editor (a SwiftUI view) fills the controller
// under the navigation bar (the document's name, back to the launch view, undo and redo). Edits through the binding
// (FileDocument) register undo and autosave; a ReferenceFileDocument's changes count through the undo manager its
// views register with (`\.undoManager`) and its objectWillChange.
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Documents

/// A document that is a value, read from and written to a file wrapper.
public protocol FileDocument {
    static var readableContentTypes: [UTType] { get }
    static var writableContentTypes: [UTType] { get }
    init(configuration: ReadConfiguration) throws
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper
    typealias ReadConfiguration = FileDocumentReadConfiguration
    typealias WriteConfiguration = FileDocumentWriteConfiguration
}
extension FileDocument {
    public static var writableContentTypes: [UTType] { readableContentTypes }
}
/// A document that is a shared object; saves write a snapshot of it.
public protocol ReferenceFileDocument: ObservableObject {
    associatedtype Snapshot
    static var readableContentTypes: [UTType] { get }
    static var writableContentTypes: [UTType] { get }
    init(configuration: ReadConfiguration) throws
    func snapshot(contentType: UTType) throws -> Snapshot
    func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper
    typealias ReadConfiguration = FileDocumentReadConfiguration
    typealias WriteConfiguration = FileDocumentWriteConfiguration
}
extension ReferenceFileDocument {
    public static var writableContentTypes: [UTType] { readableContentTypes }
}
public struct FileDocumentReadConfiguration {
    public let contentType: UTType
    public let file: FileWrapper
}
public struct FileDocumentWriteConfiguration {
    public let contentType: UTType
    public let existingFile: FileWrapper?
}

/// What an editor gets for a FileDocument: a binding to it, its file and whether it can be edited.
public struct FileDocumentConfiguration<Document: FileDocument> {
    @Binding public var document: Document
    public var fileURL: URL?
    public var isEditable: Bool
}
/// What an editor gets for a ReferenceFileDocument.
public struct ReferenceFileDocumentConfiguration<Document: ReferenceFileDocument> {
    @ObservedObject public var document: Document
    public var fileURL: URL?
    public var isEditable: Bool
}
/// The open document's file and editability, in the editor's environment.
public struct DocumentConfiguration: Sendable {
    public var fileURL: URL?
    public var isEditable: Bool
}
struct _DocumentConfigurationKey: EnvironmentKey { static var defaultValue: DocumentConfiguration? { nil } }
struct _UndoManagerKey: EnvironmentKey { nonisolated(unsafe) static var defaultValue: UndoManager? { nil } }
extension EnvironmentValues {
    public var documentConfiguration: DocumentConfiguration? { self[_DocumentConfigurationKey.self] }
    var _documentConfiguration: DocumentConfiguration? { get { self[_DocumentConfigurationKey.self] } set { self[_DocumentConfigurationKey.self] = newValue } }
    /// The undo manager of the open document (nil outside documents).
    public var undoManager: UndoManager? { self[_UndoManagerKey.self] }
    var _undoManager: UndoManager? { get { self[_UndoManagerKey.self] } set { self[_UndoManagerKey.self] = newValue } }
}

// MARK: - DocumentGroup

/// The scene of a document-based app.
public struct DocumentGroup<Document, Content: View>: Scene, _SceneRoot, _SceneNode {
    let spec: _DocumentSpec
    public var body: Never { fatalError() }
    var _rootView: AnyView { AnyView(_DocumentGroupHost(spec: spec).ignoresSafeArea()) }
    @MainActor func _collect(_ c: _SceneCollector) {
        let spec = self.spec
        if c.groups.isEmpty && c.rootController == nil {
            c.rootController = { UINavigationController(rootViewController: _SUIDocumentViewController(spec: spec)) }
        }
        let r = _rootView
        c.groups.append((nil, { r }))
    }
}
extension DocumentGroup where Document: FileDocument {
    /// New documents start as `newDocument()`; `editor` edits the open one.
    public init(newDocument: @autoclosure @escaping () -> Document, @ViewBuilder editor: @escaping (FileDocumentConfiguration<Document>) -> Content) {
        spec = _DocumentSpec.file(Document.self, new: newDocument, editable: true, content: editor)
    }
    /// Documents of this type open read-only in `viewer`; no new documents.
    public init(viewing documentType: Document.Type, @ViewBuilder viewer: @escaping (FileDocumentConfiguration<Document>) -> Content) {
        spec = _DocumentSpec.file(Document.self, new: nil, editable: false, content: viewer)
    }
}
extension DocumentGroup where Document: ReferenceFileDocument {
    public init(newDocument: @escaping () -> Document, @ViewBuilder editor: @escaping (ReferenceFileDocumentConfiguration<Document>) -> Content) {
        spec = _DocumentSpec.reference(Document.self, new: newDocument, editable: true, content: editor)
    }
    public init(viewing documentType: Document.Type, @ViewBuilder viewer: @escaping (ReferenceFileDocumentConfiguration<Document>) -> Content) {
        spec = _DocumentSpec.reference(Document.self, new: nil, editable: false, content: viewer)
    }
}

/// A document type erased: reading, writing, a new document's contents and the editor for an open document.
struct _DocumentSpec {
    let readable: [UTType], writable: [UTType]
    let editable: Bool
    /// a new document's file contents (nil: viewing only)
    let newFile: (@MainActor () throws -> FileWrapper)?
    /// reads a file into the document's state; returns the state
    var open: (@MainActor (FileWrapper, UTType) throws -> _DocumentState)?
    /// iOS 27 documents (Documents27.swift): made and read asynchronously, written by their writers
    var asyncOpen: (@MainActor (URL, UTType) async throws -> _AsyncDocumentState)? = nil
    var asyncNewFile: (@MainActor (URL, UTType) async throws -> Void)? = nil
    @MainActor static func file<D: FileDocument, C: View>(_ type: D.Type, new: (() -> D)?, editable: Bool, content: @escaping (FileDocumentConfiguration<D>) -> C) -> _DocumentSpec {
        let wtype = D.writableContentTypes.first ?? D.readableContentTypes.first ?? .data
        return _DocumentSpec(readable: D.readableContentTypes, writable: D.writableContentTypes, editable: editable,
                             newFile: new.map { make in { try make().fileWrapper(configuration: .init(contentType: wtype, existingFile: nil)) } },
                             open: { file, type in
            let s = _DocumentState()
            var value = try D(configuration: .init(contentType: type, file: file))
            s.write = { t, existing in try value.fileWrapper(configuration: .init(contentType: t, existingFile: existing)) }
            s.editor = { doc, url in
                let binding = Binding<D>(get: { value }, set: { new in
                    let old = value
                    value = new
                    // an edit: undoable, saved by autosave
                    doc?.undoManager.registerUndo(withTarget: s) { st in
                        let redo = value
                        value = old
                        st.changed?()
                        doc?.undoManager.registerUndo(withTarget: st) { st2 in value = redo; st2.changed?() }
                    }
                    doc?.updateChangeCount(.done)
                    s.changed?()
                })
                return AnyView(content(FileDocumentConfiguration(document: binding, fileURL: url, isEditable: editable)))
            }
            return s
        })
    }
    @MainActor static func reference<D: ReferenceFileDocument, C: View>(_ type: D.Type, new: (() -> D)?, editable: Bool, content: @escaping (ReferenceFileDocumentConfiguration<D>) -> C) -> _DocumentSpec {
        let wtype = D.writableContentTypes.first ?? D.readableContentTypes.first ?? .data
        return _DocumentSpec(readable: D.readableContentTypes, writable: D.writableContentTypes, editable: editable,
                             newFile: new.map { make in { let d = make(); return try d.fileWrapper(snapshot: d.snapshot(contentType: wtype), configuration: .init(contentType: wtype, existingFile: nil)) } },
                             open: { file, type in
            let s = _DocumentState()
            let object = try D(configuration: .init(contentType: type, file: file))
            s.write = { t, existing in try object.fileWrapper(snapshot: object.snapshot(contentType: t), configuration: .init(contentType: t, existingFile: existing)) }
            s.editor = { doc, url in AnyView(content(ReferenceFileDocumentConfiguration(document: object, fileURL: url, isEditable: editable))) }
            // changes the views make without registering undo still get saved
            s.subscription = object.objectWillChange.sink { _ in DispatchQueue.main.async { MainActor.assumeIsolated { s.document?.updateChangeCount(.done) } } }
            return s
        })
    }
}
@MainActor final class _DocumentState {
    var write: ((UTType, FileWrapper?) throws -> FileWrapper)?
    var editor: ((UIDocument?, URL?) -> AnyView)?
    var changed: (() -> Void)?
    var subscription: AnyCancellable?
    weak var document: UIDocument?
}

/// The UIDocument of an open SwiftUI document: its contents are file wrappers.
final class _SUIDocument: UIDocument {
    let spec: _DocumentSpec
    var state: _DocumentState?
    var asyncState: _AsyncDocumentState?
    var file: FileWrapper?
    /// iOS 27 documents save through their writers, asynchronously
    override func save(to url: URL, for saveOperation: UIDocument.SaveOperation, completionHandler: ((Bool) -> Void)? = nil) {
        guard let s = asyncState else {
            if spec.asyncOpen != nil { completionHandler?(true); return }             // not read yet: nothing to save
            return super.save(to: url, for: saveOperation, completionHandler: completionHandler)
        }
        let token = changeCountToken(for: saveOperation), type = spec.writable.first ?? contentType
        Task { @MainActor in
            do {
                try await s.save?(url, type)
                self.updateChangeCount(withToken: token, for: saveOperation)
                print("isim: document saved \(url.lastPathComponent)")
                completionHandler?(true)
            } catch {
                NSLog("isim SwiftUI: the document could not be saved: %@", "\(error)")
                completionHandler?(false)
            }
        }
    }
    init(fileURL url: URL, spec: _DocumentSpec) { self.spec = spec; super.init(fileURL: url) }
    var contentType: UTType { UTType(fileType ?? "") ?? UTType(filenameExtension: fileURL.pathExtension) ?? spec.readable.first ?? .data }
    override func read(from url: URL) throws {
        let w = try FileWrapper(url: url, options: .immediate)
        var err: Error?
        guard let open = spec.open else { return }                  // (iOS 27 documents read when they open)
        let load = { MainActor.assumeIsolated { do { let s = try open(w, self.contentType); s.document = self; self.state = s; self.file = w } catch { err = error } } }
        if Thread.isMainThread { load() } else { DispatchQueue.main.sync(execute: load) }
        if let err { throw err }
    }
    override func contents(forType typeName: String) throws -> Any {
        let type = UTType(typeName) ?? contentType
        let w = try MainActor.assumeIsolated { () throws -> FileWrapper in
            guard let write = state?.write else { throw CocoaError(.fileWriteUnknown) }
            return try write(spec.writable.contains(type) ? type : (spec.writable.first ?? type), file)
        }
        return w
    }
    override func writeContents(_ contents: Any, to url: URL, for saveOperation: UIDocument.SaveOperation, originalContentsURL: URL?) throws {
        guard let w = contents as? FileWrapper else { return try super.writeContents(contents, to: url, for: saveOperation, originalContentsURL: originalContentsURL) }
        try w.write(to: url, options: [], originalContentsURL: originalContentsURL)
        print("isim: document saved \(fileURL.lastPathComponent)")
    }
}

/// The document view controller of a DocumentGroup: the launch view and browser, and the editor of the open document.
final class _SUIDocumentViewController: UIDocumentViewController {
    let spec: _DocumentSpec
    var host: _SUIHostingController?
    init(spec: _DocumentSpec) {
        self.spec = spec
        super.init(document: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.trailingItemGroups = [undoRedoItemGroup]
        if #available(iOS 18, *) {
            launchOptions.background.backgroundColor = _accentUIColor()       // the app's accent colour behind its name
            if spec.newFile == nil && spec.asyncNewFile == nil { launchOptions.primaryAction = nil }
        }
    }
    func show(_ d: _SUIDocument) {
        host?.willMove(toParent: nil); host?.view.removeFromSuperview(); host?.removeFromParent(); host = nil
        guard let s = d.state, let editor = s.editor else { return }
        let url = d.fileURL, editable = spec.editable
        let h = _SUIHostingController(root: { [weak d] in
            editor(d, url).environment(\._undoManager, d?.undoManager).environment(\._documentConfiguration, DocumentConfiguration(fileURL: url, isEditable: editable))
        })
        s.changed = { [weak h] in h?.graph.invalidate() }
        addChild(h)
        h.view.frame = view.bounds
        h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(h.view)
        h.didMove(toParent: self)
        host = h
        print("isim: document opened \(url.lastPathComponent)")
    }
    override func documentDidOpen() {
        guard let d = document as? _SUIDocument else { return }
        if let asyncOpen = spec.asyncOpen {
            let url = d.fileURL, type = d.contentType
            Task { @MainActor in
                do {
                    let s = try await asyncOpen(url, type)
                    guard self.document === d else { return }
                    d.asyncState = s
                    self.showAsync(d, s)
                } catch { NSLog("isim SwiftUI: the document could not be read: %@", "\(error)") }
            }
            return
        }
        show(d)
    }
    override var document: UIDocument? {
        didSet {
            if document == nil || document?.documentState.contains(.closed) == true {
                host?.willMove(toParent: nil); host?.view.removeFromSuperview(); host?.removeFromParent(); host = nil
            }
        }
    }
    func showAsync(_ d: _SUIDocument, _ s: _AsyncDocumentState) {
        host?.willMove(toParent: nil); host?.view.removeFromSuperview(); host?.removeFromParent(); host = nil
        let url = d.fileURL, editable = spec.editable, editor = s.editor
        let h = _SUIHostingController(root: { [weak d] in
            editor().environment(\._undoManager, d?.undoManager).environment(\._documentConfiguration, DocumentConfiguration(fileURL: url, isEditable: editable))
        })
        addChild(h)
        h.view.frame = view.bounds
        h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(h.view)
        h.didMove(toParent: self)
        host = h
        print("isim: document opened \(url.lastPathComponent)")
    }
    func open(_ url: URL) {
        document = _SUIDocument(fileURL: url, spec: spec)
        openDocument { _ in }
    }
    override func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        if let u = documentURLs.first { open(u) }
    }
    override func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        open(destinationURL)
    }
    /// Create Document: a new file with the new document's contents ("Untitled", the first writable type's extension)
    override func documentBrowser(_ controller: UIDocumentBrowserViewController,
                                  didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        let type = spec.writable.first ?? spec.readable.first ?? .data
        let ext = type.preferredFilenameExtension ?? "data"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Untitled.\(ext)")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {}
        if let makeAsync = spec.asyncNewFile {
            Task { @MainActor in
                do { try await makeAsync(url, type); importHandler(url, .move) }
                catch { NSLog("isim SwiftUI: the new document could not be written: %@", "\(error)"); importHandler(nil, .none) }
            }
            return
        }
        guard let make = spec.newFile else { importHandler(nil, .none); return }
        do { try make().write(to: url, options: [], originalContentsURL: nil); importHandler(url, .move) }
        catch { NSLog("isim SwiftUI: the new document could not be written: %@", "\(error)"); importHandler(nil, .none) }
    }
}

struct _DocumentGroupHost: UIViewControllerRepresentable {
    let spec: _DocumentSpec
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: _SUIDocumentViewController(spec: spec))
    }
    func updateUIViewController(_ c: UINavigationController, context: Context) {}
}
