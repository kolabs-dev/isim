// isim Core ML runtime (issue #376): tree ensembles and neural networks run by isim's spec interpreter (adapted;
// the field numbers are coremltools' TreeEnsemble.proto and NeuralNetwork.proto), custom layers (MLCustomLayer),
// model states, compute devices (the CPU), compute plans and update tasks (stub: no on-device training).
// Neural networks: inner product, activations, softmax, batch normalization, add, multiply, flatten, reshape,
// concatenation and custom layers, on flat values (channel-first); other layers fail with a message naming them.
import Foundation

// MARK: - tree ensembles

struct _MLTreeNode {
    var tree: UInt64 = 0, id: UInt64 = 0, behavior = 0, feature = 0, value = 0.0
    var trueChild: UInt64 = 0, falseChild: UInt64 = 0, missingTrue = false
    var evals: [(Int, Double)] = []
}
struct _MLTrees {
    var nodes: [UInt64: [UInt64: _MLTreeNode]] = [:]     // tree -> node id -> node
    var dimensions = 1
    var base: [Double] = []
    var post = 0          // 0 none, 1 softmax, 2 logistic, 3 softmax with a zero reference class
}

extension _MLSpec {
    mutating func parseTrees(_ s: ArraySlice<UInt8>, classifier: Bool) throws {
        var t = _MLTrees()
        var p = _PB(s)
        while !p.atEnd {
            let (f, _, v, d) = try p.next()
            switch f {
            case 1:
                var q = _PB(d)
                while !q.atEnd {
                    let (g, w, v2, x) = try q.next()
                    switch g {
                    case 1:
                        var n = _MLTreeNode()
                        var r = _PB(x)
                        while !r.atEnd {
                            let (h, _, v3, y) = try r.next()
                            switch h {
                            case 1: n.tree = v3
                            case 2: n.id = v3
                            case 3: n.behavior = Int(v3)
                            case 10: n.feature = Int(v3)
                            case 11: n.value = _PB.double(y)
                            case 12: n.trueChild = v3
                            case 13: n.falseChild = v3
                            case 14: n.missingTrue = v3 != 0
                            case 20:
                                var e = _PB(y); var idx = 0, val = 0.0
                                while !e.atEnd { let (k, _, v4, z) = try e.next(); if k == 1 { idx = Int(v4) } else if k == 2 { val = _PB.double(z) } }
                                n.evals.append((idx, val))
                            default: break
                            }
                        }
                        t.nodes[n.tree, default: [:]][n.id] = n
                    case 2: t.dimensions = max(1, Int(v2))
                    case 3: t.base += _PB.doubles(w, x)
                    default: break
                    }
                }
            case 2: t.post = Int(v)
            case 100 where classifier, 101 where classifier: labels += try _MLSpec.labelVector(f, d)
            default: break
            }
        }
        trees = t
    }
    /// StringVector (100) or Int64Vector (101)
    static func labelVector(_ field: Int, _ d: ArraySlice<UInt8>) throws -> [Any] {
        var out: [Any] = []
        var q = _PB(d)
        while !q.atEnd {
            let (g, w2, v2, x) = try q.next()
            guard g == 1 else { continue }
            if field == 100 { out.append(_PB.string(x)) }
            else if w2 == 0 { out.append(Int64(bitPattern: v2)) }
            else { var r = _PB(x); while !r.atEnd { out.append(Int64(bitPattern: try r.varint())) } }
        }
        return out
    }
}

// MARK: - neural networks

struct _MLLayer {
    enum Kind {
        case innerProduct(inputs: Int, outputs: Int, weights: [Double], bias: [Double]?)
        case activation(Int, Double, Double)      // NonlinearityType field, alpha, beta
        case softmax, flatten, concat
        case add(Double), multiply(Double)
        case reshape([Int])
        case batchnorm(channels: Int, gamma: [Double], beta: [Double], mean: [Double], variance: [Double], epsilon: Double)
        case custom(className: String, weights: [Data], parameters: [String: Any])
        case unsupported(Int)
    }
    var name = "", inputs: [String] = [], outputs: [String] = []
    var kind = Kind.unsupported(0)
    var typeName: String {
        switch kind {
        case .innerProduct: return "innerProduct"
        case .activation: return "activation"
        case .softmax: return "softmax"
        case .flatten: return "flatten"
        case .concat: return "concat"
        case .add: return "add"
        case .multiply: return "multiply"
        case .reshape: return "reshape"
        case .batchnorm: return "batchnorm"
        case .custom: return "custom"
        case .unsupported(let f): return "layer type \(f)"
        }
    }
}

