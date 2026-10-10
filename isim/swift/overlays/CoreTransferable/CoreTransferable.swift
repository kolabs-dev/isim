// isim CoreTransferable (self-authored, iOS API names): the Transferable protocol with data, file and proxy
// representations, enough to import items (PhotosPickerItem.loadTransferable) and export them as data.
// Conformances: Data, String, URL (and SwiftUI's Image via PhotosUI).
@_exported import UniformTypeIdentifiers
import Foundation

public protocol TransferRepresentation<Item>: Sendable {
    associatedtype Item: Transferable
    /// isim: the importers/exporters this representation contributes (custom representations: none)
    var _isimEntries: [_TransferEntry<Item>] { get }
}
extension TransferRepresentation {
    public var _isimEntries: [_TransferEntry<Item>] { [] }
}

public protocol Transferable {
    associatedtype Representation: TransferRepresentation
    @TransferRepresentationBuilder<Self> static var transferRepresentation: Representation { get }
}

public struct _TransferEntry<Item>: @unchecked Sendable {
    public let contentType: UTType
    public let importing: (@Sendable (Data) async throws -> Item)?
    public let exporting: (@Sendable (Item) async throws -> Data)?
}


public struct DataRepresentation<Item: Transferable>: TransferRepresentation, @unchecked Sendable {
    let entries: [_TransferEntry<Item>]
    public init(contentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data, importing: @escaping @Sendable (Data) async throws -> Item) {
        entries = [_TransferEntry(contentType: contentType, importing: importing, exporting: exporting)]
    }
    public init(importedContentType: UTType, importing: @escaping @Sendable (Data) async throws -> Item) {
        entries = [_TransferEntry(contentType: importedContentType, importing: importing, exporting: nil)]
    }
    public init(exportedContentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data) {
        entries = [_TransferEntry(contentType: exportedContentType, importing: nil, exporting: exporting)]
    }
    public var _isimEntries: [_TransferEntry<Item>] { entries }
}

public struct SentTransferredFile: Sendable {
    public let file: URL
    public let allowAccessingOriginalFile: Bool
    public init(_ file: URL, allowAccessingOriginalFile: Bool = false) { self.file = file; self.allowAccessingOriginalFile = allowAccessingOriginalFile }
}
public struct ReceivedTransferredFile: Sendable {
    public let file: URL
    public let isOriginalFile: Bool
}
public struct FileRepresentation<Item: Transferable>: TransferRepresentation, @unchecked Sendable {
    let entries: [_TransferEntry<Item>]
    public init(contentType: UTType, shouldAttemptToOpenInPlace: Bool = false, exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile,
                importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) {
        entries = [_TransferEntry(contentType: contentType, importing: FileRepresentation.importer(contentType, importing), exporting: { item in
            try Data(contentsOf: try await exporting(item).file)
        })]
    }
    public init(importedContentType: UTType, shouldAttemptToOpenInPlace: Bool = false, importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) {
        entries = [_TransferEntry(contentType: importedContentType, importing: FileRepresentation.importer(importedContentType, importing), exporting: nil)]
    }
    public init(exportedContentType: UTType, shouldAllowToOpenInPlace: Bool = false, exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile) {
        entries = [_TransferEntry(contentType: exportedContentType, importing: nil, exporting: { item in try Data(contentsOf: try await exporting(item).file) })]
    }
    static func importer(_ t: UTType, _ f: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) -> @Sendable (Data) async throws -> Item {
        { data in
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "." + (t.preferredFilenameExtension ?? "data"))
            try data.write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            return try await f(ReceivedTransferredFile(file: url, isOriginalFile: false))
        }
    }
    public var _isimEntries: [_TransferEntry<Item>] { entries }
}

public struct ProxyRepresentation<Item: Transferable, ProxyRepresentation: Transferable>: TransferRepresentation, @unchecked Sendable {
    let entries: [_TransferEntry<Item>]
    public init(exporting: @escaping @Sendable (Item) async throws -> ProxyRepresentation) {
        entries = ProxyRepresentation._isimEntries.compactMap { e in
            guard let ex = e.exporting else { return nil }
            return _TransferEntry(contentType: e.contentType, importing: nil, exporting: { item in try await ex(try await exporting(item)) })
        }
    }
    public init(exporting: @escaping @Sendable (Item) async throws -> ProxyRepresentation, importing: @escaping @Sendable (ProxyRepresentation) async throws -> Item) {
        entries = ProxyRepresentation._isimEntries.map { e in
            _TransferEntry(contentType: e.contentType,
                           importing: e.importing.map { im in { @Sendable data in try await importing(try await im(data)) } },
                           exporting: e.exporting.map { ex in { @Sendable item in try await ex(try await exporting(item)) } })
        }
    }
    public init(importing: @escaping @Sendable (ProxyRepresentation) async throws -> Item) {
        entries = ProxyRepresentation._isimEntries.compactMap { e in
            guard let im = e.importing else { return nil }
            return _TransferEntry(contentType: e.contentType, importing: { data in try await importing(try await im(data)) }, exporting: nil)
        }
    }
    public var _isimEntries: [_TransferEntry<Item>] { entries }
}

