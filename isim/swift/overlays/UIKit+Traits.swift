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
@available(iOS 26.0, *)
extension UITraitTabAccessoryEnvironment: UITraitDefinition { public static var defaultValue: UITabAccessory.Environment { .unspecified } }
@available(iOS 17.0, *)
extension UITraitSplitViewControllerLayoutEnvironment: UITraitDefinition { public static var defaultValue: UISplitViewController.LayoutEnvironment { .none } }
@available(iOS 17.0, *)
extension UITraitImageDynamicRange: UITraitDefinition { public static var defaultValue: UIImage.DynamicRange { .unspecified } }
@available(iOS 17.0, *)
extension UITraitTypesettingLanguage: UITraitDefinition { public static var defaultValue: Locale.Language? { nil } }
@available(iOS 17.0, *)
extension UITraitSceneCaptureState: UITraitDefinition { public static var defaultValue: UISceneCaptureState { .unspecified } }
@available(iOS 17.0, *)
extension UITraitToolbarItemPresentationSize: UITraitDefinition { public static var defaultValue: UINSToolbarItemPresentationSize { .unspecified } }
@available(iOS 26.0, *)
extension UITraitHDRHeadroomUsageLimit: UITraitDefinition { public static var defaultValue: UIHDRHeadroomUsageLimit { .unspecified } }
@available(iOS 26.0, *)
extension UITraitResolvesNaturalAlignmentWithBaseWritingDirection: UITraitDefinition { public static var defaultValue: Bool { false } }
@available(iOS 26.0, *)
extension UITraitSystemPrefersReducedResourceUsage: UITraitDefinition { public static var defaultValue: Bool { false } }
@available(iOS 27.2, *)
extension UITraitNavigationTitleAlignment: UITraitDefinition { public static var defaultValue: UINavigationItem.TitleAlignment { .automatic } }

// the typesetting language as a Locale.Language (stored as its identifier)
@available(iOS 17.0, *)
extension UITraitCollection {
    public var typesettingLanguage: Locale.Language? { __typesettingLanguage.map { Locale.Language(identifier: $0) } }
    public convenience init(typesettingLanguage: Locale.Language) { self.init(traitsFrom: [UITraitCollection.__withTypesettingLanguage(typesettingLanguage.minimalIdentifier)]) }
    /// the system traits whose values differ from another collection's (custom traits: those used with this process)
    public func changedTraits(from traitCollection: UITraitCollection?) -> [UITrait] {
        _isim_changedTraitIdentifiers(from: traitCollection).compactMap { _isimTraitTypes[$0 as String] }
    }
    public typealias TraitMutations = (inout any UIMutableTraits) -> Void
}
@available(iOS 17.0, *)
extension UIMutableTraits {
    public var typesettingLanguage: Locale.Language? {
        get { __typesettingLanguage.map { Locale.Language(identifier: $0) } }
        set { __typesettingLanguage = newValue?.minimalIdentifier }
    }
}
/// the trait types by storage key (system traits, and Swift traits once used)
nonisolated(unsafe) var _isimTraitTypes: [String: UITrait] = {
    var d: [String: UITrait] = [:]
    var system: [UITrait] = [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self, UITraitUserInterfaceIdiom.self,
        UITraitDisplayScale.self, UITraitLayoutDirection.self, UITraitForceTouchCapability.self, UITraitPreferredContentSizeCategory.self, UITraitDisplayGamut.self,
        UITraitAccessibilityContrast.self, UITraitUserInterfaceLevel.self, UITraitLegibilityWeight.self, UITraitActiveAppearance.self,
        UITraitSplitViewControllerLayoutEnvironment.self, UITraitImageDynamicRange.self, UITraitTypesettingLanguage.self,
        UITraitSceneCaptureState.self, UITraitToolbarItemPresentationSize.self]
    if #available(iOS 18.0, *) { system.append(UITraitListEnvironment.self) }
    if #available(iOS 26.0, *) {
        system += [UITraitTabAccessoryEnvironment.self, UITraitHDRHeadroomUsageLimit.self, UITraitResolvesNaturalAlignmentWithBaseWritingDirection.self,
                   UITraitSystemPrefersReducedResourceUsage.self]
    }
    if #available(iOS 27.2, *) { system.append(UITraitNavigationTitleAlignment.self) }
    for t in system { if let c = t as? NSObject.Type { d[UITraitCollection._isim_identifier(forTrait: c)] = t } }
    return d
}()
/// what trait change registrations hand their handlers (the environment and its previous traits)
@available(iOS 17.0, *)
public protocol UITraitChangeObservable {
    typealias TraitChangeHandler<TraitEnvironment: UITraitEnvironment> = (TraitEnvironment, UITraitCollection) -> Void
}
@available(iOS 17.0, *) extension UIView: UITraitChangeObservable {}
@available(iOS 17.0, *) extension UIViewController: UITraitChangeObservable {}
@available(iOS 17.0, *) extension UIWindowScene: UITraitChangeObservable {}
@available(iOS 17.0, *) extension UIPresentationController: UITraitChangeObservable {}