extension _MLSpec {
    /// WeightParams: float values (packed or not), float16 bytes or raw float32 bytes
    static func weights(_ s: ArraySlice<UInt8>) throws -> [Double] {
        var out: [Double] = []
        var p = _PB(s)
        while !p.atEnd {
            let (f, w, _, d) = try p.next()
            let a = Array(d)
            switch f {
            case 1:
                if w == 5 { out.append(Double(Float(bitPattern: a.withUnsafeBytes { $0.load(as: UInt32.self) }))) }
                else { for i in stride(from: 0, to: a.count - 3, by: 4) { out.append(Double(Float(bitPattern: UInt32(a[i]) | UInt32(a[i + 1]) << 8 | UInt32(a[i + 2]) << 16 | UInt32(a[i + 3]) << 24))) } }
            case 2: for i in stride(from: 0, to: a.count - 1, by: 2) { out.append(Double(Float(_half: UInt16(a[i]) | UInt16(a[i + 1]) << 8))) }
            case 30: for i in stride(from: 0, to: a.count - 3, by: 4) { out.append(Double(Float(bitPattern: UInt32(a[i]) | UInt32(a[i + 1]) << 8 | UInt32(a[i + 2]) << 16 | UInt32(a[i + 3]) << 24))) }
            default: break
            }
        }
        return out
    }
    static func float(_ w: Int, _ d: ArraySlice<UInt8>) -> Double {
        w == 5 ? Double(Float(bitPattern: Array(d).withUnsafeBytes { $0.load(as: UInt32.self) })) : 0
    }

