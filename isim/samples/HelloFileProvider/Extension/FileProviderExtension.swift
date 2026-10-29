// The sample's replicated file provider extension: its items are the server's files (Shared.swift), its working set
// enumerates the changes since a sync anchor (the length of the server's change log), it has a custom action, Star
// (NSExtensionFileProviderActions in its Info.plist), and while the user is signed out its enumerators fail with
// notAuthenticated. Every call is printed ("fpx ...").
import Foundation
import FileProvider
import UniformTypeIdentifiers

func log(_ s: String) { print("fpx \(s)"); fflush(stdout) }

final class FileProviderItem: NSObject, NSFileProviderItem {
    let itemIdentifier: NSFileProviderItemIdentifier
    let parentItemIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let contentType: UTType
    let documentSize: NSNumber?
    let contentModificationDate: Date?
    let itemVersion: NSFileProviderItemVersion
    var capabilities: NSFileProviderItemCapabilities {
        contentType == .folder ? [.allowsReading, .allowsContentEnumerating, .allowsAddingSubItems, .allowsDeleting]
                               : [.allowsReading, .allowsWriting, .allowsRenaming, .allowsDeleting]
    }

    init(_ id: NSFileProviderItemIdentifier) throws {
        let url = Server.url(id)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.noSuchItem.rawValue)
        }
        let folder = attrs[.type] as? FileAttributeType == .typeDirectory
        itemIdentifier = id
        parentItemIdentifier = id.rawValue.contains("/") ? NSFileProviderItemIdentifier((id.rawValue as NSString).deletingLastPathComponent) : .rootContainer
        filename = url.lastPathComponent
        contentType = folder ? .folder : (UTType(filenameExtension: url.pathExtension) ?? .data)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        documentSize = folder ? nil : NSNumber(value: size)
        contentModificationDate = attrs[.modificationDate] as? Date
        let stamp = "\(contentModificationDate?.timeIntervalSince1970 ?? 0)-\(size)"
        itemVersion = NSFileProviderItemVersion(contentVersion: Data(stamp.utf8), metadataVersion: Data(filename.utf8))
    }
}

final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension, NSFileProviderCustomAction {
    let domain: NSFileProviderDomain

    required init(domain: NSFileProviderDomain) {
        self.domain = domain
        super.init()
        Server.seed()
        log("init \(domain.identifier.rawValue)")
    }
    func invalidate() { log("invalidate") }

    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest,
              completionHandler: @escaping (NSFileProviderItem?, (any Error)?) -> Void) -> Progress {
        do { completionHandler(try FileProviderItem(identifier), nil) } catch { completionHandler(nil, error) }
        return Progress()
    }

    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest,
                       completionHandler: @escaping (URL?, NSFileProviderItem?, (any Error)?) -> Void) -> Progress {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: Server.url(itemIdentifier), to: tmp)
            log("fetch \(itemIdentifier.rawValue) viewer=\(request.isFileViewerRequest)")
            completionHandler(tmp, try FileProviderItem(itemIdentifier), nil)
        } catch { completionHandler(nil, nil, error) }
        return Progress()
    }

    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [],
                    request: NSFileProviderRequest,
                    completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, (any Error)?) -> Void) -> Progress {
        let dst = Server.url(itemTemplate.parentItemIdentifier).appendingPathComponent(itemTemplate.filename)
        do {
            if itemTemplate.contentType == .folder { try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true) }
            else if let url {
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.copyItem(at: url, to: dst)
            }
            let id = Server.id(of: dst)
            Server.record(id)
            log("create \(id.rawValue)")
            completionHandler(try FileProviderItem(id), [], false, nil)
        } catch { completionHandler(nil, [], false, error) }
        return Progress()
    }

    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?,
                    options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest,
                    completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, (any Error)?) -> Void) -> Progress {
        let dst = Server.url(item.itemIdentifier)
        do {
            if changedFields.contains(.contents), let newContents {
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.copyItem(at: newContents, to: dst)
            }
            Server.record(item.itemIdentifier)
            log("modify \(item.itemIdentifier.rawValue) contents=\(changedFields.contains(.contents))")
            completionHandler(try FileProviderItem(item.itemIdentifier), [], false, nil)
        } catch { completionHandler(nil, [], false, error) }
        return Progress()
    }

    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [],
                    request: NSFileProviderRequest, completionHandler: @escaping ((any Error)?) -> Void) -> Progress {
        try? FileManager.default.removeItem(at: Server.url(identifier))
        Server.record(identifier, deleted: true)
        log("delete \(identifier.rawValue)")
        completionHandler(nil)
        return Progress()
    }

    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        guard Server.signedIn else {                             // the system shows the UI extension's sign-in
            log("not signed in")
            throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue)
        }
        guard containerItemIdentifier == .workingSet || FileManager.default.fileExists(atPath: Server.url(containerItemIdentifier).path) else {
            throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.noSuchItem.rawValue)
        }
        return FileProviderEnumerator(containerItemIdentifier)
    }

    func performAction(identifier actionIdentifier: NSFileProviderExtensionActionIdentifier, onItemsWithIdentifiers itemIdentifiers: [NSFileProviderItemIdentifier],
                       completionHandler: @escaping ((any Error)?) -> Void) -> Progress {
        log("action \(actionIdentifier.rawValue) on \(itemIdentifiers.map(\.rawValue).joined(separator: ","))")
        completionHandler(nil)
        return Progress()
    }
}

final class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    let container: NSFileProviderItemIdentifier
    init(_ container: NSFileProviderItemIdentifier) { self.container = container }
    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let fm = FileManager.default
        var urls: [URL] = []
        if container == .workingSet {
            if let e = fm.enumerator(at: Server.files, includingPropertiesForKeys: nil) { for case let u as URL in e { urls.append(u) } }
        } else {
            urls = (try? fm.contentsOfDirectory(at: Server.url(container), includingPropertiesForKeys: nil)) ?? []
        }
        let items = urls.filter { !$0.lastPathComponent.hasPrefix(".") }.compactMap { try? FileProviderItem(Server.id(of: $0)) }
        log("enumerate \(container == .rootContainer ? "root" : container == .workingSet ? "working set" : container.rawValue): \(items.count)")
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        let from = Int(String(decoding: syncAnchor.rawValue, as: UTF8.self)) ?? 0
        let changes = Server.changes()
        guard from <= changes.count else {
            observer.finishEnumeratingWithError(NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.syncAnchorExpired.rawValue))
            return
        }
        var updated: [NSFileProviderItem] = [], deleted: [NSFileProviderItemIdentifier] = []
        for c in changes.dropFirst(from) {
            let id = NSFileProviderItemIdentifier(c["id"] as? String ?? "")
            if let item = try? FileProviderItem(id) { updated.append(item) } else { deleted.append(id) }
        }
        log("changes since \(from): \(updated.count) updated, \(deleted.count) deleted")
        observer.didUpdate(updated)
        observer.didDeleteItems(withIdentifiers: deleted)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(Data("\(changes.count)".utf8)), moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping @Sendable (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(NSFileProviderSyncAnchor(Data("\(Server.changes().count)".utf8)))
    }
}
