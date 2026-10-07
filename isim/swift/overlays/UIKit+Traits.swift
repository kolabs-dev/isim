// isim UIKit overlay, traits part (self-authored): the iOS 17 Swift trait API — UITraitDefinition (custom traits),
// trait subscripts on UITraitCollection / UIMutableTraits / traitOverrides, UITraitCollection(mutations:),
// modifyingTraits(_:) and registerForTraitChanges with [UITrait]. Values cross into Objective-C boxed: numbers and
// enums as NSNumber, strings as NSString, other values as Swift boxes.

// MARK: - Trait definitions
@available(iOS 17.0, *)
public protocol UITraitDefinition {
    associatedtype Value
    static var defaultValue: Value { get }
    static var identifier: String { get }
    static var name: String { get }
    static var affectsColorAppearance: Bool { get }
}
@available(iOS 17.0, *)
extension UITraitDefinition {
    public static var identifier: String { String(reflecting: Self.self) }
    public static var name: String { String(describing: Self.self) }
    public static var affectsColorAppearance: Bool { false }
}
@available(iOS 17.0, *)
public protocol UICGFloatTraitDefinition: UITraitDefinition where Value == CGFloat {}
@available(iOS 17.0, *)
public protocol UINSIntegerTraitDefinition: UITraitDefinition where Value == Int {}
@available(iOS 17.0, *)
public protocol UIObjectTraitDefinition: UITraitDefinition where Value: AnyObject {}
@available(iOS 17.0, *)
public typealias UITrait = any UITraitDefinition.Type

// the system traits (Objective-C classes) as Swift trait definitions
extension UITraitUserInterfaceStyle: UITraitDefinition { public static var defaultValue: UIUserInterfaceStyle { .unspecified } }
extension UITraitHorizontalSizeClass: UITraitDefinition { public static var defaultValue: UIUserInterfaceSizeClass { .unspecified } }
extension UITraitVerticalSizeClass: UITraitDefinition { public static var defaultValue: UIUserInterfaceSizeClass { .unspecified } }
extension UITraitUserInterfaceIdiom: UITraitDefinition { public static var defaultValue: UIUserInterfaceIdiom { .unspecified } }
extension UITraitDisplayScale: UITraitDefinition { public static var defaultValue: CGFloat { 0 } }
extension UITraitLayoutDirection: UITraitDefinition { public static var defaultValue: UITraitEnvironmentLayoutDirection { .unspecified } }
extension UITraitForceTouchCapability: UITraitDefinition { public static var defaultValue: UIForceTouchCapability { .unknown } }
extension UITraitPreferredContentSizeCategory: UITraitDefinition { public static var defaultValue: UIContentSizeCategory { .unspecified } }
extension UITraitDisplayGamut: UITraitDefinition { public static var defaultValue: UIDisplayGamut { .unspecified } }
extension UITraitAccessibilityContrast: UITraitDefinition { public static var defaultValue: UIAccessibilityContrast { .unspecified } }
extension UITraitUserInterfaceLevel: UITraitDefinition { public static var defaultValue: UIUserInterfaceLevel { .unspecified } }
extension UITraitLegibilityWeight: UITraitDefinition { public static var defaultValue: UILegibilityWeight { .unspecified } }
extension UITraitActiveAppearance: UITraitDefinition { public static var defaultValue: UIUserInterfaceActiveAppearance { .unspecified } }
@available(iOS 18.0, *)
extension UITraitListEnvironment: UITraitDefinition { public static var defaultValue: UIListEnvironment { .unspecified } }

// MARK: - Bridging trait keys and values
/// the key Objective-C stores a trait under: the class's identifier for trait classes, the Swift identifier otherwise
@usableFromInline internal func _isimTraitKey(_ t: any UITraitDefinition.Type) -> String {
    if let c = t as? AnyClass { return UITraitCollection._isim_identifier(forTrait: c) }
    UITraitCollection._isim_registerTraitIdentifier(t.identifier, affectsColorAppearance: t.affectsColorAppearance)
    return t.identifier
}
/// what registrations pass to Objective-C: the traits' storage keys
@usableFromInline internal func _isimTraitObjects(_ traits: [any UITraitDefinition.Type]) -> [Any] {
    traits.map { _isimTraitKey($0) as NSString }
}
internal protocol _IsimOptionalTrait { static var _isimNone: Self { get } }
extension Optional: _IsimOptionalTrait { static var _isimNone: Self { .none } }

