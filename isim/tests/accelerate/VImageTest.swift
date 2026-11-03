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
        argb.premultiply(destination: pre)
        check(pre.array == [128, 128, 50, 0, 255, 10, 20, 30], "premultiply(destination:)")
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
    static func finish_unused() {
    }
    static func finish() {
        print("vImage Swift: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
