// isim Accelerate Swift overlay (issue #814): vImage.MultidimensionalLookupTable, vImageConverter's PixelBuffer
// conversions, and the PixelBuffer / Core Video bridges that need DynamicPixelFormat, over isim's C vImage and Core
// Video. Adapted.
@_exported import Accelerate
import CoreGraphics
import CoreVideo

// MARK: multidimensional lookup tables

extension vImage {
    /// A colour lookup table over several source channels (a 3D LUT and the like), interpolated.
    public struct MultidimensionalLookupTable {
        /// How values between the table's entries are found.
        public enum InterpolationMethod {
            case none, half, full
            var _c: vImage_InterpolationMethod {
                switch self { case .none: return kvImageNoInterpolation; case .half: return kvImageHalfInterpolation; case .full: return kvImageFullInterpolation }
            }
        }
        final class _Table {
            let table: vImage_MultidimensionalTable
            init(_ t: vImage_MultidimensionalTable) { table = t }
            deinit { _ = vImageMultidimensionalTable_Release(table) }
        }
        let _table: _Table
        public let entryCountPerSourceChannel: [UInt8]
        public let sourceChannelCount: Int
        public let destinationChannelCount: Int
        /// The table's 16-bit (16Q12) entries: destinationChannelCount values per grid point, the last source channel
        /// varying fastest.
        public init<T>(entryCountPerSourceChannel: [UInt8], destinationChannelCount: Int, data: T) where T: AccelerateBuffer, T.Element == UInt16 {
            let points = entryCountPerSourceChannel.reduce(1) { $0 * Int($1) }
            precondition(data.count >= points * destinationChannelCount, "vImage.MultidimensionalLookupTable: too few entries")
            var e = vImage_Error(kvImageNoError)
            let t = data.withUnsafeBufferPointer { d in
                vImageMultidimensionalTable_Create(d.baseAddress!, UInt32(entryCountPerSourceChannel.count), UInt32(destinationChannelCount),
                                                   entryCountPerSourceChannel, kvImageMDTableHint_Float, 0, &e)
            }
            precondition(t != nil && e == kvImageNoError, "vImage.MultidimensionalLookupTable: error \(e)")
            _table = _Table(t!)
            self.entryCountPerSourceChannel = entryCountPerSourceChannel
            sourceChannelCount = entryCountPerSourceChannel.count
            self.destinationChannelCount = destinationChannelCount
        }
        func _apply(_ srcs: [vImage_Buffer], _ dests: [vImage_Buffer], _ interpolation: InterpolationMethod) {
            precondition(srcs.count == sourceChannelCount && dests.count == destinationChannelCount,
                         "vImage.MultidimensionalLookupTable: \(sourceChannelCount) source and \(destinationChannelCount) destination planes needed")
            let e = vImageMultiDimensionalInterpolatedLookupTable_PlanarF(srcs, dests, nil, _table.table, interpolation._c, 0)
            precondition(e >= 0, "vImage: error \(e)")
        }
        public func apply<SrcFormat, DestFormat>(source: vImage.PixelBuffer<SrcFormat>, destination: vImage.PixelBuffer<DestFormat>,
                                                 interpolation: InterpolationMethod)
            where SrcFormat: MultiplePlanePixelFormat, SrcFormat.PlanarPixelFormat == vImage.PlanarF,
                  DestFormat: MultiplePlanePixelFormat, DestFormat.PlanarPixelFormat == vImage.PlanarF {
            _apply(source._buffers, destination._buffers, interpolation)
        }
        public func apply(sources: [vImage.PixelBuffer<vImage.PlanarF>], destinations: [vImage.PixelBuffer<vImage.PlanarF>], interpolation: InterpolationMethod) {
            _apply(sources.map(\._buffer), destinations.map(\._buffer), interpolation)
        }
    }
}

// MARK: converters and pixel buffers