    mutating func parseNetwork(_ s: ArraySlice<UInt8>, classifier: Bool) throws {
        var p = _PB(s)
        while !p.atEnd {
            let (f, _, _, d) = try p.next()
            switch f {
            case 1: layers.append(try _MLSpec.layer(d))
            case 100 where classifier, 101 where classifier: labels += try _MLSpec.labelVector(f, d)
            case 200 where classifier: labelProbabilityLayer = _PB.string(d)
            default: break
            }
        }
    }
    static func layer(_ s: ArraySlice<UInt8>) throws -> _MLLayer {
        var l = _MLLayer()
        var p = _PB(s)
        while !p.atEnd {
            let (f, _, _, d) = try p.next()
            switch f {
            case 1: l.name = _PB.string(d)
            case 2: l.inputs.append(_PB.string(d))
            case 3: l.outputs.append(_PB.string(d))
            case 4, 5, 10: break
            case 130:                                        // ActivationParams: one nonlinearity message
                var q = _PB(d)
                if !q.atEnd {
                    let (g, _, _, x) = try q.next()
                    var alpha = 0.0, beta = 0.0
                    var r = _PB(x)
                    while !r.atEnd { let (h, w, _, y) = try r.next(); if h == 1 { alpha = float(w, y) } else if h == 2 { beta = float(w, y) } }
                    l.kind = .activation(g, alpha, beta)
                }
            case 140:
                var ins = 0, outs = 0, hasBias = false, w: [Double] = [], b: [Double] = []
                var q = _PB(d)
                while !q.atEnd {
                    let (g, _, v, x) = try q.next()
                    switch g {
                    case 1: ins = Int(v)
                    case 2: outs = Int(v)
                    case 10: hasBias = v != 0
                    case 20: w = try weights(x)
                    case 21: b = try weights(x)
                    default: break
                    }
                }
                l.kind = .innerProduct(inputs: ins, outputs: outs, weights: w, bias: hasBias ? b : nil)
            case 160:
                var c = 0, eps = 1e-5, gamma: [Double] = [], beta: [Double] = [], mean: [Double] = [], variance: [Double] = []
                var q = _PB(d)
                while !q.atEnd {
                    let (g, w, v, x) = try q.next()
                    switch g {
                    case 1: c = Int(v)
                    case 10: eps = float(w, x)
                    case 15: gamma = try weights(x)
                    case 16: beta = try weights(x)
                    case 17: mean = try weights(x)
                    case 18: variance = try weights(x)
                    default: break
                    }
                }
                l.kind = .batchnorm(channels: c, gamma: gamma, beta: beta, mean: mean, variance: variance, epsilon: eps)
            case 175: l.kind = .softmax
            case 230, 231:
                var alpha = 0.0
                var q = _PB(d)
                while !q.atEnd { let (g, w, _, x) = try q.next(); if g == 1 { alpha = float(w, x) } }
                l.kind = f == 230 ? .add(alpha) : .multiply(alpha)
            case 300:
                var shape: [Int] = []
                var q = _PB(d)
                while !q.atEnd {
                    let (g, w, v, x) = try q.next()
                    guard g == 1 else { continue }
                    if w == 0 { shape.append(Int(Int64(bitPattern: v))) } else { var r = _PB(x); while !r.atEnd { shape.append(Int(Int64(bitPattern: try r.varint()))) } }
                }
                l.kind = .reshape(shape)
            case 301: l.kind = .flatten
            case 320: l.kind = .concat
            case 500:
                var name = "", ws: [Data] = [], params: [String: Any] = [:]
                var q = _PB(d)
                while !q.atEnd {
                    let (g, _, _, x) = try q.next()
                    switch g {
                    case 10: name = _PB.string(x)
                    case 20: let fs: [Float] = try weights(x).map { Float($0) }; ws.append(fs.withUnsafeBytes { Data($0) })
                    case 30:
                        var e = _PB(x); var key = "", value: Any = 0
                        while !e.atEnd {
                            let (h, _, _, y) = try e.next()
                            if h == 1 { key = _PB.string(y) }
                            else if h == 2 {
                                var z = _PB(y)
                                while !z.atEnd {
                                    let (k, _, v4, u) = try z.next()
                                    switch k {
                                    case 10: value = _PB.double(u)
                                    case 20: value = _PB.string(u)
                                    case 30: value = Int(Int32(truncatingIfNeeded: v4))
                                    case 40: value = Int64(bitPattern: v4)
                                    case 50: value = v4 != 0
                                    default: break
                                    }
                                }
                            }
                        }
                        params[key] = value
                    default: break
                    }
                }
                l.kind = .custom(className: name, weights: ws, parameters: params)
            default: if f >= 100 { l.kind = .unsupported(f) }
            }
        }
        return l
    }
}

/// A layer the app implements (Apple's protocol; isim calls `evaluate(inputs:outputs:)` on the CPU).
@objc public protocol MLCustomLayer: NSObjectProtocol {
    @objc(initWithParameterDictionary:error:) init(parameterDictionary parameters: [String: Any]) throws
    @objc(setWeightData:error:) func setWeightData(_ weights: [Data]) throws
    @objc(outputShapesForInputShapes:error:) func outputShapes(forInputShapes inputShapes: [[NSNumber]]) throws -> [[NSNumber]]
    @objc(evaluateOnCPUWithInputs:outputs:error:) func evaluate(inputs: [MLMultiArray], outputs: [MLMultiArray]) throws
}

