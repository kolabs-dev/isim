// Sample: Foundation's URL file APIs on isim (issue #267) — URL.DirectoryHint with URL(filePath:directoryHint:relativeTo:)
// and appending(path:directoryHint:), URL.standardized / standardizedFileURL, security-scoped access, bookmarks (made,
// written to a file, resolved after the file is renamed: stale, and the resource values kept in them) and
// NSFileVersion (adding, listing, restoring and removing versions). Each line it prints is checked by the test.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 100, width: 360, height: 40))
        label.text = "File URLs"
        vc.view.addSubview(label)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        do { try run() } catch { print("error \(error)") }
        return true
    }

    func run() throws {
        let docs = URL.documentsDirectory
        // directory hints
        let dir = URL(filePath: "/tmp/isim-hint", directoryHint: .isDirectory)
        let file = URL(filePath: "/tmp/isim-hint", directoryHint: .notDirectory)
        let inferred = URL(filePath: "/tmp/isim-hint/")
        let checked = URL(filePath: docs.path, directoryHint: .checkFileSystem)
        let relative = URL(filePath: "notes/a.txt", relativeTo: docs)
        print("hint dir=\(dir.hasDirectoryPath) file=\(file.hasDirectoryPath) inferred=\(inferred.hasDirectoryPath) checked=\(checked.hasDirectoryPath) " +
              "relative=\(relative.path.hasSuffix("/Documents/notes/a.txt")) appended=\(docs.appending(path: "sub", directoryHint: .isDirectory).hasDirectoryPath)")
        // standardized
        let web = URL(string: "https://example.com/a/./b/../c?q=1")!.standardized
        let local = URL(fileURLWithPath: "/tmp/x/../y/./z.txt").standardizedFileURL
        print("standardized web=\(web.absoluteString) file=\(local.path)")

        // a file, its bookmark, a rename
        let note = docs.appending(path: "note.txt")
        try "first".write(to: note, atomically: true, encoding: .utf8)
        print("scope start=\(note.startAccessingSecurityScopedResource()) web=\(URL(string: "https://example.com")!.startAccessingSecurityScopedResource())")
        note.stopAccessingSecurityScopedResource()
        let bookmark = try note.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: [.nameKey, .fileSizeKey])
        var stale = false
        let same = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
        print("bookmark magic=\(String(decoding: bookmark.prefix(4), as: UTF8.self)) same=\(same.lastPathComponent) stale=\(stale)")
        let renamed = docs.appending(path: "renamed.txt")
        try? FileManager.default.removeItem(at: renamed)
        try FileManager.default.moveItem(at: note, to: renamed)
        let moved = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
        let values = URL.resourceValues(forKeys: [.nameKey, .fileSizeKey], fromBookmarkData: bookmark)
        print("bookmark moved=\(moved.lastPathComponent) stale=\(stale) name=\(values?.name ?? "-") size=\(values?.fileSize ?? -1)")
        let bookmarkFile = docs.appending(path: "note.bookmark")
        try URL.writeBookmarkData(bookmark, to: bookmarkFile)
        print("bookmark file round trip=\(try URL.bookmarkData(withContentsOf: bookmarkFile) == bookmark)")
        try FileManager.default.removeItem(at: renamed)
        do { _ = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale); print("bookmark gone resolved") }
        catch { print("bookmark gone error=\((error as NSError).code)") }

        // file versions
        let doc = docs.appending(path: "draft.txt")
        try "version 1".write(to: doc, atomically: true, encoding: .utf8)
        let copy = docs.appending(path: "draft-copy.txt")
        try? FileManager.default.removeItem(at: copy)
        try FileManager.default.copyItem(at: doc, to: copy)
        let added = try NSFileVersion.addOfItem(at: doc, withContentsOf: copy, options: .byMoving)
        try "version 2".write(to: doc, atomically: true, encoding: .utf8)
        let current = NSFileVersion.currentVersionOfItem(at: doc)
        let others = NSFileVersion.otherVersionsOfItem(at: doc) ?? []
        print("versions current=\(current?.localizedName ?? "-") others=\(others.count) conflicts=\(NSFileVersion.unresolvedConflictVersionsOfItem(at: doc)?.count ?? -1) " +
              "found=\(NSFileVersion.version(itemAt: doc, forPersistentIdentifier: added.persistentIdentifier) != nil) copyMoved=\(!FileManager.default.fileExists(atPath: copy.path))")
        _ = try others[0].replaceItem(at: doc, options: [])
        print("versions restored=\(try String(contentsOf: doc, encoding: .utf8))")
        try others[0].remove()
        print("versions after remove=\(NSFileVersion.otherVersionsOfItem(at: doc)?.count ?? -1)")
        try NSFileVersion.removeOtherVersionsOfItem(at: doc)
        do { try current?.remove(); print("versions current removed") } catch { print("versions current remove error=\((error as NSError).code)") }
    }
}
