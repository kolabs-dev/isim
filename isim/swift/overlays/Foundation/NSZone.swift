// isim Foundation: NSZone. The importer brings `struct _NSZone *` in as OpaquePointer, so this alias lets the usual
// NSCopying spelling `func copy(with zone: NSZone? = nil) -> Any` compile.
public typealias NSZone = OpaquePointer
