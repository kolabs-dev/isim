// Sample: SwiftUI's file dialogs on isim — fileImporter (one file, or several, opened in place with security-scoped
// URLs), fileExporter (a FileDocument saved as a copy under its default name; a collection of documents), fileMover
// (a file of the app's Documents moved where the user chooses) and their onCancellation; and text fields whose
// prompt is the placeholder, with textContentType. The app's Documents are shared (UIFileSharingEnabled), so they
// appear as "File Dialogs" in On My iPhone.
import SwiftUI
import UniformTypeIdentifiers

struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

func setUp() {
    try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    for (name, text) in [("Notes.txt", "milk, bread"), ("Todo.txt", "call Sam"), ("Move.txt", "to be moved")] {
        try? Data(text.utf8).write(to: documents.appendingPathComponent(name))
    }
}

func read(_ url: URL) -> String {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    return String(decoding: (try? Data(contentsOf: url)) ?? Data(), as: UTF8.self)
}

struct ContentView: View {
    @State private var importing = false
    @State private var importingMany = false
    @State private var exporting = false
    @State private var exportingMany = false
    @State private var moving = false
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        VStack(spacing: 12) {
            Button("Import") { importing = true }.accessibilityIdentifier("import")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
                    switch result {
                    case .success(let url): print("imported \(url.lastPathComponent) \"\(read(url))\" presented=\(importing)")
                    case .failure(let e): print("import failed \(e)")
                    }
                }
            Button("Import several") { importingMany = true }.accessibilityIdentifier("import-many")
                .fileImporter(isPresented: $importingMany, allowedContentTypes: [.plainText], allowsMultipleSelection: true,
                              onCompletion: { result in
                    let urls = (try? result.get()) ?? []
                    print("imported \(urls.map(\.lastPathComponent).sorted()) \(urls.map(read).sorted())")
                }, onCancellation: { print("importer cancelled presented=\(importingMany)") })
            Button("Export") { exporting = true }.accessibilityIdentifier("export")
                .fileExporter(isPresented: $exporting, document: TextFile(text: "exported text"), contentType: .plainText,
                              defaultFilename: "Report") { result in
                    switch result {
                    case .success(let url): print("exported \(url.lastPathComponent) in \(url.deletingLastPathComponent().lastPathComponent) \"\(read(url))\"")
                    case .failure(let e): print("export failed \(e)")
                    }
                }
            Button("Export two") { exportingMany = true }.accessibilityIdentifier("export-many")
                .fileExporter(isPresented: $exportingMany, documents: [TextFile(text: "one"), TextFile(text: "two")], contentType: .plainText,
                              onCompletion: { result in
                    let urls = (try? result.get()) ?? []
                    print("exported \(urls.map(\.lastPathComponent).sorted())")
                }, onCancellation: { print("exporter cancelled") })
            Button("Move") { moving = true }.accessibilityIdentifier("move")
                .fileMover(isPresented: $moving, file: documents.appendingPathComponent("Move.txt")) { result in
                    switch result {
                    case .success(let url):
                        let gone = !FileManager.default.fileExists(atPath: documents.appendingPathComponent("Move.txt").path)
                        print("moved \(url.lastPathComponent) to \(url.deletingLastPathComponent().lastPathComponent) gone=\(gone)")
                    case .failure(let e): print("move failed \(e)")
                    }
                }
            TextField("Email", text: $email, prompt: Text("name@example.com"))
                .textContentType(.emailAddress).keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("email")
            SecureField("Password", text: $password, prompt: Text("Required"))
                .textContentType(.password).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("password")
            TextField(text: $email, prompt: Text("Labelled by a view")) { Label("Email", systemImage: "envelope") }
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("labelled")
        }
        .padding()
        .onChange(of: email) { print("email \"\(email)\"") }
    }
}

@main
struct HelloFileDialogsApp: App {
    init() { setUp() }
    var body: some Scene { WindowGroup { ContentView() } }
}
