// isim MobileCoreServices for C (sdk-src/Frameworks/MobileCoreServices): the deprecated UTType C functions over this
// overlay's UTType (MobileCoreServices.framework re-exports libswiftUniformTypeIdentifiers.dylib). As on iOS, a tag with
// no declared type gets a dynamic identifier ("dyn.").
import Foundation

private let filenameExtensionClass = "public.filename-extension", mimeTypeClass = "public.mime-type"

private func type(tagClass: String, tag: String, conformingTo: String?) -> UTType? {
    let sup = conformingTo.flatMap { UTType($0) } ?? .data
    switch tagClass {
    case filenameExtensionClass: return UTType(filenameExtension: tag, conformingTo: sup)
    case mimeTypeClass: return UTType(mimeType: tag, conformingTo: sup)
    default: return nil
    }
}
private func retained(_ s: String?) -> CFString? { s.map { Unmanaged.passRetained($0 as CFString).takeUnretainedValue() } }

@_cdecl("UTTypeCreatePreferredIdentifierForTag")
public func _c_UTTypeCreatePreferredIdentifierForTag(_ tagClass: CFString, _ tag: CFString, _ conformingTo: CFString?) -> CFString? {
    let t = tag as String
    let id = type(tagClass: tagClass as String, tag: t, conformingTo: conformingTo as String?)?.identifier
        ?? "dyn." + Data((tagClass as String + "=" + t).utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
    return retained(id)
}
@_cdecl("UTTypeCopyPreferredTagWithClass")
public func _c_UTTypeCopyPreferredTagWithClass(_ uti: CFString, _ tagClass: CFString) -> CFString? {
    guard let t = UTType(uti as String) else { return nil }
    switch tagClass as String {
    case filenameExtensionClass: return retained(t.preferredFilenameExtension)
    case mimeTypeClass: return retained(t.preferredMIMEType)
    default: return nil
    }
}
@_cdecl("UTTypeConformsTo")
public func _c_UTTypeConformsTo(_ a: CFString, _ b: CFString) -> Bool {
    guard let ta = UTType(a as String), let tb = UTType(b as String) else { return (a as String) == (b as String) }
    return ta.conforms(to: tb)
}
@_cdecl("UTTypeEqual")
public func _c_UTTypeEqual(_ a: CFString, _ b: CFString) -> Bool { (a as String) == (b as String) }
