// isim AppIntents: app entities annotated on the views that show them (iOS 18.4, "Making onscreen content available to
// Siri and Apple Intelligence"). isim has no Apple Intelligence to read them: they are kept on the view and shown in
// the view dump (script `dump`: entity=Type:identifier), adapted.
import Foundation
import UIKit
import ObjectiveC

/// identifies one app entity: its type and its identifier
public struct EntityIdentifier: Hashable, Sendable, CustomStringConvertible {
    public let identifier: String
    let typeName: String
    let _entityType: (any AppEntity.Type)?
    public var entityType: any AppEntity.Type { _entityType! }
    public init<Entity: AppEntity>(for entity: Entity) {
        identifier = "\(entity.id)"; typeName = String(describing: Entity.self); _entityType = Entity.self
    }
    public init<Entity: AppEntity>(for type: Entity.Type, identifier: Entity.ID) {
        self.identifier = "\(identifier)"; typeName = String(describing: Entity.self); _entityType = Entity.self
    }
    public static func == (a: EntityIdentifier, b: EntityIdentifier) -> Bool { a.identifier == b.identifier && a.typeName == b.typeName }
    public func hash(into h: inout Hasher) { h.combine(identifier); h.combine(typeName) }
    public var description: String { "\(typeName):\(identifier)" }
}
/// system types that can carry the app entity they show
public protocol AppEntityAnnotatable {
    var appEntityIdentifier: EntityIdentifier? { get set }
}

/// an app entity in a region of a custom view
public struct AppEntityUIElement: Sendable {
    public struct State: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let selected = State(rawValue: 1)
    }
    public var identifier: EntityIdentifier
    public var bounds: CGRect
    public var state: State
    public var subelements: [AppEntityUIElement]
    public init(identifier: EntityIdentifier, bounds: CGRect, state: State = [], subelements: [AppEntityUIElement] = []) {
        self.identifier = identifier; self.bounds = bounds; self.state = state; self.subelements = subelements
    }
    public init<Entity: AppEntity>(_ entity: Entity, bounds: CGRect, state: State = [], subelements: [AppEntityUIElement] = []) {
        self.init(identifier: EntityIdentifier(for: entity), bounds: bounds, state: state, subelements: subelements)
    }
}
/// what the system asks a view's element provider for
public struct AppEntityUIElementsContext: Sendable {
    public enum ElementsRequest: Sendable, Hashable { case visible, selected }
    public var bounds: CGRect
    public var requests: Set<ElementsRequest>
}

nonisolated(unsafe) private var kEntity: UInt8 = 0, kProvider: UInt8 = 0
private final class _EntityBox { let id: EntityIdentifier?; init(_ i: EntityIdentifier?) { id = i } }
private final class _ProviderBox { let f: (UIView, AppEntityUIElementsContext) -> [AppEntityUIElement]; init(_ f: @escaping (UIView, AppEntityUIElementsContext) -> [AppEntityUIElement]) { self.f = f } }

extension UIView: AppEntityAnnotatable {
    /// the app entity the view shows
    @MainActor @preconcurrency public var appEntityIdentifier: EntityIdentifier? {
        get { (objc_getAssociatedObject(self, &kEntity) as? _EntityBox)?.id }
        set { objc_setAssociatedObject(self, &kEntity, _EntityBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    /// the app entities in the view's content (for custom views drawing several)
    @MainActor @preconcurrency public var appEntityUIElementProvider: ((UIView, AppEntityUIElementsContext) -> [AppEntityUIElement])? {
        get { (objc_getAssociatedObject(self, &kProvider) as? _ProviderBox)?.f }
        set { objc_setAssociatedObject(self, &kProvider, newValue.map(_ProviderBox.init), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    /// the view dump's entity=… (UIApplication.m): the view's entity, then its provider's visible elements
    @objc func _isim_appEntityDescription() -> String? {
        var parts: [String] = []
        if let i = appEntityIdentifier { parts.append(i.description) }
        if let p = appEntityUIElementProvider {
            for e in p(self, AppEntityUIElementsContext(bounds: bounds, requests: [.visible])) {
                parts.append(e.identifier.description + (e.state.contains(.selected) ? "(selected)" : ""))
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ",")
    }
}
