// isim SwiftUI: file dialogs (issue #248) — fileImporter, fileExporter and fileMover, presented as isim's
// UIDocumentPickerViewController (the device's files, as the Files app shows them). The importer opens the files in
// place (security-scoped URLs, as iOS gives them); the exporter writes the document (FileDocument /
// ReferenceFileDocument) to a temporary file and exports a copy where the user chooses; the mover moves files there.
// Each sets isPresented back to false when the picker closes, then reports the result (or the cancellation).
import UIKit
import UniformTypeIdentifiers

@MainActor final class _FileDialogPresenter: NSObject, @preconcurrency UIDocumentPickerDelegate {
    var picked: ([URL]) -> Void = { _ in }
    var cancelled: () -> Void = {}
    weak var controller: UIDocumentPickerViewController?

    static func top() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
    /// presents the picker `make` builds (once while it is up), or dismisses it
    func update(presented: Bool, make: () -> UIDocumentPickerViewController?) {
        if !presented {
            if let c = controller { controller = nil; c.dismiss(animated: true) }
            return
        }
        guard controller == nil, let top = _FileDialogPresenter.top(), let c = make() else { return }
        c.delegate = self
        controller = c
        top.present(c, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.controller = nil
        picked(urls)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.controller = nil
        cancelled()
    }
}

struct _FileDialogModifier: ViewModifier {
    let isPresented: Binding<Bool>
    let make: () -> UIDocumentPickerViewController?
    let picked: ([URL]) -> Void
    let cancelled: () -> Void
    @State private var presenter = _FileDialogPresenter()

