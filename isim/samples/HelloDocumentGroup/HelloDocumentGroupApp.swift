// Sample: a SwiftUI document-based app on isim — DocumentGroup(newDocument:) with a FileDocument (plain text read from
// and written to a FileWrapper), a TextEditor bound to it, \.documentConfiguration and \.undoManager.
// MODE=reference uses a ReferenceFileDocument (an ObservableObject with snapshots) instead; MODE=viewer opens
// documents read-only with DocumentGroup(viewing:); MODE=url (iOS 27) uses an @Observable `Document` with a
// FileWrapperDocumentReader / FileWrapperDocumentWriter, made by DocumentGroup(editor:makeDocument:).
import SwiftUI
import UniformTypeIdentifiers

let mode = ProcessInfo.processInfo.environment["MODE"] ?? "file"

struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String = "Hello") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        text = String(decoding: data, as: UTF8.self)
        print("read \"\(text)\" as \(configuration.contentType.identifier)")
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        print("write \"\(text)\"")
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

final class Notes: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    @Published var text: String
    init(text: String = "Notes") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
        print("read reference \"\(text)\"")
    }
    func snapshot(contentType: UTType) throws -> String { text }
    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        print("write snapshot \"\(snapshot)\"")
        return FileWrapper(regularFileWithContents: Data(snapshot.utf8))
    }
}

struct Editor: View {
    @Binding var text: String
    @Environment(\.documentConfiguration) var config
    @Environment(\.undoManager) var undo
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Text", text: $text, axis: .vertical).accessibilityIdentifier("doc-text")
            Text("file \(config?.fileURL?.lastPathComponent ?? "-") editable \(config?.isEditable == true ? "yes" : "no") undo \(undo == nil ? "no" : "yes")")
                .font(.footnote).accessibilityIdentifier("doc-info")
            Spacer()
        }
        .padding()
        .onChange(of: text) { print("text \"\(text)\"") }
    }
}

struct NotesEditor: View {
    @ObservedObject var notes: Notes
    @Environment(\.undoManager) var undo
    var body: some View {
        VStack {
            Text(notes.text).accessibilityIdentifier("notes-text")
            Button("Append") {
                let old = notes.text
                notes.text += "!"
                undo?.registerUndo(withTarget: notes) { $0.text = old }
            }
            .accessibilityIdentifier("append")
        }
    }
}

@available(iOS 27.0, *)
@Observable final class Note: Document {
    static let readableContentTypes: [UTType] = [.plainText]
    var text = "New note"
    func reader(configuration: sending ReadConfiguration) -> sending FileWrapperDocumentReader<String> {
        FileWrapperDocumentReader(configuration) { file in String(decoding: file.regularFileContents ?? Data(), as: UTF8.self) }
    }
    @MainActor func apply(snapshot: sending String, previous: sending String?) async throws {
        print("apply \"\(snapshot)\" previous \(previous ?? "nil")")
        text = snapshot
    }
    func writer(configuration: sending WriteConfiguration) -> sending FileWrapperDocumentWriter<String> {
        FileWrapperDocumentWriter(configuration) { snapshot, existing in
            print("write \"\(snapshot)\" over \(existing == nil ? "nothing" : "the file")")
            return FileWrapper(regularFileWithContents: Data(snapshot.utf8))
        }
    }
    @MainActor func snapshot(contentType: UTType) async throws -> sending String { text }
}
@available(iOS 27.0, *)
struct NoteEditor: View {
    @Bindable var note: Note
    @Environment(\.undoManager) var undo
    var body: some View {
        TextField("Note", text: $note.text).padding().accessibilityIdentifier("note-text")
            .onChange(of: note.text) { old, _ in undo?.registerUndo(withTarget: note) { $0.text = old } }
    }
}

@main
struct HelloDocumentGroupApp: App {
    var body: some Scene {
        if #available(iOS 27.0, *), mode == "url" {
            DocumentGroup { (note: Note) in NoteEditor(note: note) } makeDocument: { config, _ in
                print("make document for \(config.fileURL?.lastPathComponent ?? "a new file")")
                return Note()
            }
        } else if mode == "reference" {
            DocumentGroup(newDocument: { Notes() }) { file in NotesEditor(notes: file.document) }
        } else if mode == "viewer" {
            DocumentGroup(viewing: TextFile.self) { file in Editor(text: file.$document.text) }
        } else {
            DocumentGroup(newDocument: TextFile()) { file in Editor(text: file.$document.text) }
        }
    }
}
