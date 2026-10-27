// isim AppIntents: IntentValueQuery (iOS 26), the queries the system runs with a value it has (Visual Intelligence's
// SemanticContentDescriptor) to get the app's matching results. Running one: the request { values = INPUT-NAME; ... }
// (the input's own keys: labels for Visual Intelligence) through the isim-intent: launch marker; every query of the
// app whose Input is that type runs, and the results (their display representations) come back as the run's result
// step { type = result; outcome = success; values = [{ id, title, subtitle }] }. The app's metadata lists the inputs
// its queries take (valueQueries), so the system knows whom to ask.
import Foundation

/// A query the system runs with a value (`Input`) to get the app's results for it.
@available(iOS 26.0, *)
@_alwaysEmitConformanceMetadata public protocol IntentValueQuery: Sendable {
    associatedtype Input
    associatedtype Result: ResultsCollection
    associatedtype ResultValue = Result.Result
    init()
    func values(for input: Input) async throws -> Result
}

/// a value the system can hand an IntentValueQuery (made from a run request); its modules conform
public protocol _IsimIntentValueInput {
    static func _isimMake(_ request: [String: Any]) -> Self?
    static var _isimInputName: String { get }
}

@available(iOS 26.0, *)
enum _IsimValueQueries {
    static var queries: [any IntentValueQuery.Type] {
        _IsimConformances.types(conformingTo: "IntentValueQuery").compactMap { $0 as? any IntentValueQuery.Type }
    }
    /// the inputs the app's queries take, for the metadata
    static var inputs: [String] {
        Array(Set(queries.compactMap { inputName($0) })).sorted()
    }
    static func inputName<Q: IntentValueQuery>(_ q: Q.Type) -> String? { (Q.Input.self as? any _IsimIntentValueInput.Type)?._isimInputName }
    static func results<Q: IntentValueQuery>(_ q: Q.Type, _ request: [String: Any]) async throws -> [_IsimOption]? {
        guard let make = Q.Input.self as? any _IsimIntentValueInput.Type, let input = make._isimMake(request) as? Q.Input else { return nil }
        let result = try await Q().values(for: input)
        return result._isimItems.enumerated().map { i, item in
            let rep = (item.value as? any AppEntity)?.displayRepresentation ?? item.description
            return _IsimOption(id: (item.value as? any AppEntity).map { "\($0.id)" } ?? "\(i)", title: rep.title.description,
                               subtitle: rep.subtitle?.description ?? "", value: item.value)
        }
    }
    @MainActor static func run(_ input: String, _ request: [String: Any], _ ch: _IsimChannel) async {
        var values: [[String: Any]] = [], failure: String?
        for q in queries where inputName(q) == input {
            do {
                if let found = try await results(q, request) {
                    NSLog("isim AppIntents: %@ found %ld value(s) for %@", _isimTypeName(q), found.count, input)
                    values += found.map { $0.plist }
                }
            } catch {
                failure = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                NSLog("isim AppIntents: %@ failed: %@", _isimTypeName(q), failure!)
            }
        }
        var step: [String: Any] = ["type": "result", "outcome": failure != nil && values.isEmpty ? "failure" : "success", "values": values, "dialog": ""]
        if let failure { step["error"] = failure }
        ch.write(step)
    }
}
