// isim Foundation: Swift conveniences for NSPredicate / NSExpression (format strings with Swift arguments).
// Swift's #Predicate macro (Foundation.Predicate) is not available on isim.

extension NSPredicate {
    public convenience init(format predicateFormat: String, _ args: CVarArg...) {
        self.init(format: predicateFormat, argumentArray: args.map { _isimPredicateArgument($0) })
    }
}
extension NSExpression {
    public convenience init(format expressionFormat: String, _ args: CVarArg...) {
        self.init(format: expressionFormat, argumentArray: args.map { _isimPredicateArgument($0) })
    }
}
/// Swift values passed to format strings, as the Objective-C objects the parser expects.
func _isimPredicateArgument(_ v: CVarArg) -> Any {
    switch v {
    case let s as String: return s as NSString
    case let i as Int: return NSNumber(value: i)
    case let i as Int32: return NSNumber(value: i)
    case let i as Int64: return NSNumber(value: i)
    case let u as UInt: return NSNumber(value: u)
    case let d as Double: return NSNumber(value: d)
    case let f as Float: return NSNumber(value: f)
    case let b as Bool: return NSNumber(value: b)
    case let d as Date: return d as NSDate
    case let a as [Any]: return a as NSArray
    default: return v
    }
}