/// a Swift trait value stored in Objective-C: equal when the numbers (Int-backed enums, numbers) or the Hashable
/// values match, so trait changes are detected
final class _IsimTraitBox: NSObject {
    let value: Any
    let number: NSNumber?
    let hashable: AnyHashable?
    init(_ value: Any, number: NSNumber?) { self.value = value; self.number = number; self.hashable = value as? AnyHashable; super.init() }
    override func isEqual(_ object: Any?) -> Bool {
        guard let b = object as? _IsimTraitBox else { return false }
        if let n = number, let m = b.number { return n.isEqual(to: m) }
        if let h = hashable, let k = b.hashable { return h == k }
        return self === b
    }
    override var hash: Int { number?.hash ?? hashable?.hashValue ?? ObjectIdentifier(self).hashValue }
}
/// a plain number for numbers and Int-backed enums
func _isimTraitNumber(_ v: Any) -> NSNumber? {
    switch v {
    case let x as Int: return NSNumber(value: x)
    case let x as CGFloat: return NSNumber(value: Double(x))
    case let x as Double: return NSNumber(value: x)
    case let x as Bool: return NSNumber(value: x)
    default: break
    }
    if let r = v as? any RawRepresentable, let i = r.rawValue as? Int { return NSNumber(value: i) }
    return nil
}
/// a value for Objective-C: system traits (trait classes) as NSNumber / NSString, Swift traits in a box
@usableFromInline internal func _isimBoxTrait(_ v: Any, system: Bool) -> AnyObject? {
    let m = Mirror(reflecting: v)
    if m.displayStyle == .optional { return m.children.first.flatMap { _isimBoxTrait($0.value, system: system) } }
    if system {
        if let n = _isimTraitNumber(v) { return n }
        if let x = v as? String { return x as NSString }
        if let r = v as? any RawRepresentable, let x = r.rawValue as? String { return x as NSString }
        return v as AnyObject
    }
    return _IsimTraitBox(v, number: _isimTraitNumber(v))
}
@usableFromInline internal func _isimUnboxTrait<V>(_ o: Any?, _ fallback: V) -> V {
    guard let o else { return fallback }
    if o is NSNull { if let O = V.self as? _IsimOptionalTrait.Type, let none = O._isimNone as? V { return none }; return fallback }
    if let b = o as? _IsimTraitBox { return b.value as? V ?? fallback }
    if let n = o as? NSNumber {
        if V.self == CGFloat.self { return CGFloat(n.doubleValue) as! V }
        if V.self == Double.self { return n.doubleValue as! V }
        if V.self == Int.self { return n.intValue as! V }
        if V.self == Bool.self { return n.boolValue as! V }
        // imported Int-backed enums (the system traits' values)
        if V.self is any RawRepresentable.Type && MemoryLayout<V>.size == MemoryLayout<Int>.size && _isPOD(V.self) { return unsafeBitCast(n.intValue, to: V.self) }
    }
    if let s = o as? NSString {
        if V.self == UIContentSizeCategory.self { return UIContentSizeCategory(rawValue: s as String) as! V }
        if V.self == String.self { return (s as String) as! V }
    }
    if let v = o as? V { return v }
    return fallback
}

// MARK: - Reading and writing traits
@available(iOS 17.0, *)
extension UITraitCollection {
    /// the trait's value, or its default when this collection does not specify it
    public subscript<T: UITraitDefinition>(trait: T.Type) -> T.Value {
        _isimUnboxTrait(_isim_object(forTraitIdentifier: _isimTraitKey(trait)), T.defaultValue)
    }
    public convenience init(mutations: (inout any UIMutableTraits) -> Void) {
        self.init(traitsFrom: [UITraitCollection._isim_traitCollection(traits: { m in var mm: any UIMutableTraits = m; mutations(&mm) })])
    }
    public func modifyingTraits(_ mutations: (inout any UIMutableTraits) -> Void) -> UITraitCollection {
        _isim_modifyingTraits { m in var mm: any UIMutableTraits = m; mutations(&mm) }
    }
    public static var systemTraitsAffectingColorAppearance: [UITrait] {
        [UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self, UITraitUserInterfaceLevel.self, UITraitDisplayGamut.self, UITraitActiveAppearance.self]
    }
    public static var systemTraitsAffectingImageLookup: [UITrait] {
        [UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self, UITraitDisplayScale.self, UITraitUserInterfaceIdiom.self, UITraitLayoutDirection.self,
         UITraitDisplayGamut.self, UITraitLegibilityWeight.self, UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    }
}
@available(iOS 17.0, *)
extension UIMutableTraits {
    public subscript<T: UITraitDefinition>(trait: T.Type) -> T.Value {
        get { _isimUnboxTrait(_isim_object(forTraitIdentifier: _isimTraitKey(trait)), T.defaultValue) }
        set { _isim_setObject(_isimBoxTrait(newValue, system: trait is AnyClass), forTraitIdentifier: _isimTraitKey(trait)) }
    }
}
@available(iOS 17.0, *)
extension UITraitOverrides {
    public func contains(_ trait: UITrait) -> Bool { _isim_containsTraitIdentifier(_isimTraitKey(trait)) }
    public func remove(_ trait: UITrait) { _isim_removeTraitIdentifier(_isimTraitKey(trait)) }
}

// MARK: - Trait change registration
@available(iOS 17.0, *)
extension UIView {
    @discardableResult
    public func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [UITrait], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: { env, previous in handler(env as! T, previous) }, target: nil, action: nil)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], target: Any, action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: target, action: action)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: nil, action: action)
    }
}
@available(iOS 17.0, *)
extension UIViewController {
    @discardableResult
    public func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [UITrait], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: { env, previous in handler(env as! T, previous) }, target: nil, action: nil)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], target: Any, action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: target, action: action)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: nil, action: action)
    }
}
@available(iOS 17.0, *)
extension UIWindowScene {
    @discardableResult
    public func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [UITrait], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: { env, previous in handler(env as! T, previous) }, target: nil, action: nil)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], target: Any, action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: target, action: action)
    }
    @discardableResult
    public func registerForTraitChanges(_ traits: [UITrait], action: Selector) -> any UITraitChangeRegistration {
        _isim_register(forTraits: _isimTraitObjects(traits), handler: nil, target: nil, action: action)
    }
}
