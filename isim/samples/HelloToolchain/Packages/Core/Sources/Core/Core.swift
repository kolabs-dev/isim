import CCore

public enum Core {
    /// Scales through the C target (CCORE_SCALE comes from the package's cSettings).
    public static func scaled(_ value: Int) -> Int { Int(ccore_scaled(Int32(value))) }
    /// a POSIX extended regular expression, matched by the C target (regex.h)
    public static func matches(_ pattern: String, _ text: String) -> Bool { ccore_matches(pattern, text) == 1 }
    /// uname, sysctlbyname, wide characters and kqueue's EV_SET from the C target
    public static var platformOK: Bool { ccore_platform_ok() != 0 }

    public static var description: String {
        #if CORE_FEATURE
        let feature = "on"
        #else
        let feature = "off"
        #endif
        return "Core(\(String(cString: ccore_name())), feature \(feature))"
    }
}

/// `#stringify(2 + 3)` is `(5, "2 + 3")` (CoreMacros).
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "CoreMacros", type: "StringifyMacro")

/// Adds `static let caseCount` to an enum (CoreMacros).
@attached(member, names: named(caseCount))
public macro CaseCount() = #externalMacro(module: "CoreMacros", type: "CaseCountMacro")
