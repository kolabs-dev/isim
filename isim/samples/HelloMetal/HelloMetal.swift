// Sample: Metal on isim (issue #328), on the CPU. A Mandelbrot set rendered by a compute kernel into a texture and shown
// in an image view, and checks printed as "metal ..." lines that tests/ui/test_metal.py reads: the device and the
// default library (Shaders.metal, compiled by isim build), the kernel's texture read back to a CGImage, buffers and
// the Swift overlay (setBuffers, fill(buffer:range:value:)), function constants, a library compiled at run time with
// async/await, MTLLibraryError for a bad source, and a CIContext(mtlDevice:). Then (issue #365) the fractal through
// Metal Performance Shaders (a Gaussian blur, a Lanczos downscale) and MetalFX (the spatial scaler back up), shown
// below it; an MPSMatrix product; and an MPSGraph with a gradient.
import UIKit
import Metal
import CoreImage
import MetalPerformanceShaders
import MetalPerformanceShadersGraph
import MetalFX

func log(_ s: String) { print("metal " + s) }

struct View { var center: SIMD2<Float>; var scale: Float; var iterations: UInt32 }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = FractalViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class FractalViewController: UIViewController {
    let imageView = UIImageView()
    let shadersView = UIImageView()
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.accessibilityIdentifier = "fractal"
        label.text = "Metal on the CPU"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        shadersView.contentMode = .scaleAspectFit
        shadersView.translatesAutoresizingMaskIntoConstraints = false
        shadersView.accessibilityIdentifier = "shaders"
        view.addSubview(imageView)
        view.addSubview(shadersView)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            shadersView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            shadersView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadersView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            shadersView.heightAnchor.constraint(equalTo: shadersView.widthAnchor),
        ])
        Task.detached { await Checks.run(self) }
    }

    @MainActor func show(_ image: CGImage, _ text: String) {
        imageView.image = UIImage(cgImage: image)
        label.text = text
    }
    @MainActor func showShaders(_ image: CGImage) { shadersView.image = UIImage(cgImage: image) }
}

enum Checks {
    static func run(_ vc: FractalViewController) async {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { log("no device"); return }
        log("device \(device.name) library \(library.functionNames.sorted().joined(separator: ","))")
        do {
            let (image, ms, texture) = try fractal(device, queue, library)
            let p = pixel(image, 128, 128), edge = pixel(image, 2, 2)
            log("fractal \(image.width)x\(image.height) center \(p) edge bright \(edge[0] + edge[1] + edge[2] > 100)")
            print("metal fractal took \(ms) ms")
            await vc.show(image, "Mandelbrot set, rendered by a Metal kernel")
            try saxpy(device, queue, library)
            try constants(device, queue, library)
            try await runtime(device, queue)
            await vc.showShaders(performanceShaders(device, queue, texture))
            matrices(device, queue)
            graph(device)
        } catch {
            log("failed: \(error)")
        }
        do {
            _ = try await device.makeLibrary(source: "kernel void k(device float *v [[buffer(0)]]) { v[0] = nope; }", options: nil)
        } catch let e as MTLLibraryError {
            log("compile error \(e.code == .compileFailure) \(MTLLibraryError.errorDomain)")
        } catch {
            log("compile error other \(error)")
        }
        let ci = CIContext(mtlDevice: device)
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        log("ci context renders \(ci.createCGImage(red, from: red.extent).map { pixel($0, 1, 1) } ?? [])")
        log("done")
    }

