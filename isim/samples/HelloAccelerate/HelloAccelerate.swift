// Sample: Accelerate on isim — a signal of two tones (440 Hz and 1 kHz at 8 kHz) windowed with vDSP.window, its
// spectrum from vDSP.FFT drawn as bars, the peaks found with vDSP.indexOfMaximum, vForce over the magnitudes, and a
// linear system solved with LAPACK (dgesv_) and checked with BLAS (cblas_dgemv). Every result logs a line the test reads.
// With -vimage: vImage's page instead (VImagePage.swift).
import UIKit
import Accelerate

func log(_ s: String) { NSLog("HelloAccelerate: %@", s) }

let rate = 8000.0, n = 1024, log2n: vDSP_Length = 10

/// The magnitudes of the first n / 2 bins of the signal's spectrum, in dB, and the signal itself.
func analyse() -> (signal: [Float], spectrum: [Float], peaks: [Double]) {
    let t = vDSP.ramp(withInitialValue: 0, increment: Float(1 / rate), count: n)
    let tone1 = vForce.sin(vDSP.multiply(Float(2 * Double.pi * 440), t))
    let tone2 = vDSP.multiply(0.5, vForce.sin(vDSP.multiply(Float(2 * Double.pi * 1000), t)))
    let signal = vDSP.add(tone1, tone2)
    let windowed = vDSP.multiply(signal, vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: n, isHalfWindow: false))

    var re = [Float](repeating: 0, count: n / 2), im = re, ore = re, oim = re
    re.withUnsafeMutableBufferPointer { rp in im.withUnsafeMutableBufferPointer { ip in
        ore.withUnsafeMutableBufferPointer { orp in oim.withUnsafeMutableBufferPointer { oip in
            var packed = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
            windowed.withUnsafeBytes { vDSP_ctoz($0.bindMemory(to: DSPComplex.self).baseAddress!, 2, &packed, 1, vDSP_Length(n / 2)) }
            var out = DSPSplitComplex(realp: orp.baseAddress!, imagp: oip.baseAddress!)
            vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!.forward(input: packed, output: &out)
            oip[0] = 0                                                   // imagp[0] holds the Nyquist bin
        } }
    } }
    var mags = vForce.sqrt(vDSP.add(vDSP.square(ore), vDSP.square(oim)))
    let top = vDSP.maximum(mags)
    mags = vDSP.multiply(1 / top, mags)
    let db = vDSP.clip(vDSP.multiply(20, vForce.log10(vDSP.add(1e-6, mags))), to: -80 ... 0)

    // the two strongest bins, the second searched away from the first
    let (i1, _) = vDSP.indexOfMaximum(mags)
    var rest = mags
    for k in max(0, Int(i1) - 8) ..< min(rest.count, Int(i1) + 9) { rest[k] = 0 }
    let (i2, _) = vDSP.indexOfMaximum(rest)
    let peaks = [Double(i1), Double(i2)].map { $0 * rate / Double(n) }.sorted()
    return (signal, db, peaks)
}

func solve() -> [Double] {
    var a: [Double] = [3, 1, 2, 2, 4, 1, 1, 2, 5]           // column-major
    let orig = a
    var b: [Double] = [13, 16, 12]
    let rhs = b
    var n3: __CLPK_integer = 3, lda: __CLPK_integer = 3, ldb: __CLPK_integer = 3, one: __CLPK_integer = 1, ipiv = [__CLPK_integer](repeating: 0, count: 3), info: __CLPK_integer = 0
    dgesv_(&n3, &one, &a, &lda, &ipiv, &b, &ldb, &info)
    var check = [Double](repeating: 0, count: 3)
    cblas_dgemv(CblasColMajor, CblasNoTrans, 3, 3, 1, orig, 3, b, 1, 0, &check, 1)
    log(String(format: "solve info %d x %.3f %.3f %.3f residual %.1e", info, b[0], b[1], b[2], vDSP.distanceSquared(check, rhs)))
    return b
}

final class SpectrumView: UIView {
    var signal: [Float] = [], spectrum: [Float] = []
    override func draw(_ rect: CGRect) {
        guard let g = UIGraphicsGetCurrentContext(), !spectrum.isEmpty else { return }
        let w = bounds.width, half = bounds.height / 2
        // the waveform, the first 160 samples
        g.setStrokeColor(UIColor.systemBlue.cgColor); g.setLineWidth(1.5)
        for i in 0 ..< 160 {
            let p = CGPoint(x: w * CGFloat(i) / 159, y: half / 2 - CGFloat(signal[i]) * half / 3.2)
            if i == 0 { g.move(to: p) } else { g.addLine(to: p) }
        }
        g.strokePath()
        // the spectrum up to 2 kHz (256 bins), one bar per two bins
        let bars = 128, barW = w / CGFloat(bars)
        g.setFillColor(UIColor.systemOrange.cgColor)
        for k in 0 ..< bars {
            let h = CGFloat((max(spectrum[2 * k], spectrum[2 * k + 1]) + 80) / 80) * (half - 24)
            g.fill(CGRect(x: CGFloat(k) * barW, y: bounds.height - h, width: max(1, barW - 0.5), height: h))
        }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        if ProcessInfo.processInfo.arguments.contains("-vimage") {
            vImagePage(vc)
            window?.rootViewController = vc
            window?.makeKeyAndVisible()
            log("done")
            return true
        }
        let (signal, spectrum, peaks) = analyse()
        log(String(format: "peaks %.0f Hz %.0f Hz", peaks[0], peaks[1]))
        let x = solve()

        let title = UILabel(frame: CGRect(x: 20, y: 70, width: vc.view.bounds.width - 40, height: 30))
        title.text = "Accelerate"
        title.font = .boldSystemFont(ofSize: 28)
        let label = UILabel(frame: CGRect(x: 20, y: 104, width: vc.view.bounds.width - 40, height: 60))
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.text = String(format: "Peaks: %.0f Hz and %.0f Hz\nA x = b: x = (%.0f, %.0f, %.0f)", peaks[0], peaks[1], x[0], x[1], x[2])
        label.accessibilityIdentifier = "status"
        let view = SpectrumView(frame: CGRect(x: 20, y: 180, width: vc.view.bounds.width - 40, height: 360))
        view.backgroundColor = .secondarySystemBackground
        view.signal = signal; view.spectrum = spectrum
        view.accessibilityIdentifier = "spectrum"
        [title, label, view].forEach(vc.view.addSubview)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        log("done")
        return true
    }
}
