// isim CoreVideo: attachments and planar buffers (Swift), and the C interface (<CoreVideo/CoreVideo.h>) over the same
// objects: a CVPixelBufferRef is the Swift CVBuffer, so a buffer made in C is the one Swift code (AVFoundation, Vision,
// Core ML) sees and the other way round. CoreVideo.framework re-exports this library; the C constants are in
// frameworks/CoreVideo. Adapted: attachments are kept with the buffer (no IOSurface); propagation copies them.

// MARK: - attachments (Swift)

public enum CVAttachmentMode: UInt32, Sendable {
    case shouldNotPropagate = 0
    case shouldPropagate = 1
}

public let kCVImageBufferCGColorSpaceKey: CFString = "CGColorSpace" as CFString
public let kCVImageBufferColorPrimariesKey: CFString = "ColorPrimaries" as CFString
public let kCVImageBufferTransferFunctionKey: CFString = "TransferFunction" as CFString
public let kCVImageBufferYCbCrMatrixKey: CFString = "YCbCrMatrix" as CFString
public let kCVImageBufferPixelAspectRatioKey: CFString = "CVPixelAspectRatio" as CFString
public let kCVImageBufferFieldCountKey: CFString = "CVFieldCount" as CFString
public let kCVImageBufferChromaLocationTopFieldKey: CFString = "CVImageBufferChromaLocationTopField" as CFString
public let kCVImageBufferColorPrimaries_ITU_R_709_2: CFString = "ITU_R_709_2" as CFString
public let kCVImageBufferColorPrimaries_P3_D65: CFString = "P3_D65" as CFString
public let kCVImageBufferTransferFunction_ITU_R_709_2: CFString = "ITU_R_709_2" as CFString
public let kCVImageBufferYCbCrMatrix_ITU_R_709_2: CFString = "ITU_R_709_2" as CFString
public let kCVImageBufferYCbCrMatrix_ITU_R_601_4: CFString = "ITU_R_601_4" as CFString
public let kCVBufferPropagatedAttachmentsKey: CFString = "PropagatedAttachments" as CFString
public let kCVBufferNonPropagatedAttachmentsKey: CFString = "NonPropagatedAttachments" as CFString
public let kCVBufferMovieTimeKey: CFString = "QTMovieTime" as CFString

extension CVBuffer {
    func _setAttachment(_ key: String, _ value: Any, _ mode: CVAttachmentMode) {
        _attachments[key] = value
        _propagated[key] = mode == .shouldPropagate
    }
    func _removeAttachment(_ key: String) { _attachments[key] = nil; _propagated[key] = nil }
    func _attachments(_ mode: CVAttachmentMode) -> [String: Any] {
        _attachments.filter { (_propagated[$0.key] ?? false) == (mode == .shouldPropagate) }
    }
}