    func body(content: Content) -> some View {
        content
            .onAppear { show() }
            .onChange(of: isPresented.wrappedValue) { _, _ in show() }
    }
    func show() {
        let binding = isPresented, picked = picked, cancelled = cancelled
        presenter.picked = { urls in binding.wrappedValue = false; picked(urls) }
        presenter.cancelled = { binding.wrappedValue = false; cancelled() }
        presenter.update(presented: isPresented.wrappedValue, make: make)
    }
}

/// The error a file dialog reports when it could not do what was asked.
struct _FileDialogError: Error, CustomStringConvertible { let description: String }

/// Writes a file wrapper to a temporary folder as `name` (with the content type's extension) for exporting.
func _exportFile(_ wrapper: FileWrapper, name: String?, type: UTType) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("isim-export-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var file = (name?.isEmpty == false ? name! : "Untitled")
    if let ext = type.preferredFilenameExtension, (file as NSString).pathExtension.isEmpty { file += "." + ext }
    let url = dir.appendingPathComponent(file)
    try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
    return url
}

extension View {
    // MARK: importer
    /// Lets the user choose a file of one of the types; the URL is security-scoped (start / stop accessing it).
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, any Error>) -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: allowedContentTypes, allowsMultipleSelection: false) { r in
            onCompletion(r.flatMap { urls in urls.first.map { .success($0) } ?? .failure(_FileDialogError(description: "no file chosen")) })
        }
    }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool,
                             onCompletion: @escaping (Result<[URL], any Error>) -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: allowedContentTypes, allowsMultipleSelection: allowsMultipleSelection,
                     onCompletion: onCompletion, onCancellation: {})
    }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool,
                             onCompletion: @escaping (Result<[URL], any Error>) -> Void, onCancellation: @escaping () -> Void) -> some View {
        modifier(_FileDialogModifier(isPresented: isPresented, make: {
            let c = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: false)
            c.allowsMultipleSelection = allowsMultipleSelection
            return c
        }, picked: { onCompletion(.success($0)) }, cancelled: onCancellation))
    }

    // MARK: exporter
    /// Saves the document where the user chooses (a copy of it, named `defaultFilename`).
    public func fileExporter<D: FileDocument>(isPresented: Binding<Bool>, document: D?, contentType: UTType, defaultFilename: String? = nil,
                                              onCompletion: @escaping (Result<URL, any Error>) -> Void) -> some View {
        fileExporter(isPresented: isPresented, document: document, contentType: contentType, defaultFilename: defaultFilename,
                     onCompletion: onCompletion, onCancellation: {})
    }
    public func fileExporter<D: FileDocument>(isPresented: Binding<Bool>, document: D?, contentType: UTType, defaultFilename: String? = nil,
                                              onCompletion: @escaping (Result<URL, any Error>) -> Void, onCancellation: @escaping () -> Void) -> some View {
        _exporter(isPresented: isPresented, wrappers: {
            try document.map { [try $0.fileWrapper(configuration: FileDocumentWriteConfiguration(contentType: contentType, existingFile: nil))] } ?? []
        }, contentType: contentType, names: [defaultFilename], onCompletion: { r in onCompletion(r.map { $0.first! }) }, onCancellation: onCancellation)
    }
    public func fileExporter<C: Collection>(isPresented: Binding<Bool>, documents: C, contentType: UTType,
                                            onCompletion: @escaping (Result<[URL], any Error>) -> Void) -> some View where C.Element: FileDocument {
        fileExporter(isPresented: isPresented, documents: documents, contentType: contentType, onCompletion: onCompletion, onCancellation: {})
    }
    public func fileExporter<C: Collection>(isPresented: Binding<Bool>, documents: C, contentType: UTType,
                                            onCompletion: @escaping (Result<[URL], any Error>) -> Void, onCancellation: @escaping () -> Void) -> some View
        where C.Element: FileDocument {
        let docs = Array(documents)
        return _exporter(isPresented: isPresented, wrappers: {
            try docs.map { try $0.fileWrapper(configuration: FileDocumentWriteConfiguration(contentType: contentType, existingFile: nil)) }
        }, contentType: contentType, names: docs.indices.map { docs.count > 1 ? "Untitled \($0 + 1)" : nil }, onCompletion: onCompletion, onCancellation: onCancellation)
    }
    public func fileExporter<D: ReferenceFileDocument>(isPresented: Binding<Bool>, document: D?, contentType: UTType, defaultFilename: String? = nil,
                                                       onCompletion: @escaping (Result<URL, any Error>) -> Void) -> some View {
        fileExporter(isPresented: isPresented, document: document, contentType: contentType, defaultFilename: defaultFilename,
                     onCompletion: onCompletion, onCancellation: {})
    }
    public func fileExporter<D: ReferenceFileDocument>(isPresented: Binding<Bool>, document: D?, contentType: UTType, defaultFilename: String? = nil,
                                                       onCompletion: @escaping (Result<URL, any Error>) -> Void, onCancellation: @escaping () -> Void) -> some View {
        _exporter(isPresented: isPresented, wrappers: {
            guard let d = document else { return [] }
            let config = FileDocumentWriteConfiguration(contentType: contentType, existingFile: nil)
            return [try d.fileWrapper(snapshot: try d.snapshot(contentType: contentType), configuration: config)]
        }, contentType: contentType, names: [defaultFilename], onCompletion: { r in onCompletion(r.map { $0.first! }) }, onCancellation: onCancellation)
    }
    func _exporter(isPresented: Binding<Bool>, wrappers: @escaping () throws -> [FileWrapper], contentType: UTType, names: [String?],
                   onCompletion: @escaping (Result<[URL], any Error>) -> Void, onCancellation: @escaping () -> Void) -> some View {
        modifier(_FileDialogModifier(isPresented: isPresented, make: {
            do {
                let ws = try wrappers()
                guard !ws.isEmpty else { return nil }
                let files = try ws.enumerated().map { i, w in try _exportFile(w, name: i < names.count ? names[i] : nil, type: contentType) }
                return UIDocumentPickerViewController(forExporting: files, asCopy: true)
            } catch {
                isPresented.wrappedValue = false
                onCompletion(.failure(error))
                return nil
            }
        }, picked: { onCompletion(.success($0)) }, cancelled: onCancellation))
    }

    // MARK: mover
    /// Moves the file to where the user chooses.
    public func fileMover(isPresented: Binding<Bool>, file: URL?, onCompletion: @escaping (Result<URL, any Error>) -> Void) -> some View {
        fileMover(isPresented: isPresented, file: file, onCompletion: onCompletion, onCancellation: {})
    }
    public func fileMover(isPresented: Binding<Bool>, file: URL?, onCompletion: @escaping (Result<URL, any Error>) -> Void,
                          onCancellation: @escaping () -> Void) -> some View {
        fileMover(isPresented: isPresented, files: file.map { [$0] } ?? [], onCompletion: { r in
            onCompletion(r.flatMap { urls in urls.first.map { .success($0) } ?? .failure(_FileDialogError(description: "no file moved")) })
        }, onCancellation: onCancellation)
    }
    public func fileMover<C: Collection>(isPresented: Binding<Bool>, files: C, onCompletion: @escaping (Result<[URL], any Error>) -> Void) -> some View
        where C.Element == URL {
        fileMover(isPresented: isPresented, files: files, onCompletion: onCompletion, onCancellation: {})
    }
    public func fileMover<C: Collection>(isPresented: Binding<Bool>, files: C, onCompletion: @escaping (Result<[URL], any Error>) -> Void,
                                         onCancellation: @escaping () -> Void) -> some View where C.Element == URL {
        let list = Array(files)
        return modifier(_FileDialogModifier(isPresented: isPresented, make: {
            list.isEmpty ? nil : UIDocumentPickerViewController(forExporting: list, asCopy: false)
        }, picked: { onCompletion(.success($0)) }, cancelled: onCancellation))
    }
}
