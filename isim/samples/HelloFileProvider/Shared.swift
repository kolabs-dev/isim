// The sample's "server" (in the app and its file provider extension): the provider's files live in the app group,
// Server/Files, with a change log, Server/log.json ([{ seq, id, deleted }]), that the extension's working set
// enumerates changes from. A real provider would talk to a web service instead.
import Foundation
import FileProvider

let appGroup = "group.dev.isim.samples.hellofileprovider"

enum Server {
    static var root: URL { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.appendingPathComponent("Server") }
    static var files: URL { root.appendingPathComponent("Files") }
    static var logURL: URL { root.appendingPathComponent("log.json") }
    /// the user signed out of the service: the extension's enumerators fail with notAuthenticated until signing in
    static var signedOutURL: URL { root.appendingPathComponent("signed-out") }
    static var signedIn: Bool { !FileManager.default.fileExists(atPath: signedOutURL.path) }

    static func url(_ id: NSFileProviderItemIdentifier) -> URL { id == .rootContainer ? files : files.appendingPathComponent(id.rawValue) }
    static func id(of url: URL) -> NSFileProviderItemIdentifier {
        let base = files.standardizedFileURL.path, p = url.standardizedFileURL.path
        return p == base ? .rootContainer : NSFileProviderItemIdentifier(String(p.dropFirst(base.count + 1)))
    }

    static func changes() -> [[String: Any]] {
        guard let d = try? Data(contentsOf: logURL) else { return [] }
        return (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] ?? []
    }
    static func record(_ id: NSFileProviderItemIdentifier, deleted: Bool = false) {
        var log = changes()
        log.append(["seq": log.count + 1, "id": id.rawValue, "deleted": deleted])
        try? JSONSerialization.data(withJSONObject: log).write(to: logURL)
    }
    /// the first files: hello.txt and Notes/todo.txt
    static func seed() {
        guard !FileManager.default.fileExists(atPath: files.path) else { return }
        try? FileManager.default.createDirectory(at: files.appendingPathComponent("Notes"), withIntermediateDirectories: true)
        try? Data("Hello from the server".utf8).write(to: files.appendingPathComponent("hello.txt"))
        try? Data("buy milk".utf8).write(to: files.appendingPathComponent("Notes/todo.txt"))
        try? Data("[]".utf8).write(to: logURL)
    }
}