extension vImageConverter {
    /// Converts between pixel buffers of the converter's source and destination formats.
    public func convert<Src, Dest>(from source: vImage.PixelBuffer<Src>, to destination: vImage.PixelBuffer<Dest>) throws {
        try _convert(source._buffers, destination._buffers)
    }
    /// Converts between lists of pixel buffers (one per converter buffer).
    public func convert<F1, F2>(from sources: [vImage.PixelBuffer<F1>], to destinations: [vImage.PixelBuffer<F2>]) throws {
        try _convert(sources.flatMap(\._buffers), destinations.flatMap(\._buffers))
    }
    func _convert(_ s: [vImage_Buffer], _ d: [vImage_Buffer]) throws {
        precondition(s.count >= sourceBufferCount && d.count >= destinationBufferCount, "vImageConverter.convert: too few buffers")
        var s = s, d = d
        try s.withUnsafeMutableBufferPointer { sp in try d.withUnsafeMutableBufferPointer { dp in
            try _vImageCheck(vImageConvert_AnyToAny(self, sp.baseAddress!, dp.baseAddress!, nil, 0)) } }
    }
    /// Buffers over a Core Video pixel buffer's planes, as this converter reads them (a CV-to-CG converter).
    public func makeCVToCGPixelBuffers(referencing cvPixelBuffer: CVPixelBuffer) throws -> [vImage.PixelBuffer<vImage.DynamicPixelFormat>] {
        try _referencing(cvPixelBuffer, count: sourceBufferCount) { vImageBuffer_InitForCopyFromCVPixelBuffer($0, self, cvPixelBuffer, $1) }
    }
    /// Buffers over a Core Video pixel buffer's planes, as this converter writes them (a CG-to-CV converter).
    public func makeCGToCVPixelBuffers(referencing cvPixelBuffer: CVPixelBuffer) throws -> [vImage.PixelBuffer<vImage.DynamicPixelFormat>] {
        try _referencing(cvPixelBuffer, count: destinationBufferCount) { vImageBuffer_InitForCopyToCVPixelBuffer($0, self, cvPixelBuffer, $1) }
    }
    func _referencing(_ cv: CVPixelBuffer, count: Int,
                      _ initFn: (UnsafeMutablePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error) throws -> [vImage.PixelBuffer<vImage.DynamicPixelFormat>] {
        var bufs = [vImage_Buffer](repeating: vImage_Buffer(), count: max(1, count))
        try _vImageCheck(initFn(&bufs, vImage_Flags(kvImageNoAllocate)))
        return bufs.prefix(count).map {
            let p = vImage.PixelBuffer<vImage.DynamicPixelFormat>(_storage: .init(buffer: $0, owned: false))
            p._storage.keep = cv
            return p
        }
    }
}

extension vImage.PixelBuffer where Format == vImage.DynamicPixelFormat {
    /// One pixel buffer over all of a Core Video pixel buffer's planes as a converter reads them.
    public init(referencing cvPixelBuffer: CVPixelBuffer, converter: vImageConverter, destinationPixelFormat: Format.Type = Format.self) {
        var bufs = [vImage_Buffer](repeating: vImage_Buffer(), count: max(1, converter.sourceBufferCount))
        let e = vImageBuffer_InitForCopyFromCVPixelBuffer(&bufs, converter, cvPixelBuffer, vImage_Flags(kvImageNoAllocate))
        precondition(e >= 0, "vImage.PixelBuffer(referencing:converter:): error \(e)")
        self.init(_storage: _Storage(buffers: Array(bufs.prefix(converter.sourceBufferCount)), owned: false))
        _storage.keep = cvPixelBuffer
    }
}

/// The Core Video pixel format holding a single-plane vImage format's pixels unchanged.
func _cvPixelFormat<F: SinglePlanePixelFormat>(_ f: F.Type) -> OSType? {
    switch ObjectIdentifier(f) {
    case ObjectIdentifier(vImage.Planar8.self): return 0x4C30_3038          // 'L008'
    case ObjectIdentifier(vImage.Planar16U.self): return 0x4C30_3136        // 'L016'
    case ObjectIdentifier(vImage.Planar16F.self): return 0x4C30_3068        // 'L00h'
    case ObjectIdentifier(vImage.PlanarF.self): return 0x4C30_3066          // 'L00f'
    case ObjectIdentifier(vImage.Interleaved8x2.self): return 0x3243_3038   // '2C08'
    case ObjectIdentifier(vImage.Interleaved16Ux2.self): return 0x3243_3136 // '2C16'
    case ObjectIdentifier(vImage.Interleaved16Fx2.self): return 0x3243_3068 // '2C0h'
    case ObjectIdentifier(vImage.InterleavedFx2.self): return 0x3243_3066   // '2C0f'
    case ObjectIdentifier(vImage.Interleaved8x3.self): return 0x0000_0018   // 24RGB
    case ObjectIdentifier(vImage.Interleaved8x4.self): return 0x0000_0020   // 32ARGB
    case ObjectIdentifier(vImage.Interleaved16Ux4.self): return 0x6C36_3472 // 'l64r'
    case ObjectIdentifier(vImage.Interleaved16Fx4.self): return 0x5247_6841 // 'RGhA'
    case ObjectIdentifier(vImage.InterleavedFx4.self): return 0x5247_6641   // 'RGfA'
    default: return nil
    }
}

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    /// Calls body with a Core Video pixel buffer sharing these pixels, its base address locked (read-only or not).
    public func withCVPixelBuffer(readOnly: Bool, body: (CVPixelBuffer) -> Void) {
        guard let type = _cvPixelFormat(Format.self) else { preconditionFailure("vImage.PixelBuffer.withCVPixelBuffer: no Core Video format holds \(Format.self)") }
        var out: CVPixelBuffer?
        let r = CVPixelBufferCreateWithBytes(nil, width, height, type, _buffer.data, _buffer.rowBytes, nil, nil, nil, &out)
        guard r == kCVReturnSuccess, let cv = out else { preconditionFailure("vImage.PixelBuffer.withCVPixelBuffer: error \(r)") }
        let flags: CVPixelBufferLockFlags = readOnly ? .readOnly : []
        CVPixelBufferLockBaseAddress(cv, flags)
        defer { CVPixelBufferUnlockBaseAddress(cv, flags) }
        body(cv)
    }
}

extension vImage_ARGBToYpCbCrMatrix {
    public static let itu_R_601_4: vImage_ARGBToYpCbCrMatrix = kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4.pointee
    public static let itu_R_709_2: vImage_ARGBToYpCbCrMatrix = kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2.pointee
}
