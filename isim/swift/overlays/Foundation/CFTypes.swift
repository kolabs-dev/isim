// isim Foundation overlay: Core Foundation types as dictionary keys / set members, as Apple's CoreFoundation overlay
// makes them (equality and hashing through CFEqual / CFHash). Lets apps write [CFString: Any] for ImageIO properties.
import CoreFoundation

extension CFString: @retroactive Equatable, @retroactive Hashable {
    public static func == (a: CFString, b: CFString) -> Bool { CFEqual(a, b) != 0 }
    public func hash(into h: inout Hasher) { h.combine(CFHash(self)) }
}
extension CFData: @retroactive Equatable, @retroactive Hashable {
    public static func == (a: CFData, b: CFData) -> Bool { CFEqual(a, b) != 0 }
    public func hash(into h: inout Hasher) { h.combine(CFHash(self)) }
}
