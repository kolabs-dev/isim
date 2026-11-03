// isim Accelerate Swift overlay (issue #814): vImage.PixelBuffer's gamma, polynomial, lookup, matrix multiply, clip,
// threshold and interpolation operations, over isim's C vImage. Interleaved formats are processed as planar buffers
// width x channels wide where the operation is per component. Adapted.
@_exported import Accelerate
import CoreGraphics
@_exported import simd   // Apple's Accelerate brings simd's types with it

extension vImage {
    /// A gamma function.
    public enum Gamma {
        case fullPrecision(Float)
        case halfPrecision(Float)
        case fiveOverNineHalfPrecision
        case nineOverFiveHalfPrecision
        case fiveOverElevenHalfPrecision
        case elevenOverFiveHalfPrecision
        case sRGBForwardHalfPrecision
        case sRGBReverseHalfPrecision
        case elevenOverNineHalfPrecision
        case nineOverElevenHalfPrecision
        case bt709ForwardHalfPrecision
        case bt709ReverseHalfPrecision
        var _c: (Float, Int32) {
            switch self {
            case .fullPrecision(let g): return (g, Int32(kvImageGamma_UseGammaValue))
            case .halfPrecision(let g): return (g, Int32(kvImageGamma_UseGammaValue_half_precision))
            case .fiveOverNineHalfPrecision: return (0, Int32(kvImageGamma_5_over_9_half_precision))
            case .nineOverFiveHalfPrecision: return (0, Int32(kvImageGamma_9_over_5_half_precision))
            case .fiveOverElevenHalfPrecision: return (0, Int32(kvImageGamma_5_over_11_half_precision))
            case .elevenOverFiveHalfPrecision: return (0, Int32(kvImageGamma_11_over_5_half_precision))
            case .sRGBForwardHalfPrecision: return (0, Int32(kvImageGamma_sRGB_forward_half_precision))
            case .sRGBReverseHalfPrecision: return (0, Int32(kvImageGamma_sRGB_reverse_half_precision))
            case .elevenOverNineHalfPrecision: return (0, Int32(kvImageGamma_11_over_9_half_precision))
            case .nineOverElevenHalfPrecision: return (0, Int32(kvImageGamma_9_over_11_half_precision))
            case .bt709ForwardHalfPrecision: return (0, Int32(kvImageGamma_BT709_forward_half_precision))
            case .bt709ReverseHalfPrecision: return (0, Int32(kvImageGamma_BT709_reverse_half_precision))
            }
        }
        func _with(_ body: (GammaFunction) -> vImage_Error) -> vImage_Error {
            let (g, t) = _c
            guard let f = vImageCreateGammaFunction(g, t, 0) else { return vImage_Error(kvImageInternalError) }
            defer { vImageDestroyGammaFunction(f) }
            return body(f)
        }
    }
}

// MARK: helpers

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    /// The buffer as one planar buffer, width x channels components wide.
    var _wide: vImage_Buffer {
        var b = _buffer; b.width *= vImagePixelCount(Format.channelCount); return b
    }
    /// Runs a C function on the source and destination as planar buffers width x channels wide.
    func _callWide<F: SinglePlanePixelFormat>(_ destination: vImage.PixelBuffer<F>,
                                              _ fn: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>) -> vImage_Error) {
        precondition(Format.channelCount == F.channelCount && size == destination.size, "vImage.PixelBuffer: the buffers don't match")
        var s = _wide, d = destination._wide
        let e = fn(&s, &d)
        precondition(e >= 0, "vImage: error \(e)")
    }
    /// Applies a per-component function row by row.
    func _mapComponents<F: SinglePlanePixelFormat>(_ destination: vImage.PixelBuffer<F>, _ f: (Format.ComponentType) -> F.ComponentType) {
        precondition(Format.channelCount == F.channelCount && size == destination.size, "vImage.PixelBuffer: the buffers don't match")
        let n = width * Format.channelCount, s = _buffer, d = destination._buffer
        for y in 0..<height {
            let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
            let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: F.ComponentType.self)
            for i in 0..<n { dr[i] = f(sr[i]) }
        }
    }
}

