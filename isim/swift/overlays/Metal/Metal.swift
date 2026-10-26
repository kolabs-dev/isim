// isim Metal Swift overlay (issue #328): Apple's Swift forms of the Objective-C methods that take C arrays and
// NSRange (arrays and Range<Int> here), over isim's Metal.framework (Metal on the CPU, frameworks/Metal).
@_exported import Metal
import Foundation

extension MTLComputeCommandEncoder {
    public func setBuffers(_ buffers: [MTLBuffer?], offsets: [Int], range: Range<Int>) {
        precondition(buffers.count == range.count && offsets.count == range.count, "setBuffers: counts differ from the range")
        for (i, index) in range.enumerated() { setBuffer(buffers[i], offset: offsets[i], index: index) }
    }
    public func setTextures(_ textures: [MTLTexture?], range: Range<Int>) {
        for (i, index) in range.enumerated() where i < textures.count { setTexture(textures[i], index: index) }
    }
    public func setSamplerStates(_ samplers: [MTLSamplerState?], range: Range<Int>) {
        for (i, index) in range.enumerated() where i < samplers.count { setSamplerState(samplers[i], index: index) }
    }
    public func useResources(_ resources: [MTLResource], usage: MTLResourceUsage) {
        for r in resources { useResource(r, usage: usage) }
    }
    public func memoryBarrier(resources: [MTLResource]) {
        resources.withUnsafeBufferPointer { p in
            if let base = p.baseAddress { __memoryBarrier(resources: base, count: p.count) }
        }
    }
}

extension MTLBlitCommandEncoder {
    public func fill(buffer: MTLBuffer, range: Range<Int>, value: UInt8) {
        __fill(buffer, range: NSRange(location: range.lowerBound, length: range.count), value: value)
    }
}

extension MTLBuffer {
    public func addDebugMarker(_ marker: String, range: Range<Int>) {
        __addDebugMarker(marker, range: NSRange(location: range.lowerBound, length: range.count))
    }
}

extension MTLTexture {
    public func makeTextureView(pixelFormat: MTLPixelFormat, textureType: MTLTextureType, levels levelRange: Range<Int>,
                                slices sliceRange: Range<Int>) -> MTLTexture? {
        __makeTextureView(pixelFormat: pixelFormat, textureType: textureType,
                          levels: NSRange(location: levelRange.lowerBound, length: levelRange.count),
                          slices: NSRange(location: sliceRange.lowerBound, length: sliceRange.count))
    }
}

extension MTLFunctionConstantValues {
    public func setConstantValues(_ values: UnsafeRawPointer, type: MTLDataType, range: Range<Int>) {
        __setConstantValues(values, type: type, with: NSRange(location: range.lowerBound, length: range.count))
    }
}

// MARK: - errors: the Swift structs of MTLLibraryErrorDomain and MTLCommandBufferErrorDomain (an NSError of either
// domain bridges to them, `catch let e as MTLLibraryError`)

public struct MTLLibraryError: Error, CustomNSError, Hashable, _ObjectiveCBridgeableError, @unchecked Sendable {
    public enum Code: UInt, Sendable {
        case unsupported = 1, `internal` = 2, compileFailure = 3, compileWarning = 4, functionNotFound = 5, fileNotFound = 6
    }
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == MTLLibraryErrorDomain, let c = Code(rawValue: UInt(e.code)) else { return nil }
        self.init(c, userInfo: e.userInfo)
    }
    public static var errorDomain: String { MTLLibraryErrorDomain }
    public var errorCode: Int { Int(code.rawValue) }
    public var userInfo: [String: Any] { errorUserInfo }
    public var localizedDescription: String { errorUserInfo[NSLocalizedDescriptionKey] as? String ?? "MTLLibraryErrorDomain error \(code.rawValue)" }
    public static func == (a: MTLLibraryError, b: MTLLibraryError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var unsupported: Code { .unsupported }
    public static var `internal`: Code { .internal }
    public static var compileFailure: Code { .compileFailure }
    public static var compileWarning: Code { .compileWarning }
    public static var functionNotFound: Code { .functionNotFound }
    public static var fileNotFound: Code { .fileNotFound }
}

public struct MTLCommandBufferError: Error, CustomNSError, Hashable, _ObjectiveCBridgeableError, @unchecked Sendable {
    public enum Code: UInt, Sendable {
        case none = 0, `internal` = 1, timeout = 2, pageFault = 3, notPermitted = 7, outOfMemory = 8, invalidResource = 9
        case memoryless = 10, stackOverflow = 12
    }
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == MTLCommandBufferErrorDomain, let c = Code(rawValue: UInt(e.code)) else { return nil }
        self.init(c, userInfo: e.userInfo)
    }
    public static var errorDomain: String { MTLCommandBufferErrorDomain }
    public var errorCode: Int { Int(code.rawValue) }
    public var userInfo: [String: Any] { errorUserInfo }
    public static func == (a: MTLCommandBufferError, b: MTLCommandBufferError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var none: Code { .none }
    public static var `internal`: Code { .internal }
    public static var timeout: Code { .timeout }
    public static var pageFault: Code { .pageFault }
    public static var notPermitted: Code { .notPermitted }
    public static var outOfMemory: Code { .outOfMemory }
    public static var invalidResource: Code { .invalidResource }
    public static var memoryless: Code { .memoryless }
    public static var stackOverflow: Code { .stackOverflow }
}