public struct _TupleRepresentation<Item: Transferable>: TransferRepresentation, @unchecked Sendable {
    let entries: [_TransferEntry<Item>]
    public var _isimEntries: [_TransferEntry<Item>] { entries }
}

@resultBuilder
public struct TransferRepresentationBuilder<Item: Transferable> {
    public static func buildExpression<R: TransferRepresentation>(_ r: R) -> _TupleRepresentation<Item> where R.Item == Item {
        _TupleRepresentation(entries: r._isimEntries)
    }
    public static func buildBlock(_ parts: _TupleRepresentation<Item>...) -> _TupleRepresentation<Item> {
        _TupleRepresentation(entries: parts.flatMap(\.entries))
    }
    public static func buildOptional(_ r: _TupleRepresentation<Item>?) -> _TupleRepresentation<Item> { r ?? _TupleRepresentation(entries: []) }
    public static func buildEither(first r: _TupleRepresentation<Item>) -> _TupleRepresentation<Item> { r }
    public static func buildEither(second r: _TupleRepresentation<Item>) -> _TupleRepresentation<Item> { r }
    public static func buildLimitedAvailability(_ r: _TupleRepresentation<Item>) -> _TupleRepresentation<Item> { r }
}

extension Transferable {
    public static var _isimEntries: [_TransferEntry<Self>] { (transferRepresentation._isimEntries as Any as? [_TransferEntry<Self>]) ?? [] }
    /// content types this type can be imported from
    public static var importedContentTypes: [UTType] { _isimEntries.filter { $0.importing != nil }.map(\.contentType) }
    public static var exportedContentTypes: [UTType] { _isimEntries.filter { $0.exporting != nil }.map(\.contentType) }
    /// isim: imports from data of `type` (the first representation whose content type `type` conforms to)
    public static func _isimImport(_ data: Data, contentType type: UTType) async throws -> Self? {
        for e in _isimEntries { if let im = e.importing, type.conforms(to: e.contentType) { return try await im(data) } }
        return nil
    }
    public func exported(as contentType: UTType) async throws -> Data {
        for e in Self._isimEntries { if let ex = e.exporting, e.contentType.conforms(to: contentType) || contentType.conforms(to: e.contentType) { return try await ex(self) } }
        throw NSError(domain: "NSCocoaErrorDomain", code: 512, userInfo: nil)
    }
}

extension Data: Transferable {
    public static var transferRepresentation: _TupleRepresentation<Data> {
        _TupleRepresentation(entries: [_TransferEntry(contentType: .data, importing: { $0 }, exporting: { $0 })])
    }
}
extension String: Transferable {
    public static var transferRepresentation: _TupleRepresentation<String> {
        _TupleRepresentation(entries: [_TransferEntry(contentType: .plainText, importing: { String(decoding: $0, as: UTF8.self) }, exporting: { Data($0.utf8) })])
    }
}
extension URL: Transferable {
    public static var transferRepresentation: _TupleRepresentation<URL> {
        _TupleRepresentation(entries: [_TransferEntry(contentType: .url, importing: { d in
            guard let u = URL(string: String(decoding: d, as: UTF8.self)) else { throw NSError(domain: "NSCocoaErrorDomain", code: 259, userInfo: nil) }
            return u
        }, exporting: { Data($0.absoluteString.utf8) })])
    }
}

// MARK: - NSItemProvider and Transferable

struct _IsimUnsafe<T>: @unchecked Sendable { let value: T }

extension NSItemProvider {
    /// loads the first content type the type can import (its transfer representations, in order)
    @discardableResult
    public func loadTransferable<T: Transferable>(type transferableType: T.Type, completionHandler: @escaping @Sendable (Result<T, Error>) -> Void) -> Progress {
        guard let e = T._isimEntries.first(where: { $0.importing != nil && hasItemConforming(to: $0.contentType) }), let importing = e.importing else {
            DispatchQueue.global().async { completionHandler(.failure(CocoaError(.fileReadUnknown))) }
            return Progress(totalUnitCount: 1)
        }
        return loadDataRepresentation(for: e.contentType) { data, error in
            guard let data else { completionHandler(.failure(error ?? CocoaError(.fileReadUnknown))); return }
            Task {
                do { let item = try await importing(data); completionHandler(.success(_IsimUnsafe(value: item).value)) }
                catch { completionHandler(.failure(error)) }
            }
        }
    }
    /// registers the item's exported representations (made when a receiver loads one)
    public func register<T: Transferable>(_ transferable: @autoclosure @escaping @Sendable () -> T) {
        for e in T._isimEntries {
            guard let exporting = e.exporting else { continue }
            registerDataRepresentation(for: e.contentType) { done in
                let box = _IsimUnsafe(value: done)
                Task {
                    do { box.value(try await exporting(transferable()), nil) } catch { box.value(nil, error) }
                }
                return nil
            }
        }
    }
}

/// Never is Transferable (it has no representation), so APIs can default a Transferable type parameter to it (SwiftUI's
/// SharePreview without an image or icon).
public struct _NeverTransferRepresentation: TransferRepresentation { public typealias Item = Never; public init() {} }
extension Never: Transferable {
    public typealias Representation = _TupleRepresentation<Never>
    public static var transferRepresentation: _TupleRepresentation<Never> { _NeverTransferRepresentation() }
}