extension MLModel {
    func _treeEnsemble(_ input: MLFeatureProvider) throws -> MLFeatureProvider {
        guard let t = _spec.trees else { throw _mlError(.generic, "the tree ensemble has no trees") }
        let x = try _vector(input)
        var score = [Double](repeating: 0, count: t.dimensions)
        for (i, b) in t.base.enumerated() where i < score.count { score[i] += b }
        for (_, nodes) in t.nodes {
            /* the root: the node no other node points to */
            let children = Set(nodes.values.flatMap { $0.behavior == 6 ? [] : [$0.trueChild, $0.falseChild] })
            guard var n = nodes.values.first(where: { !children.contains($0.id) }) else { continue }
            var steps = 0
            while n.behavior != 6 && steps < 100_000 {
                let v = n.feature < x.count ? x[n.feature] : .nan
                let yes: Bool
                if v.isNaN { yes = n.missingTrue }
                else {
                    switch n.behavior {
                    case 0: yes = v <= n.value
                    case 1: yes = v < n.value
                    case 2: yes = v >= n.value
                    case 3: yes = v > n.value
                    case 4: yes = v == n.value
                    default: yes = v != n.value
                    }
                }
                guard let next = nodes[yes ? n.trueChild : n.falseChild] else { throw _mlError(.generic, "tree node \(n.id) points to a missing node") }
                n = next; steps += 1
            }
            for (i, v) in n.evals where i < score.count { score[i] += v }
        }
        func sigmoid(_ v: Double) -> Double { 1 / (1 + Foundation.exp(-v)) }
        func softmax(_ z: [Double]) -> [Double] { let m = z.max() ?? 0; let e = z.map { Foundation.exp($0 - m) }; let s = e.reduce(0, +); return e.map { $0 / s } }
        let outName = _spec.predicted ?? _spec.outputs.first?.name ?? "prediction"
        var out: [String: Any] = [:]
        if _spec.kind == "treeEnsembleRegressor" {
            let y = t.post == 2 ? score.map(sigmoid) : score
            if y.count == 1, _spec.outputs.first(where: { $0.name == outName })?.type != .multiArray { out[outName] = MLFeatureValue(double: y[0]) }
            else { out[outName] = MLFeatureValue(multiArray: try MLMultiArray(y)) }
        } else {
            let labels = _spec.labels
            guard !labels.isEmpty else { throw _mlError(.generic, "the classifier has no class labels") }
            var probs: [Double]
            if score.count == 1 && labels.count == 2 {
                let p = t.post == 2 ? sigmoid(score[0]) : score[0]; probs = [1 - p, p]     // the second class's probability
            } else {
                switch t.post {
                case 1: probs = softmax(score)
                case 3: probs = Array(softmax([0] + score).dropFirst()); if probs.count == labels.count - 1 { probs.insert(max(0, 1 - probs.reduce(0, +)), at: 0) }
                case 2: probs = score.map(sigmoid)
                default: probs = score
                }
            }
            guard probs.count == labels.count else { throw _mlError(.generic, "the tree ensemble gives \(probs.count) scores for \(labels.count) labels") }
            out.merge(try _classified(labels, probs, outName)) { a, _ in a }
        }
        return try MLDictionaryFeatureProvider(dictionary: out)
    }

    /// the predicted label and the probabilities dictionary
    func _classified(_ labels: [Any], _ probs: [Double], _ outName: String) throws -> [String: Any] {
        var out: [String: Any] = [:]
        let best = probs.indices.max { probs[$0] < probs[$1] }!
        var dict: [AnyHashable: NSNumber] = [:]
        for (l, p) in zip(labels, probs) { if let s = l as? String { dict[s] = NSNumber(value: p) } else if let i = l as? Int64 { dict[i] = NSNumber(value: p) } }
        if let s = labels[best] as? String { out[outName] = MLFeatureValue(string: s) } else if let i = labels[best] as? Int64 { out[outName] = MLFeatureValue(int64: i) }
        out[_spec.probabilities ?? (outName + "Probability")] = try MLFeatureValue(dictionary: dict)
        return out
    }