// MARK: - Bridging trait keys and values
/// the key Objective-C stores a trait under: the class's identifier for trait classes, the Swift identifier otherwise
@usableFromInline internal func _isimTraitKey(_ t: any UITraitDefinition.Type) -> String {
    if let c = t as? NSObject.Type { return UITraitCollection._isim_identifier(forTrait: c) }
    UITraitCollection._isim_registerTraitIdentifier(t.identifier, affectsColorAppearance: t.affectsColorAppearance)
    if _isimTraitTypes[t.identifier] == nil { _isimTraitTypes[t.identifier] = t }
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
/// the system traits' value types (imported NS_ENUMs: their RawRepresentable conformance is not found by dynamic casts)
nonisolated(unsafe) let _isimSystemEnums: [ObjectIdentifier: (Int) -> Any?] = {
    var d: [ObjectIdentifier: (Int) -> Any?] = [:]
    func add<E: RawRepresentable>(_ t: E.Type) where E.RawValue: BinaryInteger { d[ObjectIdentifier(t)] = { (i: Int) in E(rawValue: E.RawValue(truncatingIfNeeded: i)) } }
    add(UIUserInterfaceStyle.self); add(UIUserInterfaceSizeClass.self); add(UIUserInterfaceIdiom.self); add(UITraitEnvironmentLayoutDirection.self)
    add(UIForceTouchCapability.self); add(UIDisplayGamut.self); add(UIAccessibilityContrast.self); add(UIUserInterfaceLevel.self)
    add(UILegibilityWeight.self); add(UIUserInterfaceActiveAppearance.self)
    add(UISplitViewController.LayoutEnvironment.self); add(UIImage.DynamicRange.self); add(UISceneCaptureState.self)
    add(UINSToolbarItemPresentationSize.self)
    if #available(iOS 18.0, *) { add(UIListEnvironment.self) }
    if #available(iOS 26.0, *) { add(UITabAccessory.Environment.self); add(UIHDRHeadroomUsageLimit.self) }
    if #available(iOS 27.2, *) { add(UINavigationItem.TitleAlignment.self) }
    return d
}()
/// an Int-backed enum from its number (imported NS_ENUMs and Swift enums)
func _isimEnum<R: RawRepresentable>(_ t: R.Type, _ n: NSNumber) -> R? {
    if let raw = n.integerValue as? R.RawValue { return R(rawValue: raw) }
    if let raw = n.uintValue as? R.RawValue { return R(rawValue: raw) }
    return nil
}
/// (the two-argument form, kept for apps built with earlier releases)
@usableFromInline internal func _isimUnboxTrait<V>(_ o: Any?, _ fallback: V) -> V { _isimUnboxTrait(o, fallback, system: false) }
@usableFromInline internal func _isimUnboxTrait<V>(_ o: Any?, _ fallback: V, system: Bool) -> V {
    guard let o else { return fallback }
    if o is NSNull { if let O = V.self as? _IsimOptionalTrait.Type, let none = O._isimNone as? V { return none }; return fallback }
    if let b = o as? _IsimTraitBox { return b.value as? V ?? fallback }
    if let n = o as? NSNumber {
        if V.self == CGFloat.self { return CGFloat(n.doubleValue) as! V }
        if V.self == Double.self { return n.doubleValue as! V }
        if V.self == Int.self { return n.integerValue as! V }
        if V.self == Bool.self { return n.boolValue as! V }
        // imported Int-backed enums (the system traits' values)
        if let r = V.self as? any RawRepresentable.Type, let v = _isimEnum(r, n) as? V { return v }
        // the system traits' imported NS_ENUMs (their RawRepresentable conformance is not found dynamically)
        if system, let make = _isimSystemEnums[ObjectIdentifier(V.self)], let v = make(n.integerValue) as? V { return v }
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
        let o = _isim_object(forTraitIdentifier: _isimTraitKey(trait))
        return _isimUnboxTrait(o, T.defaultValue, system: trait is NSObject.Type)
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
        get { _isimUnboxTrait(_isim_object(forTraitIdentifier: _isimTraitKey(trait)), T.defaultValue, system: trait is NSObject.Type) }
        set { _isim_setObject(_isimBoxTrait(newValue, system: trait is NSObject.Type), forTraitIdentifier: _isimTraitKey(trait)) }
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
@available(iOS 17.0, *)
extension UIPresentationController {
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
