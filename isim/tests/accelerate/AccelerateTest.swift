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
            check(close(dft.transform(real: ir, imaginary: ii).real, ref), "vDSP.DiscreteFourierTransform, 12 values")
            check((try? vDSP.DiscreteFourierTransform(count: 7, direction: .forward, transformType: .complexComplex, ofType: Float.self)) == nil, "an unsupported length throws")
            // issue #809: Apple's errors, the interleaved form, reusing a setup, the lifecycle and vDSP_DFTFunctions types
            do {
                _ = try vDSP.DiscreteFourierTransform(count: 7, direction: .forward, transformType: .complexReal, ofType: Double.self)
                check(false, "vDSP.DFTError.invalidSplitComplexCount")
            } catch let e as vDSP.DFTError {
                if case .invalidSplitComplexCount(let c, let t) = e { check(c == 7 && t == .complexReal && e.errorDescription != nil, "vDSP.DFTError.invalidSplitComplexCount") }
                else { check(false, "vDSP.DFTError.invalidSplitComplexCount") }
            } catch { check(false, "vDSP.DFTError.invalidSplitComplexCount") }
            do {
                _ = try vDSP.DiscreteFourierTransform(count: 7, direction: .forward, transformType: .complexComplex, ofType: DSPComplex.self)
                check(false, "vDSP.DFTError.invalidInterleavedCount")
            } catch vDSP.DFTError.invalidInterleavedCount(let c) { check(c == 7, "vDSP.DFTError.invalidInterleavedCount")
            } catch { check(false, "vDSP.DFTError.invalidInterleavedCount") }
            let idft = try! vDSP.DiscreteFourierTransform(previousDFT: nil, count: 12, direction: .forward, transformType: .complexComplex, ofType: DSPDoubleComplex.self)
            let iout = idft.transform(input: ir.map { DSPDoubleComplex(real: $0, imag: 0) })
            check(iout.count == 12 && close(iout.map(\.real), ref), "vDSP.DiscreteFourierTransform<DSPDoubleComplex>.transform(input:)")
            let fdft = try! vDSP.DiscreteFourierTransform(count: 12, direction: .forward, transformType: .complexComplex, ofType: DSPComplex.self)
            var fout = [DSPComplex](repeating: DSPComplex(), count: 12)
            fdft.transform(input: ir.map { DSPComplex(real: Float($0), imag: 0) }, output: &fout)
            check(close(fout.map { Double($0.real) }, ref, 1e-4), "vDSP.DiscreteFourierTransform<DSPComplex>.transform(input:output:)")
            let reuse = try! vDSP.DiscreteFourierTransform(previousDFT: dft, count: 12, direction: .inverse, transformType: .complexComplex, ofType: Double.self)
            var br = [Double](repeating: 0, count: 12), bi = br
            let fwd = dft.transform(real: ir, imaginary: ii)
            reuse.transform(inputReal: fwd.real, inputImaginary: fwd.imaginary, outputReal: &br, outputImaginary: &bi)
            check(close(br.map { $0 / 12 }, ir), "vDSP.DiscreteFourierTransform(previousDFT:): an inverse round trip")
            let rs = try! vDSP.DFTSinglePrecisionSplitComplexFunctions.makeDiscreteFourierTransform(previous: nil, count: 16, direction: .forward, transformType: .complexReal)
            vDSP.DFTSinglePrecisionSplitComplexFunctions.destroySetup(rs)
            check((try? vDSP.DFTDoublePrecisionInterleavedFunctions.makeDiscreteFourierTransform(previous: nil, count: 7, direction: .inverse, transformType: .complexComplex)) == nil,
                  "vDSP.DFT…Functions.makeDiscreteFourierTransform")
        }
        // vDSP_DFTFunctions over the C setup, and vDSP_DFT_Direction as Apple's closed enum
        if let s = vDSP.VectorizableDouble.makeDFTSetup(previous: nil as vDSP.DFT<Double>?, count: 12, direction: .forward, transformType: .complexComplex) {
            var vr = [Double](repeating: 0, count: 12), vi = vr
            vDSP.VectorizableDouble.transform(dftSetup: s, inputReal: ir, inputImaginary: ii, outputReal: &vr, outputImaginary: &vi)
            vDSP.VectorizableDouble.destroySetup(s)
            check(close(vr, ref), "vDSP.VectorizableDouble.makeDFTSetup, transform(dftSetup:...)")
        } else { check(false, "vDSP.VectorizableDouble.makeDFTSetup, transform(dftSetup:...)") }
        check(vDSP.FourierTransformDirection.inverse.dftDirection == .INVERSE, "vDSP_DFT_Direction: INVERSE")
        check(vDSP_DFT_Direction(rawValue: 1) == .FORWARD, "vDSP_DFT_Direction: init?(rawValue:)")

        // the C API from Swift
        var A: [Double] = [2, 1, 1, 3], B: [Double] = [3, 5]
        var nn: __CLPK_integer = 2, lda: __CLPK_integer = 2, ldb: __CLPK_integer = 2, one: __CLPK_integer = 1, ipiv = [__CLPK_integer](repeating: 0, count: 2), info: __CLPK_integer = -1
        dgesv_(&nn, &one, &A, &lda, &ipiv, &B, &ldb, &info)
        check(info == 0 && close(B, [0.8, 1.4]), "dgesv_ from Swift")
        var C = [Float](repeating: 0, count: 4)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1, [1, 2, 3, 4], 2, [5, 6, 7, 8], 2, 0, &C, 2)
        check(C == [19, 22, 43, 50], "cblas_sgemm from Swift")

        // issue #807: Sparse Solvers from Swift: the overloads, a direct factorization, an iterative method with a closure
        do {
            var rows: [Int32] = [0, 1, 2, 1, 2], cols: [Int32] = [0, 0, 0, 1, 2]
            var vals: [Double] = [4, 1, 1, 3, 2]   // the lower triangle of [[4,1,1],[1,3,0],[1,0,2]]
            var attrs = SparseAttributes_t()
            attrs.kind = SparseSymmetric; attrs.triangle = SparseLowerTriangle
            let A = SparseConvertFromCoordinate(3, 3, 5, 1, attrs, &rows, &cols, &vals)
            var b: [Double] = [9, 7, 7], x = [Double](repeating: 0, count: 3)   // x = (1, 2, 3)
            let F = SparseFactor(SparseFactorizationCholesky, A)
            b.withUnsafeMutableBufferPointer { bp in x.withUnsafeMutableBufferPointer { xp in
                SparseSolve(F, DenseVector_Double(count: 3, data: bp.baseAddress!), DenseVector_Double(count: 3, data: xp.baseAddress!))
            } }
            check(F.status == SparseStatusOK && close(x, [1, 2, 3], 1e-12), "SparseFactor / SparseSolve from Swift")
            var y = [Double](repeating: 0, count: 3)
            x.withUnsafeMutableBufferPointer { xp in y.withUnsafeMutableBufferPointer { yp in
                SparseMultiply(A, DenseVector_Double(count: 3, data: xp.baseAddress!), DenseVector_Double(count: 3, data: yp.baseAddress!))
            } }
            check(close(y, [9, 7, 7], 1e-12), "SparseMultiply from Swift")
            var calls = 0
            x = [0, 0, 0]
            let status = b.withUnsafeMutableBufferPointer { bp in x.withUnsafeMutableBufferPointer { xp in
                SparseSolve(SparseConjugateGradient(), { accumulate, trans, u, v in
                    calls += 1
                    if accumulate { SparseMultiplyAdd(A, u, v) } else { SparseMultiply(A, u, v) }
                }, DenseVector_Double(count: 3, data: bp.baseAddress!), DenseVector_Double(count: 3, data: xp.baseAddress!))
            } }
            check(status == SparseIterativeConverged && calls > 0 && close(x, [1, 2, 3], 1e-6), "SparseSolve(SparseConjugateGradient(), operator closure) from Swift")
            var o = SparseLSMROptions(); o.maxIterations = 50
            x = [0, 0, 0]
            let st2 = b.withUnsafeMutableBufferPointer { bp in x.withUnsafeMutableBufferPointer { xp in
                SparseSolve(SparseLSMR(o), A, DenseVector_Double(count: 3, data: bp.baseAddress!), DenseVector_Double(count: 3, data: xp.baseAddress!),
                            SparsePreconditionerDiagScaling)
            } }
            check(st2 == SparseIterativeConverged && close(x, [1, 2, 3], 1e-5), "SparseSolve(SparseLSMR(options), A, b, x, preconditioner) from Swift")
            let sub = SparseCreateSubfactor(SparseSubfactorL, F)
            check(sub.contents == SparseSubfactorL, "SparseCreateSubfactor from Swift")
            SparseCleanup(sub); SparseCleanup(F); SparseCleanup(A)
        }

        // issue #819: Sparse BLAS from Swift, and SparseConvertFromOpaque into the solvers
        do {
            let A = sparse_matrix_create_double(2, 2)!
            _ = sparse_insert_entry_double(A, 4, 0, 0); _ = sparse_insert_entry_double(A, 1, 1, 0); _ = sparse_insert_entry_double(A, 3, 1, 1)
            check(sparse_commit(UnsafeMutableRawPointer(A)) == SPARSE_SUCCESS && sparse_get_matrix_nonzero_count(UnsafeMutableRawPointer(A)) == 3,
                  "sparse_matrix_create_double, sparse_insert_entry_double, sparse_commit from Swift")
            var y: [Double] = [0, 0]
            _ = sparse_matrix_vector_product_dense_double(CblasNoTrans, 1, A, [1, 1], 1, &y, 1)
            check(y == [4, 4], "sparse_matrix_vector_product_dense_double from Swift")
            let S: SparseMatrix_Double = SparseConvertFromOpaque(A)   // the handle types are all OpaquePointer: the result picks the overload
            let F = SparseFactor(SparseFactorizationQR, S)
            var b: [Double] = [4, 4], x: [Double] = [0, 0]
            b.withUnsafeMutableBufferPointer { bp in x.withUnsafeMutableBufferPointer { xp in
                SparseSolve(F, DenseVector_Double(count: 2, data: bp.baseAddress!), DenseVector_Double(count: 2, data: xp.baseAddress!))
            } }
            check(F.status == SparseStatusOK && close(x, [1, 1], 1e-12), "SparseConvertFromOpaque then SparseFactor from Swift")
            SparseCleanup(F); SparseCleanup(S)
            _ = sparse_matrix_destroy(UnsafeMutableRawPointer(A))
        }

        // issue #543: more of vDSP from Swift
        let p: [Double] = [3, -4, 1.5, -0.25], q: [Double] = [4, 3, 2, 1]
        var sum = [Double](repeating: 0, count: 4), diff = [Double](repeating: 0, count: 4)
        vDSP.addSubtract(p, q, addResult: &sum, subtractResult: &diff)
        check(sum == [7, -1, 3.5, 0.75] && diff == [-1, -7, -0.5, -1.25], "vDSP.addSubtract")
        check(close(vDSP.amplitudeToDecibels([10, 100] as [Double], zeroReference: 1), [20, 40], 1e-12)
              && close(vDSP.powerToDecibels([10, 100] as [Float], zeroReference: 1), [10, 20], 1e-6), "vDSP.amplitudeToDecibels, powerToDecibels")
        check(vDSP.compress([1, 2, 3, 4] as [Float], gatingVector: [1, 0, 2, 0] as [Float], nonZeroGatingCount: nil) == [1, 3], "vDSP.compress")
        check(vDSP.countZeroCrossings([1, -1, -2, 3, 4, -1] as [Double]) == 3, "vDSP.countZeroCrossings")
        check(vDSP.evaluatePolynomial(usingCoefficients: [2, -3, 1] as [Double], withVariables: [0, 1, 2, 3] as [Double]) == [1, 0, 3, 10], "vDSP.evaluatePolynomial")
        check(vDSP.gather([10, 20, 30, 40] as [Float], indices: [4, 1] as [UInt]) == [40, 10], "vDSP.gather (1-based)")
        check(vDSP.hypot([3, 5] as [Double], [4, 12] as [Double]) == [5, 13] && vDSP.hypot(x0: [4] as [Float], x1: [1] as [Float], y0: [6] as [Float], y1: [2] as [Float]) == [5], "vDSP.hypot")
        let imm = vDSP.indexOfMaximumMagnitude([1, -7, 3] as [Double])
        check(imm.0 == 1 && imm.1 == 7, "vDSP.indexOfMaximumMagnitude")
        check(vDSP.integrate([0, 1, 2, 3] as [Double], using: .trapezoidal) == [0, 0.5, 2, 4.5]
              && vDSP.integrate([5, 1, 2, 3] as [Float], using: .runningSum) == [0, 1, 3, 6], "vDSP.integrate")
        check(vDSP.invertedClip([-2, -0.5, 0.5, 2] as [Double], to: -1 ... 1) == [-2, -1, 1, 2], "vDSP.invertedClip")
        check(vDSP.negativeAbsolute([1, -2] as [Float]) == [-1, -2] && vDSP.trunc([1.7, -1.7] as [Double]) == [1, -1], "vDSP.negativeAbsolute, trunc")
        check(vDSP.normalize([2, 4, 4, 4, 5, 5, 7, 9] as [Double]).first == -1.5 && vDSP.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9] as [Float]) == 2,
              "vDSP.normalize, standardDeviation")
        check(vDSP.slidingWindowSum([1, 2, 3, 4, 5] as [Double], usingWindowLength: 3) == [6, 9, 12], "vDSP.slidingWindowSum")
        let ss = vDSP.sumAndSumOfSquares([1, 2, 3] as [Float])
        check(ss.elementsSum == 6 && ss.squaresSum == 14, "vDSP.sumAndSumOfSquares")
        var sa: [Double] = [1, 2], sb: [Double] = [3, 4]
        vDSP.swapElements(&sa, &sb)
        check(sa == [3, 4] && sb == [1, 2], "vDSP.swapElements")
        check(vDSP.taperedMerge([0, 0, 0] as [Double], [3, 3, 3] as [Double]) == [0, 1.5, 3], "vDSP.taperedMerge")
        check(vDSP.threshold([1, 5, -2] as [Double], to: 2, with: .zeroFill) == [0, 5, 0]
              && vDSP.threshold([1, 5, -2] as [Double], to: 2, with: .clampToThreshold) == [2, 5, 2]
              && vDSP.threshold([1, 5, -2] as [Double], to: 2, with: .signedConstant(9)) == [-9, 9, -9], "vDSP.threshold rules")
        check(vDSP.twoPoleTwoZeroFilter([0, 0, 1, 2, 3, 4] as [Double], coefficients: (1, 0, 0, 0.5, 0)) == [0, 0, 1, 1.5, 2.25, 2.875], "vDSP.twoPoleTwoZeroFilter")
        let polar = vDSP.rectangularToPolar([0, 2, -3, 0] as [Double])
        check(polar[0] == 2 && abs(polar[1] - .pi / 2) < 1e-12 && close(vDSP.polarToRectangular(polar), [0, 2, -3, 0], 1e-12), "vDSP.rectangularToPolar, polarToRectangular")
        check(vDSP.floatToDouble([1.5] as [Float]) == [1.5] && vDSP.doubleToFloat([2.5] as [Double]) == [2.5]
              && vDSP.float16ToFloat([Float16(0.5)]) == [0.5], "vDSP precision conversions")
        var ramp = [Double](repeating: 0, count: 3), start = 1.0
        vDSP.formRamp(withInitialValue: &start, multiplyingBy: [2, 2, 2] as [Double], increment: 0.5, result: &ramp)
        check(ramp == [2, 3, 4] && start == 2.5, "vDSP.formRamp multiplying")
        var zre: [Double] = [1, 2], zim: [Double] = [3, -4], cre = [Double](repeating: 0, count: 2), cim = [Double](repeating: 0, count: 2)
        zre.withUnsafeMutableBufferPointer { r in zim.withUnsafeMutableBufferPointer { i in cre.withUnsafeMutableBufferPointer { cr in cim.withUnsafeMutableBufferPointer { ci in
            let z = DSPDoubleSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
            var c = DSPDoubleSplitComplex(realp: cr.baseAddress!, imagp: ci.baseAddress!)
            vDSP.conjugate(z, count: 2, result: &c)
            var mags = [Double](repeating: 0, count: 2)
            vDSP.squareMagnitudes(z, result: &mags)
            check(cr[1] == 2 && ci[1] == 4 && mags == [10, 20], "vDSP.conjugate, squareMagnitudes")
        } } } }
        // a two-section biquad against its recurrence, split across calls
        let coef: [Double] = [0.2, 0.3, 0.1, -0.5, 0.25,  1, -0.4, 0.2, 0.1, -0.05]
        let bx: [Double] = (0..<12).map { ($0 == 0 ? 1 : 0) + 0.5 * sin(Double($0)) }
        var bref = bx
        for sec in 0..<2 {
            let c = Array(coef[sec * 5 ..< sec * 5 + 5]), input = bref
            for n in 0..<12 {
                var v = c[0] * input[n]
                if n >= 1 { v += c[1] * input[n - 1] - c[3] * bref[n - 1] }
                if n >= 2 { v += c[2] * input[n - 2] - c[4] * bref[n - 2] }
                bref[n] = v
            }
        }
        if var bq = vDSP.Biquad(coefficients: coef, channelCount: 1, sectionCount: 2, ofType: Double.self) {
            let by = bq.apply(input: Array(bx[0..<5])) + bq.apply(input: Array(bx[5...]))
            check(close(by, bref, 1e-12), "vDSP.Biquad: two sections, state across calls")
        } else { check(false, "vDSP.Biquad init") }
        var stereo = vDSP.Biquad(coefficients: [1, 2, 0, 0, 0, 0, 0, 0, 0, 0], channelCount: 2, sectionCount: 1, ofType: Float.self)
        check(stereo?.apply(input: [1, 2, 3, 4] as [Float]) == [1, 2, 6, 8], "vDSP.Biquad: two channels (gains 1 and 2)")
        check(vDSP.Biquad(coefficients: [1, 0, 0], channelCount: 1, sectionCount: 1, ofType: Double.self) == nil, "vDSP.Biquad: wrong coefficient count")
        // DCT and FFT2D
        if let dct = vDSP.DCT(count: 16, transformType: .II), let idct = vDSP.DCT(previous: dct, count: 16, transformType: .III) {
            let sig: [Float] = (1...16).map { Float($0) }
            check(close(idct.transform(dct.transform(sig)), sig.map { 8 * Double($0) }, 1e-4), "vDSP.DCT: III(II(x)) = N/2 x")
        } else { check(false, "vDSP.DCT init") }
        check(vDSP.DCT(count: 10, transformType: .IV) == nil, "vDSP.DCT: unsupported length")
        var fr: [Float] = [1, 0, 0, 0, 0, 0, 0, 0], fi: [Float] = [0, 0, 0, 0, 0, 0, 0, 0]   /* 4 x 4 real impulse at (0, 0) */
        var gr = [Float](repeating: 0, count: 8), gi = [Float](repeating: 0, count: 8)
        if let f2 = vDSP.FFT2D(width: 4, height: 4, ofType: DSPSplitComplex.self) {
            fr.withUnsafeMutableBufferPointer { a in fi.withUnsafeMutableBufferPointer { b in gr.withUnsafeMutableBufferPointer { c in gi.withUnsafeMutableBufferPointer { d in
                let input = DSPSplitComplex(realp: a.baseAddress!, imagp: b.baseAddress!)
                var output = DSPSplitComplex(realp: c.baseAddress!, imagp: d.baseAddress!)
                f2.transform(input: input, output: &output, direction: .forward)
            } } } }
            // the flat spectrum (2 everywhere): DC / Nyquist columns packed down rows (row 3 holds bin 1's imaginary part, 0)
            check(gr == [2, 2, 2, 2, 2, 2, 0, 2] && gi == [2, 0, 2, 0, 2, 0, 0, 0], "vDSP.FFT2D: an impulse's packed spectrum")
        } else { check(false, "vDSP.FFT2D init") }

        // Quadrature
        let quad = Quadrature(integrator: .qags(maxIntervals: 200), absoluteTolerance: 1e-9, relativeTolerance: 0)
        if case .success(let r) = quad.integrate(over: 0 ... 1, integrand: { 1 / $0.squareRoot() }) {
            check(abs(r.integralResult - 2) < 1e-8, "Quadrature: 1/sqrt(x) (adaptive with singularities)")
        } else { check(false, "Quadrature qags") }
        let qag = Quadrature(integrator: .adaptive(pointsPerInterval: .sixtyOne, maxIntervals: 10), absoluteTolerance: 1e-12)
        if case .success(let r) = qag.integrate(over: 0 ... Double.pi, integrand: { x, y in for i in 0..<x.count { y[i] = sin(x[i]) } }) {
            check(abs(r.integralResult - 2) < 1e-12, "Quadrature: sin with the vector integrand")
        } else { check(false, "Quadrature qag") }
        if case .failure(let e) = Quadrature(integrator: .qags(maxIntervals: 2), absoluteTolerance: 1e-12).integrate(over: 0 ... 1, integrand: { 1 / $0.squareRoot() }) {
            check(e == .integrateMaxEval && !e.errorDescription.isEmpty, "Quadrature.Error.integrateMaxEval")
        } else { check(false, "Quadrature max eval") }

        print("accelerate swift: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