public func CVBufferSetAttachment(_ buffer: CVBuffer, _ key: CFString, _ value: CFTypeRef, _ attachmentMode: CVAttachmentMode) {
    buffer._setAttachment(key as String, value, attachmentMode)
}
/// the attachment and its mode (iOS 15: CVBufferCopyAttachment)
public func CVBufferCopyAttachment(_ buffer: CVBuffer, _ key: CFString, _ attachmentMode: UnsafeMutablePointer<CVAttachmentMode>?) -> CFTypeRef? {
    guard let v = buffer._attachments[key as String] else { return nil }
    attachmentMode?.pointee = buffer._propagated[key as String] == true ? .shouldPropagate : .shouldNotPropagate
    return v as AnyObject
}
public func CVBufferGetAttachment(_ buffer: CVBuffer, _ key: CFString, _ attachmentMode: UnsafeMutablePointer<CVAttachmentMode>?) -> Unmanaged<CFTypeRef>? {
    CVBufferCopyAttachment(buffer, key, attachmentMode).map { Unmanaged.passUnretained($0) }
}
public func CVBufferHasAttachment(_ buffer: CVBuffer, _ key: CFString) -> Bool { buffer._attachments[key as String] != nil }
public func CVBufferRemoveAttachment(_ buffer: CVBuffer, _ key: CFString) { buffer._removeAttachment(key as String) }
public func CVBufferRemoveAllAttachments(_ buffer: CVBuffer) { buffer._attachments = [:]; buffer._propagated = [:] }
public func CVBufferCopyAttachments(_ buffer: CVBuffer, _ attachmentMode: CVAttachmentMode) -> CFDictionary? {
    let a = buffer._attachments(attachmentMode)
    return a.isEmpty ? nil : a as NSDictionary as CFDictionary
}
public func CVBufferGetAttachments(_ buffer: CVBuffer, _ attachmentMode: CVAttachmentMode) -> Unmanaged<CFDictionary>? {
    CVBufferCopyAttachments(buffer, attachmentMode).map { Unmanaged.passRetained($0) }   // kept alive like a Get (isim leaks it)
}
public func CVBufferSetAttachments(_ buffer: CVBuffer, _ theAttachments: CFDictionary, _ attachmentMode: CVAttachmentMode) {
    for (k, v) in (theAttachments as NSDictionary as? [String: Any]) ?? [:] { buffer._setAttachment(k, v, attachmentMode) }
}
/// copies the source's propagatable attachments to the destination
public func CVBufferPropagateAttachments(_ sourceBuffer: CVBuffer, _ destinationBuffer: CVBuffer) {
    for (k, v) in sourceBuffer._attachments(.shouldPropagate) { destinationBuffer._setAttachment(k, v, .shouldPropagate) }
}

// MARK: - planar buffers over the caller's memory (Swift)

public typealias CVPixelBufferReleasePlanarBytesCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, Int, Int,
                                                                           UnsafeMutablePointer<UnsafeRawPointer?>?) -> Void
@discardableResult public func CVPixelBufferCreateWithPlanarBytes(_ allocator: CFAllocator?, _ width: Int, _ height: Int, _ pixelFormatType: OSType,
                                               _ dataPtr: UnsafeMutableRawPointer?, _ dataSize: Int, _ numberOfPlanes: Int,
                                               _ planeBaseAddress: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
                                               _ planeWidth: UnsafeMutablePointer<Int>, _ planeHeight: UnsafeMutablePointer<Int>,
                                               _ planeBytesPerRow: UnsafeMutablePointer<Int>,
                                               _ releaseCallback: CVPixelBufferReleasePlanarBytesCallback?, _ releaseRefCon: UnsafeMutableRawPointer?,
                                               _ pixelBufferAttributes: CFDictionary?, _ pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    guard width > 0, height > 0 else { return kCVReturnInvalidSize }
    guard CVBuffer.isBiPlanar(pixelFormatType), numberOfPlanes == 2 else { return kCVReturnInvalidPixelFormat }
    var planes: [CVBuffer.Plane] = []
    for i in 0..<numberOfPlanes {
        guard let base = planeBaseAddress[i] else { return kCVReturnInvalidArgument }
        planes.append(CVBuffer.Plane(base: base, width: planeWidth[i], height: planeHeight[i], bytesPerRow: planeBytesPerRow[i]))
    }
    let bases = (0..<numberOfPlanes).map { UnsafeRawPointer(planeBaseAddress[$0]) }
    let release: (() -> Void)? = releaseCallback.map { cb in {
        var b = bases
        b.withUnsafeMutableBufferPointer { cb(releaseRefCon, UnsafeRawPointer(dataPtr), dataSize, numberOfPlanes, $0.baseAddress) }
    } }
    pixelBufferOut.pointee = CVBuffer(_planes: planes, width: width, height: height, format: pixelFormatType, release: release)
    return kCVReturnSuccess
}

// MARK: - the C interface