    func _neuralNetwork(_ input: MLFeatureProvider) throws -> MLFeatureProvider {
        var blobs: [String: [Double]] = [:], shapes: [String: [Int]] = [:]
        for d in _spec.inputs {
            guard let v = input.featureValue(for: d.name) else {
                if d.isOptional { continue }
                throw _mlError(.featureType, "missing input feature '\(d.name)'")
            }
            switch v.type {
            case .double: blobs[d.name] = [v.doubleValue]; shapes[d.name] = [1]
            case .int64: blobs[d.name] = [Double(v.int64Value)]; shapes[d.name] = [1]
            case .multiArray:
                blobs[d.name] = v.multiArrayValue?._values ?? []; shapes[d.name] = v.multiArrayValue?.shape.map(\.integerValue) ?? []
            default: throw _mlError(.featureType, "input '\(d.name)' must be a number or multi-array (isim runs neural networks on arrays)")
            }
        }
        func value(_ name: String, _ layer: _MLLayer) throws -> [Double] {
            guard let v = blobs[name] else { throw _mlError(.generic, "layer '\(layer.name)' reads '\(name)', which nothing produced") }
            return v
        }
        for l in _spec.layers {
            guard let first = l.inputs.first else { throw _mlError(.generic, "layer '\(l.name)' has no input") }
            var x = try value(first, l)
            var shape = shapes[first] ?? [x.count]
            switch l.kind {
            case .innerProduct(let ins, let outs, let w, let b):
                guard x.count == ins, w.count == ins * outs else {
                    throw _mlError(.generic, "inner product '\(l.name)' takes \(ins) values and has \(w.count) weights for \(outs) outputs; got \(x.count) values")
                }
                x = (0..<outs).map { o in var s = b.map { $0[o] } ?? 0; for i in 0..<ins { s += w[o * ins + i] * x[i] }; return s }
                shape = [outs]
            case .activation(let type, let a, let bb):
                let f: (Double) -> Double
                switch type {
                case 5: f = { a * $0 + bb }
                case 10: f = { max(0, $0) }
                case 15: f = { $0 >= 0 ? $0 : a * $0 }
                case 20: f = { $0 > a ? $0 : 0 }
                case 30: f = { Foundation.tanh($0) }
                case 31: f = { a * Foundation.tanh(bb * $0) }
                case 40: f = { 1 / (1 + Foundation.exp(-$0)) }
                case 41: f = { min(1, max(0, a * $0 + bb)) }
                case 50: f = { $0 >= 0 ? $0 : a * (Foundation.exp($0) - 1) }
                case 60: f = { $0 / (1 + abs($0)) }
                case 70: f = { Foundation.log(1 + Foundation.exp($0)) }
                default: throw _mlError(.generic, "isim cannot run activation \(type) of layer '\(l.name)'")
                }
                x = x.map(f)
            case .softmax:
                let m = x.max() ?? 0; let e = x.map { Foundation.exp($0 - m) }; let s = e.reduce(0, +); x = e.map { $0 / s }
            case .flatten: shape = [x.count]
            case .reshape(let target):
                let n = target.reduce(1, *)
                guard n == x.count || target.isEmpty else { throw _mlError(.generic, "reshape '\(l.name)' to \(target) cannot hold \(x.count) values") }
                shape = target.isEmpty ? [x.count] : target
            case .concat:
                for name in l.inputs.dropFirst() { x += try value(name, l) }
                shape = [x.count]
            case .add(let alpha), .multiply(let alpha):
                let isAdd: Bool = { if case .add = l.kind { return true } else { return false } }()
                if l.inputs.count == 1 { x = x.map { isAdd ? $0 + alpha : $0 * alpha } }
                for name in l.inputs.dropFirst() {
                    let y = try value(name, l)
                    let n = max(x.count, y.count)
                    guard x.count == n || x.count == 1, y.count == n || y.count == 1 else { throw _mlError(.generic, "layer '\(l.name)' combines \(x.count) and \(y.count) values") }
                    x = (0..<n).map { i in let a = x[x.count == 1 ? 0 : i], b = y[y.count == 1 ? 0 : i]; return isAdd ? a + b : a * b }
                    if x.count == n && shape.reduce(1, *) != n { shape = [n] }
                }
            case .batchnorm(let c, let gamma, let beta, let mean, let variance, let eps):
                guard c > 0, x.count % c == 0 else { throw _mlError(.generic, "batch norm '\(l.name)' has \(c) channels for \(x.count) values") }
                let per = x.count / c
                for ch in 0..<c {
                    let g = ch < gamma.count ? gamma[ch] : 1, b = ch < beta.count ? beta[ch] : 0
                    let m = ch < mean.count ? mean[ch] : 0, v = ch < variance.count ? variance[ch] : 1
                    for i in 0..<per { x[ch * per + i] = g * (x[ch * per + i] - m) / (v + eps).squareRoot() + b }
                }
            case .custom(let className, let weights, let parameters):
                let module = (Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "").replacingOccurrences(of: "-", with: "_")
                let found: AnyClass? = NSClassFromString(className) ?? NSClassFromString(module + "." + className)
                guard let cls = found as? MLCustomLayer.Type else {
                    throw _mlError(.customLayer, "the custom layer class \(className) is not in the app (it must be an @objc class conforming to MLCustomLayer)")
                }
                let impl = try cls.init(parameterDictionary: parameters)
                try impl.setWeightData(weights)
                let ins = try l.inputs.map { name -> MLMultiArray in
                    let v = try value(name, l), sh = shapes[name] ?? [v.count]
                    let a = try MLMultiArray(shape: sh.map { NSNumber(value: $0) }, dataType: .double)
                    for (i, e) in v.enumerated() { a[i] = NSNumber(value: e) }
                    return a
                }
                let outShapes = try impl.outputShapes(forInputShapes: ins.map(\.shape))
                let outs = try outShapes.map { try MLMultiArray(shape: $0, dataType: .double) }
                try impl.evaluate(inputs: ins, outputs: outs)
                for (name, a) in zip(l.outputs, outs) { blobs[name] = a._values; shapes[name] = a.shape.map(\.integerValue) }
                continue
            case .unsupported:
                throw _mlError(.generic, "isim cannot run \(l.typeName) (layer '\(l.name)'); it runs inner product, activation, softmax, batch normalization, add, multiply, flatten, reshape, concat and custom layers")
            }
            for name in l.outputs { blobs[name] = x; shapes[name] = shape }
        }
        var out: [String: Any] = [:]
        let outName = _spec.predicted ?? _spec.outputs.first?.name ?? "prediction"
        if _spec.kind == "neuralNetworkClassifier" {
            let probName = _spec.labelProbabilityLayer ?? _spec.layers.last?.outputs.first ?? ""
            guard let probs = blobs[probName] else { throw _mlError(.generic, "the classifier's probability layer '\(probName)' gave nothing") }
            guard probs.count == _spec.labels.count else { throw _mlError(.generic, "the classifier gives \(probs.count) probabilities for \(_spec.labels.count) labels") }
            out.merge(try _classified(_spec.labels, probs, outName)) { a, _ in a }
        }
        for d in _spec.outputs where out[d.name] == nil {
            guard let v = blobs[d.name] else { throw _mlError(.generic, "no layer produces the output '\(d.name)'") }
            if d.type == .double, v.count == 1 { out[d.name] = MLFeatureValue(double: v[0]); continue }
            let declared = d.multiArrayConstraint?.shape.map(\.integerValue) ?? []
            let sh = !declared.isEmpty && declared.reduce(1, *) == v.count ? declared : (shapes[d.name].flatMap { $0.reduce(1, *) == v.count ? $0 : nil } ?? [v.count])
            let a = try MLMultiArray(shape: sh.map { NSNumber(value: $0) }, dataType: d.multiArrayConstraint?.dataType ?? .double)
            for (i, e) in v.enumerated() { a[i] = NSNumber(value: e) }
            out[d.name] = MLFeatureValue(multiArray: a)
        }
        return try MLDictionaryFeatureProvider(dictionary: out)
    }

