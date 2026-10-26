// Sample: Metal on isim (issue #328), on the CPU. A Mandelbrot set rendered by a compute kernel into a texture and shown
// in an image view, and checks printed as "metal ..." lines that tests/ui/test_metal.py reads: the device and the
// default library (Shaders.metal, compiled by isim build), the kernel's texture read back to a CGImage, buffers and
// the Swift overlay (setBuffers, fill(buffer:range:value:)), function constants, a library compiled at run time with
// async/await, MTLLibraryError for a bad source, and a CIContext(mtlDevice:).
import UIKit
import Metal
import CoreImage

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
        view.addSubview(imageView)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
        ])
        Task.detached { await Checks.run(self) }
    }

    @MainActor func show(_ image: CGImage, _ text: String) {
        imageView.image = UIImage(cgImage: image)
        label.text = text
    }
}

enum Checks {
    static func run(_ vc: FractalViewController) async {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { log("no device"); return }
        log("device \(device.name) library \(library.functionNames.sorted().joined(separator: ","))")
        do {
            let (image, ms) = try fractal(device, queue, library)
            let p = pixel(image, 128, 128), edge = pixel(image, 2, 2)
            log("fractal \(image.width)x\(image.height) center \(p) edge bright \(edge[0] + edge[1] + edge[2] > 100)")
            print("metal fractal took \(ms) ms")
            await vc.show(image, "Mandelbrot set, rendered by a Metal kernel")
            try saxpy(device, queue, library)
            try constants(device, queue, library)
            try await runtime(device, queue)
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

    static func fractal(_ device: MTLDevice, _ queue: MTLCommandQueue, _ library: MTLLibrary) throws -> (CGImage, Int) {
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
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: 256, height: 256, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return (image, ms)
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
