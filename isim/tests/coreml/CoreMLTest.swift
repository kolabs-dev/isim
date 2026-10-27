// Core ML runtime (CoreMLTest.app, issue #376): model specs written here (coremltools' protobuf format) for tree
// ensembles and neural networks (with a custom layer), compiled and run; MLShapedArray, MLTensor, MLState, compute
// plans, compute devices and update tasks.
import Foundation
import CoreML

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func near(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) <= tol * (1 + abs(b)) }
func near(_ a: [Double], _ b: [Double], _ tol: Double = 1e-6) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { near($0, $1, tol) } || { print("      \(a) != \(b)"); return false }()
}

// MARK: - a protobuf writer for model specs

func varint(_ n: UInt64) -> [UInt8] { var n = n, out: [UInt8] = []; repeat { var b = UInt8(n & 0x7F); n >>= 7; if n != 0 { b |= 0x80 }; out.append(b) } while n != 0; return out }
func key(_ f: Int, _ w: Int) -> [UInt8] { varint(UInt64(f << 3 | w)) }
func vint(_ f: Int, _ n: Int) -> [UInt8] { key(f, 0) + varint(UInt64(bitPattern: Int64(n))) }
func ld(_ f: Int, _ p: [UInt8]) -> [UInt8] { key(f, 2) + varint(UInt64(p.count)) + p }
func str(_ f: Int, _ s: String) -> [UInt8] { ld(f, Array(s.utf8)) }
func dbl(_ f: Int, _ d: Double) -> [UInt8] { key(f, 1) + withUnsafeBytes(of: d.bitPattern.littleEndian) { Array($0) } }
func flt(_ f: Int, _ x: Float) -> [UInt8] { key(f, 5) + withUnsafeBytes(of: x.bitPattern.littleEndian) { Array($0) } }
func floats(_ f: Int, _ xs: [Float]) -> [UInt8] { ld(f, xs.flatMap { x in withUnsafeBytes(of: x.bitPattern.littleEndian) { Array($0) } }) }
func doubles(_ f: Int, _ xs: [Double]) -> [UInt8] { ld(f, xs.flatMap { x in withUnsafeBytes(of: x.bitPattern.littleEndian) { Array($0) } }) }
func feature(_ name: String, _ type: [UInt8]) -> [UInt8] { str(1, name) + ld(3, type) }
func multiarray(_ shape: [Int], _ dtype: Int = 65600) -> [UInt8] { ld(5, shape.flatMap { vint(1, $0) } + vint(2, dtype)) }
let DOUBLE = ld(2, []), STRING = ld(3, []), INT64 = ld(1, [])
let DICT_STRING = ld(6, ld(2, [])), DICT_INT = ld(6, ld(1, []))
func weights(_ xs: [Float]) -> [UInt8] { floats(1, xs) }
func layer(_ name: String, _ ins: [String], _ outs: [String], _ field: Int, _ params: [UInt8]) -> [UInt8] {
    str(1, name) + ins.flatMap { str(2, $0) } + outs.flatMap { str(3, $0) } + ld(field, params)
}
func compiled(_ name: String, _ spec: [UInt8]) throws -> MLModel {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name + ".mlmodel")
    try Data(spec).write(to: url)
    return try MLModel(contentsOf: try MLModel.compileModel(at: url))
}
func x2(_ a: Double, _ b: Double) -> MLFeatureProvider {
    let m = try! MLMultiArray(shape: [2], dataType: .double); m[0] = NSNumber(value: a); m[1] = NSNumber(value: b)
    return try! MLDictionaryFeatureProvider(dictionary: ["x": m])
}

/// a custom layer the network names (doubles its input)
@objc(DoubleIt) final class DoubleIt: NSObject, MLCustomLayer {
    let factor: Double
    init(parameterDictionary parameters: [String: Any]) throws { factor = parameters["factor"] as? Double ?? 2 }
    func setWeightData(_ weights: [Data]) throws {}
    func outputShapes(forInputShapes inputShapes: [[NSNumber]]) throws -> [[NSNumber]] { inputShapes }
    func evaluate(inputs: [MLMultiArray], outputs: [MLMultiArray]) throws {
        for i in 0..<inputs[0].count { outputs[0][i] = NSNumber(value: inputs[0][i].doubleValue * factor) }
    }
}

