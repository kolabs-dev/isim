// isim CoreData Swift overlay: typed fetches, async perform, ObservableObject/Identifiable managed objects,
// and the diffable snapshot bridge. SwiftUI's @FetchRequest / @SectionedFetchRequest: SwiftUI.swift.
@_exported import CoreData
import Foundation
import Combine
import UIKit

extension NSManagedObjectContext {
    public func fetch<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>) throws -> [T] {
        let r = try __fetch(request as! NSFetchRequest<NSFetchRequestResult>)
        return r.map { $0 as! T }
    }
    public func count<T: NSFetchRequestResult>(for request: NSFetchRequest<T>) throws -> Int {
        var error: NSError?
        let n = __count(for: request as! NSFetchRequest<NSFetchRequestResult>, error: &error)
        if let error { throw error }
        return Int(n)
    }

    public enum ScheduledTaskType: Sendable { case immediate, enqueued }

    /// Runs the block on the context's queue and returns its result (iOS 15).
    public func perform<T>(schedule: ScheduledTaskType = .immediate, _ block: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<T, Error>) in
            self.perform { c.resume(with: Result { try block() }) }
        }
    }
    public func perform<T>(schedule: ScheduledTaskType = .immediate, _ block: @escaping () -> T) async -> T {
        await withCheckedContinuation { (c: CheckedContinuation<T, Never>) in
            self.perform { c.resume(returning: block()) }
        }
    }
    public func performAndWait<T>(_ block: () throws -> T) rethrows -> T {
        var result: Result<T, Error>?
        return try withoutActuallyEscaping(block) { b in
            self.performAndWait { result = Result { try b() } }
            return try result!.get()
        }
    }
}

extension NSPersistentContainer {
    /// Runs the block on a new background context (iOS 15 async variant).
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async rethrows -> T {
        let ctx = newBackgroundContext()
        // `block` is escaping: the background perform may release its closure after the continuation resumes,
        // so it must not go through withoutActuallyEscaping (that traps when the closure outlives the call).
        nonisolated(unsafe) var result: Result<T, Error>?
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            ctx.perform { result = Result { try block(ctx) }; c.resume() }
        }
        return try withoutActuallyEscaping(block) { _ in try result!.get() }
    }
}

extension NSManagedObject: Identifiable {}

extension NSManagedObject: ObservableObject {
    /// Fires before any modeled property of the object changes (like Core Data on iOS).
    public var objectWillChange: ObservableObjectPublisher {
        if let p = _isim_observationToken as? ObservableObjectPublisher { return p }
        let p = ObservableObjectPublisher()
        _isim_observationToken = p
        _isim_setWillChangeHandler { [weak p] in p?.send() }
        return p
    }
}

/// NSDiffableDataSourceSnapshotReference <-> NSDiffableDataSourceSnapshot (`snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>`).
extension NSDiffableDataSourceSnapshot: @retroactive _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSDiffableDataSourceSnapshotReference {
        let r = NSDiffableDataSourceSnapshotReference()
        for s in sectionIdentifiers {
            r.appendItems(withIdentifiers: itemIdentifiers(inSection: s).map { $0 as AnyObject }, intoSectionWithIdentifier: s as AnyObject)
        }
        return r
    }
    public static func _forceBridgeFromObjectiveC(_ source: NSDiffableDataSourceSnapshotReference, result: inout Self?) {
        var s = Self()
        for sec in source.sectionIdentifiers {
            guard let id = sec as? SectionIdentifierType else { continue }
            s.appendSections([id])
            s.appendItems(source.itemIdentifiersInSection(withIdentifier: sec).compactMap { $0 as? ItemIdentifierType }, toSection: id)
        }
        let reloaded = source.reloadedItemIdentifiers.compactMap { $0 as? ItemIdentifierType }
        if !reloaded.isEmpty { s.reloadItems(reloaded) }
        result = s
    }
    public static func _conditionallyBridgeFromObjectiveC(_ source: NSDiffableDataSourceSnapshotReference, result: inout Self?) -> Bool {
        _forceBridgeFromObjectiveC(source, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSDiffableDataSourceSnapshotReference?) -> Self {
        var r: Self?
        if let source { _forceBridgeFromObjectiveC(source, result: &r) }
        return r ?? Self()
    }
}