func _polynomial(_ segments: [[Float]], _ boundaries: [Float],
                 _ fn: (UnsafeMutablePointer<UnsafePointer<Float>?>, UnsafePointer<Float>, UInt32, UInt32) -> vImage_Error) -> vImage_Error {
    precondition(!segments.isEmpty && segments.count & (segments.count - 1) == 0, "vImage applyPolynomial: a power of two of segments")
    precondition(boundaries.count == segments.count + 1, "vImage applyPolynomial: segments + 1 boundaries")
    let order = segments[0].count - 1
    precondition(segments.allSatisfy { $0.count == order + 1 }, "vImage applyPolynomial: the segments differ in order")
    let flat = segments.flatMap { $0 }
    return flat.withUnsafeBufferPointer { f in
        var ptrs: [UnsafePointer<Float>?] = (0..<segments.count).map { f.baseAddress! + $0 * (order + 1) }
        return fn(&ptrs, boundaries, UInt32(order), UInt32(segments.count.trailingZeroBitCount))
    }
}

// MARK: gamma, polynomials, clip, threshold, interpolation (float formats)

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat, Format.ComponentType == Pixel_F {
    public func applyGamma(_ gamma: vImage.Gamma, destination: vImage.PixelBuffer<Format>) {
        _callWide(destination) { s, d in gamma._with { vImageGamma_PlanarF(s, d, $0, 0) } }
    }
    public func applyGamma(linearParameters: (scale: Float, bias: Float),
                           exponentialParameters: (scale: Float, preBias: Float, gamma: Float, postBias: Float),
                           boundary: Float, destination: vImage.PixelBuffer<Format>) {
        let e = [exponentialParameters.scale, exponentialParameters.preBias, exponentialParameters.postBias]
        let l = [linearParameters.scale, linearParameters.bias]
        _callWide(destination) { vImagePiecewiseGamma_PlanarF($0, $1, e, exponentialParameters.gamma, l, boundary, 0) }
    }
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<Format>) {
        _callWide(destination) { s, d in _polynomial(coefficientSegments, boundaries) { vImagePiecewisePolynomial_PlanarF(s, d, $0, $1, $2, $3, 0) } }
    }
    public func clip(to range: ClosedRange<Float>, destination: vImage.PixelBuffer<Format>) {
        _callWide(destination) { vImageClip_PlanarF($0, $1, range.upperBound, range.lowerBound, 0) }
    }
    /// 1 where a value is at or above the threshold, 0 below it.
    public func colorThreshold(_ threshold: Float, destination: vImage.PixelBuffer<Format>) {
        _mapComponents(destination) { $0 >= threshold ? 1 : 0 }
    }
    /// self + t x (bufferB - self), per component.
    public func linearInterpolate(bufferB: vImage.PixelBuffer<Format>, interpolationConstant t: Float, destination: vImage.PixelBuffer<Format>) {
        precondition(bufferB.size == size && destination.size == size, "vImage.PixelBuffer.linearInterpolate: the buffers differ in size")
        let n = width * Format.channelCount, a = _buffer, b = bufferB._buffer, d = destination._buffer
        for y in 0..<height {
            let ar = a.data.advanced(by: y * a.rowBytes).assumingMemoryBound(to: Float.self)
            let br = b.data.advanced(by: y * b.rowBytes).assumingMemoryBound(to: Float.self)
            let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: Float.self)
            for i in 0..<n { dr[i] = ar[i] + t * (br[i] - ar[i]) }
        }
    }
}