private func buf(_ p: UnsafeRawPointer) -> CVBuffer { Unmanaged<CVBuffer>.fromOpaque(p).takeUnretainedValue() }
private func dict(_ p: UnsafeRawPointer?) -> [String: Any] {
    guard let p else { return [:] }
    return (Unmanaged<NSDictionary>.fromOpaque(p).takeUnretainedValue() as? [String: Any]) ?? [:]
}
private func str(_ p: UnsafeRawPointer) -> String { Unmanaged<NSString>.fromOpaque(p).takeUnretainedValue() as String }
private func out(_ b: CVBuffer?, _ to: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    guard let b else { return kCVReturnInvalidPixelFormat }
    to?.pointee = Unmanaged.passRetained(b).toOpaque()                  // +1, released with CVPixelBufferRelease / CFRelease
    return kCVReturnSuccess
}

@_cdecl("CVPixelBufferCreate")
public func _c_CVPixelBufferCreate(_ allocator: UnsafeRawPointer?, _ width: Int, _ height: Int, _ format: OSType, _ attributes: UnsafeRawPointer?,
                                   _ pixelBufferOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    guard width > 0, height > 0 else { return kCVReturnInvalidSize }
    return out(CVBuffer(_width: width, height: height, format: format), pixelBufferOut)
}
@_cdecl("CVPixelBufferCreateWithBytes")
public func _c_CVPixelBufferCreateWithBytes(_ allocator: UnsafeRawPointer?, _ width: Int, _ height: Int, _ format: OSType, _ base: UnsafeMutableRawPointer?,
                                            _ bytesPerRow: Int, _ releaseCallback: CVPixelBufferReleaseBytesCallback?, _ refCon: UnsafeMutableRawPointer?,
                                            _ attributes: UnsafeRawPointer?, _ pixelBufferOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    guard let base else { return kCVReturnInvalidArgument }
    var b: CVPixelBuffer?
    let r = CVPixelBufferCreateWithBytes(nil, width, height, format, base, bytesPerRow, releaseCallback, refCon, nil, &b)
    return r == kCVReturnSuccess ? out(b, pixelBufferOut) : r
}
@_cdecl("CVPixelBufferCreateWithPlanarBytes")
public func _c_CVPixelBufferCreateWithPlanarBytes(_ allocator: UnsafeRawPointer?, _ width: Int, _ height: Int, _ format: OSType,
                                                  _ dataPtr: UnsafeMutableRawPointer?, _ dataSize: Int, _ numberOfPlanes: Int,
                                                  _ planeBaseAddress: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
                                                  _ planeWidth: UnsafeMutablePointer<Int>?, _ planeHeight: UnsafeMutablePointer<Int>?,
                                                  _ planeBytesPerRow: UnsafeMutablePointer<Int>?,
                                                  _ releaseCallback: CVPixelBufferReleasePlanarBytesCallback?, _ refCon: UnsafeMutableRawPointer?,
                                                  _ attributes: UnsafeRawPointer?, _ pixelBufferOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    guard let planeBaseAddress, let planeWidth, let planeHeight, let planeBytesPerRow else { return kCVReturnInvalidArgument }
    var b: CVPixelBuffer?
    let r = CVPixelBufferCreateWithPlanarBytes(nil, width, height, format, dataPtr, dataSize, numberOfPlanes, planeBaseAddress, planeWidth,
                                               planeHeight, planeBytesPerRow, releaseCallback, refCon, nil, &b)
    return r == kCVReturnSuccess ? out(b, pixelBufferOut) : r
}
@_cdecl("CVPixelBufferLockBaseAddress")
public func _c_CVPixelBufferLockBaseAddress(_ b: UnsafeRawPointer, _ flags: CVOptionFlags) -> CVReturn {
    CVPixelBufferLockBaseAddress(buf(b), CVPixelBufferLockFlags(rawValue: flags))
}
@_cdecl("CVPixelBufferUnlockBaseAddress")
public func _c_CVPixelBufferUnlockBaseAddress(_ b: UnsafeRawPointer, _ flags: CVOptionFlags) -> CVReturn {
    CVPixelBufferUnlockBaseAddress(buf(b), CVPixelBufferLockFlags(rawValue: flags))
}
@_cdecl("CVPixelBufferGetWidth") public func _c_CVPixelBufferGetWidth(_ b: UnsafeRawPointer) -> Int { buf(b)._width }
@_cdecl("CVPixelBufferGetHeight") public func _c_CVPixelBufferGetHeight(_ b: UnsafeRawPointer) -> Int { buf(b)._height }
@_cdecl("CVPixelBufferGetPixelFormatType") public func _c_CVPixelBufferGetPixelFormatType(_ b: UnsafeRawPointer) -> OSType { buf(b)._format }
@_cdecl("CVPixelBufferGetBaseAddress") public func _c_CVPixelBufferGetBaseAddress(_ b: UnsafeRawPointer) -> UnsafeMutableRawPointer? { CVPixelBufferGetBaseAddress(buf(b)) }
@_cdecl("CVPixelBufferGetBytesPerRow") public func _c_CVPixelBufferGetBytesPerRow(_ b: UnsafeRawPointer) -> Int { CVPixelBufferGetBytesPerRow(buf(b)) }
@_cdecl("CVPixelBufferGetDataSize") public func _c_CVPixelBufferGetDataSize(_ b: UnsafeRawPointer) -> Int { CVPixelBufferGetDataSize(buf(b)) }
@_cdecl("CVPixelBufferIsPlanar") public func _c_CVPixelBufferIsPlanar(_ b: UnsafeRawPointer) -> UInt8 { CVPixelBufferIsPlanar(buf(b)) ? 1 : 0 }
@_cdecl("CVPixelBufferGetPlaneCount") public func _c_CVPixelBufferGetPlaneCount(_ b: UnsafeRawPointer) -> Int { CVPixelBufferGetPlaneCount(buf(b)) }
@_cdecl("CVPixelBufferGetWidthOfPlane") public func _c_CVPixelBufferGetWidthOfPlane(_ b: UnsafeRawPointer, _ i: Int) -> Int { CVPixelBufferGetWidthOfPlane(buf(b), i) }
@_cdecl("CVPixelBufferGetHeightOfPlane") public func _c_CVPixelBufferGetHeightOfPlane(_ b: UnsafeRawPointer, _ i: Int) -> Int { CVPixelBufferGetHeightOfPlane(buf(b), i) }
@_cdecl("CVPixelBufferGetBaseAddressOfPlane")
public func _c_CVPixelBufferGetBaseAddressOfPlane(_ b: UnsafeRawPointer, _ i: Int) -> UnsafeMutableRawPointer? { CVPixelBufferGetBaseAddressOfPlane(buf(b), i) }
@_cdecl("CVPixelBufferGetBytesPerRowOfPlane")
public func _c_CVPixelBufferGetBytesPerRowOfPlane(_ b: UnsafeRawPointer, _ i: Int) -> Int { CVPixelBufferGetBytesPerRowOfPlane(buf(b), i) }
@_cdecl("CVPixelBufferGetTypeID") public func _c_CVPixelBufferGetTypeID() -> UInt { CVPixelBufferGetTypeID() }
@_cdecl("CVImageBufferGetEncodedSize") public func _c_CVImageBufferGetEncodedSize(_ b: UnsafeRawPointer) -> CGSize { CVImageBufferGetEncodedSize(buf(b)) }
@_cdecl("CVImageBufferGetDisplaySize") public func _c_CVImageBufferGetDisplaySize(_ b: UnsafeRawPointer) -> CGSize { CVImageBufferGetDisplaySize(buf(b)) }
@_cdecl("CVImageBufferGetCleanRect") public func _c_CVImageBufferGetCleanRect(_ b: UnsafeRawPointer) -> CGRect { CVImageBufferGetCleanRect(buf(b)) }
@_cdecl("CVPixelBufferRetain")
public func _c_CVPixelBufferRetain(_ b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    if let b { _ = Unmanaged<CVBuffer>.fromOpaque(b).retain() }
    return b
}
@_cdecl("CVPixelBufferRelease") public func _c_CVPixelBufferRelease(_ b: UnsafeMutableRawPointer?) { if let b { Unmanaged<CVBuffer>.fromOpaque(b).release() } }
@_cdecl("CVBufferRetain") public func _c_CVBufferRetain(_ b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? { _c_CVPixelBufferRetain(b) }
@_cdecl("CVBufferRelease") public func _c_CVBufferRelease(_ b: UnsafeMutableRawPointer?) { _c_CVPixelBufferRelease(b) }

@_cdecl("CVBufferSetAttachment")
public func _c_CVBufferSetAttachment(_ b: UnsafeRawPointer, _ key: UnsafeRawPointer, _ value: UnsafeRawPointer, _ mode: UInt32) {
    buf(b)._setAttachment(str(key), Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue(), CVAttachmentMode(rawValue: mode) ?? .shouldNotPropagate)
}
/// +0: the attachment stays owned by the buffer
@_cdecl("CVBufferGetAttachment")
public func _c_CVBufferGetAttachment(_ b: UnsafeRawPointer, _ key: UnsafeRawPointer, _ mode: UnsafeMutablePointer<UInt32>?) -> UnsafeRawPointer? {
    let buffer = buf(b), k = str(key)
    guard let v = buffer._attachments[k] else { return nil }
    mode?.pointee = buffer._propagated[k] == true ? 1 : 0
    return UnsafeRawPointer(Unmanaged.passUnretained(v as AnyObject).toOpaque())
}
@_cdecl("CVBufferCopyAttachment")
public func _c_CVBufferCopyAttachment(_ b: UnsafeRawPointer, _ key: UnsafeRawPointer, _ mode: UnsafeMutablePointer<UInt32>?) -> UnsafeRawPointer? {
    let buffer = buf(b), k = str(key)
    guard let v = buffer._attachments[k] else { return nil }
    mode?.pointee = buffer._propagated[k] == true ? 1 : 0
    return UnsafeRawPointer(Unmanaged.passRetained(v as AnyObject).toOpaque())
}
@_cdecl("CVBufferHasAttachment") public func _c_CVBufferHasAttachment(_ b: UnsafeRawPointer, _ key: UnsafeRawPointer) -> UInt8 { buf(b)._attachments[str(key)] != nil ? 1 : 0 }
@_cdecl("CVBufferRemoveAttachment") public func _c_CVBufferRemoveAttachment(_ b: UnsafeRawPointer, _ key: UnsafeRawPointer) { buf(b)._removeAttachment(str(key)) }
@_cdecl("CVBufferRemoveAllAttachments") public func _c_CVBufferRemoveAllAttachments(_ b: UnsafeRawPointer) { CVBufferRemoveAllAttachments(buf(b)) }
@_cdecl("CVBufferCopyAttachments")
public func _c_CVBufferCopyAttachments(_ b: UnsafeRawPointer, _ mode: UInt32) -> UnsafeRawPointer? {
    let a = buf(b)._attachments(CVAttachmentMode(rawValue: mode) ?? .shouldNotPropagate)
    return a.isEmpty ? nil : UnsafeRawPointer(Unmanaged.passRetained(a as NSDictionary).toOpaque())
}
@_cdecl("CVBufferGetAttachments")
public func _c_CVBufferGetAttachments(_ b: UnsafeRawPointer, _ mode: UInt32) -> UnsafeRawPointer? {
    let buffer = buf(b)
    let a = buffer._attachments(CVAttachmentMode(rawValue: mode) ?? .shouldNotPropagate)
    guard !a.isEmpty else { return nil }
    let d = a as NSDictionary
    buffer._gotAttachments = d                                            // +0, alive as long as the buffer (or the next Get)
    return UnsafeRawPointer(Unmanaged.passUnretained(d).toOpaque())
}
@_cdecl("CVBufferSetAttachments")
public func _c_CVBufferSetAttachments(_ b: UnsafeRawPointer, _ attachments: UnsafeRawPointer, _ mode: UInt32) {
    for (k, v) in dict(attachments) { buf(b)._setAttachment(k, v, CVAttachmentMode(rawValue: mode) ?? .shouldNotPropagate) }
}
@_cdecl("CVBufferPropagateAttachments")
public func _c_CVBufferPropagateAttachments(_ src: UnsafeRawPointer, _ dst: UnsafeRawPointer) { CVBufferPropagateAttachments(buf(src), buf(dst)) }

@_cdecl("CVPixelBufferPoolCreate")
public func _c_CVPixelBufferPoolCreate(_ allocator: UnsafeRawPointer?, _ poolAttributes: UnsafeRawPointer?, _ pixelBufferAttributes: UnsafeRawPointer?,
                                       _ poolOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    let a = dict(pixelBufferAttributes)
    guard let w = _cvInt(a, kCVPixelBufferWidthKey), let h = _cvInt(a, kCVPixelBufferHeightKey) else { return kCVReturnInvalidArgument }
    let f = _cvInt(a, kCVPixelBufferPixelFormatTypeKey).map { OSType(truncatingIfNeeded: $0) } ?? kCVPixelFormatType_32BGRA
    let pool = CVPixelBufferPool(width: w, height: h, format: f, attributes: a)
    pool._poolAttributes = dict(poolAttributes)
    poolOut?.pointee = Unmanaged.passRetained(pool).toOpaque()
    return kCVReturnSuccess
}
@_cdecl("CVPixelBufferPoolCreatePixelBuffer")
public func _c_CVPixelBufferPoolCreatePixelBuffer(_ allocator: UnsafeRawPointer?, _ pool: UnsafeRawPointer,
                                                  _ pixelBufferOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> CVReturn {
    let p = Unmanaged<CVPixelBufferPool>.fromOpaque(pool).takeUnretainedValue()
    guard let b = CVBuffer(_width: p.width, height: p.height, format: p.format) else { return kCVReturnPoolAllocationFailed }
    return out(b, pixelBufferOut)
}
@_cdecl("CVPixelBufferPoolGetPixelBufferAttributes")
public func _c_CVPixelBufferPoolGetPixelBufferAttributes(_ pool: UnsafeRawPointer) -> UnsafeRawPointer? {
    let p = Unmanaged<CVPixelBufferPool>.fromOpaque(pool).takeUnretainedValue()
    return UnsafeRawPointer(Unmanaged.passUnretained(p._attributesObject).toOpaque())
}
@_cdecl("CVPixelBufferPoolGetAttributes")
public func _c_CVPixelBufferPoolGetAttributes(_ pool: UnsafeRawPointer) -> UnsafeRawPointer? {
    let p = Unmanaged<CVPixelBufferPool>.fromOpaque(pool).takeUnretainedValue()
    return UnsafeRawPointer(Unmanaged.passUnretained(p._poolAttributesObject).toOpaque())
}
@_cdecl("CVPixelBufferPoolRetain")
public func _c_CVPixelBufferPoolRetain(_ p: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    if let p { _ = Unmanaged<CVPixelBufferPool>.fromOpaque(p).retain() }
    return p
}
@_cdecl("CVPixelBufferPoolRelease") public func _c_CVPixelBufferPoolRelease(_ p: UnsafeMutableRawPointer?) { if let p { Unmanaged<CVPixelBufferPool>.fromOpaque(p).release() } }
@_cdecl("CVPixelBufferPoolFlush") public func _c_CVPixelBufferPoolFlush(_ p: UnsafeRawPointer, _ options: CVOptionFlags) {}
@_cdecl("CVPixelBufferPoolGetTypeID") public func _c_CVPixelBufferPoolGetTypeID() -> UInt { 0x4356_5050 }
