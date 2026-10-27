// HelloAccelerate's -vimage page (issue #371): a drawn test card (a red square top left, a blue disc bottom right)
// through vImage: a 15 x 15 box blur, a quarter turn counterclockwise, a half-size Lanczos scale and gray through a
// colour matrix, each shown in a grid. Every result logs a line the test reads.
import UIKit
import Accelerate

private let side = 120

/// The test card as premultiplied RGBA.
private func testCard() -> CGImage {
    let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
    return r.image { ctx in
        UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        UIColor.red.setFill(); ctx.fill(CGRect(x: 10, y: 10, width: 40, height: 40))
        UIColor.blue.setFill(); UIBezierPath(ovalIn: CGRect(x: 66, y: 66, width: 44, height: 44)).fill()
    }.cgImage!
}

private func pixel(_ b: vImage_Buffer, _ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    let p = b.data.assumingMemoryBound(to: UInt8.self) + y * b.rowBytes + x * 4
    return (p[0], p[1], p[2], p[3])
}

func vImagePage(_ vc: UIViewController) {
    let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))!
    do {
        let source = try vImage_Buffer(cgImage: testCard(), format: format)
        var blurred = try vImage_Buffer(width: side, height: side, bitsPerPixel: 32)
        var turned = try vImage_Buffer(width: side, height: side, bitsPerPixel: 32)
        var half = try vImage_Buffer(width: side / 2, height: side / 2, bitsPerPixel: 32)
        var gray = try vImage_Buffer(width: side, height: side, bitsPerPixel: 32)
        var src = source
        vImageBoxConvolve_ARGB8888(&src, &blurred, nil, 0, 0, 15, 15, nil, vImage_Flags(kvImageEdgeExtend))
        vImageRotate90_ARGB8888(&src, &turned, UInt8(kRotate90DegreesCounterClockwise), [255, 255, 255, 255], vImage_Flags(kvImageNoFlags))
        vImageScale_ARGB8888(&src, &half, nil, vImage_Flags(kvImageHighQualityResampling))
        // RGBA in, RGBA out: each output channel the luminance (Rec. 601 weights / 256), alpha kept
        let luma: [Int16] = [77, 77, 77, 0, 150, 150, 150, 0, 29, 29, 29, 0, 0, 0, 0, 256]
        vImageMatrixMultiply_ARGB8888(&src, &gray, luma, 256, nil, nil, vImage_Flags(kvImageNoFlags))

        // green is 0 in the red square and 255 in the white around it: 8 of the 15 columns past its edge are white
        let edge = pixel(blurred, 50, 30), inside = pixel(blurred, 30, 30)
        log("vimage blur inside \(inside.1) edge \(edge.1)")
        let moved = pixel(turned, 30, 90)
        log("vimage turn red at bottom left \(moved.0 == 255 && moved.1 == 0)")
        log("vimage half \(half.width)x\(half.height) red \(pixel(half, 15, 15).0)")
        let g = pixel(gray, 30, 30)
        log("vimage gray \(g.0) \(g.1) \(g.2)")

        let images = try [source, blurred, turned, half, gray].map { UIImage(cgImage: try $0.createCGImage(format: format)) }
        let titles = ["Original", "Box blur", "Rotated", "Half size", "Gray"]
        let x0: CGFloat = 20, y0: CGFloat = 100, cell: CGFloat = 130
        for (i, image) in images.enumerated() {
            let col = CGFloat(i % 3), row = CGFloat(i / 3)
            let view = UIImageView(frame: CGRect(x: x0 + col * cell, y: y0 + row * (cell + 24), width: CGFloat(side), height: CGFloat(side)))
            view.image = image
            view.contentMode = .topLeft
            view.accessibilityIdentifier = "vimage-\(i)"
            let label = UILabel(frame: CGRect(x: view.frame.minX, y: view.frame.maxY + 2, width: cell - 10, height: 18))
            label.text = titles[i]
            label.font = .systemFont(ofSize: 13)
            vc.view.addSubview(view); vc.view.addSubview(label)
        }
        [source, blurred, turned, half, gray].forEach { $0.free() }
    } catch {
        log("vimage failed \(error)")
    }
    let title = UILabel(frame: CGRect(x: 20, y: 56, width: vc.view.bounds.width - 40, height: 34))
    title.text = "vImage"
    title.font = .boldSystemFont(ofSize: 28)
    vc.view.addSubview(title)
}