    // MARK: states

    /// A new state for the model's stateful predictions (zeroed buffers, one per state the model declares).
    public func makeState() -> MLState {
        var buffers: [String: MLMultiArray] = [:]
        for d in _spec.states {
            let shape = d.multiArrayConstraint?.shape ?? [1]
            buffers[d.name] = try? MLMultiArray(shape: shape.isEmpty ? [1] : shape, dataType: d.multiArrayConstraint?.dataType ?? .float32)
        }
        return MLState(buffers: buffers)
    }
    /// A prediction that reads and updates `state` (isim: models with states are ML programs, which it cannot run).
    public func prediction(from input: MLFeatureProvider, using state: MLState, options: MLPredictionOptions = MLPredictionOptions()) throws -> MLFeatureProvider {
        try _statefulPrediction(input, options)
    }
    public func prediction(from input: MLFeatureProvider, using state: MLState, options: MLPredictionOptions = MLPredictionOptions()) async throws -> MLFeatureProvider {
        try _statefulPrediction(input, options)
    }
    func _statefulPrediction(_ input: MLFeatureProvider, _ options: MLPredictionOptions) throws -> MLFeatureProvider {
        if !_spec.states.isEmpty { throw _mlError(.generic, "isim cannot run stateful \(_spec.kind) models") }
        return try prediction(from: input, options: options)
    }
}

