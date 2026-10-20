// Accelerate from Swift (AccelerateTest.app, issue #279): the vDSP and vForce namespaces over arrays, slices and
// buffer pointers, windows, the real FFT and the DFT classes, and the C API (BLAS, LAPACK) as Swift imports it.
import Foundation
import Accelerate

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func close<T: BinaryFloatingPoint>(_ a: [T], _ b: [Double], _ tol: Double = 1e-9) -> Bool {
    guard a.count == b.count else { print("      counts \(a.count) != \(b.count)"); return false }
    for (x, y) in zip(a, b) where abs(Double(x) - y) > tol * (1 + abs(y)) { print("      \(a) != \(b)"); return false }
    return true
}

@main enum AccelerateTest {
    static func main() {
        let a: [Float] = [1, -2, 3, -4, 5], b: [Float] = [2, 2, 2, 2, 2]
        check(vDSP.add(a, b) == [3, 0, 5, -2, 7] && vDSP.subtract(a, b) == [-1, -4, 1, -6, 3], "vDSP.add, subtract")
        check(vDSP.multiply(2, a) == [2, -4, 6, -8, 10] && vDSP.divide(a, 2) == [0.5, -1, 1.5, -2, 2.5] && vDSP.divide(1, b) == [0.5, 0.5, 0.5, 0.5, 0.5], "scalar overloads")
        check(vDSP.sum(a) == 3 && vDSP.maximum(a) == 5 && vDSP.minimum(a) == -4 && vDSP.sumOfSquares(a) == 55 && vDSP.meanMagnitude(a) == 3, "reductions")
        check(vDSP.indexOfMaximum(a) == (4, 5) && vDSP.indexOfMinimum(a) == (3, -4), "indexOfMaximum, indexOfMinimum")
        check(vDSP.dot(a, b) == 6 && vDSP.distanceSquared(a, b) == 1 + 16 + 1 + 36 + 9, "dot, distanceSquared")
        check(vDSP.absolute(a) == [1, 2, 3, 4, 5] && vDSP.negative(a) == [-1, 2, -3, 4, -5] && vDSP.square(a) == [1, 4, 9, 16, 25], "absolute, negative, square")
        check(vDSP.clip(a, to: -1 ... 2) == [1, -1, 2, -1, 2], "clip")
        check(vDSP.ramp(withInitialValue: 1.0, increment: 0.5, count: 4) == [1, 1.5, 2, 2.5] && vDSP.ramp(in: 0.0 ... 1.0, count: 5) == [0, 0.25, 0.5, 0.75, 1], "ramps")
        var sorted: [Double] = [3, 1, 2]
        vDSP.sort(&sorted, sortOrder: .descending)
        var rev: [Double] = [1, 2, 3]
        vDSP.reverse(&rev)
        check(sorted == [3, 2, 1] && rev == [3, 2, 1], "sort, reverse")
        var filled = [Float](repeating: 0, count: 3)
        vDSP.fill(&filled, with: 7)
        check(filled == [7, 7, 7], "fill")
        let slice = a[1 ..< 4]
        check(vDSP.sum(slice) == -3, "an ArraySlice")
        var out = [Float](repeating: 0, count: 5)
        a.withUnsafeBufferPointer { p in vDSP.add(p, b, result: &out) }
        check(out == [3, 0, 5, -2, 7], "an UnsafeBufferPointer, result: inout")
        let sig: [Float] = [1, 2, 3, 4, 5, 6], k: [Float] = [1, 0, -1]
        check(vDSP.correlate(sig, withKernel: k) == [-2, -2, -2] && vDSP.convolve(sig, withKernel: k) == [2, 2, 2], "correlate, convolve")
        check(vDSP.linearInterpolate([0, 10] as [Float], [10, 20] as [Float], using: 0.25) == [2.5, 12.5], "linearInterpolate")
        var doubles = [Double](repeating: 0, count: 3)
        vDSP.convertElements(of: [1.5, 2.5, -3] as [Float], to: &doubles)
        check(doubles == [1.5, 2.5, -3], "convertElements Float to Double")
        check(vDSP.floatingPointToInteger([1.6, -1.6, 300] as [Float], integerType: Int16.self, rounding: .towardZero) == [1, -1, 300]
              && vDSP.floatingPointToInteger([1.6, -1.6] as [Float], integerType: Int16.self, rounding: .towardNearestInteger) == [2, -2], "floatingPointToInteger")
        check(vDSP.integerToFloatingPoint([1, 255] as [UInt8], floatingPointType: Float.self) == [1, 255], "integerToFloatingPoint")
        let hann = vDSP.window(ofType: Double.self, usingSequence: .hanningDenormalized, count: 8, isHalfWindow: false)
        check(close(hann, (0 ..< 8).map { 0.5 * (1 - cos(2 * Double.pi * Double($0) / 8)) }), "window: Hann")
        check(vDSP.window(ofType: Float.self, usingSequence: .hamming, count: 9, isHalfWindow: true).count == 5, "window: half")

        check(close(vForce.sqrt([4, 9, 2] as [Double]), [2, 3, 2.0.squareRoot()]) && close(vForce.exp([0, 1] as [Float]), [1, M_E], 1e-6), "vForce.sqrt, exp")
        check(close(vForce.pow(bases: [2, 3] as [Double], exponents: [10, 2] as [Double]), [1024, 9]), "vForce.pow(bases:exponents:)")
        check(close(vForce.truncatingRemainder(dividends: [7, -7] as [Double], divisors: [3, 3] as [Double]), [1, -1])
              && close(vForce.remainder(dividends: [7] as [Double], divisors: [3] as [Double]), [1]), "remainders")
        check(close(vForce.copysign(magnitudes: [1, 2] as [Double], signs: [-1, 1] as [Double]), [-1, 2]), "copysign(magnitudes:signs:)")
        var s = [Float](repeating: 0, count: 2), c = [Float](repeating: 0, count: 2)
        vForce.sincos([0, Float.pi / 2], sinResult: &s, cosResult: &c)
        check(close(s, [0, 1], 1e-6) && close(c, [1, 0], 1e-6), "vForce.sincos")
        check(vForce.nearestInteger([2.5, 3.5] as [Double]) == [2, 4] && vForce.trunc([-2.7] as [Double]) == [-2] && vForce.reciprocal([4] as [Float]) == [0.25], "rounding, reciprocal")

        // a real FFT of 16 values: 3 cycles; the packed spectrum is twice the DFT
        let n = 16
        let x = (0 ..< n).map { sin(2 * Double.pi * 3 * Double($0) / Double(n)) }
        var re = [Double](repeating: 0, count: n / 2), im = [Double](repeating: 0, count: n / 2)
        var ore = [Double](repeating: 0, count: n / 2), oim = [Double](repeating: 0, count: n / 2)
        re.withUnsafeMutableBufferPointer { rp in im.withUnsafeMutableBufferPointer { ip in
            ore.withUnsafeMutableBufferPointer { orp in oim.withUnsafeMutableBufferPointer { oip in
                var split = DSPDoubleSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                x.withUnsafeBytes { vDSP_ctozD($0.bindMemory(to: DSPDoubleComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(n / 2)) }
                var spectrum = DSPDoubleSplitComplex(realp: orp.baseAddress!, imagp: oip.baseAddress!)
                let fft = vDSP.FFT(log2n: 4, radix: .radix2, ofType: DSPDoubleSplitComplex.self)!
                fft.forward(input: split, output: &spectrum)
            } }
        } }
        let mags = zip(ore, oim).map { ($0 * $0 + $1 * $1).squareRoot() }
        check(abs(mags[3] - Double(n)) < 1e-9 && mags.enumerated().allSatisfy { $0.offset == 3 || $0.element < 1e-9 }, "vDSP.FFT forward: a peak at bin 3 (2 x n / 2)")

        // the DFT: a length of 12, against a naive DFT
        let ir = (0 ..< 12).map { cos(Double($0) * 0.7) }, ii = [Double](repeating: 0, count: 12)
        let ref = (0 ..< 12).map { k in (0 ..< 12).reduce(0.0) { $0 + ir[$1] * cos(-2 * Double.pi * Double(k * $1) / 12) } }
        if #available(iOS 17.0, *) {
            let dft = try! vDSP.DiscreteFourierTransform(count: 12, direction: .forward, transformType: .complexComplex, ofType: Double.self)
            check(close(dft.transform(inputReal: ir, inputImaginary: ii).real, ref), "vDSP.DiscreteFourierTransform, 12 values")
            check((try? vDSP.DiscreteFourierTransform(count: 7, direction: .forward, transformType: .complexComplex, ofType: Float.self)) == nil, "an unsupported length throws")
        }

        // the C API from Swift
        var A: [Double] = [2, 1, 1, 3], B: [Double] = [3, 5]
        var nn: __CLPK_integer = 2, lda: __CLPK_integer = 2, ldb: __CLPK_integer = 2, one: __CLPK_integer = 1, ipiv = [__CLPK_integer](repeating: 0, count: 2), info: __CLPK_integer = -1
        dgesv_(&nn, &one, &A, &lda, &ipiv, &B, &ldb, &info)
        check(info == 0 && close(B, [0.8, 1.4]), "dgesv_ from Swift")
        var C = [Float](repeating: 0, count: 4)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1, [1, 2, 3, 4], 2, [5, 6, 7, 8], 2, 0, &C, 2)
        check(C == [19, 22, 43, 50], "cblas_sgemm from Swift")

        print("accelerate swift: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
