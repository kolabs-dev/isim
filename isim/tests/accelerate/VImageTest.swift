// vImage from Swift (VImageTest.app, issue #371): vImage_Buffer, vImage_CGImageFormat and vImageConverter's Swift API,
// vImage.PixelBuffer (creation, CGImage round trips, scaling, reflection, rotation, conversion, histograms,
// convolution, premultiplication) and the C functions as Swift imports them.
import Foundation
import Accelerate
import CoreGraphics
import CoreVideo

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

@main enum VImageTest {
    static func main() {
        // the C API as Swift sees it
        var b = vImage_Buffer()
        check(vImageBuffer_Init(&b, 2, 3, 32, vImage_Flags(kvImageNoFlags)) == kvImageNoError && b.width == 3 && b.height == 2, "vImageBuffer_Init from Swift")
        b.free()
        check(vImage.Error(vImageError: vImage_Error(kvImageInvalidKernelSize)) == .invalidKernelSize
              && vImage.Error(rawValue: -21772) == .nullPointerArgument, "vImage.Error")
        check(vImage.Options([.highQualityResampling, .imageExtend]).flags == vImage_Flags(kvImageHighQualityResampling | kvImageEdgeExtend), "vImage.Options")
        check(vImage.Size(exactly: CGSize(width: 4, height: 2)) == vImage.Size(width: 4, height: 2) && vImage.Size(exactly: CGSize(width: 1.5, height: 2)) == nil,
              "vImage.Size")

        // vImage_Buffer and Core Graphics
        guard let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)) else {
            check(false, "vImage_CGImageFormat"); return finish()
        }
        check(format.componentCount == 4, "vImage_CGImageFormat.componentCount")
        do {
            let buffer = try vImage_Buffer(width: 2, height: 2, bitsPerPixel: 32)
            let p = buffer.data.assumingMemoryBound(to: UInt8.self)
            for y in 0..<2 { for x in 0..<2 { let q = p + y * buffer.rowBytes + x * 4; q[0] = UInt8(x * 200); q[1] = UInt8(y * 200); q[2] = 50; q[3] = 255 } }
            check(buffer.size == CGSize(width: 2, height: 2), "vImage_Buffer.size")
            let image = try buffer.createCGImage(format: format)
            check(image.width == 2 && image.height == 2, "createCGImage(format:)")
            let back = try vImage_Buffer(cgImage: image, format: format)
            let r = back.data.assumingMemoryBound(to: UInt8.self)
            check(r[4] == 200 && (r + back.rowBytes)[1] == 200 && r[2] == 50, "vImage_Buffer(cgImage:format:) round trip")
            var copy = try vImage_Buffer(width: 2, height: 2, bitsPerPixel: 32)
            try buffer.copy(destinationBuffer: &copy, pixelSize: 4)
            check(copy.data.assumingMemoryBound(to: UInt8.self)[4] == 200, "copy(destinationBuffer:pixelSize:)")
            // a converter to BGRA
            let bgraFormat = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))!
            let converter = try vImageConverter.make(sourceFormat: format, destinationFormat: bgraFormat)
            var bgra = try vImage_Buffer(width: 2, height: 2, bitsPerPixel: 32)
            try converter.convert(source: buffer, destination: &bgra)
            let c = bgra.data.assumingMemoryBound(to: UInt8.self)
            check(c[4] == 50 && c[6] == 200 && c[7] == 255, "vImageConverter.convert(source:destination:)")
            check(converter.sourceBufferCount == 1 && converter.sourceBuffers(colorSpace: CGColorSpaceCreateDeviceRGB()) == [.coreGraphics],
                  "the converter's buffers")
            let outOfPlace = try converter.mustOperateOutOfPlace(source: buffer, destination: bgra)
            check(!outOfPlace, "mustOperateOutOfPlace")
            let (alignment, rowBytes) = try vImage_Buffer.preferredAlignmentAndRowBytes(width: 3, height: 3, bitsPerPixel: 32)
            check(alignment > 0 && rowBytes >= 12, "preferredAlignmentAndRowBytes")
            buffer.free(); back.free(); copy.free(); bgra.free()
        } catch {
            check(false, "vImage_Buffer threw \(error)")
        }

        // PixelBuffer
        let planar = vImage.PixelBuffer(pixelValues: [UInt8]([1, 2, 3, 4, 5, 6]), size: vImage.Size(width: 3, height: 2), pixelFormat: vImage.Planar8.self)
        check(planar.width == 3 && planar.height == 2 && planar.array == [1, 2, 3, 4, 5, 6] && planar.channelCount == 1, "PixelBuffer(pixelValues:)")
        let reflected = vImage.PixelBuffer(size: planar.size, pixelFormat: vImage.Planar8.self)
        planar.reflect(over: .horizontal, destination: reflected)
        check(reflected.array == [3, 2, 1, 6, 5, 4], "reflect(over:destination:)")
        let turned = vImage.PixelBuffer(width: 2, height: 3, pixelFormat: vImage.Planar8.self)
        planar.rotate(.counterClockwise90Degrees, destination: turned)
        check(turned.array == [3, 6, 2, 5, 1, 4], "rotate(_:destination:) a quarter turn")
        let floats = vImage.PixelBuffer(size: planar.size, pixelFormat: vImage.PlanarF.self)
        let bright = vImage.PixelBuffer(pixelValues: [UInt8]([0, 51, 255, 0, 0, 0]), size: planar.size, pixelFormat: vImage.Planar8.self)
        bright.convert(to: floats)
        check(floats.array[1] == 0.2 && floats.array[2] == 1, "convert(to:) Planar8 to PlanarF")
        let eight = vImage.PixelBuffer(size: planar.size, pixelFormat: vImage.Planar8.self)
        floats.convert(to: eight)
        check(eight.array == bright.array, "convert(to:) PlanarF to Planar8")
        let h = bright.histogram()
        check(h[0] == 4 && h[51] == 1 && h[255] == 1, "histogram()")
        let flat = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 80, count: 25), size: vImage.Size(width: 5, height: 5), pixelFormat: vImage.Planar8.self)
        let blurred = vImage.PixelBuffer(size: flat.size, pixelFormat: vImage.Planar8.self)
        flat.boxConvolve(kernelSize: vImage.Size(width: 3, height: 3), edgeMode: .extend, destination: blurred)
        check(blurred.array.allSatisfy { $0 == 80 }, "boxConvolve(kernelSize:edgeMode:destination:)")
        flat.tentConvolve(kernelSize: vImage.Size(width: 3, height: 3), edgeMode: .fill(backgroundColor: 0), destination: blurred)
        check(blurred.array[12] == 80 && blurred.array[0] < 80, "tentConvolve with a background fill")

        let argb = vImage.PixelBuffer(pixelValues: [UInt8]([128, 255, 100, 0, 255, 10, 20, 30]), size: vImage.Size(width: 2, height: 1),
                                      pixelFormat: vImage.Interleaved8x4.self)
        let pre = vImage.PixelBuffer(size: argb.size, pixelFormat: vImage.Interleaved8x4.self)
        argb.copy(to: pre)
        pre.premultiply(channelOrdering: .ARGB)
        check(pre.array == [128, 128, 50, 0, 255, 10, 20, 30], "premultiply(channelOrdering:)")
        argb.permuteChannels(to: (3, 2, 1, 0), destination: pre)
        check(pre.array == [0, 100, 255, 128, 30, 20, 10, 255], "permuteChannels(to:destination:)")
        let wide = vImage.PixelBuffer(width: 4, height: 2, pixelFormat: vImage.Interleaved8x4.self)
        let solid = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 77, count: 16), size: vImage.Size(width: 2, height: 2), pixelFormat: vImage.Interleaved8x4.self)
        solid.scale(destination: wide)
        check(wide.array.allSatisfy { $0 == 77 }, "scale(destination:)")
        let fx4 = vImage.PixelBuffer(size: argb.size, pixelFormat: vImage.InterleavedFx4.self)
        argb.convert(to: fx4)
        check(fx4.array[1] == 1 && abs(fx4.array[2] - 100 / 255) < 1e-6, "convert(to:) Interleaved8x4 to InterleavedFx4")
        let rgb = vImage.PixelBuffer(size: argb.size, pixelFormat: vImage.Interleaved8x3.self)
        argb.convert(to: rgb)
        check(rgb.array == [255, 100, 0, 10, 20, 30], "convert(to:) Interleaved8x4 to Interleaved8x3")

        // PixelBuffer and Core Graphics
        let rgbaBuffer = vImage.PixelBuffer(pixelValues: [UInt8]([255, 0, 0, 255, 0, 255, 0, 255]), size: vImage.Size(width: 2, height: 1),
                                            pixelFormat: vImage.Interleaved8x4.self)
        if let image = rgbaBuffer.makeCGImage(cgImageFormat: format) {
            var f = format
            if let again = try? vImage.PixelBuffer(cgImage: image, cgImageFormat: &f, pixelFormat: vImage.Interleaved8x4.self) {
                check(again.array == rgbaBuffer.array, "makeCGImage and PixelBuffer(cgImage:cgImageFormat:)")
            } else { check(false, "PixelBuffer(cgImage:cgImageFormat:)") }
        } else { check(false, "makeCGImage(cgImageFormat:)") }
        rgbaBuffer.withUnsafeRegionOfInterest(CGRect(x: 1, y: 0, width: 1, height: 1)) { roi in
            check(roi.width == 1 && roi.array == [0, 255, 0, 255], "withUnsafeRegionOfInterest")
        }
        coreVideo()
        deepFormats()
        pixelBufferMore()
        finish()
    }
    /// issue #693: vImageCVImageFormat, converters, and PixelBuffers over CVPixelBuffers
    static func coreVideo() {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, 4, 2, kCVPixelFormatType_32BGRA, nil, &pb)
        guard let pb else { check(false, "a BGRA pixel buffer"); return }
        CVPixelBufferLockBaseAddress(pb, [])
        let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self), rb = CVPixelBufferGetBytesPerRow(pb)
        for y in 0..<2 { for x in 0..<4 { let p = base + y * rb + x * 4; p[0] = 10; p[1] = 120; p[2] = 240; p[3] = 255 } }
        CVPixelBufferUnlockBaseAddress(pb, [])
        guard let cv = vImageCVImageFormat.make(buffer: pb) else { check(false, "vImageCVImageFormat.make(buffer:)"); return }
        check(cv.formatCode == kCVPixelFormatType_32BGRA && cv.channelCount == 4 && cv.channels == [.rgbRed, .rgbGreen, .rgbBlue, .alpha],
              "vImageCVImageFormat.make(buffer:): format code and channels")
        cv.alphaIsOpaqueHint = true
        check(cv.alphaIsOpaqueHint && cv.colorSpace != nil, "alphaIsOpaqueHint and colorSpace")
        var fmt = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue))!
        if let buf = try? vImage.PixelBuffer(copying: pb, cvImageFormat: cv, cgImageFormat: &fmt, pixelFormat: vImage.Interleaved8x4.self) {
            check(Array(buf.array.prefix(4)) == [255, 240, 120, 10] && buf.size == vImage.Size(cvPixelBuffer: pb),
                  "PixelBuffer(copying:cvImageFormat:cgImageFormat:pixelFormat:) and Size(cvPixelBuffer:)")
            buf.withUnsafeMutableBufferPointer { p in for i in stride(from: 0, to: p.count, by: 4) { p[i + 1] = 1; p[i + 2] = 2; p[i + 3] = 3 } }
            check((try? buf.copy(to: pb, cvImageFormat: cv, cgImageFormat: fmt)) != nil, "PixelBuffer.copy(to:cvImageFormat:cgImageFormat:)")
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            check(base[0] == 3 && base[1] == 2 && base[2] == 1, "the copy lands in BGRA order")
            let plane = vImage.PixelBuffer(referencing: pb, planeIndex: 0, pixelFormat: vImage.Interleaved8x4.self)
            check(plane.width == 4 && Array(plane.array.prefix(3)) == [3, 2, 1], "PixelBuffer(referencing:planeIndex:overrideSize:pixelFormat:)")
            CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        } else { check(false, "PixelBuffer(copying:...)") }
        // a 4:2:0 format made by hand, converters both ways
        guard let yuv = vImageCVImageFormat.make(format: .format420YpCbCr8BiPlanarVideoRange, matrix: kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4.pointee,
                                                  chromaSiting: .center, colorSpace: CGColorSpaceCreateDeviceRGB(), alphaIsOpaqueHint: true) else {
            check(false, "vImageCVImageFormat.make(format:matrix:...)"); return
        }
        check(yuv.chromaSiting == .center && yuv.channels == [.luminance, .Cb, .Cr], "make(format:matrix:chromaSiting:...): siting and channels")
        let lum = yuv.channelDescription(bufferType: .luminance)
        check(lum?.zero == 16 && lum?.full == 235, "channelDescription(bufferType:): video range luminance")
        do {
            let toCV = try vImageConverter.make(sourceFormat: fmt, destinationFormat: yuv)
            let toCG = try vImageConverter.make(sourceFormat: yuv, destinationFormat: fmt)
            check(toCV.destinationBufferCount == 2 && toCG.sourceBufferCount == 2, "vImageConverter.make between CG and CV formats: two planes")
            var y420: CVPixelBuffer?
            CVPixelBufferCreate(nil, 4, 2, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &y420)
            let white = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
            white.initialize(repeating: 255, count: 32)
            defer { white.deallocate() }
            var src = vImage_Buffer(data: white, height: 2, width: 4, rowBytes: 16)
            CVPixelBufferLockBaseAddress(y420!, [])
            var planes = [vImage_Buffer](repeating: vImage_Buffer(), count: 2)
            check(vImageBuffer_InitForCopyToCVPixelBuffer(&planes, toCV, y420!, vImage_Flags(kvImageNoAllocate)) == kvImageNoError
                  && vImageConvert_AnyToAny(toCV, &src, &planes, nil, 0) == kvImageNoError
                  && CVPixelBufferGetBaseAddressOfPlane(y420!, 0)!.load(as: UInt8.self) == 235, "Swift's vImageBuffer_InitForCopyToCVPixelBuffer: white is Y' 235")
            CVPixelBufferUnlockBaseAddress(y420!, [])
        } catch { check(false, "vImageConverter.make(... vImageCVImageFormat ...): \(error)") }
        check(vImageCVImageFormat.make(format: .format32ARGB, colorSpace: CGColorSpaceCreateDeviceRGB(), alphaIsOpaqueHint: false)?.formatCode == 0x20,
              "vImageCVImageFormat.make(format:colorSpace:alphaIsOpaqueHint:)")
    }
    /// issue #693: 10-bit packed RGB, Y'CbCr 16 and the colour spaces from Swift
    static func deepFormats() {
        let px = UnsafeMutablePointer<UInt8>.allocate(capacity: 4), word = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        defer { px.deallocate(); word.deallocate() }
        px[0] = 255; px[1] = 255; px[2] = 0; px[3] = 128
        var s = vImage_Buffer(data: px, height: 1, width: 1, rowBytes: 4), d = vImage_Buffer(data: word, height: 1, width: 1, rowBytes: 4)
        check(vImageConvert_ARGB8888ToARGB2101010(&s, &d, 0, 1023, nil, 0) == kvImageNoError && word.pointee == (3 << 30 | 1023 << 20 | 514),
              "ARGB8888ToARGB2101010 from Swift")
        var primaries = vImageRGBPrimaries(red_x: 0.64, green_x: 0.30, blue_x: 0.15, white_x: 0.3127, red_y: 0.33, green_y: 0.60, blue_y: 0.06, white_y: 0.3290)
        var tf = vImageTransferFunction(c0: 1, c1: 1, c2: 0, c3: 0, gamma: 2.2, cutoff: 0, c4: 0, c5: 0)
        var e = vImage_Error(0)
        let cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&primaries, &tf, .defaultIntent, 0, &e)?.takeRetainedValue()
        check(cs?.numberOfComponents == 3 && e == 0, "vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction from Swift")
    }

    /// issue #814: the rest of vImage.PixelBuffer
    static func pixelBufferMore() {
        let sz = vImage.Size(width: 4, height: 4)
        // formats in Apple's shape
        check(vImage.Planar8x3.planeCount == 3 && vImage.PlanarFx4.bitCountPerPlanarPixel == 32 && vImage.Interleaved8x4.channelCount == 4
              && vImage.Interleaved16Fx4.bitCountPerPixel == 64 && vImage.PlanarF.bitCountPerComponent == 32, "MultiplePlanePixelFormat / StaticPixelFormat / InitializableFromCGImage")
        check(vImage.PlanarF.makePixel(vImage.Planar16F.makePixel(0.5)) == 0.5 && vImage.InterleavedFx2.makePixel(vImage.Interleaved16Fx2.makePixel((1, 2))) == (1, 2),
              "makePixel: Float <-> half")

        // interleaving and the multiple-plane formats
        let rgba = vImage.PixelBuffer(pixelValues: [UInt8](0..<64), size: sz, pixelFormat: vImage.Interleaved8x4.self)
        let planes = rgba.planarBuffers()
        check(planes.count == 4 && planes[1].array == stride(from: 1, to: 64, by: 4).map(UInt8.init), "planarBuffers(): channel 1")
        let back = vImage.PixelBuffer<vImage.Interleaved8x4>(planarBuffers: planes)
        check(back.array == rgba.array, "init(planarBuffers:)")
        let p4 = vImage.PixelBuffer<vImage.Planar8x4>(interleavedBuffer: rgba)
        let i4 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Interleaved8x4.self)
        p4.interleave(destination: i4)
        check(i4.array == rgba.array && p4.withUnsafePixelBuffer(at: 2) { $0.array } == planes[2].array, "Planar8x4: init(interleavedBuffer:), interleave, withUnsafePixelBuffer(at:)")
        let shared = vImage.PixelBuffer(planarBuffers: planes, pixelFormat: vImage.Planar8x4.self)
        check(shared.withUnsafePixelBuffers { $0.count } == 4 && shared.size == sz, "init(planarBuffers:pixelFormat:), withUnsafePixelBuffers")
        check(rgba.makeArray(of: UInt32.self, channelCount: 1).count == 16 && rgba.cropped(to: CGRect(x: 1, y: 1, width: 2, height: 2)).array[0] == 20,
              "makeArray(of:channelCount:), cropped(to:)")

        // convolution and morphology
        let flat = vImage.PixelBuffer(pixelValues: [Float](repeating: 0.5, count: 16), size: sz, pixelFormat: vImage.PlanarF.self)
        let outF = vImage.PixelBuffer(size: sz, pixelFormat: vImage.PlanarF.self)
        flat.convolve(with: vImage.ConvolutionKernel2D(values: [Float](repeating: 1 / 9, count: 9), width: 3, height: 3), edgeMode: .extend, destination: outF)
        check(outF.array.allSatisfy { abs($0 - 0.5) < 1e-5 }, "convolve(with: ConvolutionKernel2D<Float>)")
        flat.separableConvolve(horizontalKernel: vImage.ConvolutionKernel.gaussian1Dx3, verticalKernel: vImage.ConvolutionKernel.gaussian1Dx3,
                               edgeMode: .extend, destination: outF)
        check(outF.array.allSatisfy { abs($0 - 0.5) < 1e-5 }, "separableConvolve, ConvolutionKernel.gaussian1Dx3")
        let dot = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 0, count: 5) + [200] + [UInt8](repeating: 0, count: 10), size: sz, pixelFormat: vImage.Planar8.self)
        let out8 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Planar8.self)
        dot.applyMorphology(operation: .maximize(kernelSize: vImage.Size(width: 3, height: 3)), destination: out8)
        check(out8.array.filter { $0 == 200 }.count == 9, "applyMorphology(.maximize)")
        let op = vImage.MorphologyOperation<Pixel_8>.dilate(structuringElement: vImage.ConvolutionKernel2D(values: [UInt8](repeating: 0, count: 9), width: 3, height: 3))
        check(op.width == 3 && op.structuringElement != nil, "MorphologyOperation's width, structuringElement")
        dot.convolve(with: vImage.ConvolutionKernel2D(values: [Int16](repeating: 1, count: 9), width: 3, height: 3), edgeMode: .extend, destination: out8)
        check(out8.array[0] == 22 && out8.array[15] == 0, "convolve(with: ConvolutionKernel2D<Int16>), divisor from the kernel")
        let boxed = rgba.boxConvolved(kernelSize: vImage.Size(width: 1, height: 1), edgeMode: .extend)
        check(boxed.array == rgba.array, "boxConvolved")

        // tone and lookup
        let ramp = vImage.PixelBuffer(pixelValues: (0..<16).map { Float($0) / 15 }, size: sz, pixelFormat: vImage.PlanarF.self)
        ramp.applyGamma(.fullPrecision(2), destination: outF)
        check(abs(outF.array[15] - 1) < 1e-4 && abs(outF.array[5] - pow(5 / 15, 2)) < 1e-3, "applyGamma(.fullPrecision)")
        ramp.applyPolynomial(coefficientSegments: [[0, 2]], boundaries: [0, 1], destination: outF)
        check(abs(outF.array[3] - 0.4) < 1e-5, "applyPolynomial: 2x")
        ramp.clip(to: 0.25...0.5, destination: outF)
        check(outF.array[0] == 0.25 && outF.array[15] == 0.5, "clip(to:)")
        ramp.colorThreshold(0.5, destination: outF)
        check(outF.array[7] == 0 && outF.array[8] == 1, "colorThreshold")
        ramp.linearInterpolate(bufferB: flat, interpolationConstant: 0.5, destination: outF)
        check(abs(outF.array[0] - 0.25) < 1e-6, "linearInterpolate(bufferB:interpolationConstant:)")
        dot.applyLookup([UInt8](repeating: 0, count: 200) + [UInt8](repeating: 7, count: 56), destination: out8)
        check(out8.array[5] == 7 && out8.array[0] == 0, "applyLookup([Pixel_8])")
        let lut = vImage.PixelBuffer(size: sz, pixelFormat: vImage.InterleavedFx3.self)
        dot.applyLookup([Pixel_FFFF](repeating: (0.25, 0.5, 0.75, 1), count: 256), destination: lut)
        check(lut.array[0...2] == [0.25, 0.5, 0.75], "applyLookup([Pixel_FFFF]) into InterleavedFx3")
        let gray8 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Planar8.self)
        rgba.multiply(by: (0, 1, 0, 0), divisor: 1, preBias: (0, 0, 0, 0), postBias: 0, destination: gray8)
        check(gray8.array == planes[1].array, "multiply(by:divisor:preBias:postBias:) into Planar8")
        dot.multiply(by: 1, divisor: 2, preBias: 0, postBias: 0, destination: out8)
        check(out8.array[5] == 100, "multiply(by: Int, divisor:)")
        let fx4 = vImage.PixelBuffer(pixelValues: [Float](repeating: 0.5, count: 64), size: sz, pixelFormat: vImage.InterleavedFx4.self)
        let fx4b = vImage.PixelBuffer(size: sz, pixelFormat: vImage.InterleavedFx4.self)
        fx4.multiply(by: simd_float4x4(diagonal: SIMD4<Float>(repeating: 2)), preBias: (0, 0, 0, 0), postBias: (0, 0, 0, 0), destination: fx4b)
        check(fx4b.array.allSatisfy { abs($0 - 1) < 1e-6 }, "multiply(by: simd_float4x4)")
        let a8 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Interleaved8x4.self)
        rgba.applyGamma(.fullPrecision(1), destination: a8)
        check(zip(a8.array, rgba.array).allSatisfy { abs(Int($0) - Int($1)) <= 1 }, "applyGamma(_:intermediateBuffer:destination:), gamma 1")

        // geometry
        rgba.transform(CGAffineTransform.identity, backgroundColor: (0, 0, 0, 0), destination: a8)
        check(a8.array == rgba.array, "transform(CGAffineTransform) identity")
        let quad: vImage_PerpsectiveTransform.QuadrilateralPoints = (simd_float2(0, 0), simd_float2(4, 0), simd_float2(0, 4), simd_float2(4, 4))
        if let t = vImage_PerpsectiveTransform(source: quad, destination: quad) {
            dot.transform(t, interpolation: .nearest, backgroundColor: 0, destination: out8)
            check(out8.array == dot.array, "vImage_PerpsectiveTransform(source:destination:), transform(_:interpolation:backgroundColor:)")
        } else { check(false, "vImage_PerpsectiveTransform(source:destination:)") }
        if let filter = vImageNewResamplingFilter(1, vImage_Flags(kvImageNoFlags)) {
            dot.shear(direction: .horizontal, translate: Float(0), slope: Float(0), resamplingFilter: filter, backgroundColor: 0, destination: out8)
            vImageDestroyResamplingFilter(filter)
            check(out8.array[5] > 150, "shear(direction: .horizontal)")
        }

        // compositing and channels
        let top = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 0, count: 64), size: sz, pixelFormat: vImage.Interleaved8x4.self)
        rgba.alphaComposite(.premultiplied, topLayer: top, destination: a8)
        check(a8.array == rgba.array, "alphaComposite(.premultiplied) with a transparent top layer")
        rgba.overwriteChannels([0], withScalar: 255, destination: a8)
        check(a8.array[0] == 255 && a8.array[1] == 1 && a8.array[4] == 255, "overwriteChannels(_:withScalar:destination:)")
        rgba.overwriteChannels([3], withPlanarBuffer: planes[0], destination: a8)
        check(a8.array[3] == 0 && a8.array[7] == 4, "overwriteChannels(_:withPlanarBuffer:destination:)")
        rgba.extractChannel(at: 2, destination: gray8)
        check(gray8.array == planes[2].array, "extractChannel(at:destination:)")
        let rgb = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Interleaved8x3.self)
        rgba.flatten(channelOrdering: .RGBA, backgroundColor: (0, 0, 0, 0), isPremultiplied: true, destination: rgb)
        check(rgb.array[0...2] == [0, 1, 2], "flatten(channelOrdering:backgroundColor:isPremultiplied:destination:)")
        let fill = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 0, count: 16), size: sz, pixelFormat: vImage.Planar8.self)
        fill.floodFill(from: CGPoint(x: 1, y: 1), newColor: 9, connectivity: .edges)
        check(fill.array.allSatisfy { $0 == 9 }, "floodFill(from:newColor:connectivity:)")
        fill.overwriteChannels(withScalar: 3)
        check(fill.array.allSatisfy { $0 == 3 }, "overwriteChannels(withScalar:)")

        // histograms of interleaved formats
        let h = rgba.histogram()
        check(h.0.reduce(0, +) == 16 && h.1[1] == 1 && h.3[3] == 1, "histogram() -> Histogram8888")
        let hf = fx4.histogram(binCount: 4)
        check(hf.0[2] == 16, "histogram(binCount:) -> HistogramFFFF")
        rgba.specifyHistogram(h, destination: a8)
        check(a8.size == sz, "specifyHistogram(Histogram8888)")

        // conversions
        let f2 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.InterleavedFx2.self), i82 = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Interleaved8x2.self)
        let src82 = vImage.PixelBuffer(pixelValues: [UInt8](repeating: 255, count: 32), size: sz, pixelFormat: vImage.Interleaved8x2.self)
        src82.convert(to: f2); f2.convert(to: i82)
        check(f2.array.allSatisfy { $0 == 1 } && i82.array.allSatisfy { $0 == 255 }, "convert(to:) Interleaved8x2 <-> InterleavedFx2")
        rgba.convert(to: rgb, channelOrdering: .RGBA)
        check(rgb.array[0...2] == [0, 1, 2], "convert(to:channelOrdering:)")

        // multidimensional lookup tables: an identity 2 x 2 x 2 table over three channels
        var table = [UInt16]()
        for r in 0..<2 { for g in 0..<2 { for b in 0..<2 { table += [UInt16(r * 4096), UInt16(g * 4096), UInt16(b * 4096)] } } }
        let mdt = vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: [2, 2, 2], destinationChannelCount: 3, data: table)
        let srcP = vImage.PixelBuffer<vImage.PlanarFx3>(size: sz), dstP = vImage.PixelBuffer<vImage.PlanarFx3>(size: sz)
        srcP.withUnsafePixelBuffers { ps in for (i, p) in ps.enumerated() { p.withUnsafeMutableBufferPointer { for j in $0.indices { $0[j] = Float(i + 1) / 4 } } } }
        mdt.apply(source: srcP, destination: dstP, interpolation: .full)
        check(mdt.sourceChannelCount == 3 && dstP.withUnsafePixelBuffer(at: 1) { abs($0.array[0] - 0.5) < 1e-3 }, "MultidimensionalLookupTable.apply(source:destination:interpolation:)")

        // Core Video
        var seen = 0
        rgba.withCVPixelBuffer(readOnly: true) { cv in seen = CVPixelBufferGetWidth(cv) == 4 && CVPixelBufferGetPixelFormatType(cv) == kCVPixelFormatType_32ARGB ? 1 : -1 }
        check(seen == 1, "withCVPixelBuffer(readOnly:body:)")
        let y601 = vImage_ARGBToYpCbCrMatrix.itu_R_601_4
        check(abs(y601.R_Yp - 0.299) < 1e-4 && abs(vImage_ARGBToYpCbCrMatrix.itu_R_709_2.R_Yp - 0.2126) < 1e-4, "vImage_ARGBToYpCbCrMatrix.itu_R_601_4 / itu_R_709_2")
        if let cvf = vImageCVImageFormat.make(format: .format32ARGB, colorSpace: CGColorSpaceCreateDeviceRGB(), alphaIsOpaqueHint: false),
           let cg = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)),
           let conv = try? vImageConverter.make(sourceFormat: cvf, destinationFormat: cg) {
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, 4, 4, kCVPixelFormatType_32ARGB, nil, &pb)
            if let pb {
                CVPixelBufferLockBaseAddress(pb, [])
                let refs = try? conv.makeCVToCGPixelBuffers(referencing: pb)
                let dyn = vImage.PixelBuffer(referencing: pb, converter: conv, destinationPixelFormat: vImage.DynamicPixelFormat.self)
                let out = vImage.PixelBuffer(size: sz, pixelFormat: vImage.Interleaved8x4.self)
                check(refs?.count == 1 && dyn.size == sz && (try? conv.convert(from: dyn, to: out)) != nil, "makeCVToCGPixelBuffers, PixelBuffer(referencing:converter:), vImageConverter.convert(from:to:)")
                CVPixelBufferUnlockBaseAddress(pb, [])
            }
        } else { check(false, "a CV-to-CG converter for 32ARGB") }
        _ = kvImageBufferTypeCode_CVPixelBuffer_YCbCr
        let hint: vImageMDTableUsageHint = kvImageMDTableHint_Float, interp = vImage_InterpolationMethod(rawValue: 1)
        check(hint.rawValue == 2 && interp == kvImageFullInterpolation, "vImageMDTableUsageHint / vImage_InterpolationMethod as Apple's structs")
    }
    static func finish_unused() {
    }
    static func finish() {
        print("vImage Swift: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