/// A model's state between predictions: its buffers by name.
public final class MLState: @unchecked Sendable {
    let _buffers: [String: MLMultiArray]
    let _lock = NSLock()
    init(buffers: [String: MLMultiArray]) { _buffers = buffers }
    /// the buffer of the state `stateName`
    public func withMultiArray<R>(for stateName: String, _ body: (MLMultiArray) throws -> R) rethrows -> R {
        _lock.lock(); defer { _lock.unlock() }
        guard let b = _buffers[stateName] else { preconditionFailure("the model has no state named \(stateName)") }
        return try body(b)
    }
    /// the only buffer, for a model with one state
    public func withMultiArray<R>(_ body: (MLMultiArray) -> R) throws -> R {
        _lock.lock(); defer { _lock.unlock() }
        guard _buffers.count == 1, let b = _buffers.values.first else { throw _mlError(.generic, "the model has \(_buffers.count) states; name one") }
        return body(b)
    }
}

// MARK: - compute devices and plans

public protocol MLComputeDeviceProtocol: Sendable {}
/// isim runs Core ML on the CPU: the only compute device
public final class MLCPUComputeDevice: NSObject, MLComputeDeviceProtocol, @unchecked Sendable {}
public final class MLGPUComputeDevice: NSObject, MLComputeDeviceProtocol, @unchecked Sendable {}
public final class MLNeuralEngineComputeDevice: NSObject, MLComputeDeviceProtocol, @unchecked Sendable {
    public var totalCoreCount: Int { 0 }
}
public enum MLComputeDevice: Sendable {
    case cpu(MLCPUComputeDevice), gpu(MLGPUComputeDevice), neuralEngine(MLNeuralEngineComputeDevice)
    public static var allComputeDevices: [MLComputeDevice] { [.cpu(MLCPUComputeDevice())] }
}

/// A model's structure, from its spec.
public enum MLModelStructure: Sendable {
    case neuralNetwork(NeuralNetwork), program(Program), pipeline(Pipeline), unsupported
    public struct NeuralNetwork: Sendable {
        public struct Layer: Sendable {
            public let name: String
            public let type: String
            public let inputNames: [String]
            public let outputNames: [String]
        }
        public let layers: [Layer]
    }
    /// isim does not read ML programs' operations (empty)
    public struct Program: Sendable {
        public struct Operation: Sendable {
            public let operatorName: String
            public let inputs: [String]
            public let outputs: [String]
        }
        public let functions: [String: [Operation]]
    }
    public struct Pipeline: Sendable {
        public let subModels: [(name: String, structure: MLModelStructure)]
    }
    public static func load(contentsOf url: URL) async throws -> MLModelStructure {
        let m = try MLModel(contentsOf: url)
        switch m._spec.kind {
        case "neuralNetwork", "neuralNetworkRegressor", "neuralNetworkClassifier":
            return .neuralNetwork(NeuralNetwork(layers: m._spec.layers.map { NeuralNetwork.Layer(name: $0.name, type: $0.typeName, inputNames: $0.inputs, outputNames: $0.outputs) }))
        case "mlProgram": return .program(Program(functions: [:]))
        default: return .unsupported
        }
    }
}

