import CCore

public enum Core {
    /// Scales through the C target (CCORE_SCALE comes from the package's cSettings).
    public static func scaled(_ value: Int) -> Int { Int(ccore_scaled(Int32(value))) }

    public static var description: String {
        #if CORE_FEATURE
        let feature = "on"
        #else
        let feature = "off"
        #endif
        return "Core(\(String(cString: ccore_name())), feature \(feature))"
    }
}
