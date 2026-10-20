// isim CoreTransferable (self-authored, iOS API names): the Transferable protocol with data, file, proxy and Codable
// representations and their modifiers (visibility, suggested file names, exporting conditions), enough to import items
// (PhotosPickerItem.loadTransferable, drops, paste) and export them as data (ShareLink, drags).
// Conformances: Data, String, URL (and SwiftUI's Image via PhotosUI).
@_exported import UniformTypeIdentifiers
import Foundation
import Combine

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
    /// the `.visibility(_:)` modifier: who may receive this representation
    public var visibility: TransferRepresentationVisibility = .all
    /// the `.suggestedFileName(_:)` modifier: a name for the file a share or a drop creates
    public var suggestedName: (@Sendable (Item) -> String?)? = nil
    /// the `.exportingCondition(_:)` modifier: whether this item exports through this representation
    public var condition: (@Sendable (Item) -> Bool)? = nil
    public init(contentType: UTType, importing: (@Sendable (Data) async throws -> Item)?, exporting: (@Sendable (Item) async throws -> Data)?) {
        self.contentType = contentType; self.importing = importing; self.exporting = exporting
    }
}

/// Who may receive a representation: other apps, the developer's team's apps, the app group, or only this app.
public struct TransferRepresentationVisibility: Sendable, Equatable {
    let _kind: Int
    public static let all = TransferRepresentationVisibility(_kind: 0)
    public static let team = TransferRepresentationVisibility(_kind: 1)
    @available(iOS 17.0, *)
    public static let group = TransferRepresentationVisibility(_kind: 2)
    public static let ownProcess = TransferRepresentationVisibility(_kind: 3)
    /// isim: NSItemProviderRepresentationVisibility's value (all 0, team 1, group 2, ownProcess 3)
    public var _isimRawValue: Int { _kind }
}

extension TransferRepresentation {
    func _modified(_ change: (inout _TransferEntry<Item>) -> Void) -> _TupleRepresentation<Item> {
        _TupleRepresentation(entries: _isimEntries.map { var e = $0; change(&e); return e })
    }
    /// who may receive this representation (isim: one app at a time, so only `.ownProcess` keeps it from other apps'
    /// drops and shares)
    public func visibility(_ visibility: TransferRepresentationVisibility) -> some TransferRepresentation<Item> {
        _modified { $0.visibility = visibility }
    }
    /// the name of the file this representation's data goes into when it is shared or dropped as a file
    public func suggestedFileName(_ fileName: String) -> some TransferRepresentation<Item> {
        _modified { $0.suggestedName = { _ in fileName } }
    }
    public func suggestedFileName(_ fileName: @escaping @Sendable (Item) -> String?) -> some TransferRepresentation<Item> {
        _modified { $0.suggestedName = fileName }
    }
    /// exports an item through this representation only when `condition` holds for it
    public func exportingCondition(_ condition: @escaping @Sendable (Item) -> Bool) -> some TransferRepresentation<Item> {
        _modified { $0.condition = condition }
    }
}

/// A Codable item as data: JSON by default, or the given encoder and decoder.
public struct CodableRepresentation<Item, Encoder, Decoder>: TransferRepresentation, @unchecked Sendable
    where Item: Transferable & Codable, Encoder: TopLevelEncoder, Decoder: TopLevelDecoder, Encoder.Output == Data, Decoder.Input == Data {
    let entries: [_TransferEntry<Item>]
    public init(contentType: UTType, encoder: Encoder, decoder: Decoder) {
        entries = [_TransferEntry(contentType: contentType, importing: { data in try decoder.decode(Item.self, from: data) },
                                  exporting: { item in try encoder.encode(item) })]
    }
    public init(for itemType: Item.Type = Item.self, contentType: UTType, encoder: Encoder, decoder: Decoder) {
        self.init(contentType: contentType, encoder: encoder, decoder: decoder)
    }
    public var _isimEntries: [_TransferEntry<Item>] { entries }
}
extension CodableRepresentation where Encoder == JSONEncoder, Decoder == JSONDecoder {
    public init(contentType: UTType) { self.init(contentType: contentType, encoder: JSONEncoder(), decoder: JSONDecoder()) }
    public init(for itemType: Item.Type = Item.self, contentType: UTType) { self.init(contentType: contentType) }
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
        for e in _isimExportEntries where e.contentType.conforms(to: contentType) || contentType.conforms(to: e.contentType) { return try await e.exporting!(self) }
        throw NSError(domain: "NSCocoaErrorDomain", code: 512, userInfo: nil)
    }
    /// isim: this item's exporting representations (their exporting conditions hold), in order
    public var _isimExportEntries: [_TransferEntry<Self>] { Self._isimEntries.filter { $0.exporting != nil && ($0.condition?(self) ?? true) } }
    /// isim: the content types this item exports to (exporting conditions applied)
    public var _isimExportedContentTypes: [UTType] { _isimExportEntries.map(\.contentType) }
    /// isim: the file name suggested for this item's data of `contentType` (with the type's extension)
    public func _isimSuggestedFileName(for contentType: UTType) -> String? {
        guard let e = _isimExportEntries.first(where: { $0.contentType == contentType }), let name = e.suggestedName?(self), !name.isEmpty else { return nil }
        if let ext = contentType.preferredFilenameExtension, (name as NSString).pathExtension.isEmpty { return name + "." + ext }
        return name
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