@main enum CoreMLTest {
    static func main() async {
        do { try trees(); try networks(); try await plans() } catch { failures += 1; print("FAIL  models threw \(error)") }
        shapedArrays()
        await tensors()
        print("CoreMLTest: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }

    static func trees() throws {
        /* two trees over x (2 values): x0 <= 0.5 ? 1 : 3, and x1 < 2 ? 10 : 20; base 0.5 */
        func node(_ tree: Int, _ id: Int, _ behavior: Int, feature: Int = 0, value: Double = 0, t: Int = 0, f: Int = 0, leaf: Double? = nil) -> [UInt8] {
            var n = vint(1, tree) + vint(2, id) + vint(3, behavior)
            if let leaf { n += ld(20, vint(1, 0) + dbl(2, leaf)) } else { n += vint(10, feature) + dbl(11, value) + vint(12, t) + vint(13, f) }
            return ld(1, n)
        }
        let ensemble = node(0, 0, 0, feature: 0, value: 0.5, t: 1, f: 2) + node(0, 1, 6, leaf: 1) + node(0, 2, 6, leaf: 3)
            + node(1, 0, 1, feature: 1, value: 2, t: 1, f: 2) + node(1, 1, 6, leaf: 10) + node(1, 2, 6, leaf: 20) + vint(2, 1) + doubles(3, [0.5])
        let desc = ld(1, feature("x", multiarray([2]))) + ld(10, feature("y", DOUBLE)) + str(11, "y")
        let reg = try compiled("Trees", vint(1, 4) + ld(2, desc) + ld(302, ld(1, ensemble)))
        let a = try reg.prediction(from: x2(0, 1)).featureValue(for: "y")?.doubleValue ?? -1
        let b = try reg.prediction(from: x2(1, 5)).featureValue(for: "y")?.doubleValue ?? -1
        check(reg._isimModelType == "treeEnsembleRegressor" && near(a, 11.5) && near(b, 23.5), "tree ensemble regressor: \(a), \(b)")

        /* a classifier: one tree with a logistic transform, labels 0 and 1 */
        let one = node(0, 0, 0, feature: 0, value: 0, t: 1, f: 2) + node(0, 1, 6, leaf: -2) + node(0, 2, 6, leaf: 2) + vint(2, 1)
        let cdesc = ld(1, feature("x", multiarray([2]))) + ld(10, feature("label", INT64)) + ld(10, feature("labelProbability", DICT_INT)) + str(11, "label") + str(12, "labelProbability")
        let cls = try compiled("TreeClass", vint(1, 4) + ld(2, cdesc) + ld(402, ld(1, one) + vint(2, 2) + ld(101, vint(1, 0) + vint(1, 1))))
        let out = try cls.prediction(from: x2(1, 0))
        let p1 = out.featureValue(for: "labelProbability")?.dictionaryValue[Int64(1)]?.doubleValue ?? -1
        check(out.featureValue(for: "label")?.int64Value == 1 && near(p1, 1 / (1 + Foundation.exp(-2.0))), "tree ensemble classifier: label 1, p \(p1)")
        let out0 = try cls.prediction(from: x2(-1, 0))
        check(out0.featureValue(for: "label")?.int64Value == 0, "tree ensemble classifier: the other branch")
    }

    static func networks() throws {
        /* a classifier: dense (2 -> 3) + ReLU, dense (3 -> 2), softmax; labels a and b */
        let w1: [Float] = [1, 0, 0, 1, 1, -1], b1: [Float] = [0, 0, 0.5]
        let w2: [Float] = [1, 1, 0, -1, 0, 2], b2: [Float] = [0, 0]
        let dense1 = vint(1, 2) + vint(2, 3) + vint(10, 1) + ld(20, weights(w1)) + ld(21, weights(b1))
        let dense2 = vint(1, 3) + vint(2, 2) + vint(10, 1) + ld(20, weights(w2)) + ld(21, weights(b2))
        let layers = ld(1, layer("dense1", ["x"], ["h"], 140, dense1)) + ld(1, layer("relu", ["h"], ["r"], 130, ld(10, [])))
            + ld(1, layer("dense2", ["r"], ["logits"], 140, dense2)) + ld(1, layer("softmax", ["logits"], ["probs"], 175, []))
        let desc = ld(1, feature("x", multiarray([2]))) + ld(10, feature("label", STRING)) + ld(10, feature("probs", DICT_STRING)) + str(11, "label") + str(12, "probs")
        let net = try compiled("Net", vint(1, 4) + ld(2, desc) + ld(403, layers + ld(100, str(1, "a") + str(1, "b")) + str(200, "probs")))
        /* the expected values, by hand: h = [x0, x1, x0 - x1 + 0.5], r = relu(h), logits = [r0 + r1, -r0 + 2 r2] */
        func expect(_ x0: Double, _ x1: Double) -> [Double] {
            let r = [max(0, x0), max(0, x1), max(0, x0 - x1 + 0.5)]
            let l = [r[0] + r[1], -r[0] + 2 * r[2]], m = l.max()!, e = l.map { Foundation.exp($0 - m) }
            return e.map { $0 / e.reduce(0, +) }
        }
        let o = try net.prediction(from: x2(2, 1))
        let probs = o.featureValue(for: "probs")?.dictionaryValue ?? [:]
        let e = expect(2, 1)
        check(near([probs["a"]?.doubleValue ?? -1, probs["b"]?.doubleValue ?? -1], e) && o.featureValue(for: "label")?.stringValue == (e[0] > e[1] ? "a" : "b"),
              "neural network classifier (inner product, ReLU, softmax): \(o.featureValue(for: "label")?.stringValue ?? "-")")
        let o2 = try net.prediction(from: x2(0, 3))
        check(o2.featureValue(for: "label")?.stringValue == (expect(0, 3)[0] > expect(0, 3)[1] ? "a" : "b"), "neural network classifier: another input")

        /* a regressor: multiply by 2, add to the input (3x), concatenate with the input, a custom layer doubling it,
           batch norm (mean 1, variance 4) and a scaled tanh */
        let custom = str(10, "DoubleIt") + ld(30, str(1, "factor") + ld(2, dbl(10, 2)))
        let bn = vint(1, 1) + flt(10, 0) + ld(15, weights([1])) + ld(16, weights([0])) + ld(17, weights([1])) + ld(18, weights([4]))
        let layers2 = ld(1, layer("twice", ["x"], ["x2"], 231, flt(1, 2))) + ld(1, layer("sum", ["x", "x2"], ["x3"], 230, []))
            + ld(1, layer("join", ["x3", "x"], ["j"], 320, [])) + ld(1, layer("custom", ["j"], ["c"], 500, custom))
            + ld(1, layer("norm", ["c"], ["n"], 160, bn)) + ld(1, layer("flat", ["n"], ["out"], 301, []))
        let rdesc = ld(1, feature("x", multiarray([2]))) + ld(10, feature("out", multiarray([4])))
        let reg = try compiled("NetReg", vint(1, 4) + ld(2, rdesc) + ld(303, layers2))
        let out = try reg.prediction(from: x2(1, 2)).featureValue(for: "out")?.multiArrayValue
        /* x = [1, 2]: 3x = [3, 6], joined [3, 6, 1, 2], doubled [6, 12, 2, 4], normalized (v - 1) / 2 */
        check(near(out?._isimValues ?? [], [2.5, 5.5, 0.5, 1.5]) && out?.shape == [4], "neural network: multiply, add, concat, custom layer, batch norm, flatten")

        /* a layer isim does not run: a clear error */
        let conv = ld(1, layer("conv", ["x"], ["y"], 100, []))
        let bad = try compiled("Conv", vint(1, 4) + ld(2, ld(1, feature("x", multiarray([2]))) + ld(10, feature("y", multiarray([2])))) + ld(500, conv))
        do { _ = try bad.prediction(from: x2(1, 1)); check(false, "an unsupported layer fails") }
        catch { check("\(error)".contains("layer type 100") || (error as NSError).localizedDescription.contains("layer type 100"), "an unsupported layer fails clearly") }

        /* states: a model without states; update tasks are not available */
        let state = net.makeState()
        check((try? net.prediction(from: x2(2, 1), using: state)) != nil && net.modelDescription.stateDescriptionsByName.isEmpty, "makeState, prediction(from:using:)")
        do {
            _ = try MLUpdateTask(forModelAt: URL(fileURLWithPath: "/tmp/x.mlmodelc"), trainingData: MLArrayBatchProvider(array: []), configuration: nil) { _ in }
            check(false, "MLUpdateTask throws")
        } catch { check((error as NSError).code == MLModelError.Code.update.rawValue, "MLUpdateTask throws MLModelError.update") }
        check(MLModel.availableComputeDevices.count == 1 && MLComputeDevice.allComputeDevices.count == 1, "compute devices: the CPU")
        if case .cpu = MLComputeDevice.allComputeDevices[0] { check(true, "the CPU device") } else { check(false, "the CPU device") }
    }

    static func plans() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Net.mlmodel")
        let plan = try await MLComputePlan.load(contentsOf: try MLModel.compileModel(at: url), configuration: MLModelConfiguration())
        guard case .neuralNetwork(let nn) = plan.modelStructure else { check(false, "compute plan structure"); return }
        let usage = nn.layers.first.flatMap { plan.deviceUsage(for: $0) }
        check(nn.layers.map(\.type) == ["innerProduct", "activation", "innerProduct", "softmax"] && nn.layers[0].inputNames == ["x"] && usage?.supported.count == 1,
              "MLComputePlan: the layers and their device")
    }

    static func shapedArrays() {
        var a = MLShapedArray<Float>(scalars: [1, 2, 3, 4, 5, 6], shape: [2, 3])
        check(a.shape == [2, 3] && a.strides == [3, 1] && a.scalarCount == 6 && a.count == 2 && !a.isScalar, "MLShapedArray shape, strides, counts")
        check(a[scalarAt: 1, 2] == 6 && a[1].scalars == [4, 5, 6] && a[1].shape == [3], "scalar and row subscripts")
        a[scalarAt: 0, 0] = 10
        a[1] = MLShapedArraySlice(scalars: [7, 8, 9], shape: [3])
        check(a.scalars == [10, 2, 3, 7, 8, 9], "writing through subscripts")
        check(a.transposed().shape == [3, 2] && a.transposed().scalars == [10, 7, 2, 8, 3, 9], "transposed")
        check(a.reshaped(to: [3, 2])[2].scalars == [8, 9] && a.expandingShape(at: 0).shape == [1, 2, 3] && a.expandingShape(at: 0).squeezingShape().shape == [2, 3], "reshape, expand, squeeze")
        check(a[0..<1].shape == [1, 3] && a[0..<2, 1..<3].scalars == [2, 3, 8, 9], "range subscripts")
        let m = MLMultiArray(a)
        check(m.shape == [2, 3] && m.dataType == .float32 && m[5].floatValue == 9 && MLShapedArray<Float>(m) == a, "MLMultiArray conversions")
        let d = MLShapedArray<Double>(converting: a), i = MLShapedArray<Int32>(repeating: 7, shape: [2])
        check(d.scalars.first == 10 && i.scalars == [7, 7] && MLShapedArray<Float>(identityMatrixOfSize: 2).scalars == [1, 0, 0, 1], "converting, repeating, identity")
        let joined = MLShapedArray<Float>(concatenating: [a, a], alongAxis: 1)
        check(joined.shape == [2, 6] && joined[1].scalars == [7, 8, 9, 7, 8, 9], "concatenating")
        let coded = try? JSONDecoder().decode(MLShapedArray<Float>.self, from: JSONEncoder().encode(a))
        check(coded == a && MLShapedArray<Float>(scalar: 3).isScalar, "Codable, scalars")
        var sum: Float = 0
        a.withUnsafeShapedBufferPointer { p, shape, strides in sum = p.reduce(0, +); _ = (shape, strides) }
        check(sum == 39, "withUnsafeShapedBufferPointer")
        let fv = MLFeatureValue(shapedArray: a)
        check(fv.shapedArrayValue(of: Float.self) == a, "MLFeatureValue(shapedArray:)")
    }

    static func tensors() async {
        let t = MLTensor(shape: [2, 3], scalars: [1, 2, 3, 4, 5, 6] as [Float])
        func v(_ x: MLTensor) async -> [Float] { await x.shapedArray(of: Float.self).scalars }
        func i(_ x: MLTensor) async -> [Int32] { await x.shapedArray(of: Int32.self).scalars }
        check(t.shape == [2, 3] && t.rank == 2 && t.scalarCount == 6, "MLTensor shape")
        let sum2 = await v(t + t), times2 = await v(t * Float(2))
        check(sum2 == [2, 4, 6, 8, 10, 12] && times2 == [2, 4, 6, 8, 10, 12], "element-wise add, scalar multiply")
        let row = MLTensor([10, 20, 30] as [Float])
        let broadcast = await v(t + row)
        check(broadcast == [11, 22, 33, 14, 25, 36], "broadcasting")
        let total = await v(t.sum()), cols = await v(t.sum(alongAxes: 0)), means = await v(t.mean(alongAxes: 1))
        check(total == [21] && cols == [5, 7, 9] && means == [2, 5], "sum, mean")
        let mx = t.max(alongAxes: 1, keepRank: true), mxv = await v(mx)
        check(mxv == [3, 6] && mx.shape == [2, 1], "max keepRank")
        let am = await i(t.argmax(alongAxis: 1))
        check(am == [2, 2], "argmax")
        let m = t.matmul(t.transposed()), mv = await v(m)
        check(m.shape == [2, 2] && mv == [14, 32, 32, 77], "matmul, transposed")
        let s = await v(MLTensor([1, 2, 3] as [Float]).softmax())
        check(abs(s.reduce(0, +) - 1) < 1e-6 && s[2] > s[1], "softmax")
        let r1 = await v(t.reshaped(to: [3, 2])[1]), sub = await v(t[1, 1...])
        check(r1 == [3, 4] && t[1, 1...].shape == [2] && sub == [5, 6], "reshape, subscripts")
        let col = await v(t[..., 0])
        check(col == [1, 4] && t.expandingShape(at: 0).shape == [1, 2, 3], "unbounded subscripts, expandingShape")
        let cat = await v(MLTensor(concatenating: [t, t], alongAxis: 0))
        check(cat == [1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6] && MLTensor(stacking: [t, t], alongAxis: 0).shape == [2, 2, 3], "concatenating, stacking")
        let (values, indices) = MLTensor([3, 1, 2] as [Float]).topK(2)
        let tv = await v(values), ti = await i(indices)
        check(tv == [3, 2] && ti == [0, 2], "topK")
        let cmp = await i((t .> MLTensor(Float(3))).cast(to: Int32.self))
        check(cmp == [0, 0, 0, 1, 1, 1], "comparisons")
        let cs = await v(t.cumulativeSum(alongAxis: 1)), g = await v(t.gathering(atIndices: MLTensor([1] as [Int32]), alongAxis: 0))
        check(cs == [1, 3, 6, 4, 9, 15] && g == [4, 5, 6], "cumulativeSum, gathering")
        let z = await v(MLTensor(zeros: [2])), ls = await v(MLTensor(linearSpaceFrom: 0, through: 1, count: 3))
        check(z == [0, 0] && ls == [0, 0.5, 1], "zeros, linear space")
        let pad = await v(t.padded(forSizes: [(0, 0), (1, 1)], with: 0))
        check(pad == [0, 1, 2, 3, 0, 0, 4, 5, 6, 0], "padded")
        let u1 = await v(MLTensor(randomUniform: [4], seed: 7)), u2 = await v(MLTensor(randomUniform: [4], seed: 7))
        check(u1 == u2 && u1.allSatisfy { $0 >= 0 && $0 < 1 }, "seeded random tensors")
        let sq = await v(MLTensor([4, 9] as [Float]).squareRoot()), ab = await v(MLTensor([-1.5, 2] as [Float]).abs())
        check(sq == [2, 3] && ab == [1.5, 2], "squareRoot, abs")
    }
}
extension MLMultiArray { var _isimValues: [Double] { (0..<count).map { self[$0].doubleValue } } }
