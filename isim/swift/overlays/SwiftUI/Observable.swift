// isim SwiftUI: Observation integration (iOS 17) — renders track the @Observable properties they read
// (see _Graph.render), @Bindable makes bindings to them, and .environment(_:) / @Environment(T.self) pass them down.
import Observation

extension View {
    public func environment<T: AnyObject & Observable>(_ object: T?) -> some View {
        _env { $0._objects[ObjectIdentifier(T.self)] = object }
    }
}

@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) where Value: AnyObject & Observable { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) where Value: AnyObject & Observable { self.wrappedValue = wrappedValue }
    public init(projectedValue: Bindable<Value>) { self = projectedValue }
    public var projectedValue: Bindable<Value> { self }
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> where Value: AnyObject {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}
extension Bindable: DynamicProperty {}