    static func fractal(_ device: MTLDevice, _ queue: MTLCommandQueue, _ library: MTLLibrary) throws -> (CGImage, Int, MTLTexture) {
        let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "mandelbrot")!)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 256, height: 256, mipmapped: false)
        d.usage = [.shaderWrite, .shaderRead]
        let texture = device.makeTexture(descriptor: d)!
        var view = View(center: SIMD2(-0.6, 0), scale: 2.6, iterations: 200)
        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pipeline)
        enc.setTexture(texture, index: 0)
        enc.setBytes(&view, length: MemoryLayout<View>.stride, index: 0)
        enc.dispatchThreads(MTLSize(width: 256, height: 256, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        enc.endEncoding()
        let start = Date()
        cb.commit()
        cb.waitUntilCompleted()
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        var bytes = [UInt8](repeating: 0, count: 256 * 256 * 4)
        texture.getBytes(&bytes, bytesPerRow: 256 * 4, from: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0)
        return (cgImage(texture), ms, texture)
    }

    static func cgImage(_ texture: MTLTexture) -> CGImage {
        let w = texture.width, h = texture.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        texture.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    /// the fractal blurred (MPS), down to 128 (MPS Lanczos) and back up to 256 (MetalFX), in one command buffer
    static func performanceShaders(_ device: MTLDevice, _ queue: MTLCommandQueue, _ source: MTLTexture) -> CGImage {
        func texture(_ size: Int) -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
            d.usage = [.shaderRead, .shaderWrite]
            return device.makeTexture(descriptor: d)!
        }
        let blurred = texture(256), small = texture(128), upscaled = texture(256)
        let desc = MTLFXSpatialScalerDescriptor()
        desc.inputWidth = 128; desc.inputHeight = 128; desc.outputWidth = 256; desc.outputHeight = 256
        desc.colorTextureFormat = .rgba8Unorm; desc.outputTextureFormat = .rgba8Unorm
        let scaler = desc.makeSpatialScaler(device: device)!
        scaler.colorTexture = small
        scaler.outputTexture = upscaled
        let cb = queue.makeCommandBuffer()!
        MPSImageGaussianBlur(device: device, sigma: 2).encode(commandBuffer: cb, sourceTexture: source, destinationTexture: blurred)
        MPSImageLanczosScale(device: device).encode(commandBuffer: cb, sourceTexture: blurred, destinationTexture: small)
        scaler.encode(commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()
        let image = cgImage(upscaled), center = pixel(image, 128, 128)
        log("mps blur, lanczos to 128, metalfx to \(upscaled.width): center dark \(center[0] + center[1] + center[2] < 90)"
            + " supported \(MPSSupportsMTLDevice(device)) \(MTLFXSpatialScalerDescriptor.supportsDevice(device))")
        return image
    }

    /// a 2x3 by 3x2 product with MPSMatrixMultiplication
    static func matrices(_ device: MTLDevice, _ queue: MTLCommandQueue) {
        func matrix(_ rows: Int, _ cols: Int, _ values: [Float]) -> MPSMatrix {
            let d = MPSMatrixDescriptor(rows: rows, columns: cols, rowBytes: cols * 4, dataType: .float32)
            return MPSMatrix(buffer: device.makeBuffer(bytes: values, length: max(values.count, rows * cols) * 4, options: .storageModeShared)!, descriptor: d)
        }
        let a = matrix(2, 3, [1, 2, 3, 4, 5, 6]), b = matrix(3, 2, [7, 8, 9, 10, 11, 12]), c = matrix(2, 2, [0, 0, 0, 0])
        let cb = queue.makeCommandBuffer()!
        MPSMatrixMultiplication(device: device, resultRows: 2, resultColumns: 2, interiorColumns: 3).encode(commandBuffer: cb, leftMatrix: a, rightMatrix: b, resultMatrix: c)
        cb.commit()
        cb.waitUntilCompleted()
        let r = c.data.contents().bindMemory(to: Float.self, capacity: 4)
        log("mps matrix \([r[0], r[1], r[2], r[3]].map { Int($0) })")
    }

    /// y = x w, loss = sum(y^2), and d(loss)/dw
    static func graph(_ device: MTLDevice) {
        let g = MPSGraph()
        let x = g.placeholder(shape: [1, 2], dataType: .float32, name: "x")
        let w = g.variable(with: Data(bytes: [Float](arrayLiteral: 1, 2, 3, 4), count: 16), shape: [2, 2], dataType: .float32, name: "w")
        let y = g.matrixMultiplication(primary: x, secondary: w, name: nil)
        let loss = g.reductionSum(with: g.square(with: y, name: nil), axes: nil, name: nil)
        let dw = g.gradients(of: loss, with: [w], name: nil)[w]!
        let input = MPSGraphTensorData(device: MPSGraphDevice(mtlDevice: device), data: Data(bytes: [Float](arrayLiteral: 1, 1), count: 8), shape: [1, 2], dataType: .float32)
        let results = g.run(feeds: [x: input], targetTensors: [y, dw], targetOperations: nil)
        func floats(_ t: MPSGraphTensor, _ n: Int) -> [Int] {
            var v = [Float](repeating: 0, count: n)
            results[t]!.mpsndarray().readBytes(&v, strideBytes: nil)
            return v.map { Int($0) }
        }
        log("mpsgraph y \(floats(y, 2)) dloss/dw \(floats(dw, 4))")
    }

    static func saxpy(_ device: MTLDevice, _ queue: MTLCommandQueue, _ library: MTLLibrary) throws {
        let x: [Float] = (0..<64).map(Float.init)
        let xs = device.makeBuffer(bytes: x, length: 256, options: .storageModeShared)!
        let ys = device.makeBuffer(length: 256, options: .storageModeShared)!
        let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "saxpy")!)
        let cb = queue.makeCommandBuffer()!
        let blit = cb.makeBlitCommandEncoder()!
        blit.fill(buffer: ys, range: 0..<256, value: 0)
        blit.endEncoding()
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pipeline)
        enc.setBuffers([xs, ys], offsets: [0, 0], range: 0..<2)
        var a: Float = 3
        enc.setBytes(&a, length: 4, index: 2)
        enc.dispatchThreadgroups(MTLSize(width: 4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 1, depth: 1))
        enc.endEncoding()
        var completed = false
        cb.addCompletedHandler { completed = $0.status == .completed }
        cb.commit()
        cb.waitUntilCompleted()
        let y = ys.contents().bindMemory(to: Float.self, capacity: 64)
        log("saxpy \(y[1]) \(y[63]) completed \(completed) width \(pipeline.threadExecutionWidth)")
    }

    static func constants(_ device: MTLDevice, _ queue: MTLCommandQueue, _ library: MTLLibrary) throws {
        let values = MTLFunctionConstantValues()
        var dim: Float = 0.5
        values.setConstantValue(&dim, type: .float, index: 0)
        let f = try library.makeFunction(name: "mandelbrot", constantValues: values)
        let constant = f.functionConstantsDictionary["brightness"]
        log("constant \(constant?.name ?? "-") index \(constant?.index ?? -1) float \(constant?.type == .float)")
    }

    static func runtime(_ device: MTLDevice, _ queue: MTLCommandQueue) async throws {
        let source = """
            #include <metal_stdlib>
            using namespace metal;
            kernel void square(device uint *v [[buffer(0)]], uint i [[thread_position_in_grid]]) { v[i] = v[i] * v[i]; }
            """
        let lib = try await device.makeLibrary(source: source, options: MTLCompileOptions())
        let pipeline = try await device.makeComputePipelineState(function: lib.makeFunction(name: "square")!)
        let values: [UInt32] = [2, 3, 4]
        let buf = device.makeBuffer(bytes: values, length: 12, options: [])!
        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(buf, offset: 0, index: 0)
        enc.dispatchThreads(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 3, height: 1, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        let r = buf.contents().bindMemory(to: UInt32.self, capacity: 3)
        log("runtime library \(lib.functionNames) \(r[0]) \(r[1]) \(r[2])")
    }

    /// 8-bit RGBA of a pixel, from the top left
    static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [Int] {
        var b = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &b, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return b.map { Int($0) }
    }
}