// float -> 8-bit and 8-bit -> float polynomials, gamma through a float intermediate
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.Planar8>) {
        _callWide(destination) { s, d in _polynomial(coefficientSegments, boundaries) { vImagePiecewisePolynomial_PlanarFtoPlanar8(s, d, $0, $1, $2, $3, 0) } }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx2 {
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.Interleaved8x2>) {
        _callWide(destination) { s, d in _polynomial(coefficientSegments, boundaries) { vImagePiecewisePolynomial_PlanarFtoPlanar8(s, d, $0, $1, $2, $3, 0) } }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx3 {
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.Interleaved8x3>) {
        _callWide(destination) { s, d in _polynomial(coefficientSegments, boundaries) { vImagePiecewisePolynomial_PlanarFtoPlanar8(s, d, $0, $1, $2, $3, 0) } }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        _callWide(destination) { s, d in _polynomial(coefficientSegments, boundaries) { vImagePiecewisePolynomial_PlanarFtoPlanar8(s, d, $0, $1, $2, $3, 0) } }
    }
}

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat, Format.ComponentType == Pixel_8 {
    func _gamma8<F: SinglePlanePixelFormat>(_ gamma: vImage.Gamma, _ intermediate: vImage.PixelBuffer<F>?, _ destination: vImage.PixelBuffer<Format>) {
        let tmp = intermediate ?? vImage.PixelBuffer<F>(size: size)
        precondition(tmp.size == size, "vImage.PixelBuffer.applyGamma: the intermediate buffer differs in size")
        _callWide(tmp) { s, d in gamma._with { vImageGamma_Planar8toPlanarF(s, d, $0, 0) } }
        tmp._callWide(destination) { vImageConvert_PlanarFtoPlanar8($0, $1, 1, 0, 0) }
    }
    func _poly8<F: SinglePlanePixelFormat>(_ segments: [[Float]], _ boundaries: [Float], _ destination: vImage.PixelBuffer<F>) {
        _callWide(destination) { s, d in _polynomial(segments, boundaries) { vImagePiecewisePolynomial_Planar8toPlanarF(s, d, $0, $1, $2, $3, 0) } }
    }
    public func applyGamma(linearParameters: (scale: Float, bias: Float),
                           exponentialParameters: (scale: Float, preBias: Float, gamma: Float, postBias: Float),
                           boundary: Pixel_8, destination: vImage.PixelBuffer<Format>) {
        let e = [exponentialParameters.scale, exponentialParameters.preBias, exponentialParameters.postBias]
        let l = [linearParameters.scale, linearParameters.bias]
        _callWide(destination) { vImagePiecewiseGamma_Planar8($0, $1, e, exponentialParameters.gamma, l, boundary, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func applyGamma(_ gamma: vImage.Gamma, intermediateBuffer: vImage.PixelBuffer<vImage.PlanarF>? = nil, destination: vImage.PixelBuffer<vImage.Planar8>) {
        _gamma8(gamma, intermediateBuffer, destination)
    }
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _poly8(coefficientSegments, boundaries, destination)
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x2 {
    public func applyGamma(_ gamma: vImage.Gamma, intermediateBuffer: vImage.PixelBuffer<vImage.InterleavedFx2>? = nil,
                           destination: vImage.PixelBuffer<vImage.Interleaved8x2>) {
        _gamma8(gamma, intermediateBuffer, destination)
    }
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.InterleavedFx2>) {
        _poly8(coefficientSegments, boundaries, destination)
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x3 {
    public func applyGamma(_ gamma: vImage.Gamma, intermediateBuffer: vImage.PixelBuffer<vImage.InterleavedFx3>? = nil,
                           destination: vImage.PixelBuffer<vImage.Interleaved8x3>) {
        _gamma8(gamma, intermediateBuffer, destination)
    }
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.InterleavedFx3>) {
        _poly8(coefficientSegments, boundaries, destination)
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func applyGamma(_ gamma: vImage.Gamma, intermediateBuffer: vImage.PixelBuffer<vImage.InterleavedFx4>? = nil,
                           destination: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        _gamma8(gamma, intermediateBuffer, destination)
    }
    public func applyPolynomial(coefficientSegments: [[Float]], boundaries: [Float], destination: vImage.PixelBuffer<vImage.InterleavedFx4>) {
        _poly8(coefficientSegments, boundaries, destination)
    }
    /// A table per channel (nil leaves the channel unchanged).
    public func applyLookup(alphaTable: [Pixel_8]?, redTable: [Pixel_8]?, greenTable: [Pixel_8]?, blueTable: [Pixel_8]?,
                            destination: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        for t in [alphaTable, redTable, greenTable, blueTable] { precondition(t == nil || t!.count >= 256, "vImage applyLookup: 256 entries") }
        _call2(destination) { vImageTableLookUp_ARGB8888($0, $1, alphaTable, redTable, greenTable, blueTable, 0) }
    }
}

// MARK: lookup tables

extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func applyLookup(_ table: [Pixel_8], destination: vImage.PixelBuffer<vImage.Planar8>) {
        precondition(table.count >= 256, "vImage applyLookup: 256 entries")
        _call2(destination) { vImageTableLookUp_Planar8($0, $1, table, 0) }
    }
    public func applyLookup(_ table: [Pixel_F], destination: vImage.PixelBuffer<vImage.PlanarF>) {
        precondition(table.count >= 256, "vImage applyLookup: 256 entries")
        _call2(destination) { vImageLookupTable_Planar8toPlanarF($0, $1, table, 0) }
    }
    public func applyLookup(_ table: [Pixel_16U], destination: vImage.PixelBuffer<vImage.Planar16U>) {
        precondition(table.count >= 256, "vImage applyLookup: 256 entries")
        _mapIndexed(destination, 1) { d, v in d[0] = table[Int(v)] }
    }
    /// Each value picks a table entry; the first three of its four channels are written.
    public func applyLookup(_ table: [Pixel_8888], destination: vImage.PixelBuffer<vImage.Interleaved8x3>) {
        precondition(table.count >= 256, "vImage applyLookup: 256 entries")
        _mapIndexed(destination, 3) { d, v in let e = table[Int(v)]; d[0] = e.0; d[1] = e.1; d[2] = e.2 }
    }
    public func applyLookup(_ table: [Pixel_FFFF], destination: vImage.PixelBuffer<vImage.InterleavedFx3>) {
        precondition(table.count >= 256, "vImage applyLookup: 256 entries")
        _mapIndexed(destination, 3) { d, v in let e = table[Int(v)]; d[0] = e.0; d[1] = e.1; d[2] = e.2 }
    }
    func _mapIndexed<F: SinglePlanePixelFormat>(_ destination: vImage.PixelBuffer<F>, _ channels: Int,
                                                _ f: (UnsafeMutablePointer<F.ComponentType>, UInt8) -> Void) {
        precondition(size == destination.size, "vImage applyLookup: the buffers differ in size")
        let s = _buffer, d = destination._buffer
        for y in 0..<height {
            let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
            let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: F.ComponentType.self)
            for x in 0..<width { f(dr + x * channels, sr[x]) }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    /// 4096 entries over 0...1.
    public func applyLookup(_ table: [Pixel_8], destination: vImage.PixelBuffer<vImage.Planar8>) {
        precondition(table.count >= 4096, "vImage applyLookup: 4096 entries")
        _call2(destination) { vImageLookupTable_PlanarFtoPlanar8($0, $1, table, 0) }
    }
    /// Entries spread over 0...1, interpolated between.
    public func applyLookup(_ table: [Pixel_F], destination: vImage.PixelBuffer<vImage.PlanarF>) {
        precondition(table.count >= 2, "vImage applyLookup: at least 2 entries")
        _call2(destination) { vImageInterpolatedLookupTable_PlanarF($0, $1, table, vImagePixelCount(table.count - 1), 1, 0, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func applyLookup(_ table: [Pixel_16U], destination: vImage.PixelBuffer<vImage.Planar16U>) {
        precondition(table.count >= 65536, "vImage applyLookup: 65536 entries")
        _call2(destination) { vImageLookupTable_Planar16($0, $1, table, 0) }
    }
}

// MARK: matrix multiplication

func _ints<T: BinaryInteger>(_ t: (T, T, T, T)) -> [T] { [t.0, t.1, t.2, t.3] }
func _floats(_ t: (Float, Float, Float, Float)) -> [Float] { [t.0, t.1, t.2, t.3] }

extension vImage.PixelBuffer where Format == vImage.Planar8 {
    /// (value + preBias) x by / divisor + postBias.
    public func multiply(by multiplier: Int, divisor: Int, preBias: Int, postBias: Int, destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { s, d in
            var src: UnsafePointer<vImage_Buffer>? = s, dst: UnsafePointer<vImage_Buffer>? = d
            return vImageMatrixMultiply_Planar8(&src, &dst, 1, 1, [Int16(multiplier)], Int32(divisor), [Int16(preBias)], [Int32(postBias)], 0)
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func multiply(by multiplier: Float, preBias: Float, postBias: Float, destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _call2(destination) { s, d in
            var src: UnsafePointer<vImage_Buffer>? = s, dst: UnsafePointer<vImage_Buffer>? = d
            return vImageMatrixMultiply_PlanarF(&src, &dst, 1, 1, [multiplier], [preBias], [postBias], 0)
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    /// The weighted sum of the four channels into one.
    public func multiply(by multipliers: (Int, Int, Int, Int), divisor: Int, preBias: (Int, Int, Int, Int), postBias: Int,
                         destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { vImageMatrixMultiply_ARGB8888ToPlanar8($0, $1, _ints(multipliers).map(Int16.init), Int32(divisor),
                                                                     _ints(preBias).map(Int16.init), Int32(postBias), 0) }
    }
    /// A 4 x 4 matrix (16 values, row-major in vImage's sense) over the channels.
    public func multiply<Matrix>(by matrix: Matrix, divisor: Int, preBias: (Int, Int, Int, Int), postBias: (Int, Int, Int, Int),
                                 destination: vImage.PixelBuffer<vImage.Interleaved8x4>) where Matrix: AccelerateBuffer, Matrix.Element == Int16 {
        precondition(matrix.count == 16, "vImage.PixelBuffer.multiply: a 4 x 4 matrix")
        let m = matrix.withUnsafeBufferPointer { Array($0) }
        _call2(destination) { vImageMatrixMultiply_ARGB8888($0, $1, m, Int32(divisor), _ints(preBias).map(Int16.init), _ints(postBias).map(Int32.init), 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func multiply(by multipliers: (Float, Float, Float, Float), preBias: (Float, Float, Float, Float), postBias: Float,
                         destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _call2(destination) { vImageMatrixMultiply_ARGBFFFFToPlanarF($0, $1, _floats(multipliers), _floats(preBias), postBias, 0) }
    }
    public func multiply<Matrix>(by matrix: Matrix, preBias: (Float, Float, Float, Float), postBias: (Float, Float, Float, Float),
                                 destination: vImage.PixelBuffer<vImage.InterleavedFx4>) where Matrix: AccelerateBuffer, Matrix.Element == Float {
        precondition(matrix.count == 16, "vImage.PixelBuffer.multiply: a 4 x 4 matrix")
        let m = matrix.withUnsafeBufferPointer { Array($0) }
        _call2(destination) { vImageMatrixMultiply_ARGBFFFF($0, $1, m, _floats(preBias), _floats(postBias), 0) }
    }
    /// A simd matrix: its columns are the matrix's rows in vImage's sense.
    public func multiply(by matrix: simd_float4x4, preBias: (Float, Float, Float, Float), postBias: (Float, Float, Float, Float),
                         destination: vImage.PixelBuffer<vImage.InterleavedFx4>) {
        let c = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
        let m = (0..<16).map { c[$0 / 4][$0 % 4] }
        multiply(by: m, preBias: preBias, postBias: postBias, destination: destination)
    }
}
extension vImage.PixelBuffer where Format: MultiplePlanePixelFormat, Format.PlanarPixelFormat == vImage.Planar8 {
    /// A source planes x destination planes matrix (row-major in vImage's sense) over the planes.
    public func multiply<Matrix, DestFormat>(by matrix: Matrix, divisor: Int, preBias: [Int], postBias: [Int],
                                             destination: vImage.PixelBuffer<DestFormat>)
        where Matrix: AccelerateBuffer, Matrix.Element == Int16, DestFormat: MultiplePlanePixelFormat, DestFormat.PlanarPixelFormat == vImage.Planar8 {
        let n = Format.planeCount, m = DestFormat.planeCount
        precondition(matrix.count == n * m && preBias.count == n && postBias.count == m, "vImage.PixelBuffer.multiply: the matrix or biases don't fit the planes")
        let mat = matrix.withUnsafeBufferPointer { Array($0) }
        _planesCall(destination) { s, d in
            vImageMatrixMultiply_Planar8(s, d, UInt32(n), UInt32(m), mat, Int32(divisor), preBias.map(Int16.init), postBias.map(Int32.init), 0) }
    }
}
extension vImage.PixelBuffer where Format: MultiplePlanePixelFormat, Format.PlanarPixelFormat == vImage.PlanarF {
    public func multiply<Matrix, DestFormat>(by matrix: Matrix, preBias: [Float], postBias: [Float], destination: vImage.PixelBuffer<DestFormat>)
        where Matrix: AccelerateBuffer, Matrix.Element == Float, DestFormat: MultiplePlanePixelFormat, DestFormat.PlanarPixelFormat == vImage.PlanarF {
        let n = Format.planeCount, m = DestFormat.planeCount
        precondition(matrix.count == n * m && preBias.count == n && postBias.count == m, "vImage.PixelBuffer.multiply: the matrix or biases don't fit the planes")
        let mat = matrix.withUnsafeBufferPointer { Array($0) }
        _planesCall(destination) { s, d in vImageMatrixMultiply_PlanarF(s, d, UInt32(n), UInt32(m), mat, preBias, postBias, 0) }
    }
}
extension vImage.PixelBuffer {
    /// Calls a C function taking arrays of pointers to the source's and destination's planes.
    func _planesCall<F>(_ destination: vImage.PixelBuffer<F>,
                        _ fn: (UnsafeMutablePointer<UnsafePointer<vImage_Buffer>?>, UnsafeMutablePointer<UnsafePointer<vImage_Buffer>?>) -> vImage_Error) {
        var s = _buffers, d = destination._buffers
        let e = s.withUnsafeMutableBufferPointer { sp in d.withUnsafeMutableBufferPointer { dp in
            var sps: [UnsafePointer<vImage_Buffer>?] = (0..<sp.count).map { UnsafePointer(sp.baseAddress! + $0) }
            var dps: [UnsafePointer<vImage_Buffer>?] = (0..<dp.count).map { UnsafePointer(dp.baseAddress! + $0) }
            return fn(&sps, &dps)
        } }
        precondition(e >= 0, "vImage: error \(e)")
    }
}
