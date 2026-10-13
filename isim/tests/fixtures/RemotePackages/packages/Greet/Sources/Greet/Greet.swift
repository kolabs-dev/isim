import Base
import Vendor

public enum Greeting {
    public static let version = "@VERSION@"
    public static func line() -> String { "greet \(version) base \(Base.value) vendor \(vendor_value())" }
}