/// Where each layer runs: the CPU on isim.
public final class MLComputePlan: @unchecked Sendable {
    public struct DeviceUsage: Sendable {
        public let preferred: MLComputeDevice
        public let supported: [MLComputeDevice]
    }
    public struct Cost: Sendable { public let weight: Double }
    public let modelStructure: MLModelStructure
    init(_ s: MLModelStructure) { modelStructure = s }
    public static func load(contentsOf url: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> MLComputePlan {
        MLComputePlan(try await MLModelStructure.load(contentsOf: url))
    }
    public func deviceUsage(for layer: MLModelStructure.NeuralNetwork.Layer) -> DeviceUsage? {
        let cpu = MLComputeDevice.cpu(MLCPUComputeDevice())
        return DeviceUsage(preferred: cpu, supported: [cpu])
    }
    public func deviceUsage(for operation: MLModelStructure.Program.Operation) -> DeviceUsage? { nil }
    /// isim has no cost model (nil)
    public func estimatedCost(of operation: MLModelStructure.Program.Operation) -> Cost? { nil }
}

// MARK: - update tasks (stub)

public struct MLParameterKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let learningRate = MLParameterKey(rawValue: "learningRate"), epochs = MLParameterKey(rawValue: "epochs")
    public static let miniBatchSize = MLParameterKey(rawValue: "miniBatchSize"), momentum = MLParameterKey(rawValue: "momentum")
}
public struct MLMetricKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let lossValue = MLMetricKey(rawValue: "lossValue"), epochIndex = MLMetricKey(rawValue: "epochIndex")
    public static let miniBatchIndex = MLMetricKey(rawValue: "miniBatchIndex")
}
public struct MLUpdateProgressEvent: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let trainingBegin = MLUpdateProgressEvent(rawValue: 1), epochEnd = MLUpdateProgressEvent(rawValue: 2)
    public static let miniBatchEnd = MLUpdateProgressEvent(rawValue: 4)
}
public protocol MLWritable {
    func write(to url: URL) throws
}
open class MLUpdateContext: NSObject, @unchecked Sendable {
    public let task: MLUpdateTask
    public let model: MLModel & MLWritable
    public let event: MLUpdateProgressEvent
    public let metrics: [MLMetricKey: Any]
    public let parameters: [MLParameterKey: Any]
    init(task: MLUpdateTask, model: MLModel & MLWritable, event: MLUpdateProgressEvent) {
        self.task = task; self.model = model; self.event = event; metrics = [:]; parameters = [:]
    }
}
open class MLUpdateProgressHandlers: NSObject, @unchecked Sendable {
    let events: MLUpdateProgressEvent
    let progress: ((MLUpdateContext) -> Void)?
    let completion: (MLUpdateContext) -> Void
    public init(forEvents interestedEvents: MLUpdateProgressEvent, progressHandler: ((MLUpdateContext) -> Void)?, completionHandler: @escaping (MLUpdateContext) -> Void) {
        events = interestedEvents; progress = progressHandler; completion = completionHandler
    }
}
/// On-device training (stub): isim cannot update models, so creating a task throws MLModelError.update.
open class MLUpdateTask: NSObject, @unchecked Sendable {
    static func _unsupported(_ url: URL) -> NSError {
        _mlError(.update, "isim cannot train models on the device (\(url.lastPathComponent)): model updates need Apple's Core ML runtime")
    }
    public convenience init(forModelAt modelURL: URL, trainingData: MLBatchProvider, configuration: MLModelConfiguration? = nil,
                            completionHandler: @escaping (MLUpdateContext) -> Void) throws { throw Self._unsupported(modelURL) }
    public convenience init(forModelAt modelURL: URL, trainingData: MLBatchProvider, configuration: MLModelConfiguration? = nil,
                            progressHandlers: MLUpdateProgressHandlers) throws { throw Self._unsupported(modelURL) }
    public convenience init(forModelAtURL modelURL: URL, trainingData: MLBatchProvider, configuration: MLModelConfiguration? = nil,
                            completionHandler: @escaping (MLUpdateContext) -> Void) throws { throw Self._unsupported(modelURL) }
    public convenience init(forModelAtURL modelURL: URL, trainingData: MLBatchProvider, configuration: MLModelConfiguration? = nil,
                            progressHandlers: MLUpdateProgressHandlers) throws { throw Self._unsupported(modelURL) }
    public override init() { super.init() }
    open func resume() {}
    open func resume(withParameters updateParameters: [MLParameterKey: Any]) {}
    open func cancel() {}
}
